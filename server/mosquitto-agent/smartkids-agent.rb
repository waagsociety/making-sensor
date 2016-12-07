load './sensor-agent.rb'


class SmartkidsAgent < SensorAgent

  def calculateDBParam(srv_ts,msg_hash, topic)

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

    return parameters
  end

  def calculatePostParam(srv_ts, msg_hash, key_id)

    # Format the measures with the right sensor ids
    measures = {
        "data" => [{
          "recorded_at" => "#{srv_ts}",
          "sensors" => [
            {
             "id" => @portal_conf['devices'][key_id]['no2_sensor_id'],
              "value" => msg_hash[:a]
            },
            {
             "id" => @portal_conf['devices'][key_id]['pm_sensor_id'],
              "value" => msg_hash["p2.5".to_sym]
            },
            {
             "id" => @portal_conf['devices'][key_id]['temp_sensor_id'],
              "value" => msg_hash[:t]
            },
            {
             "id" => @portal_conf['devices'][key_id]['hum_sensor_id'],
              "value" => msg_hash[:h]
            }
          ]
        }]
    }

    return measures

  end

  def getDevID(msg_hash)

    return msg_hash[:i]

  end

  def setInvalidHashMsg(error_msg,msg_hash)

    if (!msg_hash.nil?)
      my_hash = msg_hash
    end

    my_hash[:i] = -1
    my_hash[:message] = error_msg

    return my_hash

  end

end
