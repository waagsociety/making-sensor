require 'sinatra/base'
require 'sinatra/json'
require 'json'
require 'rubygems'
require 'yaml'
require 'pg'



class AirqApp < Sinatra::Base
  dir = File.dirname(File.expand_path(__FILE__))
  ms_conf = YAML.load_file("#{dir}/../conf/makingsense.yaml")

  get '/lastsensordata' do
    puts ms_conf
    conn = PGconn.open(
      :host => ms_conf['db']['host'],
      :port => ms_conf['db']['port'],
      :options => ms_conf['db']['options'],
      :tty =>  ms_conf['db']['tty'],
      :dbname => ms_conf['db']['dbname'],
      :user => ms_conf['db']['user'],
      :password => ms_conf['db']['password']
    )
    res= conn.exec("SELECT * FROM #{ms_conf['db']['measurestable']}")
    conn.close()
    puts "status " + res.cmd_status().to_s
    puts "tuples " + res.ntuples().to_s
    if res.cmd_tuples() > 0
      msgs = []
      res.each {|tuple|
        #id,tmstp,rssi,temp,pm10,pm2.5,no2a,no2b,lat,lon
        msg = {
          :id => tuple["sensor_id"],
          :tmstp => tuple["measure_ts"],
          :no2a => tuple["measures"]
        }
        puts "hash " + msg.to_s
#        content_type :json
        msgs.push(msg)
      }
      json msgs
    end

  end

  get '/' do
    json :alive => 'yes'
  end
end
