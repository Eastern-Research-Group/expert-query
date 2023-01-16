#/bin/sh

###############################################################################
# Configuration

# Staging directory needs at least 6GB to process current profile ETL
staging_dir=/data/waterspb/loading_dock
# Number of threads used by GDAL processes
gdal_num_threads=1
# Target S3 bucket details
bucket_name=cg-4b438f23-e2c7-4711-bde2-8e165bb93e01
aws_region=us-gov-west-1
aws_s3_endpoint=s3-fips.us-gov-west-1.amazonaws.com
# Chunk size to use when uploading to S3
chunk_size=1000
# target extraction database
oracle_hoststring=VMWATERS7.RTPNC.EPA.GOV:1521/OWPUB.VMWATERS7

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
# Secrets must contain values for
# DB_USERNAME
# DB_PASSWORD
# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY
# alter location if you need to place this elsewhere
secrets_location=~/.env

if [ ! -f ${secrets_location} ]
then
   echo "unable to read .env secrets file at $secrets_location"
   exit -1
fi

while read -r LINE; do
   if [[ $LINE == *'='* ]] && [[ $LINE != '#'* ]]; then
      ENV_VAR="$(echo $LINE | envsubst)"
      eval "declare $ENV_VAR"
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
   python ${s3cmd_location} --quiet                   \
      --region=${aws_region}                          \
      --host=${aws_s3_endpoint}                       \
      --host-bucket=${bucket_name}.${aws_s3_endpoint} \
      put ${logfile}                                  \
      s3://${bucket_name}/${ts}/logfile.txt
}

putstatus()
{
   python ${s3cmd_location} --quiet                   \
      --region=${aws_region}                          \
      --host=${aws_s3_endpoint}                       \
      --host-bucket=${bucket_name}.${aws_s3_endpoint} \
      put ${statusfile}                               \
      s3://${bucket_name}/${ts}/status.json
}

putready()
{
   python ${s3cmd_location} --quiet                   \
      --region=${aws_region}                          \
      --host=${aws_s3_endpoint}                       \
      --host-bucket=${bucket_name}.${aws_s3_endpoint} \
      put ${readyfile}                               \
      s3://${bucket_name}/${ts}/ready.json
}

putlatest()
{
   python ${s3cmd_location} --quiet                   \
      --region=${aws_region}                          \
      --host=${aws_s3_endpoint}                       \
      --host-bucket=${bucket_name}.${aws_s3_endpoint} \
      put ${latestfile}                               \
      s3://${bucket_name}/latest.json
}

echo `date +"%Y-%m-%d %H:%M:%S"`": Starting ATTAINS profile ETL for ${ts}" >> ${logfile}
putlog

###############################################################################
# Query bucket for information on the last extraction
python ${s3cmd_location} --quiet                   \
   --region=${aws_region}                          \
   --host=${aws_s3_endpoint}                       \
   --host-bucket=${bucket_name}.${aws_s3_endpoint} \
   get s3://${bucket_name}/latest.json ${latestfile} 2> /dev/null

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
   OCI:${DB_USERNAME}/${DB_PASSWORD}@${oracle_hoststring}:ATTAINS_APP.PROFILE_TMDL \
   -q -nomd -nocount -noextent                                                     \
   -sql "SELECT TO_CHAR(rad_nhd.util.go_nogo('JSON')) AS ready FROM dual" |        \
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
#clause="WHERE rownum <= 100"
clause=""

