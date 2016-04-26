MY_DIR="$HOME/src"
echo "Checking out making-sensor in ${MY_DIR}"

export DEBIAN_FRONTEND=noninteractive

if [ ! -d ${MY_DIR} ]
then
  mkdir -p ${MY_DIR}
else
  echo "${MY_DIR} already exists"
fi

cd ${MY_DIR}

if [ ! -d making-sensor ]
then
  git clone https://github.com/waagsociety/making-sensor.git
else
  echo "Repository already exists"
fi
