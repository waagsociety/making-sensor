#/bin/bash

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
OUTPUTFILE="${TMP_DIR}/airq.${NOW}.csv"

HEADERS="id,srv_ts,rssi,temp,pm10,pm25,no2a,no2b"
DBNAME=airq

echo "#${HEADERS}" > ${OUTPUTFILE}

sudo su postgres -c "psql -d ${DBNAME} -t -A -F',' -c \"select ${HEADERS} from measures where srv_ts > '${MY_TIME}'::timestamp with time zone;\" " >> ${OUTPUTFILE}

if [ "$(cat ${OUTPUTFILE} | wc -l)" = "1" ]
then
	echo "No sensor data for the past ${HOURS} at $(date)"
	exit 1
fi

sudo scp -i /home/airqdaemon/.ssh/id_rsa ${OUTPUTFILE} waag@sftp.rivm.nl:/incoming/waag