thread1()
{   
   # PROFILE_ACTIONS
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting actions in thread 1." >> ${logfile}
   ogr2ogr \
      --config PG_USE_COPY YES                        \
      --config GDAL_NUM_THREADS ${gdal_num_threads}   \
      -f PGDump /vsistdout/                           \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${oracle_hoststring}:ATTAINS_APP.PROFILE_ACTIONS \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,assessmentunitid,assessmentunitname,actionid,actionname,completiondate,parameter,locationdescription,actiontype,watertype,watersize,watersizeunits,actionagency,inindiancountry,includeinmeasure FROM ATTAINS_APP.PROFILE_ACTIONS a ${clause}" \
      -preserve_fid -lco FID=objectid                 \
      -nln actions                                    \
      -lco "GEOMETRY_NAME=shape"                      \
      -lco "CREATE_SCHEMA=OFF"                        \
      -lco "CREATE_TABLE=OFF" |                       \
   awk '/^COPY ".*FROM STDIN;$/{flag=1;next}/^\\\.$/{print;flag=0}flag' | \
   gzip > ${staging_dir}/actions_${ts}.copy.gz
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading actions to S3." >> ${logfile}
   python ${s3cmd_location} --quiet                   \
      --multipart-chunk-size-mb ${chunk_size}         \
      --mime-type=application/gzip                    \
      --no-guess-mime-type                            \
      --add-header=content-encoding:gzip              \
      --region=${aws_region}                          \
      --host=${aws_s3_endpoint}                       \
      --host-bucket=${bucket_name}.${aws_s3_endpoint} \
      put ${staging_dir}/actions_${ts}.copy.gz         \
      s3://${bucket_name}/${ts}/actions.copy.gz
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": ETL of actions complete." >> ${logfile}   
   
   # PROFILE_ASSESSMENT_UNITS
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting assessment_units in thread 1." >> ${logfile}
   ogr2ogr \
      --config PG_USE_COPY YES                        \
      --config GDAL_NUM_THREADS ${gdal_num_threads}   \
      -f PGDump /vsistdout/                           \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${oracle_hoststring}:ATTAINS_APP.PROFILE_ASSESSMENT_UNITS \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,reportingcycle,assessmentunitid,assessmentunitname,locationdescription,watertype,watersize,watersizeunits,assessmentunitstatus,useclassname,sizesource,sourcescale,locationtypecode,locationtext FROM ATTAINS_APP.PROFILE_ASSESSMENT_UNITS a ${clause}" \
      -preserve_fid -lco FID=objectid                 \
      -nln assessment_units                           \
      -lco "GEOMETRY_NAME=shape"                      \
      -lco "CREATE_SCHEMA=OFF"                        \
      -lco "CREATE_TABLE=OFF" |                       \
   awk '/^COPY ".*FROM STDIN;$/{flag=1;next}/^\\\.$/{print;flag=0}flag' | \
   gzip > ${staging_dir}/assessment_units_${ts}.copy.gz
      
   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading assessment_units to S3." >> ${logfile}
   python ${s3cmd_location} --quiet                   \
      --multipart-chunk-size-mb ${chunk_size}         \
      --mime-type=application/gzip                    \
      --no-guess-mime-type                            \
      --add-header=content-encoding:gzip              \
      --region=${aws_region}                          \
      --host=${aws_s3_endpoint}                       \
      --host-bucket=${bucket_name}.${aws_s3_endpoint} \
      put ${staging_dir}/assessment_units_${ts}.copy.gz \
      s3://${bucket_name}/${ts}/assessment_units.copy.gz
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": ETL of assessment_units complete." >> ${logfile} 
   
   # PROFILE_ASSESSMENT_UNITS_MONITORING_LOCATIONS
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting assessment_units_monitoring_locations in thread 1." >> ${logfile}
   ogr2ogr \
      --config PG_USE_COPY YES                        \
      --config GDAL_NUM_THREADS ${gdal_num_threads}   \
      -f PGDump /vsistdout/                           \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${oracle_hoststring}:ATTAINS_APP.PROFILE_ASSESSMENT_UNITS_MONITORING_LOCATIONS \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,reportingcycle,assessmentunitid,assessmentunitname,locationdescription,watertype,watersize,watersizeunits,monitoringlocationorgid,monitoringlocationid,monitoringlocationdatalink,assessmentunitstatus,useclassname,sizesource,sourcescale FROM ATTAINS_APP.PROFILE_ASSESSMENT_UNITS_MONITORING_LOCATIONS a ${clause}" \
      -preserve_fid -lco FID=objectid                 \
      -nln assessment_units_monitoring_locations      \
      -lco "GEOMETRY_NAME=shape"                      \
      -lco "CREATE_SCHEMA=OFF"                        \
      -lco "CREATE_TABLE=OFF" |                       \
   awk '/^COPY ".*FROM STDIN;$/{flag=1;next}/^\\\.$/{print;flag=0}flag' | \
   gzip > ${staging_dir}/assessment_units_monitoring_locations_${ts}.copy.gz
      
   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading assessment_units_monitoring_locations to S3." >> ${logfile}
   python ${s3cmd_location} --quiet                   \
      --multipart-chunk-size-mb ${chunk_size}         \
      --mime-type=application/gzip                    \
      --no-guess-mime-type                            \
      --add-header=content-encoding:gzip              \
      --region=${aws_region}                          \
      --host=${aws_s3_endpoint}                       \
      --host-bucket=${bucket_name}.${aws_s3_endpoint} \
      put ${staging_dir}/assessment_units_monitoring_locations_${ts}.copy.gz \
      s3://${bucket_name}/${ts}/assessment_units_monitoring_locations.copy.gz
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": ETL of assessment_units_monitoring_locations complete." >> ${logfile} 
   
   # PROFILE_SOURCES
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting sources in thread 1." >> ${logfile}
   ogr2ogr \
      --config PG_USE_COPY YES                        \
      --config GDAL_NUM_THREADS ${gdal_num_threads}   \
      -f PGDump /vsistdout/                           \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${oracle_hoststring}:ATTAINS_APP.PROFILE_SOURCES \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,reportingcycle,assessmentunitid,assessmentunitname,overallstatus,epaircategory,stateircategory,sourcename,confirmed,parametergroup,causename,locationdescription,watertype,watersize,watersizeunits FROM ATTAINS_APP.PROFILE_SOURCES a ${clause}" \
      -preserve_fid -lco FID=objectid                 \
      -nln sources                                    \
      -lco "GEOMETRY_NAME=shape"                      \
      -lco "CREATE_SCHEMA=OFF"                        \
      -lco "CREATE_TABLE=OFF" |                       \
   awk '/^COPY ".*FROM STDIN;$/{flag=1;next}/^\\\.$/{print;flag=0}flag' | \
   gzip > ${staging_dir}/sources_${ts}.copy.gz
      
   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading sources to S3." >> ${logfile}
   python ${s3cmd_location} --quiet                   \
      --multipart-chunk-size-mb ${chunk_size}         \
      --mime-type=application/gzip                    \
      --no-guess-mime-type                            \
      --add-header=content-encoding:gzip              \
      --region=${aws_region}                          \
      --host=${aws_s3_endpoint}                       \
      --host-bucket=${bucket_name}.${aws_s3_endpoint} \
      put ${staging_dir}/sources_${ts}.copy.gz         \
      s3://${bucket_name}/${ts}/sources.copy.gz
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": ETL of sources complete." >> ${logfile} 
   
   # PROFILE_TMDL
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting tmdl in thread 1." >> ${logfile}
   ogr2ogr \
      --config PG_USE_COPY YES                        \
      --config GDAL_NUM_THREADS ${gdal_num_threads}   \
      -f PGDump /vsistdout/                           \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${oracle_hoststring}:ATTAINS_APP.PROFILE_TMDL \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,reportingcycle,assessmentunitid,assessmentunitname,actionid,actionname,completiondate,tmdldate,fiscalyearestablished,pollutant,sourcetype,addressedparameter,locationdescription,watertype,watersize,watersizeunits,actionagency,loadallocation,loadallocationunits,explicitmarginofsafety,implicitmarginofsafety,tmdlendpoint,npdesidentifier,otheridentifier,wasteloadallocation,inindiancountry,includeinmeasure FROM ATTAINS_APP.PROFILE_TMDL a ${clause}" \
      -preserve_fid -lco FID=objectid                 \
      -nln tmdl                                       \
      -lco "GEOMETRY_NAME=shape"                      \
      -lco "CREATE_SCHEMA=OFF"                        \
      -lco "CREATE_TABLE=OFF" |                       \
   awk '/^COPY ".*FROM STDIN;$/{flag=1;next}/^\\\.$/{print;flag=0}flag' | \
   gzip > ${staging_dir}/tmdl_${ts}.copy.gz
      
   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading tmdl to S3." >> ${logfile}
   python ${s3cmd_location} --quiet                   \
      --multipart-chunk-size-mb ${chunk_size}         \
      --mime-type=application/gzip                    \
      --no-guess-mime-type                            \
      --add-header=content-encoding:gzip              \
      --region=${aws_region}                          \
      --host=${aws_s3_endpoint}                       \
      --host-bucket=${bucket_name}.${aws_s3_endpoint} \
      put ${staging_dir}/tmdl_${ts}.copy.gz            \
      s3://${bucket_name}/${ts}/tmdl.copy.gz
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": ETL of tmdl complete." >> ${logfile}
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": Thread 1 is complete." >> ${logfile} 
   putlog
} 

