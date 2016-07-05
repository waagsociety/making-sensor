MY_DIR="$HOME/src"

REP="making-sense-feedback-app"

DEST_DIR=/var/www/airq

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
  echo "Repository already exists"
fi

cd ${REP}
git checkout stable
git pull
cd ..


echo "Remove ${DEST_DIR}"
sudo rm -rf ${DEST_DIR}

echo "Make ${DEST_DIR}"
sudo mkdir ${DEST_DIR}

#echo ${PWD}

echo "Copy files from ${REP} to ${DEST_DIR}"
#sudo cp -R ${REP}/* ${DEST_DIR}
cd ${REP}
sudo git checkout-index -a -f --prefix=${DEST_DIR}/
cd ..

sudo chown -R www-data:www-data ${DEST_DIR}

sudo service nginx restart
