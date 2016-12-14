#!/bin/bash

##########################
# General parameters
##########################

TIME_THRESHOLD=30
DISK_THRESHOLD=70
LOAD_THRESHOLD=1.5

TIME_NOTICE=1440

TMP_FILE=/tmp/smartkids
EMAIL_ADDRESS=stefano@waag.org

TARGET="waag"

##########################
# Host specific parameters
##########################

if [ "${TARGET}" = "waag" ]
then
  # set -x
  MY_HOST=sensor.waag.org
  # SENSORPORT=8090
  MY_USER=stefano
  SSH_PORT=2234
  MQTT_AGENT_LOG='/home/stefano/making-sensor/server/mosquitto-agent/screenlog.0'
  MY_DIR='/Users/SB/Software/code/'
elif [ "${TARGET}" = "local" ]
then
  MY_HOST=192.168.56.101
  # SENSORPORT=80
  MY_USER=vagrant
  SSH_PORT=22
  MQTT_AGENT_LOG='/var/log/smartkids-agent/smartkids-agent.log'
  MY_DIR='/Users/SB/Software/code/'
else
  echo "Unknown server: ${1}" | tee ${TMP_FILE}
  mail -s "SMARTKIDS Test NOT passed" ${EMAIL_ADDRESS} < ${TMP_FILE}
  exit 1
fi




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

check_time(){
  local MY_TIME="$1"

  TMPIFS="${IFS}"
  IFS=$'\n'
  for i in $(echo "${MY_TIME}");
  do
    ID="$(echo ${i}|cut -d'|' -f1)"
    ID_TIME="$(echo ${i}|cut -d'|' -f2)"
    # echo "Most recent sensor data: ${ID_TIME} for sensor: ${ID}" | tee -a ${TMP_FILE}
    ID_TIME="$(echo ${ID_TIME} | sed 's/\(.*\)\.[0-9][0-9]*\(\+.*\)/\1\2/g')"
    diff_min "${ID_TIME}"
    # echo "Data is ${ELAPSED_MIN} min old" | tee -a ${TMP_FILE}
    echo "Data of sensor: ${ID} is ${ELAPSED_MIN} min old" | tee -a ${TMP_FILE}
    if (( ${ELAPSED_MIN} > ${TIME_THRESHOLD} )) && (( ${ELAPSED_MIN} < ${TIME_NOTICE} ))
    then
      echo -e "\n*** Data of sensor ${ID} is too old ***\n" | tee -a ${TMP_FILE}
      PASSED=false
      ISSENSOR=true
    fi
  done
  IFS="${TMPIFS}"
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

  MY_KEY=$(find ${MY_DIR} -name airq_key)
  SSH_OPTS='-q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
  SSH_PARAMS="${SSH_OPTS} -p ${SSH_PORT} -i ${MY_KEY} ${MY_USER}@${MY_HOST}"

  DISK_LEVELS="$(ssh ${SSH_PARAMS} 'df -h -t ext4 -t ext2 -t ext3 | tr -s " " | cut -d" " -f5 | /bin/grep -v "Use%" | tr -d "%" | tr "\n" " " ')"

  for i in ${DISK_LEVELS}
  do
    if (( $i > ${DISK_THRESHOLD} ))
    then
      echo "ERROR disk usage above threshold ${DISK_THRESHOLD} on ${MY_HOST}: ${i}" | tee -a ${TMP_FILE}
      PASSED=false
    fi
  done

  LOAD_LEVEL="$(ssh ${SSH_PARAMS} 'cat /proc/loadavg | cut -d" " -f1 ')"

  if (( $(echo "${LOAD_LEVEL} > ${LOAD_THRESHOLD}" | bc -l) ))
  then
    echo "ERROR load above threshold ${LOAD_THRESHOLD} on ${MY_HOST}: ${LOAD_LEVEL}" | tee -a ${TMP_FILE}
    PASSED=false
  fi

  ## Test measures

  MY_TIME="$(ssh ${SSH_PARAMS} 'sudo su postgres -c "psql -t -A -d smartkidsdb -c \"SELECT id, max(srv_ts) from measures where id > 100 group by id\" " ' 2>/dev/null)"
  # echo "ssh ${SSH_PARAMS}"
  if [ ! -z "${MY_TIME}" ]
  then
    check_time "${MY_TIME}"
  else
    echo "ssh command for sensor data failed" | tee -a ${TMP_FILE}
    PASSED=false
  fi

  MY_TIME="$(ssh ${SSH_PARAMS} 'sudo su postgres -c "psql -t -A -d loradb -c \"SELECT dev_eui, max(server_time) from measures group by dev_eui\" " ' 2>/dev/null)"
  # echo "ssh ${SSH_PARAMS}"
  if [ ! -z "${MY_TIME}" ]
  then
    check_time "${MY_TIME}"
  else
    echo "ssh command for sensor data failed" | tee -a ${TMP_FILE}
    PASSED=false
  fi

  ssh ${SSH_PARAMS} "grep -E \"ERROR|CRITICAL\" ${MQTT_AGENT_LOG} " 2>/dev/null > /tmp/newErrorsSmartKids.${TARGET}
  if [ -f /tmp/oldErrorsSmartKids.${TARGET} ]
  then
    ERRORS="$(diff /tmp/newErrorsSmartKids.${TARGET} /tmp/oldErrorsSmartKids.${TARGET})"
  else
    ERRORS="$(cat /tmp/newErrorsSmartKids.${TARGET})"
  fi

  mv /tmp/newErrorsSmartKids.${TARGET} /tmp/oldErrorsSmartKids.${TARGET}

  if [ ! -z "${ERRORS}" ]
  then
    echo "New errors in ${MQTT_AGENT_LOG}: ${ERRORS}" | tee -a ${TMP_FILE}
    PASSED=false
  else
    echo "No new errors in ${MQTT_AGENT_LOG}" | tee -a ${TMP_FILE}
  fi

fi

if [ ! "$PASSED" = "true" ]
then
  echo -e "\n*** Test NOT passed ***\n" | tee -a ${TMP_FILE}
  if [ "$ISSENSOR" = "true" ]
  then
    mail -s "SMARTKIDS sensors NOT active" ${EMAIL_ADDRESS} < ${TMP_FILE}
    #osascript -e 'tell app "System Events" to display dialog "SMARTKIDS Test NOT passed!!"'
  else
    mail -s "SMARTKIDS Test NOT passed" ${EMAIL_ADDRESS} < ${TMP_FILE}
  fi

else
  echo "Test passed" | tee -a ${TMP_FILE}
fi
