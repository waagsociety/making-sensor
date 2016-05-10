#!/bin/bash

MY_HOST=52.58.166.63
MY_USER=ubuntu
SSH_PORT=22
REP=1
SENSORS=10

if ! ./server/mosquitto-agent/testMQTT.sh ${SENSORS} ${REP} ${MY_HOST}
then
  echo "ERROR mosquitto not set"
fi

MY_KEY=$(find . -name airq_key)

echo "Tailing mosquitto log"
LINES=$((${REP} * ${SENSORS} * 6))

ssh -p ${SSH_PORT} -i ${MY_KEY} ${MY_USER}@${MY_HOST} "tail -n ${LINES} /var/log/mosquitto/mosquitto.log"

## Test traffic data
echo "Most recent traffic data"
ssh -p ${SSH_PORT} -i ${MY_KEY} ${MY_USER}@${MY_HOST} 'sudo su postgres -c "psql -t -A -d traffic -c \"SELECT max(timestmp) from traveltime\" " '

## Test measures

echo "Most recent sensor data"
ssh -p ${SSH_PORT} -i ${MY_KEY} ${MY_USER}@${MY_HOST} 'sudo su postgres -c "psql -t -A -d airq -c \"SELECT max(srv_ts) from measures\" " '
