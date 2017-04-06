load './sensor-agent.rb'


class LoraAgent < SensorAgent


  def calculateInsertParams(srv_ts, msg_hash, msg, topic)

    if ( msg_hash[:payload_fields].nil? )
      $stderr.puts "WARNING: empty fields in message: #{msg}"
      return nil
    end

    if ( msg_hash[:metadata][:time].nil?)
      msg_hash[:metadata][:time] = srv_ts
    end

    # {
    #   "app_id": "makingsense",
    #   "dev_id": "boralorawest",
    #   "hardware_serial": "00000000985A5569",
    #   "port": 1,
    #   "counter": 1586,
    #   "payload_raw": "BMcFTAfQJQECAAAA",
    #   "payload_fields": {
    #     "hum": 37,
    #     "op1": 1223,
    #     "op2": 1356,
    #     "pm10": 0,
    #     "pm25": 258,
    #     "temp": 20
    #   },
    #   "metadata": {
    #     "time": "2017-04-05T14:24:30.097582156Z",
    #     "frequency": 868.5,
    #     "modulation": "LORA",
    #     "data_rate": "SF7BW125",
    #     "coding_rate": "4\/5",
    #     "gateways": [
    #       {
    #         "gtw_id": "eui-0000024b08060712",
    #         "timestamp": 4157431915,
    #         "time": "",
    #         "channel": 2,
    #         "rssi": -57,
    #         "snr": 8,
    #         "rf_chain": 1,
    #         "latitude": 52.36936,
    #         "longitude": 4.8623486
    #       }
    #     ]
    #   }
    # }

    parameters = [msg_hash[:app_id], msg_hash[:dev_id], msg_hash[:hardware_serial], msg_hash[:port], msg_hash[:counter], msg_hash[:payload_raw],
          msg_hash[:payload_fields][:op1], msg_hash[:payload_fields][:op2], msg_hash[:payload_fields][:pm25], msg_hash[:payload_fields][:pm10],
          msg_hash[:payload_fields][:temp], msg_hash[:payload_fields][:hum], msg_hash[:metadata][:time], msg_hash[:metadata][:frequency],
          msg_hash[:metadata][:modulation], msg_hash[:metadata][:data_rate], msg_hash[:metadata][:coding_rate], msg_hash[:metadata][:gateways].to_json]

    puts "gateways: " + msg_hash[:metadata][:gateways].to_s

    return parameters
  end

  def calculateUpdateParams(srv_ts, msg_hash, msg, topic)

    if ( msg_hash[:metadata][:time].nil?)
      msg_hash[:metadata][:time] = srv_ts
    end

    parameters = [msg_hash[:hardware_serial], msg_hash[:metadata][:time]]

    return parameters
  end


  def calculatePostParam(srv_ts, msg_hash, key_id)

    shr_h = @portal_conf['devices'][key_id]
    prm_h = shr_h['params']
    fld_h = msg_hash[:payload_fields]
    puts "key id: #{key_id}, parameters: #{prm_h}, fields: #{fld_h}"

    # Format the measures with the right sensor ids
    measures = {
        'data' => [{
          'recorded_at' => "#{msg_hash[:metadata][:time]}",
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
  	          'value' => calculatePMConc(fld_h[:pm25].to_f,'PM2.5')
            },
            {
  	         'id' => shr_h['pm10_conc_sensor_id'],
             'value' => calculatePMConc(fld_h[:pm10].to_f,'PM10')
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

    return msg_hash[:hardware_serial]

  end

  def setInvalidHashMsg(error_msg, msg_hash)

    my_hash = {}

    fake_id = -1

    if (!msg_hash.nil?)
      my_hash = msg_hash
      if (msg_hash[:hardware_serial].to_i < 0)
        fake_id = msg_hash[:hardware_serial].to_i - 1
      end
    end

    my_hash[:hardware_serial] = fake_id
    msg_hash[:metadata][:modulation] = error_msg

    puts "New fake msg id: " + my_hash[:hardware_serial].to_s

    return my_hash

  end

end
