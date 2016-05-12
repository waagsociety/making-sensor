#!/bin/bash

MY_HOST=52.58.166.63
MY_USER=ubuntu
SSH_PORT=22
THRESHOLD=15
EMAIL_ADDRESS=stefano@waag.org
TMP_FILE=/tmp/airq


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

diff_min(){
  local DATA_TIME="${1}00"
  local DATA_S_TIME=$(date -j -f "%Y-%m-%d %H:%M:%S%z" "${DATA_TIME}" "+%s")

  ELAPSED_MIN=$(date -r $(($(date "+%s") - ${DATA_S_TIME})) "+%-M")
}

## find conf dir
if [ ! -z ${TERM} ]
then
  clear
fi

echo "Test start" | tee ${TMP_FILE}

PASSED=true

CONF_FILE=$(find ./ -name makingsense.yaml)
#echo ${CONF_FILE}
MY_KEY=$(find . -name airq_key)
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

if which mosquitto_pub >/dev/null
then
  ## Test mosquitto agent
  MOSQUITTO_USER=$(parse_yaml ${CONF_FILE} mqtt username)
  MOSQUITTO_PASSWD=$(parse_yaml ${CONF_FILE} mqtt password)

  #echo ${MY_USR} ${MY_PWD}
  TESTID=0
  MY_QOS=0
  UNIQUE_MSG="$RANDOM $(date +'%Y-%m-%d %H:%M:%S%z')"
  MY_MSG="{\"i\":${TESTID},\"rssi\":-75,\"message\":\"${UNIQUE_MSG}\"}"

  if ! mosquitto_pub -h ${MY_HOST} -u "${MOSQUITTO_USER}" -P "${MOSQUITTO_PASSWD}" -i "${TESTID}" -t "sensor/${ID}/data" -m "$MY_MSG" -q ${MY_QOS}
  then
    echo "ERROR mosquitto not set" | tee -a ${TMP_FILE}
    PASSED=false
  fi

#  echo "Tailing mosquitto log"
#  LINES=$((${REP} * ${SENSORS} * 6))
#  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p ${SSH_PORT} -i ${MY_KEY} ${MY_USER}@${MY_HOST} "tail -n ${LINES} /var/log/mosquitto/mosquitto.log"

  AIRQ_USER=$(parse_yaml ${CONF_FILE} airqdb user)
  AIRQ_PASSWD=$(parse_yaml ${CONF_FILE} airqdb password)

  HITS=$(ssh ${SSH_OPTS} -p ${SSH_PORT} -i ${MY_KEY} ${MY_USER}@${MY_HOST} "PGPASSWORD=${AIRQ_PASSWD} psql -t -A -U ${AIRQ_USER} -h localhost airq -c \"SELECT count(id) from measures WHERE id=${TESTID} AND message = '${UNIQUE_MSG}'\" " 2>/dev/null)
  if [ "${HITS}" = "0" ]
  then
    echo "Something wrong in data acquisition from mosquitto server to DB" | tee -a ${TMP_FILE}
    PASSED=false
  else
    echo "Data acquisition from mosquitto server to DB is OK" | tee -a ${TMP_FILE}
  fi
else
  echo "mosquitto_pub is not installed, skipping mosquitto test" | tee -a ${TMP_FILE}
  PASSED=false
fi


## Test traffic data

MY_TIME=$(ssh ${SSH_OPTS} -p ${SSH_PORT} -i ${MY_KEY} ${MY_USER}@${MY_HOST} 'sudo su postgres -c "psql -t -A -d traffic -c \"SELECT max(timestmp) from traveltime\" " ' 2>/dev/null)
echo "Most recent traffic data: ${MY_TIME}" | tee -a ${TMP_FILE}
diff_min "${MY_TIME}"
echo "Data is ${ELAPSED_MIN} min old" | tee -a ${TMP_FILE}

if (( ${ELAPSED_MIN} > ${THRESHOLD} ))
then
  PASSED=false
fi
## Test measures

MY_TIME=$(ssh ${SSH_OPTS} -p ${SSH_PORT} -i ${MY_KEY} ${MY_USER}@${MY_HOST} 'sudo su postgres -c "psql -t -A -d airq -c \"SELECT max(srv_ts) from measures\" " ' 2>/dev/null)
echo "Most recent sensor data: ${MY_TIME}" | tee -a ${TMP_FILE}
MY_TIME=$(echo ${MY_TIME} | sed 's/\(.*\)\.[0-9][0-9]*\(\+.*\)/\1\2/g')
diff_min "${MY_TIME}"
echo "Data is ${ELAPSED_MIN} min old" | tee -a ${TMP_FILE}

if ((${ELAPSED_MIN} > ${THRESHOLD} ))
then
  PASSED=false
fi

if [ ! "$PASSED" = "true" ]
then
  echo "Test NOT passed" | tee -a ${TMP_FILE}
  mail -s "AIRQ Test NOT passed" ${EMAIL_ADDRESS} < ${TMP_FILE}
else
  echo "Test passed" | tee -a ${TMP_FILE}
fi
