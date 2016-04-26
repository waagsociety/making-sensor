MY_DIR="$HOME/src"
echo "Checking out citysdk-amsterdam in ${MY_DIR}"

export DEBIAN_FRONTEND=noninteractive

if [ ! -d ${MY_DIR} ]
then
  mkdir -p ${MY_DIR}
else
  echo "${MY_DIR} already exists"
fi

cd ${MY_DIR}

if [ ! -d citysdk-amsterdam ]
then
  git clone https://github.com/waagsociety/citysdk-amsterdam.git
else
  echo "Repository already exists"
fi

if [ ! -d citysdk-services ]
then
  git clone https://github.com/waagsociety/citysdk-services.git
else
  echo "Repository already exists"
fi
