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

    end_ts = Time.now.strftime('%Y-%m-%d %H:%M:%S.%L%z')
    start_ts = (Time.now - 1*60*60).strftime('%Y-%m-%d %H:%M:%S.%L%z')

    puts "start " + start_ts + ", end " + end_ts

    res= conn.exec("WITH averages AS " +
      "(SELECT id, max(srv_ts) AS srv_ts, avg(rssi) AS rssi, avg(temp) AS temp, avg(pm10) AS pm10, " +
      "avg(pm25) AS pm25, avg(no2a) AS no2a, avg(no2b) AS no2b, avg(humidity) AS humidity " +
      "FROM #{ms_conf['airqdb']['measurestable']} WHERE srv_ts > '#{start_ts}' AND srv_ts <= '#{end_ts}' AND temp IS NOT NULL GROUP BY id), " +
      "latest_measures AS " +
      "(SELECT id, max(srv_ts) AS srv_ts FROM #{ms_conf['airqdb']['measurestable']} WHERE temp IS NOT NULL GROUP BY id)" +
      " SELECT l.srv_ts AS srv_ts, a.rssi AS rssi, a.temp AS temp, a.pm10 AS pm10, a.pm25 AS pm25, a.no2a AS no2a, a.no2b AS no2b, a.humidity AS humidity, s.* " +
      "FROM #{ms_conf['airqdb']['sensorparameters']} s,  averages a RIGHT JOIN latest_measures l ON l.id = a.id WHERE l.id = s.id")

    # res= conn.exec("WITH latest_measures AS (SELECT id AS theID, max(srv_ts) AS theTS FROM  #{ms_conf['airqdb']['measurestable']} WHERE temp IS NOT NULL GROUP BY id) " +
    #   "SELECT * from  #{ms_conf['airqdb']['measurestable']} m, #{ms_conf['airqdb']['sensorparameters']} s, latest_measures l WHERE m.id=l.theID AND  m.srv_ts=l.theTS AND s.id=m.id")
    conn.close()
    puts "status " + res.cmd_status().to_s
    puts "tuples " + res.ntuples().to_s
    if res.cmd_tuples() > 0
      msgs = []
      res.each {|tuple|
        #id,tmstp,rssi,temp,pm10,pm25,no2a,no2b,humidity,lat,lon
        rssi_calc = tuple["rssi"].to_f.round(2)
        temp_calc = tuple["temp"].to_f.round(2)
        humidity_calc = tuple["humidity"].to_f.round(2)
        pm10_calc = (tuple["pm10_offset"].to_f + tuple["pm10_pm10_coeff"].to_f * tuple["pm10"].to_f + tuple["pm10_pm25_coeff"].to_f * tuple["pm25"].to_f + tuple["pm10_t_coeff"].to_f * tuple["temp"].to_f + tuple["pm10_rh_coeff"].to_f * tuple["humidity"].to_f).round(2)
        pm25_calc = (tuple["pm25_offset"].to_f + tuple["pm25_pm25_coeff"].to_f * tuple["pm25"].to_f + tuple["pm25_pm10_coeff"].to_f * tuple["pm10"].to_f + tuple["pm25_t_coeff"].to_f * tuple["temp"].to_f + tuple["pm25_rh_coeff"].to_f * tuple["humidity"].to_f).round(2)
        no2_calc = (tuple["no2_offset numeric"].to_f + tuple["no2_no2a_coeff"].to_f * tuple["no2a"].to_f + tuple["no2_no2b_coeff"].to_f * tuple["no2a"].to_f + tuple["no2_t_coeff"].to_f * tuple["temp"].to_f + tuple["no2_rh_coeff"].to_f * tuple["humidity"].to_f).round(2)

        msg = {
          :id => tuple["id"],
          :sensorname => tuple["sensorname"],
          :srv_ts => tuple["srv_ts"],
          :rssi => rssi_calc.to_s,
          :temp => temp_calc.to_s,
          :pm10 => pm10_calc.to_s,
          :pm25 => pm25_calc.to_s,
          :no2 => no2_calc.to_s,
          :humidity => humidity_calc.to_s
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
