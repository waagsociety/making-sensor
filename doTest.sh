#!/bin/bash

MY_HOST=52.58.166.63
MY_USER=ubuntu
SSH_PORT=22
REP=10

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

## find conf dir

CONF_DIR=$(find ./server -name conf)

## Test mosquitto agent
MY_USR=$(parse_yaml ${CONF_DIR}/makingsense.yaml mqtt username)
MY_PWD=$(parse_yaml ${CONF_DIR}/makingsense.yaml mqtt password)

#echo ${MY_USR} ${MY_PWD}
if ! ./server/mosquitto-agent/testMQTT.sh 1 ${REP} ${MY_USR} ${MY_PWD} ${MY_HOST}
then
  echo "ERROR mosquitto not set"
fi

## Test traffic data
MY_KEY=$(find ${CONF_DIR} -name airq_key)
echo "Most recent traffic data"
ssh -p ${SSH_PORT} -i ${MY_KEY} ${MY_USER}@${MY_HOST} 'sudo su postgres -c "psql -t -A -d traffic -c \"SELECT max(timestmp) from traveltime\" " '

## Test measures

echo "Most recent sensor data"
ssh -p ${SSH_PORT} -i ${MY_KEY} ${MY_USER}@${MY_HOST} 'sudo su postgres -c "psql -t -A -d airq -c \"SELECT max(srv_ts) from measures\" " '
