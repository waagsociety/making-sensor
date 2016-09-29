
// Code for NodeMCU v1.0 module (ESP8266)
// Waag Society, Making Sense
// author: Dave Gonner & Emma Pareschi
// version 11 May 2016


#include <FS.h>                   // Make sure ESP library 2.1.0 or higher is installed
#include <ESP8266WiFi.h>          //https://github.com/esp8266/Arduino
#include <DNSServer.h>
#include <ESP8266WebServer.h>
#include <WiFiManager.h>          //https://github.com/tzapu/WiFiManager
#include <ArduinoJson.h>          //https://github.com/bblanchon/ArduinoJson
#include <PubSubClient.h>         //https://github.com/knolleary/pubsubclient

// DEFAULT MQTT SETTINGS, will be overwritten by values from config.json
//char mqtt_server[41] = "m21.cloudmqtt.com\0";
//char mqtt_portStr[7] = "12132\0";
//char mqtt_username[21] = "no2_sensor\0";
//char mqtt_password[21] = "WaagSociety\0";
//char mqtt_topic[21] = "sensor/%u/data\0";

//char mqtt_server[41] = "wg66.waag.org\0";
char mqtt_server[41] = "<my_server>\0";
char mqtt_portStr[7] = "<my_port>\0";
char mqtt_username[21] = "<my_username>\0";
char mqtt_password[21] = "<my_password>\0";
char mqtt_topic[21] = "<my_topic>\0";

int mqtt_port = atoi(mqtt_portStr);

#define BUTTON_PIN 16              // D0, button to enter wifi manager
#define RX_ACTIVITY_LED_PIN 5      // D1
#define MQTT_CONNECTED_LED_PIN 4   // D2
#define WIFI_CONNECTED_LED_PIN 14  // D5
#define WIFI_CONFIG_LED_PIN 12     // D6


WiFiManager wifiManager;
WiFiClient espClient;
PubSubClient mqttClient(espClient);

String readStr;
long chipid;
bool shouldSaveConfig = false;    //flag for saving data

//callback notifying us of the need to save config
void saveConfigCallback () {
  Serial.println("Should save config");
  shouldSaveConfig = true;
}

void saveConfigJson() {
  //save the custom parameters to FS
  Serial.println("saving config");
  DynamicJsonBuffer jsonBuffer;
  JsonObject& json = jsonBuffer.createObject();
  json["mqtt_server"] = mqtt_server;
  json["mqtt_port"] = mqtt_portStr;
  json["mqtt_username"] = mqtt_username;
  json["mqtt_password"] = mqtt_password;
  json["mqtt_topic"] = mqtt_topic;

  File configFile = SPIFFS.open("/config.json", "w");
  if (!configFile) {
    Serial.println("failed to open config file for writing");
  }

  json.printTo(Serial);
  Serial.println();
  json.printTo(configFile);
  configFile.close();
  //end save
}


