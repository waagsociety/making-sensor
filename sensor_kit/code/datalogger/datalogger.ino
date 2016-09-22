
// Code for Arduino Uno
// No2, temperature & Finedust sensor
// Waag Society, Making Sense 
// author: Dave Gonner & Emma Pareschi
// version 4 May 2016

#include <Wire.h>
#include <Adafruit_ADS1015.h>
#include "DHT.h"

#define LOG_INTERVAL  925  // mills between entries (reduce to take more/faster data)


//---------------------------
// VOOR TEMP & HUM sensor DHT22
#define DHTPIN A1
#define DHTTYPE DHT22   // DHT 22  (AM2302)

DHT dht(DHTPIN, DHTTYPE);

//---------------------------
// VOOR DE ADC

// Averagigng period:
int  FLAVG = 32;  // 60

Adafruit_ADS1115 ads1115;

float Vstep = 5.0 / 32768.0 * 1000.0;  // Assuming 16 bits adc, units is mV
int  iptr = 0;                          // iptr is the pointer to the table holding the second-values
// and can be used as the number of seconds in the minute.

int16_t results1;
int16_t results2;

uint32_t acc_op1 = 0;                       // accumulator 1 value
uint32_t acc_op2 = 0;                       // accumulator 2 value

//---------------------------
// Dust Sensor

//DustDuino Serial
//By Matthew Schroyer, MentalMunition.com
//Created 2/19/2014
//Last updated 8/24/2015

// DESCRIPTION
// Outputs particle concentration per cubic foot and
// mass concentration (microgram per cubic meter) to
// serial, from a Shinyei particuate matter sensor.

// CONNECTING THE DUSTDUINO
// P1 channel on sensor is connected to digital 3
// P2 channel on sensor is connected to digital 2

// THEORY OF OPERATION
// Sketch measures the width of pulses through
// boolean triggers, on each channel.
// Pulse width is converted into a percent integer
// of time on, and equation uses this to determine
// particle concentration.
// Shape, size, and density are assumed for PM10
// and PM2.5 particles. Mass concentration is
// estimated based on these assumptions, along with
// the particle concentration.

float pm10 = 0.0;
float pm2_5 = 0.0;

unsigned long starttime;

unsigned long triggerOnP1;
unsigned long triggerOffP1;
unsigned long pulseLengthP1;
unsigned long durationP1;
boolean valP1 = HIGH;
boolean triggerP1 = false;

unsigned long triggerOnP2;
unsigned long triggerOffP2;
unsigned long pulseLengthP2;
unsigned long durationP2;
boolean valP2 = HIGH;
boolean triggerP2 = false;

float ratioP1 = 0;
float ratioP2 = 0;
unsigned long sampletime_ms = 30000;
float countP1;
float countP2;

#define DUST_P1_PIN 4      // Dust sensor PM2.5 pin
#define DUST_P2_PIN 3      // Dust senspr PM10 pin

void setup(void) {

  pinMode(DHTPIN, INPUT);

  pinMode(DUST_P1_PIN, INPUT); 
  pinMode(DUST_P2_PIN, INPUT); 

  Serial.begin(9600);
  Serial.println();

  // Start up the temperature sensor library
  dht.begin();

  // VOOR DE ASCL
  // If you want to set the aref to something other than 5v
  analogReference(EXTERNAL);

  Serial.println("Making Sense, Waag Society Amsterdam");
  Serial.println("- Alphasense NO2-B42F sensor");
  Serial.println("- DHT22 temp sensor");
  Serial.println("- Shinyei PPD42 PM10 and PM2.5 sensor");
  Serial.println("Version 25 april 2016");

  ads1115.begin();
}


void loop(void) {
  // first do 30 seconds of dust measurement
  loop_dustsensor();
  // then do 30 seconds of no2 measurement
  loop_no2();
}


