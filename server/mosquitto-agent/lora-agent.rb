require 'rubygems'
require 'bundler/setup'

require 'faraday'
require 'faraday_middleware'
require 'yaml'
require 'pg'
require 'json'
require 'mqtt'
require 'base64'


# Global variables
$mqtt_client = nil
$db_conn = nil
$byebye = false

$stdout.sync = true

# Signal handler to handle a clean exit
Signal.trap("SIGTERM") {
  puts "Exiting"
  $byebye = true
}

# Release the MQTT connection
def closeMQTTConn(client)

  if ( !client.nil? )
    begin
      client.disconnect(send_msg = false)
    rescue Exception => e
    #ignore it
    end
  end
end

# Set up the MQTT connection
def makeMQTTConnection(conf, client)

  if ( !client.nil? && client.connected?)
    return client
  end

  # trying anyway to release the client just in case
  closeMQTTConn(client)

  begin
    client = MQTT::Client.connect(
      :host => conf['ttnmqtt']['host'],
      :port => conf['ttnmqtt']['port'],
      :ssl => conf['ttnmqtt']['ssl'],
      :clean_session => conf['ttnmqtt']['clean_session'],
      :client_id => conf['ttnmqtt']['client_id'],
      :username => conf['ttnmqtt']['username'],
      :password => conf['ttnmqtt']['password']
    )
    client.subscribe([conf['ttnmqtt']['topic'],conf['ttnmqtt']['QoS']])

  rescue MQTT::Exception,Errno::ECONNREFUSED,Errno::ENETUNREACH,SocketError => e
    $stderr.puts "ERROR: while connecting to MQTT server, class: #{e.class.name}, message: #{e.message}"

    if $byebye
      return nil
    end

    $stderr.puts "Sleep #{ms_conf['ttnmqtt']['retry']} seconds and retry"
    sleep conf['ttnmqtt']['retry']
    retry
  end

  return client

end

# Release the DB connection
def closeDBConn(dbConn)
  if ( !dbConn.nil? )
    begin
      dbConn.finish()
    rescue Exception => e
      #ignore it
    end
  end
end

# Set up the DB connection
def makeDBConnection(conf, dbConn)

  if ( !dbConn.nil? && dbConn.status == PGconn::CONNECTION_OK)
    return dbConn
  end

  # trying anyway to release the connection just in case
  closeDBConn(dbConn)

  begin
    dbConn = PGconn.open(
      :host => conf['lorasensordb']['host'],
      :port => conf['lorasensordb']['port'],
      :options => conf['lorasensordb']['options'],
      :tty =>  conf['lorasensordb']['tty'],
      :dbname => conf['lorasensordb']['dbname'],
      :user => conf['lorasensordb']['user'],
      :password => conf['lorasensordb']['password']
    )

    dbConn.prepare("sensordata", "INSERT INTO #{conf['lorasensordb']['measurestable']} " +
      "(payload, port, counter, dev_eui, frequency, datarate, codingrate, gateway_timestamp," +
      " channel, server_time, rssi, lsnr, rfchain, crc, modulation, gateway_eui, altitude," +
      " longitude, latitude, temp, pm10, pm25, no2a, no2b, humidity) " +
      "VALUES ($1::varchar, $2::smallint, $3::bigint, $4::varchar, $5::numeric, " +
      "$6::varchar, $7::varchar, $8::bigint, $9::smallint, $10::timestamp with time zone, $11::smallint," +
      "$12::numeric, $13::smallint, $14::smallint, $15::text, $16::varchar, $17::numeric, $18::numeric," +
      "$19::numeric, $20::numeric, $21::numeric, $22::numeric, $23::numeric, $24::numeric, $25::numeric" +
       ")")

  rescue PGError => e
    $stderr.puts "ERROR: while connecting to Postgres server, class: #{e.class.name}, message: #{e.message}"

    if $byebye
      return nil
    end

    $stderr.puts "Sleep #{ms_conf['lorasensordb']['retry']} seconds and retry"
    sleep conf['lorasensordb']['retry']
    retry
  end

  return dbConn
end

