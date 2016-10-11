# making-sensor

This repository contains several modules for the setting up of Making Sense experiments.

The module `server` contains the settings and the code written for the front-end and back-end of the infrastructure, while `sensor_kit` contains software and specifications for the sensors.

This repository also contains the measurements produced by the sensors as a compressed CSV file: `sensormeasures.csv.zip`

The columns in this file have the following meaning:

1. "id" = id of the sensor
2. "srv_ts" = timestamp assigned by the server that received the message
3. "topic" = the topic this message was posted to (not relevant for the measures)
4. "rssi" = strenght of the WIFI signal received by the sensor
5. "temp" = temperature in Celsius
6. "pm10" = value related to Particulate Matter 10 micron (from the PPD42NS sensor, see [documentation](./sensor_kit/doc/Sensor_Kit_doc.pdf))
7. "pm25" = value related to Particulate Matter 2.5 micron (from the PPD42NS sensor, see [documentation](./sensor_kit/doc/Sensor_Kit_doc.pdf))
8. "no2a" = value of the Alphasense main electrode in Volts (from the NO2-B42F and NO2-B43F Alphasense sensor, see [documentation](./sensor_kit/doc/Sensor_Kit_doc.pdf))
9. "no2b" = value of the Alphasense auxiliary electrode in Volts (from the NO2-B42F and NO2-B43F Alphasense sensor, see [documentation](./sensor_kit/doc/Sensor_Kit_doc.pdf))
10. "humidity" = relative humidity
11. "message" = a message sent by the sensor during start-up
