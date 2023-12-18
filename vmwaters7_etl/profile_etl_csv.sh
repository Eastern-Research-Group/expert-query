#/bin/sh

###############################################################################
# Configuration

# Number of threads used by GDAL processes
gdal_num_threads=1

# Chunk size to use when uploading to S3
chunk_size=1000

###############################################################################

###############################################################################
# Verify ogr2ogr
# PATH must include the GDAL bin 
# such as /usr/app/oracle/product/19.3.0/md/gdal/bin
# LD_LIBRARY_PATH must include both
# oracle libs such as /usr/app/oracle/product/19.3.0/lib
# and gdal libs such as /usr/app/oracle/product/19.3.0/md/gdal/lib
# GDAL_HOME should point to the Oracle GDAL home
# such as /usr/app/oracle/product/19.3.0/md/gdal
# GDAL_DATA should point to supplemental GDAL files
# such as /usr/app/oracle/product/19.3.0/md/gdal/data
# GDAL_DRIVER_PATH should include plugins dir 
# such as/usr/app/oracle/product/19.3.0/md/gdal/lib/gdalplugin
if ! command -v ogr2ogr &> /dev/null
then
   echo "unable to execute ogr2ogr under path"
   exit -1
fi

if ! command -v ogrinfo &> /dev/null
then
   echo "unable to execute ogrinfo under path"
   exit -1
fi

###############################################################################
# Verify s3cmd is in place
# Fetch the archive from GitHub at https://github.com/s3tools/s3cmd
s3cmd_location=./s3cmd-master/s3cmd

if [ ! -f ${s3cmd_location} ]
then
   echo "unable to find s3cmd at $s3cmd_location"
   exit -1
fi

###############################################################################
# Load the secrets file from the users home
# Secrets must contain values for:
# DB_USERNAME
# DB_PASSWORD
# DB_HOSTSTRING
#
# Load list of environments to processes
# ENVS=DEV,STG,PRD
#
# XXX_AWS_BUCKET_NAME
# XXX_AWS_BUCKET_DIR
# XXX_AWS_REGION
# XXX_AWS_S3_ENDPOINT
# XXX_AWS_ACCESS_KEY_ID
# XXX_AWS_SECRET_ACCESS_KEY
#
# Set DO_CLEANUP to True in order to remove staging diretory files
# DO_CLEANUP
# Set FORCE_REFRESH to True to ignore refresh QA errors
# FORCE_REFRESH
# Set UPLOAD_TO_S3 to False to forgo actual pushes to S3
# UPLOAD_TO_S3

# alter secrets location if you need to place this elsewhere
secrets_location=~/.env

if [ ! -f ${secrets_location} ]
then
   echo "unable to read .env secrets file at $secrets_location"
   exit -1
fi

IFS=
while read -r LINE; do
   if [[ $LINE == *'='* ]] && [[ $LINE != '#'* ]]; then
      ENV_VAR="$(echo $LINE | envsubst)"
      eval "export $ENV_VAR"
   fi
done < ${secrets_location}

###############################################################################
# Global GDAL configuration 
export GDAL_DISABLE_READDIR_ON_OPEN=TRUE
export CPL_VSIL_GZIP_WRITE_PROPERTIES=NO
export VSI_CACHE=TRUE
export VSI_CACHE_SIZE=100000000
staging_dir=${STAGING_DIR}

###############################################################################
# Determine the ETL julian ts value for the load to drive logging actions
ts=$(date +%s)

logfile=${staging_dir}/log_${ts}.txt
statusfile=${staging_dir}/status_${ts}.json
latestfile=${staging_dir}/latest_${ts}.json
readyfile=${staging_dir}/ready_${ts}.json

echo `date +"%Y-%m-%d %H:%M:%S"`": Starting ATTAINS profile ETL for ${ts}" | tee -a ${logfile}

setaws()
{
   z=$(eval echo \$\{${ENVN}_AWS_ACCESS_KEY_ID\})
   export AWS_ACCESS_KEY_ID=$z
   
   z=$(eval echo \$\{${ENVN}_AWS_SECRET_ACCESS_KEY\})
   export AWS_SECRET_ACCESS_KEY=$z
   
   z=$(eval echo \$\{${ENVN}_AWS_REGION\})
   export AWS_REGION=$z
   
   z=$(eval echo \$\{${ENVN}_AWS_S3_ENDPOINT\})
   export AWS_S3_ENDPOINT=$z

   z=$(eval echo \$\{${ENVN}_AWS_BUCKET_NAME\})
   export AWS_BUCKET_NAME=$z
   
   z=$(eval echo \$\{${ENVN}_AWS_BUCKET_DIR\})
   export AWS_BUCKET_DIR=$z
}

putlog()
{
   if [ -z "${UPLOAD_TO_S3}" ] || [ "${UPLOAD_TO_S3}" = "True" ]
   then
      python ${s3cmd_location} --quiet                               \
         --region=${AWS_REGION}                                      \
         --host=${AWS_S3_ENDPOINT}                               \
         --host-bucket=${AWS_BUCKET_NAME}.${AWS_S3_ENDPOINT}         \
         put ${logfile}                                              \
         s3://${AWS_BUCKET_NAME}${AWS_BUCKET_DIR}/${ts}/logfile.txt
         
   fi
}

