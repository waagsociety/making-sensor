
echo "Installing postgres ruby gem"

export DEBIAN_FRONTEND=noninteractive

#sudo apt-get install postgresql

sudo apt-get install -y libpq-dev

gem install pg
