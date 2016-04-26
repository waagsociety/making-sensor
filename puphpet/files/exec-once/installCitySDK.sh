echo "Installing citysdk ruby gem"

export DEBIAN_FRONTEND=noninteractive

sudo apt-get install -y ncurses-dev
sudo apt-get install -y libicu-dev
gem install citysdk
