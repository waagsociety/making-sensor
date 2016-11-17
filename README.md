# making-sensor

This repository contains several modules for the setting up of Making Sense experiments.

The module `server` contains the settings and the code written for the front-end and back-end of the infrastructure, while `sensor_kit` contains software and specifications for the sensors.

## Data files
This repository also contains the measurements produced by the sensors in the data folder.

For a general picture of the data analysis you can have a look at the presentation `data/final_presentation_20161019.pdf`.

There are three types of sensor measurements produced:

1. Low-cost devices developed by the [Waag] (http://waag.org/nl/project/urban-airq) that measure NO2, PM, temperature and humidity sensors
2. Airboxes devices developed by [ECN](https://www.ecn.nl) that measure PM and ultrafine particles (UFPs)
3. Calibrated data produced by calibrating sensor measurements with [GGD] (http://www.ggd.nl/) reference measurements.

### Waag sensors

The measures are in a compressed CSV file: `data/sensormeasures.csv.zip`

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

### ECN sensors

The file is `data/AMS_hourly_airboxdata_total.csv`. There are two sensors, AB46 and AB47:

1. AB46 is the airbox on the Valkenburgerstraat (exact location lat 52.36988 lon 4.907755).
2. AB47 is the airbox on the Rapenburg (lat 52.370435 lon 4.910468).

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

### Calibrated data
The file `data/urbanairq_no2_final.csv` contains hourly averaged and calibrated measurements of nitrogen dioxide (NO2) in microgram per cubic metre (μg/m3).

The columns in this file have the following meaning:

1. "ggd" = Measurements from the Vondelpark station, operated by the public health service GGD Amsterdam
2. "ggd_os" = Measurements from the Oude Schans station, operated by the public health service GGD Amsterdam 
3. "ecn_AB46" = AirBox measurements provided by ECN (also present in file `data/AMS_hourly_airboxdata_total.csv`)
4. "ecn_AB47" = AirBox measurements provided by ECN (also present in file `data/AMS_hourly_airboxdata_total.csv`)
5. "waag_nnnn" = Experimental NO2 measurements by the Waag

To improve accuracy of the electrochemical NO2 sensor used by the Waag, the calibration of the individual sensors is based on a unique linear regression of the sensor output, temperature, and relative humidity (RH). The sensors were calibrated during two side-by-side calibration periods at the GGD Vondelpark station, right before and after the Urban AirQ campaign. First calibration period: 2 June 2016 - 10 June 2016; second calibration period: 18 August 2016 - 29 August 2016. The effects of sensor drift have been reduced by assuming a linear sensor degradation over time and taking a weighted average of the 1st calibration coefficients and the 2nd calibration coefficients accordingly. Typical error for hourly averages is estimated to be 7 ug/m3.

Although the calibration was done with care, the Waag NO2 data set is still experimental. One should always be aware of possible data artefacts.


#### Known issues

* Sensor startup time is typically around 4 hours. The high NO2 values during startup are not realistic.

* All electrochemical sensors are very sensitive to sudden changes in RH. The data series have not been corrected for this.

* Sensor 14560051 and 1184206 have been used in other experiments for more than one year. Due to aging they have limited performance.

* Sensor 55303 was removed from 10-14 July for service. When put back into place, an unexplained bias showed up. The calibration is not to be trusted, as the linear sensor degradation assumption is not valid here.


* The RH sensor of sensor 1184206 saturates often at 100%. Readings under humid conditions can be less accurate.

* The RH sensor of sensor 1184838 breaks down after July 25. During campaign unrealistic high values of NO2, about two times of AirBox 46 which is located at 65m. Not to be trusted.

* During the campaign, sensor 55300 shows low long-term average NO2 values, when compared to closeby AirBox 46 or Palmes tubes. Not to be trusted.


Question and remarks about this data set can be directed to Bas Mijling, mijling@knmi.nl
