#NAME_PRG=citysdk_daemon
MY_SRV=ndw_traveltimeams
MY_TMP=/tmp/${MY_SRV}


MY_RUBY=$(which ruby)
ORIG_DIR=$(dirname $(find ${HOME}/src -type f -name ${MY_SRV}.rb))
MY_USER=$(echo $HOME | sed 's/\/home\/\(.*\)/\1/g')

#DEST_FILE=/etc/init.d/${MY_SRV}

LOG_DIR=/var/log/${MY_SRV}

LOG_FILE=${LOG_DIR}/${MY_SRV}.log

cd ${ORIG_DIR}


bundle install
MY_GEMS="$(gem env gempath)"
#MY_PATH="${PATH}:${MY_GEMS}:${MY_GEMS}/wrappers"

if [ ! -d "${LOG_DIR}" ]
then
  sudo mkdir -p ${LOG_DIR}
fi

sudo chown -R ${MY_USER}:${MY_USER} ${LOG_DIR}

FILT_LOGFILE=$(echo ${LOG_FILE} | sed 's/\//\\\//g')

cat ${MY_SRV}.logrotate | sed "s/^LOG_FILE {/${FILT_LOGFILE} {/g" > ${MY_TMP}

sudo mv ${MY_TMP} /etc/logrotate.d/${MY_SRV}

sudo chown root:root /etc/logrotate.d/${MY_SRV}

sudo chmod 644 /etc/logrotate.d/${MY_SRV}

MY_CMD="export GEM_PATH=${MY_GEMS}; cd ${ORIG_DIR}; ${MY_RUBY} ${MY_SRV}.rb &>> ${LOG_FILE}"
MY_JOB="*/4 * * * * ${MY_CMD}"
cat <(fgrep -i -v "${MY_SRV}" <(crontab -l)) <(echo "${MY_JOB}") | crontab -
