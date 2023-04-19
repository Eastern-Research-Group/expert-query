#/bin/sh

###############################################################################
# Configuration

# Staging directory
staging_dir=/data/waterspb/loading_dock

# Number of threads used by GDAL processes
gdal_num_threads=1

# Chunk size to use when uploading to S3
chunk_size=1000

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
# Required primary bucket target:
# PRI_AWS_BUCKET_NAME
# PRI_AWS_BUCKET_DIR
# PRI_AWS_REGION
# PRI_AWS_S3_ENDPOINT
# PRI_AWS_ACCESS_KEY_ID
# PRI_AWS_SECRET_ACCESS_KEY
#
# Optional secondary bucket target:
# SEC_AWS_BUCKET_NAME
# SEC_AWS_BUCKET_DIR
# SEC_AWS_REGION
# SEC_AWS_S3_ENDPOINT
# SEC_AWS_ACCESS_KEY_ID
# SEC_AWS_SECRET_ACCESS_KEY
#
# Set DO_CLEANUP to True in order to remove staging diretory files
# DO_CLEANUP

# alter secrets location if you need to place this elsewhere
secrets_location=~/.env

if [ ! -f ${secrets_location} ]
then
   echo "unable to read .env secrets file at $secrets_location"
   exit -1
fi

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

###############################################################################
# Determine the ETL julian ts value for the load to drive logging actions
ts=$(date +%s)

logfile=${staging_dir}/log_${ts}.txt
statusfile=${staging_dir}/status_${ts}.json
latestfile=${staging_dir}/latest_${ts}.json
readyfile=${staging_dir}/ready_${ts}.json

putlog()
{
   export AWS_ACCESS_KEY_ID=$PRI_AWS_ACCESS_KEY_ID
   export AWS_SECRET_ACCESS_KEY=$PRI_AWS_SECRET_ACCESS_KEY
   python ${s3cmd_location} --quiet                               \
      --region=${PRI_AWS_REGION}                                  \
      --host=${PRI_AWS_S3_ENDPOINT}                               \
      --host-bucket=${PRI_AWS_BUCKET_NAME}.${PRI_AWS_S3_ENDPOINT} \
      put ${logfile}                                              \
      s3://${PRI_AWS_BUCKET_NAME}${PRI_AWS_BUCKET_DIR}/${ts}/logfile.txt
}

putlog_sec()
{
   export AWS_ACCESS_KEY_ID=$SEC_AWS_ACCESS_KEY_ID
   export AWS_SECRET_ACCESS_KEY=$SEC_AWS_SECRET_ACCESS_KEY
   python ${s3cmd_location} --quiet                               \
      --region=${SEC_AWS_REGION}                                  \
      --host=${SEC_AWS_S3_ENDPOINT}                               \
      --host-bucket=${SEC_AWS_BUCKET_NAME}.${SEC_AWS_S3_ENDPOINT} \
      put ${logfile}                                              \
      s3://${SEC_AWS_BUCKET_NAME}${SEC_AWS_BUCKET_DIR}/${ts}/logfile.txt
}

putstatus()
{
   export AWS_ACCESS_KEY_ID=$PRI_AWS_ACCESS_KEY_ID
   export AWS_SECRET_ACCESS_KEY=$PRI_AWS_SECRET_ACCESS_KEY
   python ${s3cmd_location} --quiet                               \
      --region=${PRI_AWS_REGION}                                  \
      --host=${PRI_AWS_S3_ENDPOINT}                               \
      --host-bucket=${PRI_AWS_BUCKET_NAME}.${PRI_AWS_S3_ENDPOINT} \
      put ${statusfile}                                           \
      s3://${PRI_AWS_BUCKET_NAME}${PRI_AWS_BUCKET_DIR}/${ts}/status.json
}

putready()
{
   export AWS_ACCESS_KEY_ID=$PRI_AWS_ACCESS_KEY_ID
   export AWS_SECRET_ACCESS_KEY=$PRI_AWS_SECRET_ACCESS_KEY
   python ${s3cmd_location} --quiet                               \
      --region=${PRI_AWS_REGION}                                  \
      --host=${PRI_AWS_S3_ENDPOINT}                               \
      --host-bucket=${PRI_AWS_BUCKET_NAME}.${PRI_AWS_S3_ENDPOINT} \
      put ${readyfile}                                            \
      s3://${PRI_AWS_BUCKET_NAME}${PRI_AWS_BUCKET_DIR}/${ts}/ready.json
}

putlatest()
{
   export AWS_ACCESS_KEY_ID=$PRI_AWS_ACCESS_KEY_ID
   export AWS_SECRET_ACCESS_KEY=$PRI_AWS_SECRET_ACCESS_KEY
   python ${s3cmd_location} --quiet                               \
      --region=${PRI_AWS_REGION}                                  \
      --host=${PRI_AWS_S3_ENDPOINT}                               \
      --host-bucket=${PRI_AWS_BUCKET_NAME}.${PRI_AWS_S3_ENDPOINT} \
      put ${latestfile}                                           \
      s3://${PRI_AWS_BUCKET_NAME}${PRI_AWS_BUCKET_DIR}/latest.json
}

putlatest_sec()
{
   export AWS_ACCESS_KEY_ID=$SEC_AWS_ACCESS_KEY_ID
   export AWS_SECRET_ACCESS_KEY=$SEC_AWS_SECRET_ACCESS_KEY
   python ${s3cmd_location} --quiet                               \
      --region=${SEC_AWS_REGION}                                  \
      --host=${SEC_AWS_S3_ENDPOINT}                               \
      --host-bucket=${SEC_AWS_BUCKET_NAME}.${SEC_AWS_S3_ENDPOINT} \
      put ${latestfile}                                           \
      s3://${SEC_AWS_BUCKET_NAME}${SEC_AWS_BUCKET_DIR}/latest.json
}

echo `date +"%Y-%m-%d %H:%M:%S"`": Starting ATTAINS profile ETL for ${ts}" >> ${logfile}
putlog