thread2()
{
   # PROFILE_ASSESSMENTS
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting assessments in thread 2." >> ${logfile}
   ogr2ogr \
      --config PG_USE_COPY YES                        \
      --config GDAL_NUM_THREADS ${gdal_num_threads}   \
      -f PGDump /vsistdout/                           \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${oracle_hoststring}:ATTAINS_APP.PROFILE_ASSESSMENTS \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,reportingcycle,assessmentunitid,assessmentunitname,cyclelastassessed,overallstatus,epaircategory,stateircategory,parametergroup,parametername,parameterstatus,usegroup,usename,useircategory,usestateircategory,usesupport,parameterattainment,parameterircategory,parameterstateircategory,cyclefirstlisted,associatedactionid,associatedactionname,associatedactiontype,locationdescription,watertype,watersize,watersizeunits,sizesource,sourcescale,assessmentunitstatus,useclassname,assessmentdate,assessmentbasis,monitoringstartdate,monitoringenddate,assessmentmethods,assessmenttypes,delisted,delistedreason,seasonstartdate,seasonenddate,pollutantindicator,cyclescheduledfortmdl,cycleexpectedtoattain,cwa303dpriorityranking,vision303dpriority,alternatelistingidentifier,consentdecreecycle,associatedactionstatus,associatedactionagency FROM ATTAINS_APP.PROFILE_ASSESSMENTS a ${clause}" \
      -preserve_fid -lco FID=objectid                 \
      -nln assessments                                \
      -lco "GEOMETRY_NAME=shape"                      \
      -lco "CREATE_SCHEMA=OFF"                        \
      -lco "CREATE_TABLE=OFF" |                       \
   awk '/^COPY ".*FROM STDIN;$/{flag=1;next}/^\\\.$/{print;flag=0}flag' | \
   gzip > ${staging_dir}/assessments_${ts}.copy.gz
      
   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading assessments to S3." >> ${logfile}
   python ${s3cmd_location} --quiet                   \
      --multipart-chunk-size-mb ${chunk_size}         \
      --mime-type=application/gzip                    \
      --no-guess-mime-type                            \
      --add-header=content-encoding:gzip              \
      --region=${aws_region}                          \
      --host=${aws_s3_endpoint}                       \
      --host-bucket=${bucket_name}.${aws_s3_endpoint} \
      put ${staging_dir}/assessments_${ts}.copy.gz     \
      s3://${bucket_name}/${ts}/assessments.copy.gz
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": ETL of assessments complete." >> ${logfile}
   
   echo `date +"%Y-%m-%d %H:%M:%S"`": Thread 2 is complete." >> ${logfile} 
   putlog
} 

