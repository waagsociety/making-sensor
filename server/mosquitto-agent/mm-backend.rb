require 'rubygems'
require 'mqtt'
require 'yaml'
require 'pg'
require 'json'


dir = File.dirname(File.expand_path(__FILE__))
ms_conf = YAML.load_file("#{dir}/../conf/makingsense.yaml")

puts ms_conf

client = MQTT::Client.connect(
  :host => ms_conf['mqtt']['host'],
  :port => ms_conf['mqtt']['port'],
  :ssl => ms_conf['mqtt']['ssl'],
  :clean_session => ms_conf['mqtt']['clean_session'],
  :client_id => ms_conf['mqtt']['client_id'],
  :username => ms_conf['mqtt']['username'],
  :password => ms_conf['mqtt']['password']
)

client.subscribe([ms_conf['mqtt']['topic'],ms_conf['mqtt']['QoS']])

conn = PGconn.open(
  :host => ms_conf['airqdb']['host'],
  :port => ms_conf['airqdb']['port'],
  :options => ms_conf['airqdb']['options'],
  :tty =>  ms_conf['airqdb']['tty'],
  :dbname => ms_conf['airqdb']['dbname'],
  :user => ms_conf['airqdb']['user'],
  :password => ms_conf['airqdb']['password']
)

conn.prepare("sensordata", "INSERT INTO #{ms_conf['airqdb']['measurestable']} (id, srv_ts, topic, rssi, temp, pm10, pm25, no2a, no2b) " +
  "VALUES ($1::bigint, $2::timestamp with time zone, $3::text, $4::smallint, $5::numeric, $6::numeric, $7::numeric, $8::numeric, $9::numeric)")

while true do
  # Subscribe example
  topic,msg = client.get()
  srv_ts = Time.now.strftime('%Y-%m-%d %H:%M:%S.%L%z')

  #msg.gsub!("pm2.5","pm25")

  msg_hash = JSON.parse(msg,symbolize_names: true)

  puts "#{topic} #{msg} #{srv_ts} " + msg_hash.to_s

  #id = topic.delete(ms_conf['mqtt']['topic'].delete('+'))

  res = conn.exec_prepared("sensordata",[msg_hash[:id], srv_ts, topic, msg_hash[:rssi], msg_hash[:temp], msg_hash[:pm10], msg_hash["pm2.5".to_sym], msg_hash[:no2a], msg_hash[:no2b]])

end

at_exit do
  puts "Closing MQTT and DB connections"
  client.disconnect()
  conn.close()
end
