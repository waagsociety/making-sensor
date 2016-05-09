#!/bin/bash
# Backup DBs

BACKUPDIR=/opt/airqbk
PORT=2234
USER=stefano
HOST=sensor.waag.org

DBs=( "airq" "traffic" )
SUFFIX="$(/bin/date +%H_%w).gz"

for (( i=0; i<${#DBs[@]}; i++ ))
do
# ( pg_dump -h localhost -p ${PORT} -U postgres ${DBs[${i}]} | /usr/bin/gzip --best > ${BACKUPDIR}/${DBs[${i}]}.${SUFFIX} )&
  echo "Backing up db ${DBs[${i}]} at $(date)"
  ssh -p ${PORT} ${USER}@${HOST} "sudo su postgres -c \"pg_dump ${DBs[${i}]}\"" | /bin/gzip --best > ${BACKUPDIR}/${DBs[${i}]}.${SUFFIX}
done