###############################################################################
# Query bucket for information on the last extraction
export AWS_ACCESS_KEY_ID=$PRI_AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$PRI_AWS_SECRET_ACCESS_KEY
python ${s3cmd_location} --quiet                                  \
   --region=${PRI_AWS_REGION}                                     \
   --host=${PRI_AWS_S3_ENDPOINT}                                  \
   --host-bucket=${PRI_AWS_BUCKET_NAME}.${PRI_AWS_S3_ENDPOINT}    \
   get s3://${PRI_AWS_BUCKET_NAME}${PRI_AWS_BUCKET_DIR}/latest.json ${latestfile} 2> /dev/null

if [[ $? -eq 0 ]]
then
   last_tag=$(cat ${latestfile} | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["tag"];')
   last_julian=$(cat ${latestfile} | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["julian"];')
   echo `date +"%Y-%m-%d %H:%M:%S"`": latest.json reports last tag as ${last_tag} under ${last_julian}." >> ${logfile}
else
   last_tag=""
   last_julian=""
   echo `date +"%Y-%m-%d %H:%M:%S"`": latest.json file not found in bucket." >> ${logfile}
fi
rm -f ${latestfile}

putlog

###############################################################################
# Query database if the datasets are in a ready state
ogrinfo \
   OCI:${DB_USERNAME}/${DB_PASSWORD}@${DB_HOSTSTRING}:ATTAINS_APP.PROFILE_TMDL        \
   -q -nomd -nocount -noextent                                                        \
   -sql "SELECT TO_CHAR(attains_eq.util.go_nogo('JSON')) AS ready FROM dual" |        \
awk '/^  READY \(String\) \= /{$1=$2=$3="";gsub(/^[ ]+/,"",$0);print $0}' > ${readyfile}
putready

ready_status=$(cat ${readyfile} | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["ready"];')

if [ "$ready_status" = "nogo" ]
then
   echo `date +"%Y-%m-%d %H:%M:%S"`": profile materialized views are in a nogo state. aborting." >> ${logfile}
   putlog
   exit 0
fi 

etl_tag=$(cat ${readyfile} | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["tag"];')
echo `date +"%Y-%m-%d %H:%M:%S"`": database reports tag $etl_tag ready to extract." >> ${logfile}

if [ "$etl_tag" = "$last_tag" ]
then
   echo `date +"%Y-%m-%d %H:%M:%S"`": $etl_tag has already been extracted per ready.json in bucket. Exiting." >> ${logfile}
   putlog
   exit 0
fi

###############################################################################
# Begin the extract in three threads
# note the usage of -fz with the fifo input to zip makes no sense but is necessary
# to work on RedHat.  When no flag is given the --fifo input seems forced into
# 32 bit mode which bombs when the archive tops 2GB.  However when -fz is expressly
# provided this seems to trigger some internal logic that forces over to 64 bit processing.
#
# A clause may be provided for testing a limited set of data to validate the workflow
#clause="WHERE rownum <= 100"
clause=""

thread1()
{   
   ############################################################################
   # PROFILE_ACTIONS
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting actions in thread 1." >> ${logfile}
   ogr2ogr \
      --config GDAL_NUM_THREADS ${gdal_num_threads}                    \
      -f CSV /vsistdout/                                               \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${DB_HOSTSTRING}:ATTAINS_APP.PROFILE_ACTIONS \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,assessmentunitid,assessmentunitname,actionid,actionname,completiondate,parameter,locationdescription,actiontype,watertype,watersize,watersizeunits,actionagency,inindiancountry,includeinmeasure FROM ATTAINS_APP.PROFILE_ACTIONS a ${clause}" \
      -preserve_fid -lco LINEFORMAT=LF                                 \
      -lco STRING_QUOTING=IF_NEEDED                         |          \
   gzip -q > ${staging_dir}/actions_${ts}.csv.gz

   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading actions gz to S3." >> ${logfile}
   export AWS_ACCESS_KEY_ID=$PRI_AWS_ACCESS_KEY_ID
   export AWS_SECRET_ACCESS_KEY=$PRI_AWS_SECRET_ACCESS_KEY
   python ${s3cmd_location} --quiet                                    \
      --multipart-chunk-size-mb ${chunk_size}                          \
      --mime-type=application/gzip                                     \
      --no-guess-mime-type                                             \
      --add-header=content-encoding:gzip                               \
      --region=${PRI_AWS_REGION}                                       \
      --host=${PRI_AWS_S3_ENDPOINT}                                    \
      --host-bucket=${PRI_AWS_BUCKET_NAME}.${PRI_AWS_S3_ENDPOINT}      \
      put ${staging_dir}/actions_${ts}.csv.gz                          \
      s3://${PRI_AWS_BUCKET_NAME}${PRI_AWS_BUCKET_DIR}/${ts}/actions.csv.gz
      
   if [ ! -z "$SEC_AWS_ACCESS_KEY_ID" ]
   then
      export AWS_ACCESS_KEY_ID=$SEC_AWS_ACCESS_KEY_ID
      export AWS_SECRET_ACCESS_KEY=$SEC_AWS_SECRET_ACCESS_KEY
      python ${s3cmd_location} --quiet                                 \
         --multipart-chunk-size-mb ${chunk_size}                       \
         --mime-type=application/gzip                                  \
         --no-guess-mime-type                                          \
         --add-header=content-encoding:gzip                            \
         --region=${SEC_AWS_REGION}                                    \
         --host=${SEC_AWS_S3_ENDPOINT}                                 \
         --host-bucket=${SEC_AWS_BUCKET_NAME}.${SEC_AWS_S3_ENDPOINT}   \
         put ${staging_dir}/actions_${ts}.csv.gz                       \
         s3://${SEC_AWS_BUCKET_NAME}${SEC_AWS_BUCKET_DIR}/${ts}/actions.csv.gz
         
      if [ $? -ne 0 ]
      then
         echo "s3cmd failed against secondary credentials."
         exit -1
      fi
   
   fi
      
   echo `date +"%Y-%m-%d %H:%M:%S"`": Creating actions zipfile." >> ${logfile}
   rm -Rf ${staging_dir}/actions.csv
   mkfifo ${staging_dir}/actions.csv
   gzip -q -d -c ${staging_dir}/actions_${ts}.csv.gz > ${staging_dir}/actions.csv & \
      zip -q -j -fz --fifo ${staging_dir}/actions_${ts}.csv.zip ${staging_dir}/actions.csv
   rm -Rf ${staging_dir}/actions.csv
      
   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading actions zip to S3." >> ${logfile}
   export AWS_ACCESS_KEY_ID=$PRI_AWS_ACCESS_KEY_ID
   export AWS_SECRET_ACCESS_KEY=$PRI_AWS_SECRET_ACCESS_KEY
   python ${s3cmd_location} --quiet                                    \
      --multipart-chunk-size-mb ${chunk_size}                          \
      --region=${PRI_AWS_REGION}                                       \
      --host=${PRI_AWS_S3_ENDPOINT}                                    \
      --host-bucket=${PRI_AWS_BUCKET_NAME}.${PRI_AWS_S3_ENDPOINT}      \
      put ${staging_dir}/actions_${ts}.csv.zip                         \
      s3://${PRI_AWS_BUCKET_NAME}${PRI_AWS_BUCKET_DIR}/${ts}/actions.csv.zip
      
   if [ ! -z "$SEC_AWS_ACCESS_KEY_ID" ]
   then
      export AWS_ACCESS_KEY_ID=$SEC_AWS_ACCESS_KEY_ID
      export AWS_SECRET_ACCESS_KEY=$SEC_AWS_SECRET_ACCESS_KEY
      python ${s3cmd_location} --quiet                                 \
         --multipart-chunk-size-mb ${chunk_size}                       \
         --region=${SEC_AWS_REGION}                                    \
         --host=${SEC_AWS_S3_ENDPOINT}                                 \
         --host-bucket=${SEC_AWS_BUCKET_NAME}.${SEC_AWS_S3_ENDPOINT}   \
         put ${staging_dir}/actions_${ts}.csv.zip                      \
         s3://${SEC_AWS_BUCKET_NAME}${SEC_AWS_BUCKET_DIR}/${ts}/actions.csv.zip
   
   fi
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": ETL of actions complete." >> ${logfile}   
   
   ############################################################################
   # PROFILE_ASSESSMENT_UNITS
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting assessment_units in thread 1." >> ${logfile}
   ogr2ogr \
      --config GDAL_NUM_THREADS ${gdal_num_threads}                    \
      -f CSV /vsistdout/                                               \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${DB_HOSTSTRING}:ATTAINS_APP.PROFILE_ASSESSMENT_UNITS \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,reportingcycle,cycleid,assessmentunitid,assessmentunitname,locationdescription,watertype,watersize,watersizeunits,assessmentunitstatus,useclassname,sizesource,sourcescale,locationtypecode,locationtext FROM ATTAINS_APP.PROFILE_ASSESSMENT_UNITS a ${clause}" \
      -preserve_fid -lco LINEFORMAT=LF                                 \
      -lco STRING_QUOTING=IF_NEEDED                         |          \
   gzip -q > ${staging_dir}/assessment_units_${ts}.csv.gz
    
   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading assessment_units gz to S3." >> ${logfile}
   export AWS_ACCESS_KEY_ID=$PRI_AWS_ACCESS_KEY_ID
   export AWS_SECRET_ACCESS_KEY=$PRI_AWS_SECRET_ACCESS_KEY
   python ${s3cmd_location} --quiet                                    \
      --multipart-chunk-size-mb ${chunk_size}                          \
      --mime-type=application/gzip                                     \
      --no-guess-mime-type                                             \
      --add-header=content-encoding:gzip                               \
      --region=${PRI_AWS_REGION}                                       \
      --host=${PRI_AWS_S3_ENDPOINT}                                    \
      --host-bucket=${PRI_AWS_BUCKET_NAME}.${PRI_AWS_S3_ENDPOINT}      \
      put ${staging_dir}/assessment_units_${ts}.csv.gz                 \
      s3://${PRI_AWS_BUCKET_NAME}${PRI_AWS_BUCKET_DIR}/${ts}/assessment_units.csv.gz
      
   if [ ! -z "$SEC_AWS_ACCESS_KEY_ID" ]
   then
      export AWS_ACCESS_KEY_ID=$SEC_AWS_ACCESS_KEY_ID
      export AWS_SECRET_ACCESS_KEY=$SEC_AWS_SECRET_ACCESS_KEY
      python ${s3cmd_location} --quiet                                 \
         --multipart-chunk-size-mb ${chunk_size}                       \
         --mime-type=application/gzip                                  \
         --no-guess-mime-type                                          \
         --add-header=content-encoding:gzip                            \
         --region=${SEC_AWS_REGION}                                    \
         --host=${SEC_AWS_S3_ENDPOINT}                                 \
         --host-bucket=${SEC_AWS_BUCKET_NAME}.${SEC_AWS_S3_ENDPOINT}   \
         put ${staging_dir}/assessment_units_${ts}.csv.gz              \
         s3://${SEC_AWS_BUCKET_NAME}${SEC_AWS_BUCKET_DIR}/${ts}/assessment_units.csv.gz
      
   fi
      
   echo `date +"%Y-%m-%d %H:%M:%S"`": Creating assessment_units zipfile." >> ${logfile}
   rm -Rf ${staging_dir}/assessment_units.csv
   mkfifo ${staging_dir}/assessment_units.csv
   gzip -q -d -c ${staging_dir}/assessment_units_${ts}.csv.gz > ${staging_dir}/assessment_units.csv & \
      zip -q -j -fz --fifo ${staging_dir}/assessment_units_${ts}.csv.zip ${staging_dir}/assessment_units.csv
   rm -Rf ${staging_dir}/assessment_units.csv
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading assessment_units zip to S3." >> ${logfile}
   export AWS_ACCESS_KEY_ID=$PRI_AWS_ACCESS_KEY_ID
   export AWS_SECRET_ACCESS_KEY=$PRI_AWS_SECRET_ACCESS_KEY
   python ${s3cmd_location} --quiet                                    \
      --multipart-chunk-size-mb ${chunk_size}                          \
      --region=${PRI_AWS_REGION}                                       \
      --host=${PRI_AWS_S3_ENDPOINT}                                    \
      --host-bucket=${PRI_AWS_BUCKET_NAME}.${PRI_AWS_S3_ENDPOINT}      \
      put ${staging_dir}/assessment_units_${ts}.csv.zip                \
      s3://${PRI_AWS_BUCKET_NAME}${PRI_AWS_BUCKET_DIR}/${ts}/assessment_units.csv.zip
      
   if [ ! -z "$SEC_AWS_ACCESS_KEY_ID" ]
   then
      export AWS_ACCESS_KEY_ID=$SEC_AWS_ACCESS_KEY_ID
      export AWS_SECRET_ACCESS_KEY=$SEC_AWS_SECRET_ACCESS_KEY
      python ${s3cmd_location} --quiet                                 \
         --multipart-chunk-size-mb ${chunk_size}                       \
         --region=${SEC_AWS_REGION}                                    \
         --host=${SEC_AWS_S3_ENDPOINT}                                 \
         --host-bucket=${SEC_AWS_BUCKET_NAME}.${SEC_AWS_S3_ENDPOINT}   \
         put ${staging_dir}/assessment_units_${ts}.csv.zip             \
         s3://${SEC_AWS_BUCKET_NAME}${SEC_AWS_BUCKET_DIR}/${ts}/assessment_units.csv.zip
   fi
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": ETL of assessment_units complete." >> ${logfile} 
   
   ############################################################################
   # PROFILE_ASSESSMENT_UNITS_MONITORING_LOCATIONS
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting assessment_units_monitoring_locations in thread 1." >> ${logfile}
   ogr2ogr \
      --config GDAL_NUM_THREADS ${gdal_num_threads}                    \
      -f CSV /vsistdout/                                               \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${DB_HOSTSTRING}:ATTAINS_APP.PROFILE_ASSESSMENT_UNITS_MONITORING_LOCATIONS \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,reportingcycle,cycleid,assessmentunitid,assessmentunitname,locationdescription,watertype,watersize,watersizeunits,monitoringlocationorgid,monitoringlocationid,monitoringlocationdatalink,assessmentunitstatus,useclassname,sizesource,sourcescale FROM ATTAINS_APP.PROFILE_ASSESSMENT_UNITS_MONITORING_LOCATIONS a ${clause}" \
      -preserve_fid -lco LINEFORMAT=LF                                 \
      -lco STRING_QUOTING=IF_NEEDED                         |          \
   gzip -q > ${staging_dir}/assessment_units_monitoring_locations_${ts}.csv.gz
      
   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading assessment_units_monitoring_locations gz to S3." >> ${logfile}
   export AWS_ACCESS_KEY_ID=$PRI_AWS_ACCESS_KEY_ID
   export AWS_SECRET_ACCESS_KEY=$PRI_AWS_SECRET_ACCESS_KEY
   python ${s3cmd_location} --quiet                                    \
      --multipart-chunk-size-mb ${chunk_size}                          \
      --mime-type=application/gzip                                     \
      --no-guess-mime-type                                             \
      --add-header=content-encoding:gzip                               \
      --region=${PRI_AWS_REGION}                                       \
      --host=${PRI_AWS_S3_ENDPOINT}                                    \
      --host-bucket=${PRI_AWS_BUCKET_NAME}.${PRI_AWS_S3_ENDPOINT}      \
      put ${staging_dir}/assessment_units_monitoring_locations_${ts}.csv.gz \
      s3://${PRI_AWS_BUCKET_NAME}${PRI_AWS_BUCKET_DIR}/${ts}/assessment_units_monitoring_locations.csv.gz
      
   if [ ! -z "$SEC_AWS_ACCESS_KEY_ID" ]
   then
      export AWS_ACCESS_KEY_ID=$SEC_AWS_ACCESS_KEY_ID
      export AWS_SECRET_ACCESS_KEY=$SEC_AWS_SECRET_ACCESS_KEY
      python ${s3cmd_location} --quiet                                 \
         --multipart-chunk-size-mb ${chunk_size}                       \
         --mime-type=application/gzip                                  \
         --no-guess-mime-type                                          \
         --add-header=content-encoding:gzip                            \
         --region=${SEC_AWS_REGION}                                    \
         --host=${SEC_AWS_S3_ENDPOINT}                                 \
         --host-bucket=${SEC_AWS_BUCKET_NAME}.${SEC_AWS_S3_ENDPOINT}   \
         put ${staging_dir}/assessment_units_monitoring_locations_${ts}.csv.gz \
         s3://${SEC_AWS_BUCKET_NAME}${SEC_AWS_BUCKET_DIR}/${ts}/assessment_units_monitoring_locations.csv.gz
      
   fi
      
   echo `date +"%Y-%m-%d %H:%M:%S"`": Creating assessment_units_monitoring_locations zipfile." >> ${logfile}
   rm -Rf ${staging_dir}/assessment_units_monitoring_locations.csv
   mkfifo ${staging_dir}/assessment_units_monitoring_locations.csv
   gzip -q -d -c ${staging_dir}/assessment_units_monitoring_locations_${ts}.csv.gz > ${staging_dir}/assessment_units_monitoring_locations.csv & \
      zip -q -j -fz --fifo ${staging_dir}/assessment_units_monitoring_locations_${ts}.csv.zip ${staging_dir}/assessment_units_monitoring_locations.csv
   rm -Rf ${staging_dir}/assessment_units_monitoring_locations.csv
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading assessment_units_monitoring_locations zip to S3." >> ${logfile}
   export AWS_ACCESS_KEY_ID=$PRI_AWS_ACCESS_KEY_ID
   export AWS_SECRET_ACCESS_KEY=$PRI_AWS_SECRET_ACCESS_KEY
   python ${s3cmd_location} --quiet                                    \
      --multipart-chunk-size-mb ${chunk_size}                          \
      --region=${PRI_AWS_REGION}                                       \
      --host=${PRI_AWS_S3_ENDPOINT}                                    \
      --host-bucket=${PRI_AWS_BUCKET_NAME}.${PRI_AWS_S3_ENDPOINT}      \
      put ${staging_dir}/assessment_units_monitoring_locations_${ts}.csv.zip \
      s3://${PRI_AWS_BUCKET_NAME}${PRI_AWS_BUCKET_DIR}/${ts}/assessment_units_monitoring_locations.csv.zip
      
   if [ ! -z "$SEC_AWS_ACCESS_KEY_ID" ]
   then
      export AWS_ACCESS_KEY_ID=$SEC_AWS_ACCESS_KEY_ID
      export AWS_SECRET_ACCESS_KEY=$SEC_AWS_SECRET_ACCESS_KEY
      python ${s3cmd_location} --quiet                                 \
         --multipart-chunk-size-mb ${chunk_size}                       \
         --region=${SEC_AWS_REGION}                                    \
         --host=${SEC_AWS_S3_ENDPOINT}                                 \
         --host-bucket=${SEC_AWS_BUCKET_NAME}.${SEC_AWS_S3_ENDPOINT}   \
         put ${staging_dir}/assessment_units_monitoring_locations_${ts}.csv.zip \
         s3://${SEC_AWS_BUCKET_NAME}${SEC_AWS_BUCKET_DIR}/${ts}/assessment_units_monitoring_locations.csv.zip
      
   fi
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": ETL of assessment_units_monitoring_locations complete." >> ${logfile} 
   
   ############################################################################
   # PROFILE_SOURCES
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting sources in thread 1." >> ${logfile}
   ogr2ogr \
      --config GDAL_NUM_THREADS ${gdal_num_threads}                    \
      -f CSV /vsistdout/                                               \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${DB_HOSTSTRING}:ATTAINS_APP.PROFILE_SOURCES \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,reportingcycle,cycleid,assessmentunitid,assessmentunitname,overallstatus,epaircategory,stateircategory,sourcename,confirmed,parametergroup,causename,locationdescription,watertype,watersize,watersizeunits FROM ATTAINS_APP.PROFILE_SOURCES a ${clause}" \
      -preserve_fid -lco LINEFORMAT=LF                                 \
      -lco STRING_QUOTING=IF_NEEDED                         |          \
   gzip -q > ${staging_dir}/sources_${ts}.csv.gz
      
   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading sources files to S3." >> ${logfile}
   export AWS_ACCESS_KEY_ID=$PRI_AWS_ACCESS_KEY_ID
   export AWS_SECRET_ACCESS_KEY=$PRI_AWS_SECRET_ACCESS_KEY
   python ${s3cmd_location} --quiet                                    \
      --multipart-chunk-size-mb ${chunk_size}                          \
      --mime-type=application/gzip                                     \
      --no-guess-mime-type                                             \
      --add-header=content-encoding:gzip                               \
      --region=${PRI_AWS_REGION}                                       \
      --host=${PRI_AWS_S3_ENDPOINT}                                    \
      --host-bucket=${PRI_AWS_BUCKET_NAME}.${PRI_AWS_S3_ENDPOINT}      \
      put ${staging_dir}/sources_${ts}.csv.gz                          \
      s3://${PRI_AWS_BUCKET_NAME}${PRI_AWS_BUCKET_DIR}/${ts}/sources.csv.gz
      
   if [ ! -z "$SEC_AWS_ACCESS_KEY_ID" ]
   then
      export AWS_ACCESS_KEY_ID=$SEC_AWS_ACCESS_KEY_ID
      export AWS_SECRET_ACCESS_KEY=$SEC_AWS_SECRET_ACCESS_KEY
      python ${s3cmd_location} --quiet                                 \
         --multipart-chunk-size-mb ${chunk_size}                       \
         --mime-type=application/gzip                                  \
         --no-guess-mime-type                                          \
         --add-header=content-encoding:gzip                            \
         --region=${SEC_AWS_REGION}                                    \
         --host=${SEC_AWS_S3_ENDPOINT}                                 \
         --host-bucket=${SEC_AWS_BUCKET_NAME}.${SEC_AWS_S3_ENDPOINT}   \
         put ${staging_dir}/sources_${ts}.csv.gz                       \
         s3://${SEC_AWS_BUCKET_NAME}${SEC_AWS_BUCKET_DIR}/${ts}/sources.csv.gz
   
   fi
      
   echo `date +"%Y-%m-%d %H:%M:%S"`": Creating sources zipfile." >> ${logfile}
   rm -Rf ${staging_dir}/sources.csv
   mkfifo ${staging_dir}/sources.csv
   gzip -q -d -c ${staging_dir}/sources_${ts}.csv.gz > ${staging_dir}/sources.csv & \
      zip -q -j -fz --fifo ${staging_dir}/sources_${ts}.csv.zip ${staging_dir}/sources.csv
   rm -Rf ${staging_dir}/sources.csv
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading sources zip to S3." >> ${logfile}
   export AWS_ACCESS_KEY_ID=$PRI_AWS_ACCESS_KEY_ID
   export AWS_SECRET_ACCESS_KEY=$PRI_AWS_SECRET_ACCESS_KEY
   python ${s3cmd_location} --quiet                                    \
      --multipart-chunk-size-mb ${chunk_size}                          \
      --region=${PRI_AWS_REGION}                                       \
      --host=${PRI_AWS_S3_ENDPOINT}                                    \
      --host-bucket=${PRI_AWS_BUCKET_NAME}.${PRI_AWS_S3_ENDPOINT}      \
      put ${staging_dir}/sources_${ts}.csv.zip                         \
      s3://${PRI_AWS_BUCKET_NAME}${PRI_AWS_BUCKET_DIR}/${ts}/sources.csv.zip
      
   if [ ! -z "$SEC_AWS_ACCESS_KEY_ID" ]
   then
      export AWS_ACCESS_KEY_ID=$SEC_AWS_ACCESS_KEY_ID
      export AWS_SECRET_ACCESS_KEY=$SEC_AWS_SECRET_ACCESS_KEY
      python ${s3cmd_location} --quiet                                 \
         --multipart-chunk-size-mb ${chunk_size}                       \
         --region=${SEC_AWS_REGION}                                    \
         --host=${SEC_AWS_S3_ENDPOINT}                                 \
         --host-bucket=${SEC_AWS_BUCKET_NAME}.${SEC_AWS_S3_ENDPOINT}   \
         put ${staging_dir}/sources_${ts}.csv.zip                      \
         s3://${SEC_AWS_BUCKET_NAME}${SEC_AWS_BUCKET_DIR}/${ts}/sources.csv.zip
      
   fi
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": ETL of sources complete." >> ${logfile} 
   
   ############################################################################
   # PROFILE_TMDL
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting tmdl in thread 5." >> ${logfile}
   ogr2ogr \
      --config GDAL_NUM_THREADS ${gdal_num_threads}                    \
      -f CSV /vsistdout/                                               \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${DB_HOSTSTRING}:ATTAINS_APP.PROFILE_TMDL \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,assessmentunitid,assessmentunitname,actionid,actionname,completiondate,tmdldate,fiscalyearestablished,pollutant,sourcetype,addressedparameter,locationdescription,watertype,watersize,watersizeunits,actionagency,loadallocation,loadallocationunits,explicitmarginofsafety,implicitmarginofsafety,tmdlendpoint,npdesidentifier,otheridentifier,wasteloadallocation,inindiancountry,includeinmeasure FROM ATTAINS_APP.PROFILE_TMDL a ${clause}" \
      -preserve_fid -lco LINEFORMAT=LF                                 \
      -lco STRING_QUOTING=IF_NEEDED                         |          \
   gzip -q > ${staging_dir}/tmdl_${ts}.csv.gz
        
   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading tmdl files to S3." >> ${logfile}
   export AWS_ACCESS_KEY_ID=$PRI_AWS_ACCESS_KEY_ID
   export AWS_SECRET_ACCESS_KEY=$PRI_AWS_SECRET_ACCESS_KEY
   python ${s3cmd_location} --quiet                                    \
      --multipart-chunk-size-mb ${chunk_size}                          \
      --mime-type=application/gzip                                     \
      --no-guess-mime-type                                             \
      --add-header=content-encoding:gzip                               \
      --region=${PRI_AWS_REGION}                                       \
      --host=${PRI_AWS_S3_ENDPOINT}                                    \
      --host-bucket=${PRI_AWS_BUCKET_NAME}.${PRI_AWS_S3_ENDPOINT}      \
      put ${staging_dir}/tmdl_${ts}.csv.gz                             \
      s3://${PRI_AWS_BUCKET_NAME}${PRI_AWS_BUCKET_DIR}/${ts}/tmdl.csv.gz
      
   if [ ! -z "$SEC_AWS_ACCESS_KEY_ID" ]
   then
      export AWS_ACCESS_KEY_ID=$SEC_AWS_ACCESS_KEY_ID
      export AWS_SECRET_ACCESS_KEY=$SEC_AWS_SECRET_ACCESS_KEY
      python ${s3cmd_location} --quiet                                 \
         --multipart-chunk-size-mb ${chunk_size}                       \
         --mime-type=application/gzip                                  \
         --no-guess-mime-type                                          \
         --add-header=content-encoding:gzip                            \
         --region=${SEC_AWS_REGION}                                    \
         --host=${SEC_AWS_S3_ENDPOINT}                                 \
         --host-bucket=${SEC_AWS_BUCKET_NAME}.${SEC_AWS_S3_ENDPOINT}   \
         put ${staging_dir}/tmdl_${ts}.csv.gz                          \
         s3://${SEC_AWS_BUCKET_NAME}${SEC_AWS_BUCKET_DIR}/${ts}/tmdl.csv.gz
      
   fi
      
   echo `date +"%Y-%m-%d %H:%M:%S"`": Creating tmdl zipfile." >> ${logfile}
   rm -Rf ${staging_dir}/tmdl.csv
   mkfifo ${staging_dir}/tmdl.csv
   gzip -q -d -c ${staging_dir}/tmdl_${ts}.csv.gz > ${staging_dir}/tmdl.csv & \
      zip -q -j -fz --fifo ${staging_dir}/tmdl_${ts}.csv.zip ${staging_dir}/tmdl.csv
   rm -Rf ${staging_dir}/tmdl.csv
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading tmdl zip to S3." >> ${logfile}
   export AWS_ACCESS_KEY_ID=$PRI_AWS_ACCESS_KEY_ID
   export AWS_SECRET_ACCESS_KEY=$PRI_AWS_SECRET_ACCESS_KEY
   python ${s3cmd_location} --quiet                                    \
      --multipart-chunk-size-mb ${chunk_size}                          \
      --region=${PRI_AWS_REGION}                                       \
      --host=${PRI_AWS_S3_ENDPOINT}                                    \
      --host-bucket=${PRI_AWS_BUCKET_NAME}.${PRI_AWS_S3_ENDPOINT}      \
      put ${staging_dir}/tmdl_${ts}.csv.zip                            \
      s3://${PRI_AWS_BUCKET_NAME}${PRI_AWS_BUCKET_DIR}/${ts}/tmdl.csv.zip
      
   if [ ! -z "$SEC_AWS_ACCESS_KEY_ID" ]
   then
      export AWS_ACCESS_KEY_ID=$SEC_AWS_ACCESS_KEY_ID
      export AWS_SECRET_ACCESS_KEY=$SEC_AWS_SECRET_ACCESS_KEY
      python ${s3cmd_location} --quiet                                 \
         --multipart-chunk-size-mb ${chunk_size}                       \
         --region=${SEC_AWS_REGION}                                    \
         --host=${SEC_AWS_S3_ENDPOINT}                                 \
         --host-bucket=${SEC_AWS_BUCKET_NAME}.${SEC_AWS_S3_ENDPOINT}   \
         put ${staging_dir}/tmdl_${ts}.csv.zip                         \
         s3://${SEC_AWS_BUCKET_NAME}${SEC_AWS_BUCKET_DIR}/${ts}/tmdl.csv.zip
      
   fi
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": ETL of tmdl complete." >> ${logfile}
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": Thread 1 is complete." >> ${logfile} 
   putlog
} 

thread2()
{
   ############################################################################
   # PROFILE_ASSESSMENTS
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting assessments in thread 2." >> ${logfile}
   ogr2ogr \
      --config GDAL_NUM_THREADS ${gdal_num_threads}                    \
      -f CSV /vsistdout/                                               \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${DB_HOSTSTRING}:ATTAINS_APP.PROFILE_ASSESSMENTS \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,reportingcycle,cycleid,assessmentunitid,assessmentunitname,cyclelastassessed,overallstatus,epaircategory,stateircategory,parametergroup,parametername,parameterstatus,usegroup,usename,useircategory,usestateircategory,usesupport,parameterattainment,parameterircategory,parameterstateircategory,cyclefirstlisted,associatedactionid,associatedactionname,associatedactiontype,locationdescription,watertype,watersize,watersizeunits,sizesource,sourcescale,assessmentunitstatus,useclassname,assessmentdate,assessmentbasis,monitoringstartdate,monitoringenddate,assessmentmethods,assessmenttypes,delisted,delistedreason,seasonstartdate,seasonenddate,pollutantindicator,cyclescheduledfortmdl,cycleexpectedtoattain,cwa303dpriorityranking,vision303dpriority,alternatelistingidentifier,consentdecreecycle,associatedactionstatus,associatedactionagency FROM ATTAINS_APP.PROFILE_ASSESSMENTS a ${clause}" \
      -preserve_fid -lco LINEFORMAT=LF                                 \
      -lco STRING_QUOTING=IF_NEEDED                         |          \
   gzip -q > ${staging_dir}/assessments_${ts}.csv.gz
      
   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading assessments gz to S3." >> ${logfile}
   export AWS_ACCESS_KEY_ID=$PRI_AWS_ACCESS_KEY_ID
   export AWS_SECRET_ACCESS_KEY=$PRI_AWS_SECRET_ACCESS_KEY
   python ${s3cmd_location} --quiet                                    \
      --multipart-chunk-size-mb ${chunk_size}                          \
      --mime-type=application/gzip                                     \
      --no-guess-mime-type                                             \
      --add-header=content-encoding:gzip                               \
      --region=${PRI_AWS_REGION}                                       \
      --host=${PRI_AWS_S3_ENDPOINT}                                    \
      --host-bucket=${PRI_AWS_BUCKET_NAME}.${PRI_AWS_S3_ENDPOINT}      \
      put ${staging_dir}/assessments_${ts}.csv.gz                      \
      s3://${PRI_AWS_BUCKET_NAME}${PRI_AWS_BUCKET_DIR}/${ts}/assessments.csv.gz
      
   if [ ! -z "$SEC_AWS_ACCESS_KEY_ID" ]
   then
      export AWS_ACCESS_KEY_ID=$SEC_AWS_ACCESS_KEY_ID
      export AWS_SECRET_ACCESS_KEY=$SEC_AWS_SECRET_ACCESS_KEY
      python ${s3cmd_location} --quiet                                 \
         --multipart-chunk-size-mb ${chunk_size}                       \
         --mime-type=application/gzip                                  \
         --no-guess-mime-type                                          \
         --add-header=content-encoding:gzip                            \
         --region=${SEC_AWS_REGION}                                    \
         --host=${SEC_AWS_S3_ENDPOINT}                                 \
         --host-bucket=${SEC_AWS_BUCKET_NAME}.${SEC_AWS_S3_ENDPOINT}   \
         put ${staging_dir}/assessments_${ts}.csv.gz                   \
         s3://${SEC_AWS_BUCKET_NAME}${SEC_AWS_BUCKET_DIR}/${ts}/assessments.csv.gz
      
   fi
      
   echo `date +"%Y-%m-%d %H:%M:%S"`": Creating assessments zipfile." >> ${logfile}
   rm -Rf ${staging_dir}/assessments.csv
   mkfifo ${staging_dir}/assessments.csv
   gzip -q -d -c ${staging_dir}/assessments_${ts}.csv.gz > ${staging_dir}/assessments.csv & \
      zip -q -j -fz --fifo ${staging_dir}/assessments_${ts}.csv.zip ${staging_dir}/assessments.csv
   rm -Rf ${staging_dir}/assessments.csv
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading assessments zip to S3." >> ${logfile}
   export AWS_ACCESS_KEY_ID=$PRI_AWS_ACCESS_KEY_ID
   export AWS_SECRET_ACCESS_KEY=$PRI_AWS_SECRET_ACCESS_KEY
   python ${s3cmd_location} --quiet                                    \
      --multipart-chunk-size-mb ${chunk_size}                          \
      --region=${PRI_AWS_REGION}                                       \
      --host=${PRI_AWS_S3_ENDPOINT}                                    \
      --host-bucket=${PRI_AWS_BUCKET_NAME}.${PRI_AWS_S3_ENDPOINT}      \
      put ${staging_dir}/assessments_${ts}.csv.zip                     \
      s3://${PRI_AWS_BUCKET_NAME}${PRI_AWS_BUCKET_DIR}/${ts}/assessments.csv.zip
      
   if [ ! -z "$SEC_AWS_ACCESS_KEY_ID" ]
   then
      export AWS_ACCESS_KEY_ID=$SEC_AWS_ACCESS_KEY_ID
      export AWS_SECRET_ACCESS_KEY=$SEC_AWS_SECRET_ACCESS_KEY
      python ${s3cmd_location} --quiet                                 \
         --multipart-chunk-size-mb ${chunk_size}                       \
         --region=${SEC_AWS_REGION}                                    \
         --host=${SEC_AWS_S3_ENDPOINT}                                 \
         --host-bucket=${SEC_AWS_BUCKET_NAME}.${SEC_AWS_S3_ENDPOINT}   \
         put ${staging_dir}/assessments_${ts}.csv.zip                  \
         s3://${SEC_AWS_BUCKET_NAME}${SEC_AWS_BUCKET_DIR}/${ts}/assessments.csv.zip
      
   fi
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": ETL of assessments complete." >> ${logfile}
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": Thread 2 is complete." >> ${logfile} 
   putlog
} 

thread3()
{
   ############################################################################
   # PROFILE_CATCHMENT_CORRESPONDENCE
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting catchment_correspondence in thread 3." >> ${logfile}
   ogr2ogr \
      --config GDAL_NUM_THREADS ${gdal_num_threads}                    \
      -f CSV /vsistdout/                                               \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${DB_HOSTSTRING}:ATTAINS_APP.PROFILE_CATCHMENT_CORRESPONDENCE \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,reportingcycle,cycleid,assessmentunitid,assessmentunitname,catchmentnhdplusid FROM ATTAINS_APP.PROFILE_CATCHMENT_CORRESPONDENCE a ${clause}" \
      -preserve_fid -lco LINEFORMAT=LF                                 \
      -lco STRING_QUOTING=IF_NEEDED                         |          \
   gzip -q > ${staging_dir}/catchment_correspondence_${ts}.csv.gz

   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading catchment_correspondence gz to S3." >> ${logfile}
   export AWS_ACCESS_KEY_ID=$PRI_AWS_ACCESS_KEY_ID
   export AWS_SECRET_ACCESS_KEY=$PRI_AWS_SECRET_ACCESS_KEY
   python ${s3cmd_location} --quiet                                    \
      --multipart-chunk-size-mb ${chunk_size}                          \
      --mime-type=application/gzip                                     \
      --no-guess-mime-type                                             \
      --add-header=content-encoding:gzip                               \
      --region=${PRI_AWS_REGION}                                       \
      --host=${PRI_AWS_S3_ENDPOINT}                                    \
      --host-bucket=${PRI_AWS_BUCKET_NAME}.${PRI_AWS_S3_ENDPOINT}      \
      put ${staging_dir}/catchment_correspondence_${ts}.csv.gz         \
      s3://${PRI_AWS_BUCKET_NAME}${PRI_AWS_BUCKET_DIR}/${ts}/catchment_correspondence.csv.gz
      
   if [ ! -z "$SEC_AWS_ACCESS_KEY_ID" ]
   then
      export AWS_ACCESS_KEY_ID=$SEC_AWS_ACCESS_KEY_ID
      export AWS_SECRET_ACCESS_KEY=$SEC_AWS_SECRET_ACCESS_KEY
      python ${s3cmd_location} --quiet                                 \
         --multipart-chunk-size-mb ${chunk_size}                       \
         --mime-type=application/gzip                                  \
         --no-guess-mime-type                                          \
         --add-header=content-encoding:gzip                            \
         --region=${SEC_AWS_REGION}                                    \
         --host=${SEC_AWS_S3_ENDPOINT}                                 \
         --host-bucket=${SEC_AWS_BUCKET_NAME}.${SEC_AWS_S3_ENDPOINT}   \
         put ${staging_dir}/catchment_correspondence_${ts}.csv.gz      \
         s3://${SEC_AWS_BUCKET_NAME}${SEC_AWS_BUCKET_DIR}/${ts}/catchment_correspondence.csv.gz
      
   fi
      
   echo `date +"%Y-%m-%d %H:%M:%S"`": Creating catchment_correspondence zipfile." >> ${logfile}
   rm -Rf ${staging_dir}/catchment_correspondence.csv
   mkfifo ${staging_dir}/catchment_correspondence.csv
   gzip -q -d -c ${staging_dir}/catchment_correspondence_${ts}.csv.gz > ${staging_dir}/catchment_correspondence.csv & \
      zip -q -j -fz --fifo ${staging_dir}/catchment_correspondence_${ts}.csv.zip ${staging_dir}/catchment_correspondence.csv
   rm -Rf ${staging_dir}/catchment_correspondence.csv
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading catchment_correspondence zip to S3." >> ${logfile}
   export AWS_ACCESS_KEY_ID=$PRI_AWS_ACCESS_KEY_ID
   export AWS_SECRET_ACCESS_KEY=$PRI_AWS_SECRET_ACCESS_KEY
   python ${s3cmd_location} --quiet                                    \
      --multipart-chunk-size-mb ${chunk_size}                          \
      --region=${PRI_AWS_REGION}                                       \
      --host=${PRI_AWS_S3_ENDPOINT}                                    \
      --host-bucket=${PRI_AWS_BUCKET_NAME}.${PRI_AWS_S3_ENDPOINT}      \
      put ${staging_dir}/catchment_correspondence_${ts}.csv.zip        \
      s3://${PRI_AWS_BUCKET_NAME}${PRI_AWS_BUCKET_DIR}/${ts}/catchment_correspondence.csv.zip
      
   if [ ! -z "$SEC_AWS_ACCESS_KEY_ID" ]
   then
      export AWS_ACCESS_KEY_ID=$SEC_AWS_ACCESS_KEY_ID
      export AWS_SECRET_ACCESS_KEY=$SEC_AWS_SECRET_ACCESS_KEY
      python ${s3cmd_location} --quiet                                 \
         --multipart-chunk-size-mb ${chunk_size}                       \
         --region=${SEC_AWS_REGION}                                    \
         --host=${SEC_AWS_S3_ENDPOINT}                                 \
         --host-bucket=${SEC_AWS_BUCKET_NAME}.${SEC_AWS_S3_ENDPOINT}   \
         put ${staging_dir}/catchment_correspondence_${ts}.csv.zip     \
         s3://${SEC_AWS_BUCKET_NAME}${SEC_AWS_BUCKET_DIR}/${ts}/catchment_correspondence.csv.zip
      
   fi
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": ETL of catchment_correspondence complete." >> ${logfile}
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": Thread 3 is complete." >> ${logfile} 
   putlog
}

thread1 &
thread2 &
thread3 &
wait

echo `date +"%Y-%m-%d %H:%M:%S"`": All threads complete." >> ${logfile} 

###############################################################################
# Write out the status and latest files
echo "{"                          >  ${statusfile}
echo "    \"tag\":\"${etl_tag}\"" >> ${statusfile}
echo "   ,\"julian\":${ts}"       >> ${statusfile}
echo "}"                          >> ${statusfile}
putstatus

echo "{"                          >  ${latestfile}
echo "    \"tag\":\"${etl_tag}\"" >> ${latestfile}
echo "   ,\"julian\":${ts}"       >> ${latestfile}
echo "}"                          >> ${latestfile}
putlatest

if [ ! -z "$SEC_AWS_ACCESS_KEY_ID" ]
then
   putlatest_sec
fi

###############################################################################
echo `date +"%Y-%m-%d %H:%M:%S"`": All ETL tasks completed successfully." >> ${logfile} 
putlog

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
