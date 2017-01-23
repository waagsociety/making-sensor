load './sensor-agent.rb'


class LoraAgent < SensorAgent


  def calculateDBParam(srv_ts, msg_hash, msg, topic)

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

    shr_h = @portal_conf['devices'][key_id]
    prm_h = shr_h['params']
    fld_h = msg_hash[:fields]
    puts "key id: #{key_id}, parameters: #{prm_h}, fields: #{fld_h}"

    # Format the measures with the right sensor ids
    measures = {
        'data' => [{
          'recorded_at' => "#{msg_hash[:metadata][0][:server_time]}",
          'sensors' => [
            {
  	         'id' => shr_h['no2a_sensor_id'],
  	          'value' => fld_h[:op1]
            },
            {
  	         'id' => shr_h['no2b_sensor_id'],
  	          'value' => fld_h[:op2]
            },
            {
  	         'id' => shr_h['no2_sensor_id'],
  	          'value' => (prm_h['no2_offset'].to_f + prm_h['no2_no2a_coeff'].to_f * fld_h[:op1].to_f +
              prm_h['no2_no2b_coeff'].to_f * fld_h[:op2].to_f + prm_h['no2_t_coeff'].to_f * fld_h[:temp].to_f +
              prm_h['no2_rh_coeff'].to_f * fld_h[:hum].to_f).round(2)
            },
            {
  	         'id' => shr_h['pm25_nr_sensor_id'],
  	          'value' => fld_h[:pm25]
            },
            {
  	         'id' => shr_h['pm10_nr_sensor_id'],
  	          'value' => fld_h[:pm10]
            },
            {
  	         'id' => shr_h['pm25_conc_sensor_id'],
  	          'value' => calculatePMConc(fld_h[:pm25],'PM2.5')
            },
            {
  	         'id' => shr_h['pm10_conc_sensor_id'],
             'value' => calculatePMConc(fld_h[:pm10],'PM10')
            },
            {
  	         'id' => shr_h['temp_sensor_id'],
  	          'value' => fld_h[:temp]
            },
            {
             'id' => shr_h['hum_sensor_id'],
              'value' => fld_h[:hum]
            }
          ]
        }]
    }

    puts "value => (#{prm_h['no2_offset'].to_f} + #{prm_h['no2_no2a_coeff'].to_f} * #{fld_h[:op1].to_f} + \
    #{prm_h['no2_no2b_coeff'].to_f} * #{fld_h[:op2].to_f} + #{prm_h['no2_t_coeff'].to_f} * #{fld_h[:temp].to_f} + \
    #{prm_h['no2_rh_coeff'].to_f} * #{fld_h[:hum].to_f})"
    return measures

  end

  def getDevID(msg_hash)

    return msg_hash[:dev_eui]

  end

  def setInvalidHashMsg(error_msg, msg_hash)

    my_hash = {}

    fake_id = -1

    if (!msg_hash.nil?)
      my_hash = msg_hash
      if (msg_hash[:dev_eui] < 0)
        fake_id = msg_hash[:dev_eui] - 1
      end
    end

    my_hash[:dev_eui] = fake_id
    msg_hash[:metadata][0][:modulation] = error_msg

    return my_hash

  end

end
