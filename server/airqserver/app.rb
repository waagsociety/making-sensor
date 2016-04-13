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
      :host => ms_conf['airqdb']['host'],
      :port => ms_conf['airqdb']['port'],
      :options => ms_conf['airqdb']['options'],
      :tty =>  ms_conf['airqdb']['tty'],
      :dbname => ms_conf['airqdb']['dbname'],
      :user => ms_conf['airqdb']['user'],
      :password => ms_conf['airqdb']['password']
    )
    #WITH latest_measures AS (SELECT id AS theID, max(srv_ts) AS theTS FROM measures GROUP BY id) SELECT * from measures m, latest_measures l WHERE m.id=l.theID AND  m.srv_ts=l.theTS

    res= conn.exec("WITH latest_measures AS (SELECT id AS theID, max(srv_ts) AS theTS FROM  #{ms_conf['airqdb']['measurestable']} GROUP BY id) " +
      "SELECT * from  #{ms_conf['airqdb']['measurestable']} m, latest_measures l WHERE m.id=l.theID AND  m.srv_ts=l.theTS")
    conn.close()
    puts "status " + res.cmd_status().to_s
    puts "tuples " + res.ntuples().to_s
    if res.cmd_tuples() > 0
      msgs = []
      res.each {|tuple|
        #id,tmstp,rssi,temp,pm10,pm25,no2a,no2b,lat,lon
        msg = {
          :id => tuple["id"],
          :srv_ts => tuple["srv_ts"],
          :rssi => tuple["rssi"],
          :temp => tuple["temp"],
          :pm10 => tuple["pm10"],
          :pm25 => tuple["pm25"],
          :no2a => tuple["no2a"],
          :no2b => tuple["no2b"]
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
