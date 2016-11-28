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
      :host => conf['mqtt']['host'],
      :port => conf['mqtt']['port'],
      :ssl => conf['mqtt']['ssl'],
      :clean_session => conf['mqtt']['clean_session'],
      :client_id => conf['mqtt']['client_id'],
      :username => conf['mqtt']['username'],
      :password => conf['mqtt']['password']
    )
    client.subscribe([conf['mqtt']['topic'],conf['mqtt']['QoS']])

  rescue MQTT::Exception,Errno::ECONNREFUSED,Errno::ENETUNREACH,SocketError => e
    $stderr.puts "ERROR: while connecting to MQTT server, class: #{e.class.name}, message: #{e.message}"

    if $byebye
      return nil
    end

    $stderr.puts "Sleep #{ms_conf['mqtt']['retry']} seconds and retry"
    sleep conf['mqtt']['retry']
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
      :host => conf['smartkidsdb']['host'],
      :port => conf['smartkidsdb']['port'],
      :options => conf['smartkidsdb']['options'],
      :tty =>  conf['smartkidsdb']['tty'],
      :dbname => conf['smartkidsdb']['dbname'],
      :user => conf['smartkidsdb']['user'],
      :password => conf['smartkidsdb']['password']
    )

    dbConn.prepare("sensordata", "INSERT INTO #{conf['smartkidsdb']['measurestable']} " +
      "(id, srv_ts, topic, rssi, temp, pm10, pm25, no2a, no2b, humidity, message) " +
      "VALUES ($1::bigint, $2::timestamp with time zone, $3::text, $4::smallint, $5::numeric, " +
      "$6::numeric, $7::numeric, $8::numeric, $9::numeric, $10::numeric, $11::text)")

  rescue PGError => e
    $stderr.puts "ERROR: while connecting to Postgres server, class: #{e.class.name}, message: #{e.message}"

    if $byebye
      return nil
    end

    $stderr.puts "Sleep #{ms_conf['smartkidsdb']['retry']} seconds and retry"
    sleep conf['smartkidsdb']['retry']
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

      $stderr.puts "Sleep #{ms_conf['mqtt']['retry']} seconds and retry"
      sleep ms_conf['mqtt']['retry']
      mqtt_client = makeMQTTConnection(ms_conf,mqtt_client)
      retry
    end

    srv_ts = Time.now.strftime('%Y-%m-%d %H:%M:%S.%L%z')

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

    puts "topic: #{topic}, msg: #{msg}, timestamp: #{srv_ts}, hash: " + msg_hash.to_s

    #id = topic.delete(ms_conf['mqtt']['topic'].delete('+'))

    begin

      parameters = nil
      # check for overflow

      if ( (! msg_hash["p2.5".to_sym].nil?) && msg_hash["p2.5".to_sym] == "ovf" )
        msg_hash["p2.5".to_sym] = -1
      end
      if ( (! msg_hash[:pm10].nil?) && msg_hash[:p10] == "ovf" )
        msg_hash[:p10] = -1
      end



      if (! msg_hash[:id].nil?)
        $stderr.puts "WARNING: Old format detected, translate to new format and save msg"
        msg_hash[:i] = msg_hash[:id]
      elsif (msg_hash[:i].nil?)
        $stderr.puts "WARNING: msg with no id: #{msg}"
        $stderr.puts "Save raw message with fake id"
        msg_hash[:i] = -1
        msg_hash[:message] = msg
      end

      # (id, srv_ts, topic, rssi, temp, pm10, pm25, no2a, no2b, humidity, message)
      parameters = [msg_hash[:i], srv_ts, topic, msg_hash[:r], msg_hash[:t], msg_hash[:p10],
            msg_hash["p2.5".to_sym], msg_hash[:a], msg_hash[:b], msg_hash[:h], msg_hash[:message]]

      res = db_conn.exec_prepared("sensordata",  parameters)

    rescue PG::NotNullViolation => e
      $stderr.puts "ERROR: while inserting message (PG::NotNullViolation): #{msg}, error: #{e.message}"
      $stderr.puts "Save raw message with fake id"
      msg_hash[:i] = -1
      msg_hash[:message] = msg
      $stderr.puts "Sleep #{ms_conf['smartkidsdb']['retry']} seconds and retry"
      sleep ms_conf['smartkidsdb']['retry']
      retry
    rescue PG::InvalidTextRepresentation => e
      $stderr.puts "ERROR: while inserting message (PG::InvalidTextRepresentation): #{msg}, error: #{e.message}"
      $stderr.puts "Save raw message with fake id"
      msg_hash[:i] = -1
      msg_hash[:message] = msg
      $stderr.puts "Sleep #{ms_conf['smartkidsdb']['retry']} seconds and retry"
      sleep ms_conf['smartkidsdb']['retry']
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
    if ( device['device_address'] == msg_hash[:i] )
      device_id = device['device_id']
      key_id = key
    end
  end

  if ( device_id == -1 )
    $stderr.puts "WARNING: #{msg_hash[:i]} is not a known device"
    next
  end

  # Format the measures with the right sensor ids
  measures = {
      "data" => [{
        "recorded_at" => "#{srv_ts}",
        "sensors" => [
          {
	         "id" => ms_conf['smartcitizenme']['devices'][key_id]['no2_sensor_id'],
	          "value" => msg_hash[:a]
          },
          {
	         "id" => ms_conf['smartcitizenme']['devices'][key_id]['pm_sensor_id'],
	          "value" => msg_hash["p2.5".to_sym]
          },
          {
	         "id" => ms_conf['smartcitizenme']['devices'][key_id]['temp_sensor_id'],
	          "value" => msg_hash[:t]
          },
          {
           "id" => ms_conf['smartcitizenme']['devices'][key_id]['hum_sensor_id'],
            "value" => msg_hash[:h]
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
    $stderr.puts "Sleep #{ms_conf['mqtt']['retry']} seconds and retry"
    sleep ms_conf['mqtt']['retry']
  end

end

at_exit do
  clean_up()
  puts "Program exited"
end
