#NAME_PRG=citysdk_daemon
MY_SRV=toRIVM
MY_TMP=/tmp/${MY_SRV}

ORIG_DIR=$(dirname $(find ${HOME}/src -type f -name ${MY_SRV}.sh))
MY_USER=$(echo $HOME | sed 's/\/home\/\(.*\)/\1/g')

#DEST_FILE=/etc/init.d/${MY_SRV}

LOG_DIR=/var/log/${MY_SRV}

LOG_FILE=${LOG_DIR}/${MY_SRV}.log

cd ${ORIG_DIR}


if [ ! -d "${LOG_DIR}" ]
then
  sudo mkdir -p ${LOG_DIR}
fi

sudo chown -R ${MY_USER}:${MY_USER} ${LOG_DIR}

#MY_CMD="export GEM_PATH=${MY_GEMS}; cd ${ORIG_DIR}; ${MY_SRV}.sh &>> ${LOG_FILE}"
MY_CMD="cd ${ORIG_DIR}; ./${MY_SRV}.sh 1 &>> ${LOG_FILE}"
MY_JOB="0 * * * * ${MY_CMD}"
cat <(fgrep -i -v "${MY_SRV}" <(crontab -l)) <(echo "${MY_JOB}") | crontab -
