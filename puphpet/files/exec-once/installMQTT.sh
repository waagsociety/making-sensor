echo "Installing MQTT ruby client from $(pwd)"

export DEBIAN_FRONTEND=noninteractive


#sudo apt-get install ruby

#sudo apt-get install ruby-dev

if [ ! -d ruby-mqtt ]
then
  git clone https://github.com/njh/ruby-mqtt.git
fi

cd ruby-mqtt/

gem build mqtt.gemspec

gem install mqtt-0.4.0.gem
