if [ "$(echo $0)" != "-bash" ]
then
	echo "Run the command with source!!!"
	exit 1
fi

MY_CMD=$1

if [ -z "${MY_CMD}" ]
then
	echo "You must specify either ON or OFF, exiting"
	return 1
fi


if [ "${MY_CMD}" = "ON" ]
then
  echo "Setting Vagrant for AWS"
  if ! vagrant plugin list | grep vagrant-aws
  then
    vagrant plugin install vagrant-aws
  fi

  if ! vagrant box list | grep dummy | grep aws
  then
    vagrant box add dummy https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box
  fi

  export VAGRANT_DEFAULT_PROVIDER=aws && echo VAGRANT_DEFAULT_PROVIDER=$VAGRANT_DEFAULT_PROVIDER!!
  export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep -i AWS_ACCESS_KEY_ID | tr -d ' ' | cut -d'=' -f2) && echo AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID!!
  export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep -i AWS_SECRET_ACCESS_KEY | tr -d ' ' | cut -d'=' -f2) && echo AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY!!
else
  echo "Resetting Vagrant to local environment and preparing repositories"
  unset VAGRANT_DEFAULT_PROVIDER
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY

	if [ ! -d ../city-sdk/citysdk-amsterdam/ ]
	then
		mkdir -P ../city-sdk/citysdk-amsterdam
		cd ../city-sdk
		git clone https://github.com/waagsociety/citysdk-amsterdam.git citysdk-amsterdam
		cd -
	fi

	if [ ! -d ../city-sdk/citysdk-services/ ]
	then
		mkdir -P ../city-sdk/citysdk-services
		cd ../city-sdk
		git clone https://github.com/waagsociety/citysdk-services.git citysdk-services
		cd -
	fi

	if [ ! -d ../making-sense-feedback-app/ ]
	then
		cd ../
		git clone https://github.com/waagsociety/making-sense-feedback-app.git making-sense-feedback-app
		cd -
	fi
fi
