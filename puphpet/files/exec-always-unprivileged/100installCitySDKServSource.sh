MY_DIR="$HOME/src"

REP="citysdk-services"

echo "Checking out ${REP} in ${MY_DIR}"

export DEBIAN_FRONTEND=noninteractive

if [ ! -d ${MY_DIR} ]
then
  mkdir -p ${MY_DIR}
else
  echo "${MY_DIR} already exists"
fi

cd ${MY_DIR}

if [ ! -d "${REP}" ]
then
  git clone https://github.com/waagsociety/${REP}.git
else
  echo "Repository already exists, pulling"
  cd ${REP}
  git pull
fi
