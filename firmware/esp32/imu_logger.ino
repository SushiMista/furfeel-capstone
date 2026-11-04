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
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_MAX1704X.h>
#include <math.h>

const char* WIFI_SSID     = "YOUR-WIFI-SSID";
const char* WIFI_PASSWORD = "YOUR-WIFI-PASSWORD";
const char* SERVER_URL    = "http://192.168.1.22:8765/imu"; // desktop's IP (ipconfig), same network as the ESP32

MPU9250_asukiaaa imu;
// Same shared I2C wiring as furfeel_sensor.ino: SDA 21, SCL 22.
Adafruit_SSD1306 display(128, 64, &Wire, -1);
Adafruit_MAX17048 batteryGauge;
bool oledReady = false;
bool batteryGaugeReady = false;
unsigned long lastDisplayMs = 0;
int lastPostCode = 0;
bool postAttempted = false;
void updateDisplay();
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
  oledReady = display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  batteryGaugeReady = batteryGauge.begin();
  if (!oledReady) Serial.println("OLED NOT FOUND");
  if (!batteryGaugeReady) Serial.println("MAX17048 NOT FOUND");
  imu.setWire(&Wire);
  imu.beginAccel();
  imu.beginGyro();

  Serial.print("Connecting to WiFi");
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  updateDisplay();
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
    updateDisplay();
  }
  Serial.println(" connected: " + WiFi.localIP().toString());
  updateDisplay();

  batch = "[";
}

void loop() {
  if (millis() - lastDisplayMs >= 2000) {
    lastDisplayMs = millis();
    updateDisplay();
  }
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
  http.addHeader("X-ESP32-RSSI", String(WiFi.RSSI()));
  http.addHeader("X-ESP32-IP", WiFi.localIP().toString());
  http.setTimeout(3000);
  int code = http.POST(batch);
  lastPostCode = code;
  postAttempted = true;
  Serial.print("POST -> "); Serial.println(code);
  http.end();
}

void updateDisplay() {
  if (!oledReady) return;
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setTextWrap(false);
  display.setCursor(0, 0);
  display.print("FurFeel IMU Logger");
  bool connected = WiFi.status() == WL_CONNECTED;
  display.setCursor(0, 12);
  display.print(connected ? "WiFi: CONNECTED" : "WiFi: CONNECTING...");
  display.setCursor(0, 24);
  if (connected) {
    display.print("IP:");
    display.print(WiFi.localIP());
  } else {
    display.print("Logger: NO WIFI");
  }
  display.setCursor(0, 36);
  display.print("Battery:");
  if (batteryGaugeReady) {
    float percent = batteryGauge.cellPercent();
    float voltage = batteryGauge.cellVoltage();
    if (isfinite(percent) && percent >= 0 && percent <= 100 &&
        isfinite(voltage) && voltage > 0) {
      display.print(percent, 0);
      display.print("% ");
      display.print(voltage, 2);
      display.print("V");
    } else {
      display.print("UNAVAILABLE");
    }
  } else {
    display.print("NO GAUGE");
  }
  display.setCursor(0, 48);
  // HTTP 200 confirms receipt, not that the laptop is recording (it may be paused).
  if (!connected) display.print("HTTP: OFFLINE");
  else if (!postAttempted) display.print("HTTP: WAITING");
  else {
    display.print("Last HTTP: ");
    display.print(lastPostCode);
  }
  display.display();
}
