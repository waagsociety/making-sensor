MY_DIR="$HOME/src"

REP="making-sense-feedback-app"

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
  git checkout stable
  git pull
  cd ..
fi

sudo rm -rf /var/www/airq

sudo mkdir /var/www/airq

#echo ${PWD}

sudo cp -R ${REP}/* /var/www/airq/

sudo chown -R www-data:www-data /var/www/airq

sudo service nginx restart
