require 'rubygems'
require 'mqtt'
require 'yaml'
require 'pg'


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
  :host => ms_conf['db']['host'],
  :port => ms_conf['db']['port'],
  :options => ms_conf['db']['options'],
  :tty =>  ms_conf['db']['tty'],
  :dbname => ms_conf['db']['dbname'],
  :user => ms_conf['db']['user'],
  :password => ms_conf['db']['password']
)

while true do
  # Subscribe example
  topic,measure = client.get()
  ts = Time.now.strftime('%Y-%m-%d %H:%M:%S.%L%z')

  puts "#{topic} #{measure} #{ts}"

  id = topic.delete(ms_conf['mqtt']['topic'].delete('+'))

  res = conn.exec('INSERT INTO measures (sensor_id, topic, measures, measure_ts) VALUES ($1, $2, $3, $4)',[id,topic, measure, ts])

end

client.disconnect()
conn.close()