void setup() {

  Serial.begin(9600);
  Serial.println();

  pinMode(BUTTON_PIN, INPUT);
  pinMode(WIFI_CONFIG_LED_PIN, OUTPUT);
  digitalWrite(WIFI_CONFIG_LED_PIN, HIGH); // off
  pinMode(WIFI_CONNECTED_LED_PIN, OUTPUT);
  digitalWrite(WIFI_CONNECTED_LED_PIN, HIGH); // off
  pinMode(MQTT_CONNECTED_LED_PIN, OUTPUT);
  digitalWrite(MQTT_CONNECTED_LED_PIN, HIGH); // off
  pinMode(RX_ACTIVITY_LED_PIN, OUTPUT);
  digitalWrite(RX_ACTIVITY_LED_PIN, HIGH); // off

  //--------------------------------------------
  //Format FS, reset Wifi settings, for testing
  Serial.print("Formatting FS...");
  SPIFFS.format();
  Serial.println("Done.");
  Serial.print("Reset WiFi settings...");
   wifiManager.resetSettings();  //****
  Serial.println("Done.");
  while(1) {
    delay(1000);
    Serial.println("loop...");
  }
  //--------------------------------------------

  //read configuration from FS json
  Serial.println("mounting FS...");

  if (SPIFFS.begin()) {
    Serial.println("mounted file system");
    if (SPIFFS.exists("/config.json")) {
      //file exists, reading and loading
      Serial.println("reading config file");
      File configFile = SPIFFS.open("/config.json", "r");
      if (configFile) {
        Serial.println("opened config file");
        size_t size = configFile.size();
        // Allocate a buffer to store contents of the file.
        std::unique_ptr<char[]> buf(new char[size]);

        configFile.readBytes(buf.get(), size);
        DynamicJsonBuffer jsonBuffer;
        JsonObject& json = jsonBuffer.parseObject(buf.get());
        json.printTo(Serial);
        if (json.success()) {
          Serial.println("\nparsed json");

          strcpy(mqtt_server, json["mqtt_server"]);
          strcpy(mqtt_portStr, json["mqtt_port"]);
          mqtt_port = atoi(mqtt_portStr);
          strcpy(mqtt_username, json["mqtt_username"]);
          strcpy(mqtt_password, json["mqtt_password"]);
          strcpy(mqtt_topic, json["mqtt_topic"]);

        } else {
          Serial.println("failed to load json config");
        }
      }
    } else {
      Serial.println("/config.json does not exist, creating");
      saveConfigJson(); // saving the hardcoded default values
    }
  } else {
    Serial.println("failed to mount FS");
  }
  //end read

  wifiManager.setSaveConfigCallback(saveConfigCallback);

  boolean startConfigPortal = false;
  if ( digitalRead(BUTTON_PIN) == LOW ) {
    startConfigPortal = true;
  }

  WiFi.mode(WIFI_STA);
  if (WiFi.SSID()) {
    Serial.println("Using saved credentials");
    ETS_UART_INTR_DISABLE();
    wifi_station_disconnect();
    ETS_UART_INTR_ENABLE();
    WiFi.begin();
  } else {
    Serial.println("No saved credentials");
    startConfigPortal = true;
  }

  WiFi.waitForConnectResult();
  if (WiFi.status() != WL_CONNECTED) {
    Serial.print("Failed to connect Wifi");
    startConfigPortal = true;
  }

  if (startConfigPortal) {
    WiFiManagerParameter custom_mqtt_server("server", "mqtt server", mqtt_server, 40);
    WiFiManagerParameter custom_mqtt_port("port", "mqtt port", mqtt_portStr, 6);
    WiFiManagerParameter custom_mqtt_username("username", "mqtt username", mqtt_username, 20);
    WiFiManagerParameter custom_mqtt_password("password", "mqtt password", mqtt_password, 20);
    WiFiManagerParameter custom_mqtt_topic("topic", "mqtt topic", mqtt_topic, 20);

    wifiManager.addParameter(&custom_mqtt_server);
    wifiManager.addParameter(&custom_mqtt_port);
    wifiManager.addParameter(&custom_mqtt_username);
    wifiManager.addParameter(&custom_mqtt_password);
    wifiManager.addParameter(&custom_mqtt_topic);

    // If the user requests it, start the wifimanager
    digitalWrite(WIFI_CONNECTED_LED_PIN, HIGH); // off
    digitalWrite(MQTT_CONNECTED_LED_PIN, HIGH); // off
    digitalWrite(WIFI_CONFIG_LED_PIN, LOW); // on
    wifiManager.startConfigPortal("MakingSense");
    digitalWrite(WIFI_CONFIG_LED_PIN, HIGH); // off

    if (shouldSaveConfig) {
      // read the updated parameters
      strcpy(mqtt_server, custom_mqtt_server.getValue());
      strcpy(mqtt_portStr, custom_mqtt_port.getValue());
      mqtt_port = atoi(mqtt_portStr);
      strcpy(mqtt_username, custom_mqtt_username.getValue());
      strcpy(mqtt_password, custom_mqtt_password.getValue());
      strcpy(mqtt_topic, custom_mqtt_topic.getValue());

      saveConfigJson();
      shouldSaveConfig = false;
    }
  }

  digitalWrite(WIFI_CONNECTED_LED_PIN, LOW); // on
  Serial.println("Wifi connected...");

  mqttClient.setServer(mqtt_server, mqtt_port);
  chipid = ESP.getChipId();
}


