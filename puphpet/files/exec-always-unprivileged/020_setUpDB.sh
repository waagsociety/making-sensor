MY_DIR=$HOME/src/making-sensor/server

sudo su postgres -c 'psql' < ${MY_DIR}/db/airq.sql 
