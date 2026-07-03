#include <WiFi.h>
#include <PubSubClient.h>
#include <ESP32Servo.h>
#include <ArduinoJson.h>
#include <Wire.h>               
#include <Adafruit_VL53L0X.h>   
  
// ==============================================================================
// 1. KONFIGURASI JARINGAN & MQTT
// ==============================================================================
const char* ssid     = "Android"; // Sesuaikan dengan WiFi Anda
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

// ==============================================================================
// 3. OBJEK & VARIABEL GLOBAL
// ==============================================================================
WiFiClient espClient;
PubSubClient mqttClient(espClient);
Servo servoPakan;
Adafruit_VL53L0X lox = Adafruit_VL53L0X();

float phGlobal = 7.0;
float jarakGlobal = 20.0;
unsigned long timerSensor = 0;
bool statusLaserOK = false; // Pengaman status sensor laser

bool statusPakanAktif = false;   
bool posisiServoTerbuka = false; 
unsigned long timerIntervalServo = 0; 

const int SUDUT_BUKA = 90;
const int SUDUT_TUTUP = 0;
const unsigned long DURASI_BUKA = 700;  
const unsigned long DURASI_TUTUP = 10000; 

// ==============================================================================
// 4. FUNGSI PEMBACAAN SENSOR LASER
// ==============================================================================
float bacaJarakLaser() {
  if (!statusLaserOK) return 20.0; // Jangan paksa baca jika sensor mati/kabel putus

  VL53L0X_RangingMeasurementData_t measure;
  lox.rangingTest(&measure, false);

  Serial.print(">>> DEBUG SENSOR LASER | ");
  if (measure.RangeStatus != 4) {
    float jarakCm = measure.RangeMilliMeter / 10.0;
    Serial.print("Jarak Mentah: ");
    Serial.print(measure.RangeMilliMeter);
    Serial.println(" mm");
    return jarakCm;
  } else {
    Serial.println("Out of Range (Tidak ada pantulan)");
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
  // Cara yang lebih aman untuk mencegah kebocoran memori (Memory Leak)
  char pesan[length + 1];
  memcpy(pesan, payload, length);
  pesan[length] = '\0';
  
  StaticJsonDocument<200> doc;
  DeserializationError error = deserializeJson(doc, pesan);
  
  if (!error) {
    String perintah = doc["perintah_servo"].as<String>();
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
// 6. FUNGSI UTAMA
// ==============================================================================
void setup() {
  Serial.begin(115200);
  Wire.begin();
  
  Serial.println("\n--- INISIALISASI HARDWARE ---");
  if (!lox.begin()) {
    Serial.println("❌ Gagal menemukan VL53L0X! Cek kabel SDA (21) dan SCL (22).");
    statusLaserOK = false;
  } else {
    Serial.println("✅ Sensor VL53L0X siap bekerja!");
    statusLaserOK = true;
  }

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

  // INTERVAL DIUBAH KE 5 DETIK AGAR TIDAK DIBLOKIR BROKER
  if (millis() - timerSensor > 5000) {
    timerSensor = millis();

    jarakGlobal = bacaJarakLaser();

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

    StaticJsonDocument<200> doc;
    doc["jarak_cm"] = jarakGlobal;
    doc["ph_level"] = phGlobal; 
    
    char bufferPayload[200];
    serializeJson(doc, bufferPayload);
    
    if(mqttClient.publish(topic_sensor, bufferPayload)) {
        Serial.println("✅ Data sensor berhasil dikirim ke Dashboard");
    } else {
        Serial.println("❌ Gagal mengirim data (Koneksi Terputus/Throttled)");
    }
  }
}