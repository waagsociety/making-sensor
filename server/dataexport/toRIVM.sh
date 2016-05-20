#!/bin/bash

HOURS=${1}
TMP_DIR=/tmp

if [ -z "${HOURS}" ]
then
	echo "Nr of hours in the past must be provided, exiting"
	exit 1
fi

FORMAT="'${HOURS} hour ago'"

#echo ${FORMAT}

FROM_TIME="date '+%Y-%m-%d %T%z' -d ${FORMAT} "

#echo "${FROM_TIME}"

MY_TIME=$(eval "${FROM_TIME}")
#MY_TIME="$(${FROM_TIME})"

NOW="$(date '+%Y_%m_%d_%H_%M_%S')"
MACHINE_NAME="$(uname -n)"
OUTPUTFILE="${TMP_DIR}/${MACHINE_NAME}.${NOW}.csv"

# remove old data files
rm -f ${TMP_DIR}/${MACHINE_NAME}.*.csv &>/dev/null

HEADERS="id,srv_ts,rssi,temp,pm10,pm25,no2a,no2b,humidity"
VALID_DATA=" AND id >= 100 AND NOT (temp is NULL AND pm10 is NULL AND pm25 IS NULL AND no2a IS NULL AND no2b IS NULL AND humidity IS NULL) "
#VALID_DATA=" AND id >= 100 "

DBNAME=airq

echo "#${HEADERS}" > ${OUTPUTFILE}

sudo su postgres -c "psql -d ${DBNAME} -t -A -F',' -c \"select ${HEADERS} from measures where srv_ts > '${MY_TIME}'::timestamp with time zone ${VALID_DATA} ;\" " >> ${OUTPUTFILE}

if [ "$(cat ${OUTPUTFILE} | wc -l)" = "1" ]
then
	echo "No real sensor data for the past ${HOURS} hour(s) at $(date)"
	exit 1
fi

MY_KEY="$(find $HOME -name rvmi_key.private.key)"

sudo scp -o StrictHostKeyChecking=no -i ${MY_KEY} ${OUTPUTFILE} waag@sftp.rivm.nl:/incoming/waag