void loop_no2(void) {
//  Serial.println("Start NO2 measurments...");
    iptr=0;
  
    while (iptr < FLAVG) {
    results1 = ads1115.readADC_Differential_0_1();    // Read ADC ports 0 and 1    
    results2 = ads1115.readADC_Differential_2_3();    // Read ADC ports 2 and 3
    
    acc_op1 += results1;
    acc_op2 += results2;

    iptr++;

    // delay for the amount of time we want between readings
    delay(LOG_INTERVAL);
  }

    Serial.print("acc_op1");
    Serial.println(acc_op1);

    Serial.print("acc_op2");
    Serial.println(acc_op2);

//  if (iptr > FLAVG - 1) {

    //-------------------------------------------  

    float temperature = dht.readTemperature();
    float hum = dht.readHumidity();

    float no2_a = 0;
    float no2_b = 0;
    
    no2_a = acc_op1 / FLAVG;
    no2_b = acc_op2 / FLAVG;

//    if (FLAVG == 32) {
//      no2_a = acc_op1 >> 5; // right shift by 5 equals divide by 32
//      no2_b = acc_op2 >> 5; // right shift by 5 equals divide by 32
//    }
//    
//    if (FLAVG == 64) {
//      no2_a = acc_op1 >> 6; // right shift by 6 equals divide by 64
//      no2_b = acc_op2 >> 6; // right shift by 6 equals divide by 64
//    }
     
    // SEND EVERYTHING TO THE ESP8266
    Serial.println();
    Serial.print("--ESP:");
    Serial.print(temperature);
    Serial.print(":");
    Serial.print(hum);
    Serial.print(":");
    Serial.print(no2_a);
    Serial.print(":");
    Serial.print(no2_b);
    Serial.print(":");
    Serial.print(pm10);
    Serial.print(":");
    Serial.print(pm2_5);
    Serial.println("#");

    iptr = 0;
    acc_op1 = 0;
    acc_op2 = 0;
    pm10 = 0.0;
    pm2_5 = 0.0;
}


void loop_dustsensor() {

//Serial.println("Start Dust measurments...");
     
  starttime = millis();
  durationP1 = 0;
  durationP2 = 0;

  // take samples for 30 seconds
  while ((millis() - starttime) < sampletime_ms) {
 
    valP1 = digitalRead(DUST_P1_PIN); // 3
    valP2 = digitalRead(DUST_P2_PIN);  // 2
  
    if (valP1 == LOW && triggerP1 == false) {
      triggerP1 = true;
      triggerOnP1 = micros();
    }
  
    if (valP1 == HIGH && triggerP1 == true) {
      triggerOffP1 = micros();
      pulseLengthP1 = triggerOffP1 - triggerOnP1;
      durationP1 = durationP1 + pulseLengthP1;
      triggerP1 = false;
    }
  
    if (valP2 == LOW && triggerP2 == false) {
      triggerP2 = true;
      triggerOnP2 = micros();
    }
  
    if (valP2 == HIGH && triggerP2 == true){
      triggerOffP2 = micros();
      pulseLengthP2 = triggerOffP2 - triggerOnP2;
      durationP2 = durationP2 + pulseLengthP2;
      triggerP2 = false;
    }
  }

  // sampling is over, calculate results
      
  ratioP1 = durationP1/(sampletime_ms*10.0);  // Integer percentage 0=>100
  ratioP2 = durationP2/(sampletime_ms*10.0);
  countP1 = 1.1*pow(ratioP1,3)-3.8*pow(ratioP1,2)+520*ratioP1+0.62;
  countP2 = 1.1*pow(ratioP2,3)-3.8*pow(ratioP2,2)+520*ratioP2+0.62;
  float PM10count = countP2;
  float PM25count = countP1 - countP2;

  pm10 = PM10count;
  pm2_5 = PM25count;

//    Serial.print("--RAW dust:");
//    Serial.print(countP2);
//    Serial.print(":");
//    Serial.println(countP1);
//    Serial.print("--ESP dust:");
//    Serial.print(pm10);
//    Serial.print(":");
//    Serial.println(pm2_5);
    
}

