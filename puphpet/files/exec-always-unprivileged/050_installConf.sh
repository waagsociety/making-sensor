CONF_DIR=/aws-conf
LOCAL_CONF_DIR="$(dirname $(find ${HOME}/src -type f -name mosquitto.conf))"

if [ -d ${CONF_DIR} ]
then
  cp ${CONF_DIR}/* ${LOCAL_CONF_DIR}
fi
