require 'rubygems'
require 'bundler/setup'

require 'faraday'
require 'faraday_middleware'
require 'yaml'
require 'pg'
require 'json'
require 'mqtt'
require 'base64'

class SensorAgent
  private
  # Class variables
  attr_accessor :mqtt_client
  attr_accessor :db_conn
  attr_accessor :byebye
  attr_accessor :auth_encoded

  attr_accessor :mqtt_conf
  attr_accessor :db_conf
  attr_accessor :portal_conf

  public
  # Close connections before exiting
  def clean_up()
    puts "Closing MQTT and DB connections"
    closeMQTTConn()
    closeDBConn()
  end

  def initialize(mqtt_conf,db_conf,portal_conf)

    @mqtt_client = nil
    @db_conn = nil
    @byebye = false

    @mqtt_conf = mqtt_conf
    @db_conf = db_conf
    @portal_conf = portal_conf

    $stdout.sync = true

    # Signal handler to handle a clean exit
    Signal.trap("SIGTERM") {
      puts "Exiting"
      @byebye = true
    }

    makeMQTTConnection()
    makeDBConnection()

    # encode the credentials, no need to do this in a loop

    @auth_encoded = Base64.encode64("#{@portal_conf['username']}:#{@portal_conf['password']}")

  end

  def read_and_upload
    while ! @byebye do
      msg_hash = nil
      begin
        begin
          # blocking call, not ideal if need to exit
          topic,msg = @mqtt_client.get()
        rescue MQTT::Exception, Errno::ECONNRESET, Exception => e
          $stderr.puts "WARNING: while getting MQTT connection, class: #{e.class.name}, message: #{e.message}"
          if @byebye
            break
          end

          $stderr.puts "Sleep #{@mqtt_conf['retry']} seconds and retry"
          sleep @mqtt_conf['retry']
          makeMQTTConnection()
          retry
        end

        puts "topic: #{topic}, msg: #{msg}"

        srv_ts = Time.now.strftime('%Y-%m-%d %H:%M:%S.%L%z')

        puts "local timestamp: #{srv_ts}"

        #id = topic.delete(@mqtt_conf['topic'].delete('+'))

        begin
          msg_hash = JSON.parse(msg,symbolize_names: true)
        rescue JSON::JSONError => e
          $stderr.puts "ERROR: while processing sensor data: #{msg}, class: #{e.class.name}, message: #{e.message}"
          $stderr.puts "Save raw message with fake id"
          msg_hash = setInvalidHashMsg(msg,msg_hash)
        end

        puts "hash: " + msg_hash.to_s

        begin

          parameters = calculateDBParam(srv_ts,msg_hash, msg, topic)
          res = db_conn.exec_prepared("mypreparedquery",  parameters)

        rescue PG::NotNullViolation => e
          $stderr.puts "ERROR: while inserting message (PG::NotNullViolation): #{msg}, error: #{e.message}"
          $stderr.puts "Save raw message with fake id"
          msg_hash = setInvalidHashMsg("EXCEPTION: PG::NotNullViolation, ERROR: #{e.message}, MESSAGE: #{msg}",msg_hash)
          $stderr.puts "Sleep #{@db_conf['retry']} seconds and retry"
          sleep @db_conf['retry']
          retry
        rescue PG::UniqueViolation => e
          $stderr.puts "ERROR: while inserting message (PG::UniqueViolation): #{msg}, error: #{e.message}"
          $stderr.puts "Save raw message with fake id"
          msg_hash = setInvalidHashMsg("EXCEPTION: PG::UniqueViolation, ERROR: #{e.message}, MESSAGE: #{msg}",msg_hash)
          $stderr.puts "Sleep #{@db_conf['retry']} seconds and retry"
          sleep @db_conf['retry']
          retry
        rescue PG::InvalidTextRepresentation => e
          $stderr.puts "ERROR: while inserting message (PG::InvalidTextRepresentation): #{msg}, error: #{e.message}"
          $stderr.puts "Ignore msg"
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

        msg_dev_id = getDevID(msg_hash)

        @portal_conf['devices'].each do |key,device|
          if ( device['device_address'] == msg_dev_id )
            device_id = device['device_id']
            key_id = key
          end
        end

        if ( device_id == -1 )
          $stderr.puts "WARNING: #{msg_dev_id} is not a known device"
          next
        end

        if ( !@portal_conf['devices'][key_id]['upload'] )
          next
        end

        # Format the measures with the right sensor ids
        measures = calculatePostParam(srv_ts, msg_hash, key_id)

        measures_s = JSON.generate(measures).to_s

        puts "Measures #{measures_s} for device #{device_id}"


        httppost(@portal_conf['base_url'], "devices/#{device_id}/readings",
                measures_s, auth_encoded,@portal_conf['retry'],@portal_conf['retry'])

      rescue Exception => e
        $stderr.puts "CRITICAL: Generic exception caught in process loop, class: #{e.class.name}, message: #{e.message}"
        $stderr.puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
        $stderr.puts "Sensor data: msg: #{msg}, hash: #{msg_hash.to_s}"

        if @byebye
          break
        end
        $stderr.puts "Sleep #{@mqtt_conf['retry']} seconds and retry"
        sleep @mqtt_conf['retry']
      end

    end

  end

  protected

  def calculateDBParam(srv_ts, msg_hash, msg, topic)

    raise "Exception: called base class calculateDBParam function"

  end

  def calculatePostParam(srv_ts, msg_hash, key_id)

    raise "Exception: called base class calculatePostParam function"

  end

  def getDevID(msg_hash)

    raise "Exception: called base class getDevID function"

  end

  def setInvalidHashMsg(error_msg, msg_hash)

    raise "Exception: called base class setInvalidHashMsg function"

  end



  private

  # Set up the MQTT connection
  def makeMQTTConnection()

    if ( !@mqtt_client.nil? && @mqtt_client.connected?)
      return
    end

    # trying anyway to release the client just in case
    closeMQTTConn()

    begin
      @mqtt_client = MQTT::Client.connect(
        :host => @mqtt_conf['host'],
        :port => @mqtt_conf['port'],
        :ssl => @mqtt_conf['ssl'],
        :clean_session => @mqtt_conf['clean_session'],
        :client_id => @mqtt_conf['client_id'],
        :username => @mqtt_conf['username'],
        :password => @mqtt_conf['password']
      )
      @mqtt_client.subscribe(@mqtt_conf['topic'],@mqtt_conf['QoS'])

    rescue MQTT::Exception,Errno::ECONNREFUSED,Errno::ENETUNREACH,SocketError => e
      $stderr.puts "ERROR: while connecting to MQTT server, class: #{e.class.name}, message: #{e.message}"

      if @byebye
        return
      end

      $stderr.puts "Sleep #{@mqtt_conf['retry']} seconds and retry"
      sleep @mqtt_conf['retry']
      retry
    end

    return

  end

  # Release the MQTT connection
  def closeMQTTConn()

    if ( !@mqtt_client.nil? )
      begin
        @mqtt_client.disconnect(send_msg = false)
      rescue Exception => e
      #ignore it
      end
    end
  end

  # Set up the DB connection
  def makeDBConnection()

    if ( !@db_conn.nil? && @db_conn.status == PGconn::CONNECTION_OK)
      return
    end

    # trying anyway to release the connection just in case
    closeDBConn()

    begin
      @db_conn = PGconn.open(
        :host => @db_conf['host'],
        :port => @db_conf['port'],
        :options => @db_conf['options'],
        :tty =>  @db_conf['tty'],
        :dbname => @db_conf['dbname'],
        :user => @db_conf['user'],
        :password => @db_conf['password']
      )

      @db_conn.prepare("mypreparedquery", @db_conf['query'])

    rescue PGError => e
      $stderr.puts "ERROR: while connecting to Postgres server, class: #{e.class.name}, message: #{e.message}"

      if @byebye
        return nil
      end

      $stderr.puts "Sleep #{@db_conf['retry']} seconds and retry"
      sleep @db_conf['retry']
      retry
    end

    return
  end


  # Release the DB connection
  def closeDBConn()
    if ( !@db_conn.nil? )
      begin
        @db_conn.finish()
      rescue Exception => e
        #ignore it
      end
    end
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
    rescue Faraday::TimeoutError, Net::ReadTimeout => e
      sleep sleep_time
      if nretry > 0
        nretry -= 1
        $stderr.puts "WARNING: #{e.class.name} to #{host} #{path}, #{e.message} in posting reading, will retry #{nretry} times, body: #{body}"
        retry
      else
        $stderr.puts "ERROR: #{e.class.name} to #{host} #{path}, #{e.message} in posting reading after #{n_retries} attempts"
      end
    rescue Faraday::Error::ClientError => e
      $stderr.puts "ERROR: #{e.class.name}, #{e.message} in posting reading to #{host} #{path}, response: #{response.to_s}, body: #{body}"
    end

   # can be null
    return response

  end

  def calculatePMConc(nr, type)

    radius = 0

    if (type == "PM2.5")
      radius = 0.44*10**(-6)
    elsif (type == "PM10")
      radius = 2.6*10**(-6)
    else
      raise "Exception: unknown PM type: #{type}"
    end

    volume = (4.0/3.0) * Math::PI * radius**3
    density = 1.65 * 10**12

    mass = volume * density
    k = 3531.5

    return nr * k * mass

  end

end
