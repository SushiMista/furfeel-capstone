#include <Wire.h>
#include <DHT.h>
#include <MPU9250_asukiaaa.h>
#include "MAX30105.h"
#include "heartRate.h"
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <time.h>

//================== FurFeel / Supabase ==================
// Provision the device first (dashboard Admin > Devices, plus the one-time
// SQL that sets devices.ingest_key_hash) and paste the values it gives you.
const char* WIFI_SSID     = "YOUR-WIFI-SSID";
const char* WIFI_PASSWORD = "YOUR-WIFI-PASSWORD";
const char* DEVICE_CODE   = "FURFEEL-DEV-0010";
const char* DEVICE_KEY    = "YOUR-LONG-RANDOM-SECRET"; // plaintext ingest key, not the hash
const char* FUNCTION_URL  = "https://kkbumkjvltlrggfefnkp.supabase.co/functions/v1/telemetry-intake";
const unsigned long SEND_INTERVAL_MS = 10000; // docs/07 default transmit interval

//================== DHT22 ==================
#define DHTPIN 4
#define DHTTYPE DHT22
DHT dht(DHTPIN, DHTTYPE);

//================== MPU9250 ==================
MPU9250_asukiaaa imu;

//================== MAX30102 ==================
MAX30105 particleSensor;
TwoWire I2C_MAX = TwoWire(1);

const byte RATE_SIZE = 4;
byte rates[RATE_SIZE];
byte rateSpot = 0;
byte validReadings = 0;

long lastBeat = 0;
float beatsPerMinute = 0;
float beatAvg = 0;

unsigned long lastSendMs = 0;

//==================================================
void setup()
{
  Serial.begin(115200);
  delay(1000);

  dht.begin();

  Wire.begin(21, 22);
  imu.setWire(&Wire);
  imu.beginAccel();
  imu.beginGyro();

  I2C_MAX.begin(25, 26);
  if (!particleSensor.begin(I2C_MAX))
  {
    Serial.println("MAX30102 NOT FOUND!");
    while (1);
  }
  particleSensor.setup(0x1F, 4, 2, 100, 215, 2048);
  particleSensor.setPulseAmplitudeRed(0x1F);
  particleSensor.setPulseAmplitudeIR(0x1F);
  particleSensor.setPulseAmplitudeGreen(0);

  connectWifi();
  syncTime();

  Serial.println("=================================");
  Serial.println(" FurFeel Sensor System Ready");
  Serial.println("=================================");
}