# HTTP POST function
def httppost(host, path, body, auth_encoded, n_retries, sleep_time, user_agent='Waag agent', timeout=5, open_timeout=2)

  connection = Faraday.new(host) do |c|
    c.use FaradayMiddleware::FollowRedirects, limit: 3
    c.use Faraday::Response::RaiseError       # raise exceptions on 40x, 50x responses
    c.use Faraday::Adapter::NetHttp
  end

  connection.headers[:user_agent] = user_agent

  response = nil

  nretry = n_retries

  begin
    response = connection.post do |req|
      req.url(path)
      req.options[:timeout] = timeout
      req.options[:open_timeout] = open_timeout
      req.headers['Content-Type'] = 'application/json'
      req.headers["authorization"] = "Basic #{auth_encoded}"
      req.body = "#{body}"
    end
    puts "Post reading response: #{response.status.to_s}"
  rescue Faraday::ConnectionFailed => e

    sleep sleep_time
    if nretry > 0
      nretry -= 1
      $stderr.puts "WARNING: Faraday::ConnectionFailed to #{host} #{path}, #{e.message} in posting reading, will retry #{nretry} times, body: #{body}"
      retry
    else
      $stderr.puts "ERROR: Faraday::ConnectionFailed to #{host} #{path}, #{e.message} in posting reading after #{n_retries} attempts"
    end
  rescue Faraday::Error::ClientError => e
    $stderr.puts "ERROR: #{e.class.name}, #{e.message} in posting reading to #{host} #{path}, response: #{response.to_s}, body: #{body}"
  end

 # can be null
  return response

end


# Close connections before exiting
def clean_up()
  puts "Closing MQTT and DB connections"
  closeMQTTConn($mqtt_client)
  closeDBConn($db_conn)
end


# here the main part starts
dir = File.dirname(File.expand_path(__FILE__))
ms_conf = YAML.load_file("#{dir}/../conf/makingsense.yaml")
puts ms_conf


mqtt_client = makeMQTTConnection(ms_conf,nil)
db_conn = makeDBConnection(ms_conf,nil)

# encode the credentials, no need to do this in a loop

auth_encoded = Base64.encode64("#{ms_conf['smartcitizenme']['username']}:#{ms_conf['smartcitizenme']['password']}")


