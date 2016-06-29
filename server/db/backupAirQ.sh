#!/bin/bash
# Backup DBs

TARGET=${1}
AWS_HOST="52.58.166.63"

if [ "${TARGET} " == " " ]
then
  if ! nslookup sensor.waag.org | grep "${AWS_HOST}"  > /dev/null
  then
     TARGET="WAAG"
   else
     TARGET="AWS"
   fi
fi


if [ "${TARGET} " == "AWS " ]
then
  DBs=( "airq" )
  BACKUPDIR=/opt/airqbk_aws
  PORT=22
  USER=ubuntu
  HOST=${AWS_HOST}
elif [ "${TARGET} " == "WAAG " ]
then
  DBs=( "traffic" )
  BACKUPDIR=/opt/airqbk_waag
  PORT=2234
  USER=stefano
  HOST=wg66.waag.org
else
  echo "Need to specify server!!"
  exit 1
fi

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

SUFFIX="$(/bin/date +%H_%w).gz"

for (( i=0; i<${#DBs[@]}; i++ ))
do
# ( pg_dump -h localhost -p ${PORT} -U postgres ${DBs[${i}]} | /usr/bin/gzip --best > ${BACKUPDIR}/${DBs[${i}]}.${SUFFIX} )&
  echo "Backing up db ${DBs[${i}]} at $(date)"
  ssh ${SSH_OPTS} -p ${PORT} ${USER}@${HOST} "sudo su postgres -c \"pg_dump ${DBs[${i}]}\"" | /bin/gzip --best > ${BACKUPDIR}/${DBs[${i}]}.${SUFFIX}
done
