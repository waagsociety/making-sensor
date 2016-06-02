#!/bin/bash
# Backup DBs

parse_yaml() {
  FILE=${1}
  CONTEXT=${2}
  FIELD=${3}

  #echo "FILE=${FILE}, CONTEXT=${CONTEXT}, FIELD=${FIELD}"

   awk  "
   BEGIN {i=0}
   /${CONTEXT}:/ {i=1;next}
   i && /${FIELD}:/ {print \$2;i=0}
   " ${FILE}

}

TARGET=${1}
AWS_HOST="52.58.166.63"
EMAIL_ADDRESS="stefano@waag.org"

if [ "${TARGET} " == " " ]
then
  if ! nslookup sensor.waag.org | grep "${AWS_HOST}"  > /dev/null
  then
     TARGET="WAAG"
   else
     TARGET="AWS"
   fi
fi

#set -o nounset

if [ "${TARGET} " == "AWS " ]
then
  PORT=22
  USER=ubuntu
  HOST=${AWS_HOST}
elif [ "${TARGET} " == "WAAG " ]
then
  PORT=2234
  USER=stefano
  HOST=wg66.waag.org
else
  echo "Need to specify server!!"
  exit 1
fi

#set -o errexit

NOW="$(date '+%Y_%m_%d_%H_%M_%S')"
MACHINE_NAME="$(uname -n)"
TMP_DIR=/tmp
OUTPUTFILE="${TMP_DIR}/${MACHINE_NAME}.${NOW}.csv"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
MY_KEY=$(find ../ -name airq_key)

# remove old data files
rm -f ${TMP_DIR}/${MACHINE_NAME}.*.csv &>/dev/null

HEADERS="id,srv_ts,rssi,temp,pm10,pm25,no2a,no2b,humidity"
VALID_DATA="id >= 100 AND NOT (temp is NULL AND pm10 is NULL AND pm25 IS NULL AND no2a IS NULL AND no2b IS NULL AND humidity IS NULL) "
#VALID_DATA=" AND id >= 100 "

DBNAME=airq


if date -j >/dev/null 2>&1
then
  FROM_TIME="$(date -v-1d '+%F 00:00:00%z')"
else
  FROM_TIME="$(date '+%Y-%m-%d 00:00:00%z' -d '1 day ago')"
fi

TO_TIME="$(date '+%Y-%m-%d 00:00:00%z')"

#echo ${FROM_TIME} -- ${TO_TIME}

TIME_WHERE="srv_ts >= '${FROM_TIME}'::timestamp with time zone AND srv_ts < '${TO_TIME}'::timestamp with time zone"
#echo ${TIME_WHERE}

CONF_FILE=$(find ../ -name makingsense.yaml)
AIRQ_USER=$(parse_yaml ${CONF_FILE} airqdb user)
AIRQ_PASSWD=$(parse_yaml ${CONF_FILE} airqdb password)

CMD="PGPASSWORD=${AIRQ_PASSWD} psql -U ${AIRQ_USER} -h localhost airq -c -t -A -F',' -c \"select ${HEADERS} from measures where ${TIME_WHERE} AND ${VALID_DATA} ;\"  "
#echo ${CMD}

ssh ${SSH_OPTS} -p ${PORT} -i ${MY_KEY} ${USER}@${HOST}  "${CMD}" >> ${OUTPUTFILE}


if [ "$(cat ${OUTPUTFILE} | wc -l)" = "1" ]
then
	echo "No real sensor data for the past day at $(date)"
	exit 1
else
  echo "Sensor data for the past day at $(date) in ${OUTPUTFILE}"
  echo "Sensor data file generated at $(date)" | mail -s "Sensor data for the past day" ${EMAIL_ADDRESS} --content-type="text/csv" --attach=${OUTPUTFILE}
fi
