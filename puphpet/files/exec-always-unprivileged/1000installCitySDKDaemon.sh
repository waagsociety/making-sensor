#NAME_PRG=citysdk_daemon

MY_BUNDLE=/usr/local/rvm/gems/ruby-2.1.5/wrappers/bundle
ORIG_DIR=${HOME}/src/making-sensor/server/airqserver

MY_SRV=airqserver
MY_TMP=/tmp/airqserver
MY_USER=www-data

DEST_FILE=/usr/bin/${MY_SRV}

DEST_CONF=/etc/init/${MY_SRV}.conf

LOG_DIR=/var/log/airq/

cd ${ORIG_DIR}
export rvmsudo_secure_path=1
rvmsudo bundle install

cat <<-EOF > ${MY_TMP}

  cd ${ORIG_DIR}
  ${MY_BUNDLE} exec passenger start

EOF

sudo mv ${MY_TMP} ${DEST_FILE}

sudo chown root:root ${DEST_FILE}

sudo chmod u+x ${DEST_FILE}

cat <<-EOF > ${MY_TMP}
  # ${MY_SRV} - ${MY_SRV} job file

  description "AirQ web server for reading sensor data§"
  author "Stefano Bocconi <stefano@waag.org>"

  # Stanzas
  #
  # Stanzas control when and how a process is started and stopped
  # See a list of stanzas here: http://upstart.ubuntu.com/wiki/Stanzas#respawn

  # When to start the service
  start on runlevel [2345]

  # When to stop the service
  stop on runlevel [016]

  # Automatically restart process if crashed
  respawn

  # Essentially lets upstart know the process will detach itself to the background
  expect fork

  # Run before process
  #pre-start script
  #    [ -d /var/run/myservice ] || mkdir -p /var/run/myservice
  #        echo "Put bash code here"
  #        end script

  # Start the process
  exec ${DEST_FILE}

EOF

sudo mv ${MY_TMP} ${DEST_CONF}
sudo chown root:root ${DEST_CONF}

if [ ! -d "${LOG_DIR}" ]
then
  sudo mkdir -p ${LOG_DIR}
fi

sudo chown -R ${MY_USER}:${MY_USER} ${LOG_DIR}

sudo service ${MY_SRV} restart

#NAMEPID=$(ps -ef | /bin/grep -i "screen -S ${NAME_PRG}" | /bin/grep -v 'grep -i')

#if [ "${NAMEPID} " != " " ]
#then
#  screen -S ${NAME_PRG}.${NAMEPID} -X quit
#fi

#bundle install
#rvmsudo bundle exec passenger start

#screen -S ${NAME_PRG} -d -m bundle exec passenger start