void reconnect() {
  digitalWrite(MQTT_CONNECTED_LED_PIN, HIGH); // off
  // Loop until we're reconnected
  while (!mqttClient.connected()) {
    Serial.print("Attempting MQTT connection to ");
    Serial.print(mqtt_server);
    Serial.println("...");
    // Attempt to connect
    char mqtt_clientid[15];
    snprintf (mqtt_clientid, 14, "ESP%u", chipid);

    if (mqttClient.connect(mqtt_clientid, mqtt_username, mqtt_password)) {
      digitalWrite(WIFI_CONNECTED_LED_PIN, LOW); // on
      digitalWrite(MQTT_CONNECTED_LED_PIN, LOW); // on
      Serial.println("MQTT connected.");
      long rssi = WiFi.RSSI();

 //     char buf[50];
 //     sprintf(buf, "ESP: %u Connected @ %i dBm", chipid, rssi);
 //     char topic_buf[50];
 //     sprintf(topic_buf, mqtt_topic, chipid);
 //     mqttClient.publish(topic_buf, buf);

      // send proper JSON startup message
      DynamicJsonBuffer jsonBuffer;
      JsonObject& json = jsonBuffer.createObject();
      json["id"] = chipid;
      json["rssi"] = rssi;
      json["message"] = "Sensor startup";
      char buf[110];
      json.printTo(buf, sizeof(buf));

      Serial.print("Publish message: ");
      Serial.println(buf);

      char topic_buf[50];
      sprintf(topic_buf, mqtt_topic, chipid);
      mqttClient.publish(topic_buf, buf);


    } else {
      Serial.print("failed, rc=");
      Serial.print(mqttClient.state());
      Serial.println(" try again in 5 seconds");
      // Wait 5 seconds before retrying
      delay(5000);
    }
  }
}


void loop() {

  // make sure the MQTT client is connencted
  if (!mqttClient.connected()) {
    reconnect();
  }
  mqttClient.loop(); // Need to call this, otherwise mqtt breaks

  // read data from the serial port
  while (Serial.available()) {
    digitalWrite(RX_ACTIVITY_LED_PIN, LOW); // on
    delay(3);  //delay to allow buffer to fill
    if (Serial.available() >0) {
      char c = Serial.read();  //gets one byte from serial buffer
      // if the byte is not end of line, append it
      if (c == 10) { // end of the line
        if (readStr.startsWith("--ESP:") && readStr.endsWith("#\r")) { // test to see for esp command line
          int colom1 = readStr.indexOf(':',7);
          int colom2 = readStr.indexOf(':',colom1+1);
          int colom3 = readStr.indexOf(':',colom2+1);
          int colom4 = readStr.indexOf(':',colom3+1);
          int colom5 = readStr.indexOf(':',colom4+1);
          int colom6 = readStr.indexOf(':',colom5+1);

          String temp = readStr.substring(6, colom1);
          String hum = readStr.substring(colom1+1, colom2);
          String no2_a = readStr.substring(colom2+1, colom3);
          String no2_b = readStr.substring(colom3+1, colom4);
          String pm10 = readStr.substring(colom4+1, colom5);
          String pm2_5 = readStr.substring(colom5+1, readStr.length()-2);

          long rssi = WiFi.RSSI(); // RSSI = wifi signal strength

          DynamicJsonBuffer jsonBuffer;
          JsonObject& json = jsonBuffer.createObject();
          json["i"] = chipid;
          json["r"] = rssi;
          json["t"] = temp;
          json["a"] = no2_a;
          json["b"] = no2_b;
          json["p10"] = pm10;
          json["p2.5"] = pm2_5;
          json["h"] = hum;

          char buffer[130];
          json.printTo(buffer, sizeof(buffer));

          Serial.print("Publish message 1: ");
          Serial.println(buffer);

          char topic_buf[50];
          sprintf(topic_buf, mqtt_topic, chipid);
          int aux = mqttClient.publish(topic_buf, buffer);

          Serial.print("Return from publish: ");
          Serial.println(aux);
          Serial.print("topic buff: ");
          Serial.println(topic_buf);

        }

        Serial.println(readStr);
        readStr = "";
      } else {
        readStr += c; //makes the string readString
      }
    }
  }
  digitalWrite(RX_ACTIVITY_LED_PIN, HIGH); // off

}
