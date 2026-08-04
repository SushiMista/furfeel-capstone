#include <Wire.h>
#include <DHT.h>
#include <MPU9250_asukiaaa.h>
#include "MAX30105.h"
#include "heartRate.h"
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <time.h>
#include "posture_model.h"

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

// Posture model (ml/train_posture_model.py -> ml/export_posture_model_to_arduino.py
// -> posture_model.h). Runs on-device because raw IMU samples never leave the
// device (docs/07 payload-size decision) -- only the classified posture does.
// PROVISIONAL: trained on standing/lying only so far (see posture_model.h's
// class list) -- will only ever predict one of the classes it's been trained
// on. Regenerate posture_model.h and re-upload as more postures are added.
Eloquent::ML::Port::RandomForest postureModel;

const int WINDOW_SIZE = 20;                  // ~1s at 20Hz, matches training (docs/07)
const unsigned long SAMPLE_INTERVAL_MS = 50; // 20Hz
float winAccelX[WINDOW_SIZE], winAccelY[WINDOW_SIZE], winAccelZ[WINDOW_SIZE];
float winGyroX[WINDOW_SIZE], winGyroY[WINDOW_SIZE], winGyroZ[WINDOW_SIZE];

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

// Polls the heart-rate sensor once -- called every ~50ms during the posture
// window instead of once/second, so beat detection is more responsive than
// before, not less, despite the loop restructuring below.
void pollHeartRate(long &irValueOut, bool &fingerDetectedOut)
{
  irValueOut = particleSensor.getIR();
  fingerDetectedOut = irValueOut > 50000;

  if (fingerDetectedOut && checkForBeat(irValueOut))
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
}

// Mean/std(population)/min/max of one window -- must match the statistics
// ml/train_posture_model.py's window_features() computes, in the same order.
void computeStats(float *arr, int n, float &mean, float &stdDev, float &mn, float &mx)
{
  float sum = 0, sumSq = 0;
  mn = arr[0];
  mx = arr[0];
  for (int i = 0; i < n; i++)
  {
    sum += arr[i];
    if (arr[i] < mn) mn = arr[i];
    if (arr[i] > mx) mx = arr[i];
  }
  mean = sum / n;
  for (int i = 0; i < n; i++)
  {
    float d = arr[i] - mean;
    sumSq += d * d;
  }
  stdDev = sqrt(sumSq / n);
}

// Samples the IMU at 20Hz for one ~1s window (also keeps heart-rate detection
// running during that second), builds the 26 features in the exact order
// ml/train_posture_model.py's window_features() uses, and classifies posture.
// Replaces the old single-sample motionActivity() placeholder.
String capturePostureWindow(float &motionOut, long &irValueOut, bool &fingerDetectedOut)
{
  for (int i = 0; i < WINDOW_SIZE; i++)
  {
    imu.accelUpdate();
    imu.gyroUpdate();
    winAccelX[i] = imu.accelX(); winAccelY[i] = imu.accelY(); winAccelZ[i] = imu.accelZ();
    winGyroX[i] = imu.gyroX();   winGyroY[i] = imu.gyroY();   winGyroZ[i] = imu.gyroZ();

    pollHeartRate(irValueOut, fingerDetectedOut);
    delay(SAMPLE_INTERVAL_MS);
  }

  float feats[26];
  float mean, stdDev, mn, mx;
  computeStats(winAccelX, WINDOW_SIZE, mean, stdDev, mn, mx); feats[0]=mean; feats[1]=stdDev; feats[2]=mn; feats[3]=mx;
  computeStats(winAccelY, WINDOW_SIZE, mean, stdDev, mn, mx); feats[4]=mean; feats[5]=stdDev; feats[6]=mn; feats[7]=mx;
  computeStats(winAccelZ, WINDOW_SIZE, mean, stdDev, mn, mx); feats[8]=mean; feats[9]=stdDev; feats[10]=mn; feats[11]=mx;
  computeStats(winGyroX,  WINDOW_SIZE, mean, stdDev, mn, mx); feats[12]=mean; feats[13]=stdDev; feats[14]=mn; feats[15]=mx;
  computeStats(winGyroY,  WINDOW_SIZE, mean, stdDev, mn, mx); feats[16]=mean; feats[17]=stdDev; feats[18]=mn; feats[19]=mx;
  computeStats(winGyroZ,  WINDOW_SIZE, mean, stdDev, mn, mx); feats[20]=mean; feats[21]=stdDev; feats[22]=mn; feats[23]=mx;

  float mag[WINDOW_SIZE];
  for (int i = 0; i < WINDOW_SIZE; i++)
    mag[i] = sqrt(winAccelX[i] * winAccelX[i] + winAccelY[i] * winAccelY[i] + winAccelZ[i] * winAccelZ[i]);
  computeStats(mag, WINDOW_SIZE, mean, stdDev, mn, mx); feats[24] = mean; feats[25] = stdDev;

  // motion_activity: same gyro-magnitude heuristic as before (docs/15: revisit
  // with real baseline data), now averaged over the window instead of one
  // sample -- less noisy, same 0-1 scale.
  float gyroMagSum = 0;
  for (int i = 0; i < WINDOW_SIZE; i++)
    gyroMagSum += sqrt(winGyroX[i] * winGyroX[i] + winGyroY[i] * winGyroY[i] + winGyroZ[i] * winGyroZ[i]);
  float normalized = (gyroMagSum / WINDOW_SIZE) / 250.0; // rough dps scale, not a measured max
  motionOut = normalized < 0 ? 0 : (normalized > 1 ? 1 : normalized);

  return String(postureModel.predictLabel(feats));
}

//==================================================
void loop()
{
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature();

  float motion;
  long irValue;
  bool fingerDetected;
  String posture = capturePostureWindow(motion, irValue, fingerDetected);

  printReadings(temperature, humidity, irValue, fingerDetected, posture);

  if (millis() - lastSendMs >= SEND_INTERVAL_MS)
  {
    lastSendMs = millis();
    sendTelemetry(temperature, humidity, fingerDetected, motion, posture);
  }
}

void printReadings(float temperature, float humidity, long irValue, bool fingerDetected, String posture)
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
  Serial.print("Posture : "); Serial.println(posture);
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

void sendTelemetry(float temperature, float humidity, bool fingerDetected, float motion, String posture)
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

  char payload[512];
  int len = snprintf(payload, sizeof(payload),
    "{\"device_code\":\"%s\",\"captured_at\":\"%s\","
    "\"motion_activity\":%.3f,\"posture\":\"%s\"",
    DEVICE_CODE, capturedAt, motion, posture.c_str());

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