void connectWifi()
{
  Serial.print("Connecting to WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED)
  {
    delay(500);
    Serial.print(".");
  }
  Serial.println(" connected: " + WiFi.localIP().toString());
}

void syncTime()
{
  // captured_at must be real UTC — the server flags readings whose timestamp
  // drifts more than an hour, and the ESP32 has no RTC of its own.
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  struct tm timeinfo;
  Serial.print("Syncing time");
  while (!getLocalTime(&timeinfo))
  {
    delay(500);
    Serial.print(".");
  }
  Serial.println(" synced");
}

//==================================================
void loop()
{
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature();

  imu.accelUpdate();
  imu.gyroUpdate();

  long irValue = particleSensor.getIR();
  bool fingerDetected = irValue > 50000;

  if (fingerDetected && checkForBeat(irValue))
  {
    long delta = millis() - lastBeat;
    lastBeat = millis();
    beatsPerMinute = 60.0 / (delta / 1000.0);

    if (beatsPerMinute > 20 && beatsPerMinute < 220)
    {
      rates[rateSpot++] = (byte)beatsPerMinute;
      rateSpot %= RATE_SIZE;
      if (validReadings < RATE_SIZE) validReadings++;

      beatAvg = 0;
      for (byte i = 0; i < validReadings; i++) beatAvg += rates[i];
      beatAvg /= validReadings;
    }
  }

  printReadings(temperature, humidity, irValue, fingerDetected);

  if (millis() - lastSendMs >= SEND_INTERVAL_MS)
  {
    lastSendMs = millis();
    sendTelemetry(temperature, humidity, fingerDetected);
  }

  delay(1000);
}

void printReadings(float temperature, float humidity, long irValue, bool fingerDetected)
{
  Serial.println("========================================");
  Serial.println("DHT22");
  Serial.print("Temperature : "); Serial.print(temperature); Serial.println(" C");
  Serial.print("Humidity    : "); Serial.print(humidity); Serial.println(" %");
  Serial.println();
  Serial.println("MPU9250");
  Serial.print("Accel X : "); Serial.println(imu.accelX());
  Serial.print("Accel Y : "); Serial.println(imu.accelY());
  Serial.print("Accel Z : "); Serial.println(imu.accelZ());
  Serial.print("Gyro X  : "); Serial.println(imu.gyroX());
  Serial.print("Gyro Y  : "); Serial.println(imu.gyroY());
  Serial.print("Gyro Z  : "); Serial.println(imu.gyroZ());
  Serial.println();
  Serial.println("MAX30102");
  Serial.print("IR Value : "); Serial.println(irValue);
  if (!fingerDetected)
  {
    Serial.println("Contact : Not Detected");
  }
  else
  {
    Serial.println("Contact : Detected");
    Serial.print("Heart Rate : "); Serial.print(beatsPerMinute, 1); Serial.println(" BPM");
    Serial.print("Average BPM : "); Serial.println(beatAvg, 1);
  }
  Serial.println("========================================\n");
}

// ponytail: motion_activity is a naive gyro-magnitude heuristic, not a
// calibrated accelerometer-variance model — good enough to separate
// still-vs-moving, revisit with real baseline data (docs/15).
float motionActivity()
{
  float mag = sqrt(sq(imu.gyroX()) + sq(imu.gyroY()) + sq(imu.gyroZ()));
  float normalized = mag / 250.0; // rough dps scale, not a measured max
  return normalized < 0 ? 0 : (normalized > 1 ? 1 : normalized);
}

void sendTelemetry(float temperature, float humidity, bool fingerDetected)
{
  if (WiFi.status() != WL_CONNECTED)
  {
    Serial.println("WiFi not connected, skipping send");
    return;
  }

  struct tm timeinfo;
  if (!getLocalTime(&timeinfo))
  {
    Serial.println("Time not synced yet, skipping send");
    return;
  }
  char capturedAt[25];
  strftime(capturedAt, sizeof(capturedAt), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);

  float motion = motionActivity();
  const char* posture = motion > 0.5 ? "moving" : "unknown";

  char payload[512];
  int len = snprintf(payload, sizeof(payload),
    "{\"device_code\":\"%s\",\"captured_at\":\"%s\","
    "\"motion_activity\":%.3f,\"posture\":\"%s\"",
    DEVICE_CODE, capturedAt, motion, posture);

  if (fingerDetected && beatAvg > 0)
  {
    len += snprintf(payload + len, sizeof(payload) - len,
      ",\"heart_rate_bpm\":%.0f", beatAvg);
  }
  if (!isnan(temperature))
  {
    // DHT22 reads ambient air near the harness, not core body temp — there's
    // no dedicated body-temp sensor on this board, so body_temperature_c is
    // left out rather than faked from this reading.
    len += snprintf(payload + len, sizeof(payload) - len,
      ",\"ambient_temperature_c\":%.1f", temperature);
  }
  if (!isnan(humidity))
  {
    len += snprintf(payload + len, sizeof(payload) - len,
      ",\"humidity_percent\":%.1f", humidity);
  }
  snprintf(payload + len, sizeof(payload) - len, "}");

  WiFiClientSecure client;
  client.setInsecure(); // ponytail: skips cert validation for the prototype; pin Supabase's root CA before shipping past bench testing

  HTTPClient https;
  https.begin(client, FUNCTION_URL);
  https.addHeader("Content-Type", "application/json");
  https.addHeader("x-device-key", DEVICE_KEY);

  int code = https.POST((uint8_t*)payload, strlen(payload));
  Serial.print("POST -> ");
  Serial.print(code);
  Serial.print(" ");
  Serial.println(https.getString());
  https.end();
}
