# making-sensor

This repository contains several modules for the setting up of Making Sense experiments.

The module `server` contains the settings and the code written for the front-end and back-end of the infrastructure, while `sensor_kit` contains software and specifications for the sensors.

## Data files
This repository also contains the measurements produced by the sensors. There are three types of sensor measurements produced:

1. Low-cost devices developed by the [Waag] (http://waag.org/nl/project/urban-airq) that measure NO2, PM, temperature and humidity sensors
2. Calibration data produced by GGD's Vondelpark station, high quality measurements that are used to calibrate Waag's sensors.
3. Airboxes devices developed by [ECN](https://www.ecn.nl) that measure PM and ultrafine particles (UFPs)

### Waag sensors

The measures are in a compressed CSV file: `sensormeasures.csv.zip`

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

The following list gives the location of the sensors in the form id => lat,lon:
```
26296 => 52.374204,4.902643
53788 => 52.370778,4.900735
54200 => 52.371874,4.902867
54911 => 52.369294,4.907168
55300 => 52.369294,4.907168
55303 => 52.359684,4.866167
717780 => 52.369123,4.906964
1183931 => 52.370121,4.900912
1184206 => 52.367005,4.903258
1184453 => 52.376650,4.901522
1184527 => 52.374204,4.902643
1184739 => 52.369116,4.907405
1184838 => 52.369633,4.908618
1185325 => 52.361186,4.908988
13905017 => 52.372560,4.900649
14560051 => 52.367022,4.903169
```

### Calibration data



### ECN sensors

There are two sensors, AB46 and AB47:

1. AB46 is the airbox on the Valkenburgerstraat (exact location lat 52.36988 lon 4.907755).
2. AB47 is the airbox on the Rapenburg (lat 52.370435 lon 4.910468).

The file is `AMS_hourly_airboxdata_total.csv`

The columns in this file have the following meaning:

1. "Time" = Time in UTC
2. "NO2" = NO2 measurement from sensor AB46, in μg/m3
3. "PM1" = Particulate Matter 1 μ from sensor AB46
4. "PM2.5" = Particulate Matter 2.5 μ from sensor AB46
5. "PM10" = Particulate Matter 10 μ from sensor AB46
6. "NO2" = NO2 measurement from sensor AB47, in μg/m3
7. "PM1" = Particulate Matter 1 μ from sensor AB47
8. "PM2.5" = Particulate Matter 2.5 μ from sensor AB47
9. "PM10" = Particulate Matter 10 μ from sensor AB47
