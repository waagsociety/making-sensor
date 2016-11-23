#!/bin/bash

##########################
# General parameters
##########################

TIME_THRESHOLD=30
TRAFFIC_TIME_THRESHOLD=10
DISK_THRESHOLD=50
LOAD_THRESHOLD=1.5

TIME_NOTICE=120

TMP_FILE=/tmp/airq
EMAIL_ADDRESS=stefano@waag.org

TARGET=${1}
AWS_HOST="52.58.166.63"

if [ "${TARGET} " == " " ]
then
  if ! nslookup sensor.waag.org | grep "${AWS_HOST}"  > /dev/null
  then
     TARGET="waag"
   else
     TARGET="aws"
   fi
fi

# if [ ! "$#" = 1 ]
# then
#   echo "Usage: specify aws or waag" | tee ${TMP_FILE}
#   mail -s "AIRQ Test NOT passed" ${EMAIL_ADDRESS} < ${TMP_FILE}
#   exit 1
# fi


##########################
# Host specific parameters
##########################

if [ "${TARGET}" = "aws" ]
then
  MY_HOST=52.58.166.63
  SENSORPORT=80
  MY_USER=ubuntu
  SSH_PORT=22
  APP_SERVER=airq.waag.org
  MQTT_AGENT_LOG='/var/log/airq-agent/airq-agent.log'
elif [ "${TARGET}" = "waag" ]
then
#  set -x
  MY_HOST=sensor.waag.org
  SENSORPORT=8090
  MY_USER=stefano
  SSH_PORT=2234
  APP_SERVER=sensor.waag.org:3000
  MQTT_AGENT_LOG='/home/stefano/making-sensor/server/mosquitto-agent/screenlog.0'
elif [ "${TARGET}" = "local" ]
then
  MY_HOST=192.168.56.101
  SENSORPORT=80
  MY_USER=vagrant
  SSH_PORT=22
  APP_SERVER=airq.local
  MQTT_AGENT_LOG='/var/log/airq-agent/airq-agent.log'
else
  echo "Unknown server: ${1}" | tee ${TMP_FILE}
  mail -s "AIRQ Test NOT passed" ${EMAIL_ADDRESS} < ${TMP_FILE}
  exit 1
fi




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

  if date -j >/dev/null 2>&1
  then
    local DATA_S_TIME=$(date -j -f "%Y-%m-%d %H:%M:%S%z" "${DATA_TIME}" "+%s")
  else
    local DATA_S_TIME=$(date -d "${DATA_TIME}" "+%s")
  fi

  local NOW=$(date +%s)
  ELAPSED_MIN=$(( (${NOW}-${DATA_S_TIME}) / 60 ))
}

if [ ! -z ${TERM} ]
then
  clear
fi

echo "Test start at $(date) for ${TARGET}, time threshold for sensor data is ${TIME_THRESHOLD} min, notice time is ${TIME_NOTICE} min" | tee ${TMP_FILE}

PASSED=true
ISSENSOR=false

if ! curl --max-time 15 ${MY_HOST} &> /dev/null
then
  echo "ERROR no connection to default webserver on ${MY_HOST}" | tee -a ${TMP_FILE}
  PASSED=false