putstatus()
{
   if [ -z "${UPLOAD_TO_S3}" ] || [ "${UPLOAD_TO_S3}" = "True" ]
   then
      python ${s3cmd_location} --quiet                               \
         --region=${AWS_REGION}                                      \
         --host=${AWS_S3_ENDPOINT}                                   \
         --host-bucket=${AWS_BUCKET_NAME}.${AWS_S3_ENDPOINT}         \
         put ${statusfile}                                           \
         s3://${AWS_BUCKET_NAME}${AWS_BUCKET_DIR}/${ts}/status.json
         
   fi
}

putready()
{
   if [ -z "${UPLOAD_TO_S3}" ] || [ "${UPLOAD_TO_S3}" = "True" ]
   then
      python ${s3cmd_location} --quiet                               \
         --region=${AWS_REGION}                                      \
         --host=${AWS_S3_ENDPOINT}                                   \
         --host-bucket=${AWS_BUCKET_NAME}.${AWS_S3_ENDPOINT}         \
         put ${readyfile}                                            \
         s3://${AWS_BUCKET_NAME}${AWS_BUCKET_DIR}/${ts}/ready.json
         
   fi
}

putlatest()
{
   if [ -z "${UPLOAD_TO_S3}" ] || [ "${UPLOAD_TO_S3}" = "True" ]
   then
      python ${s3cmd_location} --quiet                               \
         --region=${AWS_REGION}                                      \
         --host=${AWS_S3_ENDPOINT}                                   \
         --host-bucket=${AWS_BUCKET_NAME}.${AWS_S3_ENDPOINT}         \
         put ${latestfile}                                           \
         s3://${AWS_BUCKET_NAME}${AWS_BUCKET_DIR}/latest.json
         
   fi
}

stopit=0
###############################################################################
echo `date +"%Y-%m-%d %H:%M:%S"`": Querying production bucket for information on the last extraction." | tee -a ${logfile}
ENVN=PRD
setaws

python ${s3cmd_location} --quiet                                  \
   --region=${AWS_REGION}                                         \
   --host=${AWS_S3_ENDPOINT}                                      \
   --host-bucket=${AWS_BUCKET_NAME}.${AWS_S3_ENDPOINT}            \
   get s3://${AWS_BUCKET_NAME}${AWS_BUCKET_DIR}/latest.json ${latestfile} 2> /dev/null

