// Phase 1 data-collection sketch for the posture/activity model (ml/README.md).
// Streams raw MPU9250 accel/gyro over WiFi to a laptop running
// ml/imu_wifi_logger_server.py, batched every BATCH_SIZE samples. Runs off a
// power bank -- no USB tether to the laptop, so the dog can move freely
// within WiFi range. Labeling happens on the laptop side, not on-device.
// Bench-only: no Supabase, no device-key auth, separate from furfeel_sensor.ino.

#include <Wire.h>
#include <MPU9250_asukiaaa.h>
#include <WiFi.h>
#include <HTTPClient.h>

const char* WIFI_SSID     = "YOUR-WIFI-SSID";
const char* WIFI_PASSWORD = "YOUR-WIFI-PASSWORD";
const char* SERVER_URL    = "http://192.168.1.100:8765/imu"; // laptop's IP (ipconfig), same WiFi network as the ESP32

MPU9250_asukiaaa imu;
const unsigned long SAMPLE_INTERVAL_MS = 50; // ~20 Hz, matches docs/07 IMU sampling rate
const int BATCH_SIZE = 10; // ~0.5s of samples per HTTP POST

unsigned long lastSampleMs = 0;
unsigned long lastDebugPrintMs = 0;
String batch;
int batchCount = 0;

void setup() {
  Serial.begin(115200);
  delay(1000);

  Wire.begin(21, 22);
  imu.setWire(&Wire);
  imu.beginAccel();
  imu.beginGyro();

  Serial.print("Connecting to WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println(" connected: " + WiFi.localIP().toString());

  batch = "[";
}

void loop() {
  if (millis() - lastSampleMs < SAMPLE_INTERVAL_MS) return;
  lastSampleMs = millis();

  imu.accelUpdate();
  imu.gyroUpdate();

  // Debug print every ~1s so you can check the sensor itself in Serial Monitor,
  // independent of WiFi/CSV -- if these all read 0.0000, it's a wiring/IMU
  // problem, not a networking one.
  if (millis() - lastDebugPrintMs >= 1000) {
    lastDebugPrintMs = millis();
    Serial.print("accel x/y/z: ");
    Serial.print(imu.accelX(), 4); Serial.print(", ");
    Serial.print(imu.accelY(), 4); Serial.print(", ");
    Serial.print(imu.accelZ(), 4);
    Serial.print("  gyro x/y/z: ");
    Serial.print(imu.gyroX(), 4); Serial.print(", ");
    Serial.print(imu.gyroY(), 4); Serial.print(", ");
    Serial.println(imu.gyroZ(), 4);
  }

  if (batchCount > 0) batch += ",";
  batch += "{\"millis_ms\":" + String(lastSampleMs) +
           ",\"accel_x\":" + String(imu.accelX(), 4) +
           ",\"accel_y\":" + String(imu.accelY(), 4) +
           ",\"accel_z\":" + String(imu.accelZ(), 4) +
           ",\"gyro_x\":" + String(imu.gyroX(), 4) +
           ",\"gyro_y\":" + String(imu.gyroY(), 4) +
           ",\"gyro_z\":" + String(imu.gyroZ(), 4) + "}";
  batchCount++;

  if (batchCount >= BATCH_SIZE) {
    batch += "]";
    sendBatch();
    batch = "[";
    batchCount = 0;
  }
}

void sendBatch() {
  if (WiFi.status() != WL_CONNECTED) return;
  HTTPClient http;
  http.begin(SERVER_URL);
  http.addHeader("Content-Type", "application/json");
  int code = http.POST(batch);
  Serial.print("POST -> "); Serial.println(code);
  http.end();
}