else

  CONF_FILE=$(find ./ -name makingsense.yaml)
  #echo ${CONF_FILE}
  MY_KEY=$(find . -name airq_key)
  SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

  DISK_LEVELS=$(ssh ${SSH_OPTS} -p ${SSH_PORT} -i ${MY_KEY} ${MY_USER}@${MY_HOST} 'df -h | tr -s " " | cut -d" " -f5 | /bin/grep -v "Use%" | tr -d "%" | tr "\n" " " ')

  for i in ${DISK_LEVELS}
  do
    if (( $i > ${DISK_THRESHOLD} ))
    then
      echo "ERROR disk usage above threshold ${DISK_THRESHOLD} on ${MY_HOST}: ${i}" | tee -a ${TMP_FILE}
      PASSED=false
    fi
  done

  LOAD_LEVEL=$(ssh ${SSH_OPTS} -p ${SSH_PORT} -i ${MY_KEY} ${MY_USER}@${MY_HOST} 'cat /proc/loadavg | cut -d" " -f1 ')

  if (( $(echo "${LOAD_LEVEL} > ${LOAD_THRESHOLD}" | bc -l) ))
  then
    echo "ERROR load above threshold ${LOAD_THRESHOLD} on ${MY_HOST}: ${LOAD_LEVEL}" | tee -a ${TMP_FILE}
    PASSED=false
  fi


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

  #MY_TIME=$(ssh ${SSH_OPTS} -p ${SSH_PORT} -i ${MY_KEY} ${MY_USER}@${MY_HOST} 'sudo su postgres -c "psql -t -A -d traffic -c \"SELECT max(timestmp) from traveltime\" " ' 2>/dev/null)
  MY_TIME=$(ssh ${SSH_OPTS} -p 2234 -i ${MY_KEY} stefano@wg66.waag.org 'sudo su postgres -c "psql -t -A -d traffic -c \"SELECT max(timestmp) from traveltime\" " ' 2>/dev/null)
  if [ ! -z "${MY_TIME}" ]
  then
    echo "Most recent traffic data: ${MY_TIME}" | tee -a ${TMP_FILE}
    diff_min "${MY_TIME}"
    echo "Traffic data is ${ELAPSED_MIN} min old" | tee -a ${TMP_FILE}
    if (( ${ELAPSED_MIN} > ${TRAFFIC_TIME_THRESHOLD} )) && (( ${ELAPSED_MIN} < ${TIME_NOTICE} ))
    then
      PASSED=false
    fi
  else
    echo "ssh command for traffic data failed" | tee -a ${TMP_FILE}
    PASSED=false
  fi

  ## Test measures

  MY_TIME=$(ssh ${SSH_OPTS} -p ${SSH_PORT} -i ${MY_KEY} ${MY_USER}@${MY_HOST} 'sudo su postgres -c "psql -t -A -d airq -c \"SELECT id, max(srv_ts) from measures where id > 100 group by id\" " ' 2>/dev/null)
  # echo "ssh ${SSH_OPTS} -p ${SSH_PORT} -i ${MY_KEY} ${MY_USER}@${MY_HOST}"
  if [ ! -z "${MY_TIME}" ]
  then
    #echo ${MY_TIME}
    export IFS=$'\n'
    for i in $(echo ${MY_TIME} | sed 's/+00 /+00@/g' | tr '@' '\n');
    do
      ID=$(echo ${i}|cut -d'|' -f1);
      ID_TIME=$(echo ${i}|cut -d'|' -f2);
      # echo "Most recent sensor data: ${ID_TIME} for sensor: ${ID}" | tee -a ${TMP_FILE}
      ID_TIME=$(echo ${ID_TIME} | sed 's/\(.*\)\.[0-9][0-9]*\(\+.*\)/\1\2/g')
      diff_min "${ID_TIME}"
      # echo "Data is ${ELAPSED_MIN} min old" | tee -a ${TMP_FILE}
      if (( ${ELAPSED_MIN} > ${TIME_THRESHOLD} )) && (( ${ELAPSED_MIN} < ${TIME_NOTICE} ))
      then
        echo "Data of sensor: ${ID} is too old: ${ELAPSED_MIN} min" | tee -a ${TMP_FILE}
        PASSED=false
        ISSENSOR=true
      fi
    done

  else
    echo "ssh command for sensor data failed" | tee -a ${TMP_FILE}
    PASSED=false
  fi


  ssh ${SSH_OPTS} -p ${SSH_PORT} -i ${MY_KEY} ${MY_USER}@${MY_HOST} "grep -E \"ERROR|CRITICAL\" ${MQTT_AGENT_LOG} " 2>/dev/null > /tmp/newErrorsAirQ.${TARGET}
  if [ -f /tmp/oldErrorsAirQ.${TARGET} ]
  then
    ERRORS="$(diff /tmp/newErrorsAirQ.${TARGET} /tmp/oldErrorsAirQ.${TARGET})"
  else
    ERRORS="$(cat /tmp/newErrorsAirQ.${TARGET})"
  fi

  mv /tmp/newErrorsAirQ.${TARGET} /tmp/oldErrorsAirQ.${TARGET}

  if [ ! -z "${ERRORS}" ]
  then
    echo "Errors in ${MQTT_AGENT_LOG}: ${ERRORS}" | tee -a ${TMP_FILE}
    PASSED=false
  else
    echo "No errors in ${MQTT_AGENT_LOG}" | tee -a ${TMP_FILE}
  fi

  LASTSENSORDATA="$(curl sensor.waag.org:${SENSORPORT}/lastsensordata 2>/dev/null)"
  if [ -z "${LASTSENSORDATA}" ]
  then
    echo "No last sensor data (curl sensor.waag.org/lastsensordata)" | tee -a ${TMP_FILE}
    PASSED=false
  else
    echo "Last sensor data (curl sensor.waag.org/lastsensordata): ${LASTSENSORDATA}" | tee -a ${TMP_FILE}
  fi

  if ! curl ${APP_SERVER} 2>&1 | grep bundle.js >/dev/null
  then
    echo "App does not respond on ${APP_SERVER}" | tee -a ${TMP_FILE}
    PASSED=false
  else
    echo "App responds on ${APP_SERVER}" | tee -a ${TMP_FILE}
  fi

fi

if [ ! "$PASSED" = "true" ]
then
  echo "Test NOT passed" | tee -a ${TMP_FILE}
  if [ "$ISSENSOR" = "true" ]
  then
    mail -s "AIRQ sensors NOT active" ${EMAIL_ADDRESS} < ${TMP_FILE}
    #osascript -e 'tell app "System Events" to display dialog "AIRQ Test NOT passed!!"'
  else
    mail -s "AIRQ Test NOT passed" ${EMAIL_ADDRESS} < ${TMP_FILE}
  fi

else
  echo "Test passed" | tee -a ${TMP_FILE}
fi