while ! $byebye do
  begin
    begin
      # blocking call, not ideal if need to exit
      topic,msg = mqtt_client.get()
    rescue MQTT::Exception, Errno::ECONNRESET, Exception => e
      $stderr.puts "WARNING: while getting MQTT connection, class: #{e.class.name}, message: #{e.message}"
      if $byebye
        break
      end

      $stderr.puts "Sleep #{ms_conf['ttnmqtt']['retry']} seconds and retry"
      sleep ms_conf['ttnmqtt']['retry']
      mqtt_client = makeMQTTConnection(ms_conf,mqtt_client)
      retry
    end



      #msg.gsub!("pm2.5","pm25")

    begin
      msg_hash = JSON.parse(msg,symbolize_names: true)
    rescue JSON::JSONError => e
      $stderr.puts "ERROR: while processing sensor data: #{msg}, class: #{e.class.name}, message: #{e.message}"
      $stderr.puts "Save raw message with fake id"
      msg_hash = {}
      msg_hash[:i] = -1
      msg_hash[:message] = msg
    end

    puts "topic: #{topic}, msg: #{msg}, hash: " + msg_hash.to_s

    #id = topic.delete(ms_conf['ttnmqtt']['topic'].delete('+'))

    begin

      parameters = nil
      # check for overflow

      if ( (! msg_hash["p2.5".to_sym].nil?) && msg_hash["p2.5".to_sym] == "ovf" )
        msg_hash["p2.5".to_sym] = -1
      end
      if ( (! msg_hash[:pm10].nil?) && msg_hash[:p10] == "ovf" )
        msg_hash[:p10] = -1
      end

      # {
      #   "payload": "MzIzMgnELwILxMQA",
      #   "fields": {
      #     "hum": 47,
      #     "op1": 13106,
      #     "op2": 13106,
      #     "pm10": 50372,
      #     "pm25": 523,
      #     "temp": 25
      #   },
      #   "port": 1,
      #   "counter": 15,
      #   "dev_eui": "000000004D8D3F94",
      #   "metadata": [
      #     {
      #       "frequency": 867.7,
      #       "datarate": "SF7BW125",
      #       "codingrate": "4/5",
      #       "gateway_timestamp": 1492507156,
      #       "channel": 7,
      #       "server_time": "2016-11-01T14:01:42.128849779Z",
      #       "rssi": -73,
      #       "lsnr": 9.2,
      #       "rfchain": 0,
      #       "crc": 1,
      #       "modulation": "LORA",
      #       "gateway_eui": "0000024B08060030",
      #       "altitude": 16,
      #       "longitude": 4.90036,
      #       "latitude": 52.37283
      #     }
      #   ]
      # }

      parameters = [msg_hash[:payload], msg_hash[:port], msg_hash[:counter], msg_hash[:dev_eui], msg_hash[:metadata][0][:frequency], msg_hash[:metadata][0][:datarate],
            msg_hash[:metadata][0][:codingrate], msg_hash[:metadata][0][:gateway_timestamp], msg_hash[:metadata][0][:channel], msg_hash[:metadata][0][:server_time],
            msg_hash[:metadata][0][:rssi], msg_hash[:metadata][0][:lsnr], msg_hash[:metadata][0][:rfchain], msg_hash[:metadata][0][:crc],
            msg_hash[:metadata][0][:modulation], msg_hash[:metadata][0][:gateway_eui], msg_hash[:metadata][0][:altitude], msg_hash[:metadata][0][:longitude],
            msg_hash[:metadata][0][:latitude], msg_hash[:fields][:op1], msg_hash[:fields][:op2], msg_hash[:fields][:pm25],
            msg_hash[:fields][:pm10], msg_hash[:fields][:temp], msg_hash[:fields][:hum]]

      res = db_conn.exec_prepared("sensordata",  parameters)

    rescue PG::NotNullViolation => e
      $stderr.puts "ERROR: while inserting message (PG::NotNullViolation): #{msg}, error: #{e.message}"
      $stderr.puts "Save raw message with fake id"
      msg_hash[:dev_eui] = -1
      msg_hash[:metadata][0][:modulation] = msg
      $stderr.puts "Sleep #{ms_conf['lorasensordb']['retry']} seconds and retry"
      sleep ms_conf['lorasensordb']['retry']
      retry
    rescue PG::InvalidTextRepresentation => e
      $stderr.puts "ERROR: while inserting message (PG::InvalidTextRepresentation): #{msg}, error: #{e.message}"
      $stderr.puts "Save raw message with fake id"
      msg_hash[:dev_eui] = -1
      msg_hash[:metadata][0][:modulation] = msg
      $stderr.puts "Sleep #{ms_conf['lorasensordb']['retry']} seconds and retry"
      sleep ms_conf['lorasensordb']['retry']
      retry
    rescue PG::CharacterNotInRepertoire => e
      $stderr.puts "ERROR: wrong encoding (PG::CharacterNotInRepertoire) for message: #{msg}, error: #{e.message}"
      $stderr.puts "Ignore msg"
    rescue PGError => e
      $stderr.puts "ERROR: while inserting into DB, class: #{e.class.name}, message: #{e.message}, payload: #{msg}"
      $stderr.puts "Ignore msg"
    end

  # Post sensor data to smartcitizen.me

  device_id = -1
  key_id = -1

  ms_conf['smartcitizenme']['devices'].each do |key,device|
    if ( device['device_address'] == msg_hash[:dev_eui] )
      device_id = device['device_id']
      key_id = key
    end
  end

  if ( device_id == -1 )
    $stderr.puts "WARNING: #{msg_hash[:dev_eui]} is not a known device"
    next
  end

  # Format the measures with the right sensor ids
  measures = {
      "data" => [{
        "recorded_at" => "#{msg_hash[:metadata][0][:server_time]}",
        "sensors" => [
          {
	         "id" => ms_conf['smartcitizenme']['devices'][key_id]['no2_sensor_id'],
	          "value" => msg_hash[:fields][:op1]
          },
          {
	         "id" => ms_conf['smartcitizenme']['devices'][key_id]['pm_sensor_id'],
	          "value" => msg_hash[:fields][:pm25]
          },
          {
	         "id" => ms_conf['smartcitizenme']['devices'][key_id]['temp_sensor_id'],
	          "value" => msg_hash[:fields][:temp]
          },
          {
           "id" => ms_conf['smartcitizenme']['devices'][key_id]['hum_sensor_id'],
            "value" => msg_hash[:fields][:hum]
          }
        ]
      }]
  }

  measures_s = JSON.generate(measures).to_s

  puts "Measures #{measures_s} for device #{device_id}"


  httppost(ms_conf['smartcitizenme']['base_url'], "devices/#{device_id}/readings",
          measures_s, auth_encoded,ms_conf['smartcitizenme']['retry'],ms_conf['smartcitizenme']['retry'])


  rescue Exception => e
    $stderr.puts "CRITICAL: Generic exception caught in process loop, class: #{e.class.name}, message: #{e.message}"
    $stderr.puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
    $stderr.puts "Sensor data: msg: #{msg}, hash: #{msg_hash.to_s}"

    if $byebye
      break
    end
    $stderr.puts "Sleep #{ms_conf['ttnmqtt']['retry']} seconds and retry"
    sleep ms_conf['ttnmqtt']['retry']
  end

end

at_exit do
  clean_up()
  puts "Program exited"
end
