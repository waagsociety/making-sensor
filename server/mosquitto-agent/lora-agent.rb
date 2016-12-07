load './sensor-agent.rb'


class LoraAgent < SensorAgent


  def calculateDBParam(srv_ts,msg_hash, topic)

    if ( msg_hash[:metadata][0][:server_time].nil?)
      msg_hash[:metadata][0][:server_time] = srv_ts
    end

    parameters = [msg_hash[:payload], msg_hash[:port], msg_hash[:counter], msg_hash[:dev_eui], msg_hash[:metadata][0][:frequency], msg_hash[:metadata][0][:datarate],
          msg_hash[:metadata][0][:codingrate], msg_hash[:metadata][0][:gateway_timestamp], msg_hash[:metadata][0][:channel], msg_hash[:metadata][0][:server_time],
          msg_hash[:metadata][0][:rssi], msg_hash[:metadata][0][:lsnr], msg_hash[:metadata][0][:rfchain], msg_hash[:metadata][0][:crc],
          msg_hash[:metadata][0][:modulation], msg_hash[:metadata][0][:gateway_eui], msg_hash[:metadata][0][:altitude], msg_hash[:metadata][0][:longitude],
          msg_hash[:metadata][0][:latitude], msg_hash[:fields][:op1], msg_hash[:fields][:op2], msg_hash[:fields][:pm25],
          msg_hash[:fields][:pm10], msg_hash[:fields][:temp], msg_hash[:fields][:hum]]

    return parameters
  end

  def calculatePostParam(srv_ts, msg_hash, key_id)

    # Format the measures with the right sensor ids
    measures = {
        "data" => [{
          "recorded_at" => "#{msg_hash[:metadata][0][:server_time]}",
          "sensors" => [
            {
  	         "id" => @portal_conf['devices'][key_id]['no2_sensor_id'],
  	          "value" => msg_hash[:fields][:op1]
            },
            {
  	         "id" => @portal_conf['devices'][key_id]['pm_sensor_id'],
  	          "value" => msg_hash[:fields][:pm25]
            },
            {
  	         "id" => @portal_conf['devices'][key_id]['temp_sensor_id'],
  	          "value" => msg_hash[:fields][:temp]
            },
            {
             "id" => @portal_conf['devices'][key_id]['hum_sensor_id'],
              "value" => msg_hash[:fields][:hum]
            }
          ]
        }]
    }

    return measures

  end

  def getDevID(msg_hash)

    return msg_hash[:dev_eui]

  end

  def setInvalidHashMsg(error_msg)

    if (!msg_hash.nil?)
      my_hash = msg_hash
    end

    my_hash[:dev_eui] = -1
    msg_hash[:metadata][0][:modulation] = msg

    return my_hash

  end

end