thread3()
{
   # PROFILE_CATCHMENT_CORRESPONDENCE
   echo `date +"%Y-%m-%d %H:%M:%S"`": Exporting catchment_correspondence in thread 3." >> ${logfile}
   ogr2ogr \
      --config PG_USE_COPY YES                        \
      --config GDAL_NUM_THREADS ${gdal_num_threads}   \
      -f PGDump /vsistdout/                           \
      OCI:${DB_USERNAME}/${DB_PASSWORD}@${oracle_hoststring}:ATTAINS_APP.PROFILE_CATCHMENT_CORRESPONDENCE \
      -sql "SELECT CAST(row_id AS INTEGER) AS objectid,state,region,organizationid,organizationname,organizationtype,reportingcycle,assessmentunitid,assessmentunitname,catchmentnhdplusid FROM ATTAINS_APP.PROFILE_CATCHMENT_CORRESPONDENCE a ${clause}" \
      -preserve_fid -lco FID=objectid                 \
      -nln catchment_correspondence                   \
      -lco "GEOMETRY_NAME=shape"                      \
      -lco "CREATE_SCHEMA=OFF"                        \
      -lco "CREATE_TABLE=OFF" |                       \
   awk '/^COPY ".*FROM STDIN;$/{flag=1;next}/^\\\.$/{print;flag=0}flag' | \
   gzip > ${staging_dir}/catchment_correspondence_${ts}.copy.gz
      
   echo `date +"%Y-%m-%d %H:%M:%S"`": Uploading catchment_correspondence to S3." >> ${logfile}
   python ${s3cmd_location} --quiet                   \
      --multipart-chunk-size-mb ${chunk_size}         \
      --mime-type=application/gzip                    \
      --no-guess-mime-type                            \
      --add-header=content-encoding:gzip              \
      --region=${aws_region}                          \
      --host=${aws_s3_endpoint}                       \
      --host-bucket=${bucket_name}.${aws_s3_endpoint} \
      put ${staging_dir}/catchment_correspondence_${ts}.copy.gz \
      s3://${bucket_name}/${ts}/catchment_correspondence.copy.gz
   
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

###############################################################################
echo `date +"%Y-%m-%d %H:%M:%S"`": All ETL tasks completed successfuly." >> ${logfile} 
putlog