if [[ $? -eq 0 ]]
then
   last_tag=$(cat ${latestfile} | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["tag"];')
   last_julian=$(cat ${latestfile} | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["julian"];')
   echo `date +"%Y-%m-%d %H:%M:%S"`": latest.json reports last tag as ${last_tag} under ${last_julian}." | tee -a ${logfile}
   
else
   last_tag=""
   last_julian=""
   echo `date +"%Y-%m-%d %H:%M:%S"`": latest.json file not found in bucket." | tee -a ${logfile}
   
fi
rm -f ${latestfile}

###############################################################################
# Query database if the datasets are in a ready state
tfile1="$(mktemp /tmp/attains_eq.XXXXXXXXX)"
ogrinfo \
   OCI:${DB_USERNAME}/${DB_PASSWORD}@${DB_HOSTSTRING}:ATTAINS_APP.PROFILE_TMDL        \
   -q -nomd -nocount -noextent                                                        \
   -sql "SELECT TO_CHAR(attains_eq.util.go_nogo('JSON')) AS ready FROM dual" |        \
awk '/^  READY \(String\) \= /{$1=$2=$3="";gsub(/^[ ]+/,"",$0);print $0}' > ${tfile1}

tfile2="$(mktemp /tmp/attains_eq.XXXXXXXXX)"
ogrinfo \
   OCI:${DB_USERNAME}/${DB_PASSWORD}@${DB_HOSTSTRING}:ATTAINS_APP.PROFILE_TMDL        \
   -q -nomd -nocount -noextent                                                        \
   -sql "SELECT TO_CHAR(attains_eq.util.mv_counts('JSON')) AS ready FROM dual" |      \
awk '/^  READY \(String\) \= /{$1=$2=$3="";gsub(/^[ ]+/,"",$0);print $0}' > ${tfile2}

tfile3="$(mktemp /tmp/attains_eq.XXXXXXXXX)"
awk  '{print substr($0,1,length($0) - 1)}' ${tfile1} >  ${tfile3}
echo ',' >> ${tfile3}
awk  '{print substr($0,2,length($0) - 1)}' ${tfile2} >> ${tfile3}
awk -vORS="" '1' ${tfile3} > ${readyfile}

rm -Rf ${tfile1}
rm -Rf ${tfile2}
rm -Rf ${tfile3}

ready_status=$(cat ${readyfile} | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["ready"];')

etl_tag=$(cat ${readyfile} | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["tag"];')
echo `date +"%Y-%m-%d %H:%M:%S"`": database reports tag $etl_tag ready to extract." | tee -a ${logfile}

if [ "$etl_tag" = "$last_tag" ]
then
   if [ "${FORCE_REFRESH}" = "True" ]
   then
     echo `date +"%Y-%m-%d %H:%M:%S"`": $etl_tag has already been extracted per ready.json in bucket."          | tee -a ${logfile}
     echo `date +"%Y-%m-%d %H:%M:%S"`": forcing refresh of $etl_tag due to .env setting."                       | tee -a ${logfile}
   
   else
     echo `date +"%Y-%m-%d %H:%M:%S"`": $etl_tag has already been extracted per ready.json in bucket. Exiting." | tee -a ${logfile}
     stopit=1
     
   fi
   
fi

###############################################################################
# Update all buckets with the current log and ready files
# Exit if ETL should abend
###############################################################################
IFS=,
for envn in ${ENVS}
do
   ENVN=$envn
   setaws
   putlog
   putready

done

if [ $stopit -ne 0 ]
then
   exit 1
fi

###############################################################################
# Begin the extract in three threads
# note the usage of -fz with the fifo input to zip makes no sense but is necessary
# to work on RedHat.  When no flag is given the --fifo input seems forced into
# 32 bit mode which bombs when the archive tops 2GB.  However when -fz is expressly
# provided this seems to trigger some internal logic that forces over to 64 bit processing.
#
# A clause may be provided in the .env secrets file for testing 
# a limited set of data to validate the workflow
#WHERE_CLAUSE="WHERE rownum <= 100"
#
if [ ! -z "${WHERE_CLAUSE}" ]
then
   clause="${WHERE_CLAUSE}"
   echo `date +"%Y-%m-%d %H:%M:%S"`": using custom clause ${WHERE_CLAUSE}." | tee -a ${logfile}
   
else
   clause=""

fi

thread1()
{   
   ############################################################################
   # PROFILE_ACTIONS
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting actions in thread 1." | tee -a ${logfile}
   ogr2ogr \
      --config GDAL_NUM_THREADS ${gdal_num_threads}                    \
      -f CSV /vsistdout/                                               \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${DB_HOSTSTRING}:ATTAINS_APP.PROFILE_ACTIONS \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,assessmentunitid,assessmentunitname,actionid,actionname,completiondate,fiscalyearestablished,parameter,parametergroup,locationdescription,actiontype,watertype,watersize,watersizeunits,actionagency,inindiancountry,includeinmeasure FROM ATTAINS_APP.PROFILE_ACTIONS a ${clause}" \
      -preserve_fid -lco LINEFORMAT=LF                                 \
      -lco STRING_QUOTING=IF_NEEDED                         |          \
   gzip -q > ${staging_dir}/actions_${ts}.csv.gz
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": Creating actions zipfile." | tee -a ${logfile}
   rm -Rf ${staging_dir}/actions.csv
   mkfifo ${staging_dir}/actions.csv
   gzip -q -d -c ${staging_dir}/actions_${ts}.csv.gz > ${staging_dir}/actions.csv & \
      zip -q -j -fz --fifo ${staging_dir}/actions_${ts}.csv.zip ${staging_dir}/actions.csv
   rm -Rf ${staging_dir}/actions.csv

   ###############################################################################
   IFS=,
   for envn in ${ENVS}
   do
      ENVN=$envn
	   setaws
     
	   if [ -z "${UPLOAD_TO_S3}" ] || [ "${UPLOAD_TO_S3}" = "True" ]
      then
         echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading actions gz to $envn S3." | tee -a ${logfile}
         python ${s3cmd_location} --quiet                                    \
            --multipart-chunk-size-mb ${chunk_size}                          \
            --mime-type=application/gzip                                     \
            --no-guess-mime-type                                             \
            --add-header=content-encoding:gzip                               \
            --region=${AWS_REGION}                                           \
            --host=${AWS_S3_ENDPOINT}                                        \
            --host-bucket=${AWS_BUCKET_NAME}.${AWS_S3_ENDPOINT}              \
            put ${staging_dir}/actions_${ts}.csv.gz                          \
            s3://${AWS_BUCKET_NAME}${AWS_BUCKET_DIR}/${ts}/actions.csv.gz
            
         echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading actions zip to $envn S3." | tee -a ${logfile}
         python ${s3cmd_location} --quiet                                    \
            --multipart-chunk-size-mb ${chunk_size}                          \
            --region=${AWS_REGION}                                           \
            --host=${AWS_S3_ENDPOINT}                                        \
            --host-bucket=${AWS_BUCKET_NAME}.${AWS_S3_ENDPOINT}              \
            put ${staging_dir}/actions_${ts}.csv.zip                         \
            s3://${AWS_BUCKET_NAME}${AWS_BUCKET_DIR}/${ts}/actions.csv.zip
      
      fi
      
   done

   profile_actions_size_raw=$(unzip -Zt "${staging_dir}/actions_${ts}.csv.zip" | awk '{ print $3 }')
   profile_actions_size_gz=$(stat -c%s "${staging_dir}/actions_${ts}.csv.gz")
   profile_actions_size_zip=$(stat -c%s "${staging_dir}/actions_${ts}.csv.zip")
   echo "profile_actions.csv,${profile_actions_size_raw},${profile_actions_size_gz},${profile_actions_size_zip}" >> ${staging_dir}/thread.txt
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": ETL of actions complete." | tee -a ${logfile}   
   
   ############################################################################
   # PROFILE_ASSESSMENT_UNITS
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting assessment_units in thread 1." | tee -a ${logfile}
   ogr2ogr \
      --config GDAL_NUM_THREADS ${gdal_num_threads}                    \
      -f CSV /vsistdout/                                               \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${DB_HOSTSTRING}:ATTAINS_APP.PROFILE_ASSESSMENT_UNITS \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,reportingcycle,cycleid,assessmentunitid,assessmentunitname,locationdescription,watertype,watersize,watersizeunits,assessmentunitstatus,useclassname,sizesource,sourcescale,locationtypecode,locationtext FROM ATTAINS_APP.PROFILE_ASSESSMENT_UNITS a ${clause}" \
      -preserve_fid -lco LINEFORMAT=LF                                 \
      -lco STRING_QUOTING=IF_NEEDED                         |          \
   gzip -q > ${staging_dir}/assessment_units_${ts}.csv.gz
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": Creating assessment_units zipfile." | tee -a ${logfile}
   rm -Rf ${staging_dir}/assessment_units.csv
   mkfifo ${staging_dir}/assessment_units.csv
   gzip -q -d -c ${staging_dir}/assessment_units_${ts}.csv.gz > ${staging_dir}/assessment_units.csv & \
      zip -q -j -fz --fifo ${staging_dir}/assessment_units_${ts}.csv.zip ${staging_dir}/assessment_units.csv
   rm -Rf ${staging_dir}/assessment_units.csv
    
   ###############################################################################
   IFS=,
   for envn in ${ENVS}
   do
      ENVN=$envn
	   setaws
     
	   if [ -z "${UPLOAD_TO_S3}" ] || [ "${UPLOAD_TO_S3}" = "True" ]
      then
         echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading assessment_units gz to $envn S3." | tee -a ${logfile}
         python ${s3cmd_location} --quiet                                    \
            --multipart-chunk-size-mb ${chunk_size}                          \
            --mime-type=application/gzip                                     \
            --no-guess-mime-type                                             \
            --add-header=content-encoding:gzip                               \
            --region=${AWS_REGION}                                           \
            --host=${AWS_S3_ENDPOINT}                                        \
            --host-bucket=${AWS_BUCKET_NAME}.${AWS_S3_ENDPOINT}              \
            put ${staging_dir}/assessment_units_${ts}.csv.gz                 \
            s3://${AWS_BUCKET_NAME}${AWS_BUCKET_DIR}/${ts}/assessment_units.csv.gz
 
         echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading assessment_units zip to $envn S3." | tee -a ${logfile}
         python ${s3cmd_location} --quiet                                    \
            --multipart-chunk-size-mb ${chunk_size}                          \
            --region=${AWS_REGION}                                           \
            --host=${AWS_S3_ENDPOINT}                                        \
            --host-bucket=${AWS_BUCKET_NAME}.${AWS_S3_ENDPOINT}              \
            put ${staging_dir}/assessment_units_${ts}.csv.zip                \
            s3://${AWS_BUCKET_NAME}${AWS_BUCKET_DIR}/${ts}/assessment_units.csv.zip  

      fi
      
   done
   
   profile_assessment_units_size_raw=$(unzip -Zt "${staging_dir}/assessment_units_${ts}.csv.zip" | awk '{ print $3 }')
   profile_assessment_units_size_gz=$(stat -c%s "${staging_dir}/assessment_units_${ts}.csv.gz")
   profile_assessment_units_size_zip=$(stat -c%s "${staging_dir}/assessment_units_${ts}.csv.zip")
   echo "profile_assessment_units.csv,${profile_assessment_units_size_raw},${profile_assessment_units_size_gz},${profile_assessment_units_size_zip}" >> ${staging_dir}/thread.txt
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": ETL of assessment_units complete." | tee -a ${logfile}
   
   ############################################################################
   # PROFILE_ASSESSMENT_UNITS_MONITORING_LOCATIONS
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting assessment_units_monitoring_locations in thread 1." | tee -a ${logfile}
   ogr2ogr \
      --config GDAL_NUM_THREADS ${gdal_num_threads}                    \
      -f CSV /vsistdout/                                               \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${DB_HOSTSTRING}:ATTAINS_APP.PROFILE_ASSESSMENT_UNITS_MONITORING_LOCATIONS \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,reportingcycle,cycleid,assessmentunitid,assessmentunitname,locationdescription,watertype,watersize,watersizeunits,monitoringlocationorgid,monitoringlocationid,monitoringlocationdatalink,assessmentunitstatus,useclassname,sizesource,sourcescale FROM ATTAINS_APP.PROFILE_ASSESSMENT_UNITS_MONITORING_LOCATIONS a ${clause}" \
      -preserve_fid -lco LINEFORMAT=LF                                 \
      -lco STRING_QUOTING=IF_NEEDED                         |          \
   gzip -q > ${staging_dir}/assessment_units_monitoring_locations_${ts}.csv.gz
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": Creating assessment_units_monitoring_locations zipfile." | tee -a ${logfile}
   rm -Rf ${staging_dir}/assessment_units_monitoring_locations.csv
   mkfifo ${staging_dir}/assessment_units_monitoring_locations.csv
   gzip -q -d -c ${staging_dir}/assessment_units_monitoring_locations_${ts}.csv.gz > ${staging_dir}/assessment_units_monitoring_locations.csv & \
      zip -q -j -fz --fifo ${staging_dir}/assessment_units_monitoring_locations_${ts}.csv.zip ${staging_dir}/assessment_units_monitoring_locations.csv
   rm -Rf ${staging_dir}/assessment_units_monitoring_locations.csv
   
   ###############################################################################
   IFS=,
   for envn in ${ENVS}
   do
      ENVN=$envn
	   setaws
     
	   if [ -z "${UPLOAD_TO_S3}" ] || [ "${UPLOAD_TO_S3}" = "True" ]
      then
         echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading assessment_units_monitoring_locations gz to $envn S3." | tee -a ${logfile}
         python ${s3cmd_location} --quiet                                    \
            --multipart-chunk-size-mb ${chunk_size}                          \
            --mime-type=application/gzip                                     \
            --no-guess-mime-type                                             \
            --add-header=content-encoding:gzip                               \
            --region=${AWS_REGION}                                           \
            --host=${AWS_S3_ENDPOINT}                                        \
            --host-bucket=${AWS_BUCKET_NAME}.${AWS_S3_ENDPOINT}              \
            put ${staging_dir}/assessment_units_monitoring_locations_${ts}.csv.gz \
            s3://${AWS_BUCKET_NAME}${AWS_BUCKET_DIR}/${ts}/assessment_units_monitoring_locations.csv.gz
         
         echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading assessment_units_monitoring_locations zip to $envn S3." | tee -a ${logfile}
         python ${s3cmd_location} --quiet                                    \
            --multipart-chunk-size-mb ${chunk_size}                          \
            --region=${AWS_REGION}                                           \
            --host=${AWS_S3_ENDPOINT}                                        \
            --host-bucket=${AWS_BUCKET_NAME}.${AWS_S3_ENDPOINT}              \
            put ${staging_dir}/assessment_units_monitoring_locations_${ts}.csv.zip \
            s3://${AWS_BUCKET_NAME}${AWS_BUCKET_DIR}/${ts}/assessment_units_monitoring_locations.csv.zip
         
      fi
      
   done
   
   profile_assessment_units_monitoring_locations_size_raw=$(unzip -Zt "${staging_dir}/assessment_units_monitoring_locations_${ts}.csv.zip" | awk '{ print $3 }')
   profile_assessment_units_monitoring_locations_size_gz=$(stat -c%s "${staging_dir}/assessment_units_monitoring_locations_${ts}.csv.gz")
   profile_assessment_units_monitoring_locations_size_zip=$(stat -c%s "${staging_dir}/assessment_units_monitoring_locations_${ts}.csv.zip")
   echo "profile_assessment_units_monitoring_locations.csv,${profile_assessment_units_monitoring_locations_size_raw},${profile_assessment_units_monitoring_locations_size_gz},${profile_assessment_units_monitoring_locations_size_zip}" >> ${staging_dir}/thread.txt
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": ETL of assessment_units_monitoring_locations complete." | tee -a ${logfile}
   
   ############################################################################
   # PROFILE_SOURCES
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting sources in thread 1." | tee -a ${logfile}
   ogr2ogr \
      --config GDAL_NUM_THREADS ${gdal_num_threads}                    \
      -f CSV /vsistdout/                                               \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${DB_HOSTSTRING}:ATTAINS_APP.PROFILE_SOURCES \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,reportingcycle,cycleid,assessmentunitid,assessmentunitname,overallstatus,epaircategory,stateircategory,sourcename,confirmed,parametergroup,causename,locationdescription,watertype,watersize,watersizeunits FROM ATTAINS_APP.PROFILE_SOURCES a ${clause}" \
      -preserve_fid -lco LINEFORMAT=LF                                 \
      -lco STRING_QUOTING=IF_NEEDED                         |          \
   gzip -q > ${staging_dir}/sources_${ts}.csv.gz
      
   echo `date +"%Y-%m-%d %H:%M:%S"`": Creating sources zipfile." | tee -a ${logfile}
   rm -Rf ${staging_dir}/sources.csv
   mkfifo ${staging_dir}/sources.csv
   gzip -q -d -c ${staging_dir}/sources_${ts}.csv.gz > ${staging_dir}/sources.csv & \
      zip -q -j -fz --fifo ${staging_dir}/sources_${ts}.csv.zip ${staging_dir}/sources.csv
   rm -Rf ${staging_dir}/sources.csv
   
   ###############################################################################
   IFS=,
   for envn in ${ENVS}
   do
      ENVN=$envn
	   setaws
     
	   if [ -z "${UPLOAD_TO_S3}" ] || [ "${UPLOAD_TO_S3}" = "True" ]
      then
         echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading sources files to $envn S3." | tee -a ${logfile}
         python ${s3cmd_location} --quiet                                    \
            --multipart-chunk-size-mb ${chunk_size}                          \
            --mime-type=application/gzip                                     \
            --no-guess-mime-type                                             \
            --add-header=content-encoding:gzip                               \
            --region=${AWS_REGION}                                           \
            --host=${AWS_S3_ENDPOINT}                                        \
            --host-bucket=${AWS_BUCKET_NAME}.${AWS_S3_ENDPOINT}              \
            put ${staging_dir}/sources_${ts}.csv.gz                          \
            s3://${AWS_BUCKET_NAME}${AWS_BUCKET_DIR}/${ts}/sources.csv.gz
         
         echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading sources zip to $envn S3." | tee -a ${logfile}
         python ${s3cmd_location} --quiet                                    \
            --multipart-chunk-size-mb ${chunk_size}                          \
            --region=${AWS_REGION}                                           \
            --host=${AWS_S3_ENDPOINT}                                        \
            --host-bucket=${AWS_BUCKET_NAME}.${AWS_S3_ENDPOINT}              \
            put ${staging_dir}/sources_${ts}.csv.zip                         \
            s3://${AWS_BUCKET_NAME}${AWS_BUCKET_DIR}/${ts}/sources.csv.zip
         
      fi
      
   done
   
   profile_sources_size_raw=$(unzip -Zt "${staging_dir}/sources_${ts}.csv.zip" | awk '{ print $3 }')
   profile_sources_size_gz=$(stat -c%s "${staging_dir}/sources_${ts}.csv.gz")
   profile_sources_size_zip=$(stat -c%s "${staging_dir}/sources_${ts}.csv.zip")
   echo "profile_sources.csv,${profile_sources_size_raw},${profile_sources_size_gz},${profile_sources_size_zip}" >> ${staging_dir}/thread.txt
 
   echo `date +"%Y-%m-%d %H:%M:%S"`": ETL of sources complete." | tee -a ${logfile}
   
   ############################################################################
   # PROFILE_TMDL
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting tmdl in thread 5." | tee -a ${logfile}
   ogr2ogr \
      --config GDAL_NUM_THREADS ${gdal_num_threads}                    \
      -f CSV /vsistdout/                                               \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${DB_HOSTSTRING}:ATTAINS_APP.PROFILE_TMDL \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,assessmentunitid,assessmentunitname,actionid,actionname,completiondate,tmdldate,fiscalyearestablished,pollutant,pollutantgroup,sourcetype,addressedparameter,addressedparametergroup,locationdescription,watertype,watersize,watersizeunits,actionagency,loadallocation,loadallocationunits,explicitmarginofsafety,implicitmarginofsafety,CAST(SUBSTR(tmdlendpoint,1,3000) AS VARCHAR2(4000)) AS tmdlendpoint1,CAST(SUBSTR(tmdlendpoint,3001,6000) AS VARCHAR2(4000)) AS tmdlendpoint2,CAST(SUBSTR(tmdlendpoint,6001,9000) AS VARCHAR2(4000)) AS tmdlendpoint3,npdesidentifier,otheridentifier,wasteloadallocation,inindiancountry,includeinmeasure FROM ATTAINS_APP.PROFILE_TMDL a ${clause}" \
      -preserve_fid -lco LINEFORMAT=LF                                 \
      -lco STRING_QUOTING=IF_NEEDED                         |          \
   gzip -q > ${staging_dir}/tmdl_${ts}.csv.gz
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": Creating tmdl zipfile." | tee -a ${logfile}
   rm -Rf ${staging_dir}/tmdl.csv
   mkfifo ${staging_dir}/tmdl.csv
   gzip -q -d -c ${staging_dir}/tmdl_${ts}.csv.gz > ${staging_dir}/tmdl.csv & \
      zip -q -j -fz --fifo ${staging_dir}/tmdl_${ts}.csv.zip ${staging_dir}/tmdl.csv
   rm -Rf ${staging_dir}/tmdl.csv
   
   ###############################################################################
   IFS=,
   for envn in ${ENVS}
   do
      ENVN=$envn
	   setaws
     
	   if [ -z "${UPLOAD_TO_S3}" ] || [ "${UPLOAD_TO_S3}" = "True" ]
      then
         echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading tmdl files to $envn S3." | tee -a ${logfile}
         python ${s3cmd_location} --quiet                                    \
            --multipart-chunk-size-mb ${chunk_size}                          \
            --mime-type=application/gzip                                     \
            --no-guess-mime-type                                             \
            --add-header=content-encoding:gzip                               \
            --region=${AWS_REGION}                                           \
            --host=${AWS_S3_ENDPOINT}                                        \
            --host-bucket=${AWS_BUCKET_NAME}.${AWS_S3_ENDPOINT}              \
            put ${staging_dir}/tmdl_${ts}.csv.gz                             \
            s3://${AWS_BUCKET_NAME}${AWS_BUCKET_DIR}/${ts}/tmdl.csv.gz
         
         echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading tmdl zip to $envn S3." | tee -a ${logfile}
         python ${s3cmd_location} --quiet                                    \
            --multipart-chunk-size-mb ${chunk_size}                          \
            --region=${AWS_REGION}                                           \
            --host=${AWS_S3_ENDPOINT}                                        \
            --host-bucket=${AWS_BUCKET_NAME}.${AWS_S3_ENDPOINT}              \
            put ${staging_dir}/tmdl_${ts}.csv.zip                            \
            s3://${AWS_BUCKET_NAME}${AWS_BUCKET_DIR}/${ts}/tmdl.csv.zip
         
      fi
      
   done
   
   profile_tmdl_size_raw=$(unzip -Zt "${staging_dir}/tmdl_${ts}.csv.zip" | awk '{ print $3 }')
   profile_tmdl_size_gz=$(stat -c%s "${staging_dir}/tmdl_${ts}.csv.gz")
   profile_tmdl_size_zip=$(stat -c%s "${staging_dir}/tmdl_${ts}.csv.zip")
   echo "profile_tmdl.csv,${profile_tmdl_size_raw},${profile_tmdl_size_gz},${profile_tmdl_size_zip}" >> ${staging_dir}/thread.txt
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": ETL of tmdl complete." | tee -a ${logfile}
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": Thread 1 is complete." | tee -a ${logfile}

} 

thread2()
{
   ############################################################################
   # PROFILE_ASSESSMENTS
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting assessments in thread 2." | tee -a ${logfile}
   ogr2ogr \
      --config GDAL_NUM_THREADS ${gdal_num_threads}                    \
      -f CSV /vsistdout/                                               \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${DB_HOSTSTRING}:ATTAINS_APP.PROFILE_ASSESSMENTS \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,reportingcycle,cycleid,assessmentunitid,assessmentunitname,cyclelastassessed,overallstatus,epaircategory,stateircategory,parametergroup,parametername,parameterstatus,usegroup,usename,useircategory,usestateircategory,usesupport,parameterattainment,parameterircategory,parameterstateircategory,cyclefirstlisted,associatedactionid,associatedactionname,associatedactiontype,locationdescription,watertype,watersize,watersizeunits,sizesource,sourcescale,assessmentunitstatus,useclassname,assessmentdate,assessmentbasis,monitoringstartdate,monitoringenddate,assessmentmethods,assessmenttypes,delisted,delistedreason,seasonstartdate,seasonenddate,pollutantindicator,cyclescheduledfortmdl,cycleexpectedtoattain,cwa303dpriorityranking,vision303dpriority,alternatelistingidentifier,consentdecreecycle,associatedactionstatus,associatedactionagency FROM ATTAINS_APP.PROFILE_ASSESSMENTS a ${clause}" \
      -preserve_fid -lco LINEFORMAT=LF                                 \
      -lco STRING_QUOTING=IF_NEEDED                         |          \
   gzip -q > ${staging_dir}/assessments_${ts}.csv.gz
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": Creating assessments zipfile." | tee -a ${logfile}
   rm -Rf ${staging_dir}/assessments.csv
   mkfifo ${staging_dir}/assessments.csv
   gzip -q -d -c ${staging_dir}/assessments_${ts}.csv.gz > ${staging_dir}/assessments.csv & \
      zip -q -j -fz --fifo ${staging_dir}/assessments_${ts}.csv.zip ${staging_dir}/assessments.csv
   rm -Rf ${staging_dir}/assessments.csv
   
   ###############################################################################
   IFS=,
   for envn in ${ENVS}
   do
      ENVN=$envn
	   setaws
     
	   if [ -z "${UPLOAD_TO_S3}" ] || [ "${UPLOAD_TO_S3}" = "True" ]
      then
         echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading assessments gz to $envn S3." | tee -a ${logfile}
         python ${s3cmd_location} --quiet                                    \
            --multipart-chunk-size-mb ${chunk_size}                          \
            --mime-type=application/gzip                                     \
            --no-guess-mime-type                                             \
            --add-header=content-encoding:gzip                               \
            --region=${AWS_REGION}                                           \
            --host=${AWS_S3_ENDPOINT}                                        \
            --host-bucket=${AWS_BUCKET_NAME}.${AWS_S3_ENDPOINT}              \
            put ${staging_dir}/assessments_${ts}.csv.gz                      \
            s3://${AWS_BUCKET_NAME}${AWS_BUCKET_DIR}/${ts}/assessments.csv.gz
         
         echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading assessments zip to $envn S3." | tee -a ${logfile}
         python ${s3cmd_location} --quiet                                    \
            --multipart-chunk-size-mb ${chunk_size}                          \
            --region=${AWS_REGION}                                           \
            --host=${AWS_S3_ENDPOINT}                                        \
            --host-bucket=${AWS_BUCKET_NAME}.${AWS_S3_ENDPOINT}              \
            put ${staging_dir}/assessments_${ts}.csv.zip                     \
            s3://${AWS_BUCKET_NAME}${AWS_BUCKET_DIR}/${ts}/assessments.csv.zip
         
      fi
      
   done
   
   profile_assessments_size_raw=$(unzip -Zt "${staging_dir}/assessments_${ts}.csv.zip" | awk '{ print $3 }')
   profile_assessments_size_gz=$(stat -c%s "${staging_dir}/assessments_${ts}.csv.gz")
   profile_assessments_size_zip=$(stat -c%s "${staging_dir}/assessments_${ts}.csv.zip")
   echo "profile_assessments.csv,${profile_assessments_size_raw},${profile_assessments_size_gz},${profile_assessments_size_zip}" >> ${staging_dir}/thread.txt
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": ETL of assessments complete." | tee -a ${logfile}
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": Thread 2 is complete." | tee -a ${logfile}

} 

thread3()
{
   ############################################################################
   # PROFILE_CATCHMENT_CORRESPONDENCE
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting catchment_correspondence in thread 3." | tee -a ${logfile}
   ogr2ogr \
      --config GDAL_NUM_THREADS ${gdal_num_threads}                    \
      -f CSV /vsistdout/                                               \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${DB_HOSTSTRING}:ATTAINS_APP.PROFILE_CATCHMENT_CORRESPONDENCE \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,reportingcycle,cycleid,assessmentunitid,assessmentunitname,catchmentnhdplusid FROM ATTAINS_APP.PROFILE_CATCHMENT_CORRESPONDENCE a ${clause}" \
      -preserve_fid -lco LINEFORMAT=LF                                 \
      -lco STRING_QUOTING=IF_NEEDED                         |          \
   gzip -q > ${staging_dir}/catchment_correspondence_${ts}.csv.gz
 
   echo `date +"%Y-%m-%d %H:%M:%S"`": Creating catchment_correspondence zipfile." | tee -a ${logfile}
   rm -Rf ${staging_dir}/catchment_correspondence.csv
   mkfifo ${staging_dir}/catchment_correspondence.csv
   gzip -q -d -c ${staging_dir}/catchment_correspondence_${ts}.csv.gz > ${staging_dir}/catchment_correspondence.csv & \
      zip -q -j -fz --fifo ${staging_dir}/catchment_correspondence_${ts}.csv.zip ${staging_dir}/catchment_correspondence.csv
   rm -Rf ${staging_dir}/catchment_correspondence.csv
   
   ###############################################################################
   IFS=,
   for envn in ${ENVS}
   do
      ENVN=$envn
	   setaws
     
	   if [ -z "${UPLOAD_TO_S3}" ] || [ "${UPLOAD_TO_S3}" = "True" ]
      then
         echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading catchment_correspondence gz to $envn S3." | tee -a ${logfile}
         python ${s3cmd_location} --quiet                                    \
            --multipart-chunk-size-mb ${chunk_size}                          \
            --mime-type=application/gzip                                     \
            --no-guess-mime-type                                             \
            --add-header=content-encoding:gzip                               \
            --region=${AWS_REGION}                                           \
            --host=${AWS_S3_ENDPOINT}                                        \
            --host-bucket=${AWS_BUCKET_NAME}.${AWS_S3_ENDPOINT}              \
            put ${staging_dir}/catchment_correspondence_${ts}.csv.gz         \
            s3://${AWS_BUCKET_NAME}${AWS_BUCKET_DIR}/${ts}/catchment_correspondence.csv.gz
         
         echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading catchment_correspondence zip to $envn S3." | tee -a ${logfile}
         python ${s3cmd_location} --quiet                                    \
            --multipart-chunk-size-mb ${chunk_size}                          \
            --region=${AWS_REGION}                                           \
            --host=${AWS_S3_ENDPOINT}                                        \
            --host-bucket=${AWS_BUCKET_NAME}.${AWS_S3_ENDPOINT}              \
            put ${staging_dir}/catchment_correspondence_${ts}.csv.zip        \
            s3://${AWS_BUCKET_NAME}${AWS_BUCKET_DIR}/${ts}/catchment_correspondence.csv.zip

      fi
      
   done
   
   profile_catchment_correspondence_size_raw=$(unzip -Zt "${staging_dir}/catchment_correspondence_${ts}.csv.zip" | awk '{ print $3 }')
   profile_catchment_correspondence_size_gz=$(stat -c%s "${staging_dir}/catchment_correspondence_${ts}.csv.gz")
   profile_catchment_correspondence_size_zip=$(stat -c%s "${staging_dir}/catchment_correspondence_${ts}.csv.zip")
   echo "profile_catchment_correspondence.csv,${profile_catchment_correspondence_size_raw},${profile_catchment_correspondence_size_gz},${profile_catchment_correspondence_size_zip}" >> ${staging_dir}/thread.txt
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": ETL of catchment_correspondence complete." | tee -a ${logfile}
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": Thread 3 is complete." | tee -a ${logfile} 

}

rm -Rf ${staging_dir}/thread.txt
thread1 &
thread2 &
thread3 &
wait

echo `date +"%Y-%m-%d %H:%M:%S"`": All threads complete." | tee -a ${logfile}

###############################################################################
# Write out the status and latest files
echo "{"                       >  ${statusfile}
echo "\"tag\":\"${etl_tag}\""  >> ${statusfile}
echo ",\"julian\":${ts}"       >> ${statusfile}
echo ",\"files\":["            >> ${statusfile}

z=0
while read -r line
do
   if [ $z -eq 1 ]
   then
      echo "," >> ${statusfile}
   
   fi

   nm=$(echo "$line" | cut -d',' -f1)
   rw=$(echo "$line" | cut -d',' -f2)
   gz=$(echo "$line" | cut -d',' -f3)
   zp=$(echo "$line" | cut -d',' -f4)
   
   echo "{"                     >> ${statusfile}
   echo "\"name\":\"${nm}\""    >> ${statusfile}
   echo ",\"csv_size\":${rw}"   >> ${statusfile}
   echo ",\"gz_size\":${gz}"    >> ${statusfile}
   echo ",\"zip_size\":${zp}"   >> ${statusfile}
   echo "}"                     >> ${statusfile}

   z=1
done < ${staging_dir}/thread.txt
rm -Rf ${staging_dir}/thread.txt

echo "]"                        >> ${statusfile}
echo "}"                        >> ${statusfile}

echo "{"                        >  ${latestfile}
echo "\"tag\":\"${etl_tag}\""   >> ${latestfile}
echo ",\"julian\":${ts}"        >> ${latestfile}
echo "}"                        >> ${latestfile}

###############################################################################
echo `date +"%Y-%m-%d %H:%M:%S"`": All ETL tasks completed successfully." | tee -a ${logfile} 

IFS=,
for envn in ${ENVS}
do
   ENVN=$envn
   setaws
   
   putstatus
   putlatest
   putlog
   
done

###############################################################################
if [ ! -z "$DO_CLEANUP" ]
then
   if [ "$DO_CLEANUP" = "True" ]
   then
      rm -f ${staging_dir}/actions_${ts}.csv.gz
      rm -f ${staging_dir}/actions_${ts}.csv.zip
      
      rm -f ${staging_dir}/assessment_units_${ts}.csv.gz
      rm -f ${staging_dir}/assessment_units_${ts}.csv.zip
      
      rm -f ${staging_dir}/assessment_units_monitoring_locations_${ts}.csv.gz
      rm -f ${staging_dir}/assessment_units_monitoring_locations_${ts}.csv.zip
      
      rm -f ${staging_dir}/sources_${ts}.csv.gz
      rm -f ${staging_dir}/sources_${ts}.csv.zip
      
      rm -f ${staging_dir}/tmdl_${ts}.csv.gz
      rm -f ${staging_dir}/tmdl_${ts}.csv.zip
      
      rm -f ${staging_dir}/assessments_${ts}.csv.gz
      rm -f ${staging_dir}/assessments_${ts}.csv.zip
      
      rm -f ${staging_dir}/catchment_correspondence_${ts}.csv.gz
      rm -f ${staging_dir}/catchment_correspondence_${ts}.csv.zip
      
      rm -f ${staging_dir}/log_${ts}.txt
      rm -f ${staging_dir}/status_${ts}.json
      rm -f ${staging_dir}/latest_${ts}.json
      rm -f ${staging_dir}/ready_${ts}.json
   
   fi

fi
