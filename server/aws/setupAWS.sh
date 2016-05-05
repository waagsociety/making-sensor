#!/bin/bash
#Important: before running, make sure to install boto (pip install boto) and jq (brew install jq)


echo "Reading AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY from ~/.aws/credentials"

export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep aws_access_key_id | tr -d ' ' | cut -f2 -d'=')
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep aws_secret_access_key | tr -d ' ' | cut -f2 -d'=')

for var in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY ; do
	if [ -n "${!var}" ] ; then
		echo "$var is set to ${!var}"
	else
		echo "$var is not set"
		exit 1
	fi
done

export VENV_DIR=venv

pip3 install virtualenv

virtualenv -p python3 ${VENV_DIR}

source ${VENV_DIR}/bin/activate

#brew install jq
pip3 install -r requirements.txt
