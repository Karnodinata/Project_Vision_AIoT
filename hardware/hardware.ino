#include <WiFi.h>
#include <PubSubClient.h>
#include <ESP32Servo.h>
#include <ArduinoJson.h>
#include <Wire.h>               
#include <Adafruit_VL53L0X.h>   
  
// ==============================================================================
// 1. KONFIGURASI JARINGAN & MQTT
// ==============================================================================
const char* ssid     = "Android"; // Sesuaikan dengan WiFi kamu
const char* password = "11221122";
const char* mqtt_broker = "broker.emqx.io";
const int mqtt_port = 1883;

const char* topic_sensor = "visio/bioflok/sensor";
const char* topic_kontrol = "visio/bioflok/kontrol";

// ==============================================================================
// 2. KONFIGURASI PIN ESP32
// ==============================================================================
const int pinServo = 19;
const int pinPH = 35;
// VL53L0X otomatis menggunakan pin SDA (21) dan SCL (22) bawaan ESP32.

// ==============================================================================
// 3. OBJEK & VARIABEL GLOBAL
// ==============================================================================
WiFiClient espClient;
PubSubClient mqttClient(espClient);
Servo servoPakan;
Adafruit_VL53L0X lox = Adafruit_VL53L0X(); // Objek sensor laser

float phGlobal = 7.0;
float jarakGlobal = 20.0;
unsigned long timerSensor = 0;

// --- Variabel Interval Servo ---
bool statusPakanAktif = false;   
bool posisiServoTerbuka = false; 
unsigned long timerIntervalServo = 0; 

const int SUDUT_BUKA = 90;
const int SUDUT_TUTUP = 0;
const unsigned long DURASI_BUKA = 700;  // 0,7 Detik
const unsigned long DURASI_TUTUP = 10000; // 10 Detik

// ==============================================================================
// 4. FUNGSI PEMBACAAN SENSOR LASER VL53L0X (MODE DEBUGGING)
// ==============================================================================
float bacaJarakLaser() {
  VL53L0X_RangingMeasurementData_t measure;
  lox.rangingTest(&measure, false); // Minta sensor menembakkan laser 1x

  Serial.print(">>> DEBUG SENSOR LASER | ");

  // RangeStatus = 4 artinya benda terlalu jauh / tidak ada pantulan
  if (measure.RangeStatus != 4) {
    float jarakCm = measure.RangeMilliMeter / 10.0;
    
    // Cetak hasil mentah ke Serial Monitor
    Serial.print("Jarak Mentah: ");
    Serial.print(measure.RangeMilliMeter);
    Serial.print(" mm (");
    Serial.print(jarakCm);
    Serial.println(" cm)");
    
    // Fitur Clamping dimatikan sementara agar Anda bisa melihat nilai aslinya
    // if (jarakCm > 20.0) return 20.0;
    // if (jarakCm < 2.0) return 2.0;
    
    return jarakCm;
  } else {
    Serial.println("Out of Range (Tidak ada pantulan / Terlalu Jauh)");
    return 20.0;
  }
}

// ==============================================================================
// 5. KONEKSI & KONTROL MQTT
// ==============================================================================
void hubungkanWiFi() {
  Serial.print("Menghubungkan ke WiFi: ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi Terhubung!");
}

void hubungkanMQTT() {
  while (!mqttClient.connected()) {
    Serial.print("Menghubungkan ke MQTT Broker...");
    String clientId = "ESP32-VISION-" + String(random(0xffff), HEX);
    
    if (mqttClient.connect(clientId.c_str())) {
      Serial.println("Berhasil Terhubung!");
      mqttClient.subscribe(topic_kontrol);
    } else {
      Serial.print("Gagal, status=");
      Serial.print(mqttClient.state());
      Serial.println(" Coba lagi dalam 5 detik.");
      delay(5000);
    }
  }
}

void callbackMQTT(char* topic, byte* payload, unsigned int length) {
  String pesan = "";
  for (int i = 0; i < length; i++) {
    pesan += (char)payload[i];
  }
  
  StaticJsonDocument<200> doc;
  DeserializationError error = deserializeJson(doc, pesan);
  
  if (!error) {
    String perintah = doc["perintah_servo"];
    if (perintah == "buka") {
      statusPakanAktif = true;
      posisiServoTerbuka = true;
      servoPakan.write(SUDUT_BUKA); 
      timerIntervalServo = millis();
    } 
    else if (perintah == "tutup") {
      statusPakanAktif = false;
      posisiServoTerbuka = false;
      servoPakan.write(SUDUT_TUTUP); 
    }
  }
}

// ==============================================================================
// 6. FUNGSI UTAMA (SETUP & LOOP)
// ==============================================================================
void setup() {
  Serial.begin(115200);
  
  // Inisialisasi jalur I2C
  Wire.begin();
  
  // Inisialisasi Sensor VL53L0X
  Serial.println("Mencari sensor VL53L0X...");
  if (!lox.begin()) {
    Serial.println("Gagal menemukan VL53L0X! Cek kabel SDA (21) dan SCL (22).");
  } else {
    Serial.println("Sensor VL53L0X siap bekerja!");
  }

  // Inisialisasi Servo
  servoPakan.setPeriodHertz(50);
  servoPakan.attach(pinServo, 500, 2400);
  servoPakan.write(SUDUT_TUTUP); 
  
  hubungkanWiFi();
  mqttClient.setServer(mqtt_broker, mqtt_port);
  mqttClient.setCallback(callbackMQTT);
}

void loop() {
  if (!mqttClient.connected()) {
    hubungkanMQTT();
  }
  mqttClient.loop();

  // Logika Interval Servo
  if (statusPakanAktif) {
    unsigned long waktuSekarang = millis();
    if (posisiServoTerbuka) {
      if (waktuSekarang - timerIntervalServo >= DURASI_BUKA) {
        servoPakan.write(SUDUT_TUTUP);
        posisiServoTerbuka = false;
        timerIntervalServo = waktuSekarang; 
      }
    } 
    else {
      if (waktuSekarang - timerIntervalServo >= DURASI_TUTUP) {
        servoPakan.write(SUDUT_BUKA);
        posisiServoTerbuka = true;
        timerIntervalServo = waktuSekarang; 
      }
    }
  }

  // Kirim data sensor setiap 2 Detik
  if (millis() - timerSensor > 2000) {
    timerSensor = millis();

    // 1. Baca Jarak dengan Laser
    jarakGlobal = bacaJarakLaser();

    // 2. Baca pH
    long totalAnalog = 0;
    for(int i = 0; i < 10; i++) {
      totalAnalog += analogRead(pinPH);
      delay(10); 
    }
    float rataAnalog = totalAnalog / 10.0;
    float tegangan = rataAnalog * (3.3 / 4095.0);
    phGlobal = 3.5 * tegangan + 0.0; 
    
    if (phGlobal > 14.0) phGlobal = 14.0;
    if (phGlobal < 0.0) phGlobal = 0.0;

    // 3. Kirim ke MQTT
    StaticJsonDocument<200> doc;
    doc["jarak_cm"] = jarakGlobal;
    doc["ph_level"] = phGlobal; 
    
    char bufferPayload[200];
    serializeJson(doc, bufferPayload);
    mqttClient.publish(topic_sensor, bufferPayload);
  }
}