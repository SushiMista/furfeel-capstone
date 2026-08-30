#include <Wire.h>
#include <DHT.h>
#include <MPU9250_asukiaaa.h>
#include "MAX30105.h"
#include "heartRate.h"
#include "posture_model.h"
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <time.h>

//================ WIFI & CREDENTIALS ====================
const char* WIFI_SSID     = "llalalalaa";
const char* WIFI_PASSWORD = "nyanyanya";
const char* DEVICE_CODE   = "FURFEEL-DEV-0002";
const char* DEVICE_KEY    = "014561cd2c1ab0f56a5e5c3ee0814122a868837f45ec441e";
const char* FUNCTION_URL  = "https://kkbumkjvltlrggfefnkp.supabase.co/functions/v1/telemetry-intake";

// ⏱️ Reduced from 10000 (10s) to 3000 (3s) for fast real-time app updates!
const unsigned long SEND_INTERVAL_MS = 3000;

//================ DHT22 ===================
#define DHTPIN 4
#define DHTTYPE DHT22
DHT dht(DHTPIN, DHTTYPE);

//================ FLEX SENSOR =============
#define FLEX_PIN 34
const int BREATH_THRESHOLD = 1260;
bool readyForNextBreath = true;
int breathCount = 0;
int respiratoryRate = 0;

//================ MPU9250 =================
MPU9250_asukiaaa imu;

//================ POSTURE MODEL ===========
Eloquent::ML::Port::RandomForest postureModel;
const int WINDOW_SIZE = 20;                  // ~1s at 20Hz, matches training
const unsigned long SAMPLE_INTERVAL_MS = 50; // 20Hz
float winAccelX[WINDOW_SIZE], winAccelY[WINDOW_SIZE], winAccelZ[WINDOW_SIZE];
float winGyroX[WINDOW_SIZE], winGyroY[WINDOW_SIZE], winGyroZ[WINDOW_SIZE];
String currentPosture = "unknown";
float currentMotion = 0;

//================ MAX30102 ================
MAX30105 particleSensor;
TwoWire I2C_MAX = TwoWire(1);

//================ HEART RATE ==============
const byte RATE_SIZE = 8;
byte rates[RATE_SIZE];
byte rateSpot = 0;
byte validReadings = 0;
long lastBeat = 0;
float beatsPerMinute = 0;
float beatAvg = 0;
long irValue = 0;
bool fingerDetected = false;

//================ TIMERS ==================
unsigned long lastSendMs = 0;
unsigned long lastPrint = 0;
unsigned long lastDHT = 0;
unsigned long lastRespiration = 0;
float temperature = NAN;
float humidity = NAN;

//================ PROTOTYPES ==============
void connectWifi();
void syncTime();
void updateHeartRate();
void updateRespiration();
void printReadings();
void capturePostureWindow();
void computeStats(float *arr, int n, float &mean, float &stdDev, float &mn, float &mx);
void sendTelemetry();

//================ SETUP ===================
void setup()
{
  Serial.begin(115200);
  delay(500);

  dht.begin();
  pinMode(FLEX_PIN, INPUT);

  Wire.begin(21, 22);
  imu.setWire(&Wire);
  imu.beginAccel();
  imu.beginGyro();

  I2C_MAX.begin(25, 26);
  if (!particleSensor.begin(I2C_MAX))
  {
    Serial.println("⚠️ MAX30102 NOT FOUND on pins 25, 26");
  }
  else
  {
    particleSensor.setup(0x3F, 4, 2, 400, 411, 4096);
    particleSensor.setPulseAmplitudeRed(0x3F);
    particleSensor.setPulseAmplitudeIR(0x3F);
    particleSensor.setPulseAmplitudeGreen(0);
  }

  connectWifi();
  syncTime();

  lastRespiration = millis();
  Serial.println();
  Serial.println("==============================");
  Serial.println(" FurFeel Ready (3s Real-Time)");
  Serial.println("==============================");
}

//================ LOOP ====================
void loop()
{
  // ~1s: samples IMU, keeps HR/respiration alive, runs posture classifier
  capturePostureWindow();

  if (millis() - lastDHT >= 2000)
  {
    lastDHT = millis();
    humidity = dht.readHumidity();
    temperature = dht.readTemperature();
  }

  if (millis() - lastPrint >= 3000)
  {
    lastPrint = millis();
    printReadings();
  }

  if (millis() - lastSendMs >= SEND_INTERVAL_MS)
  {
    lastSendMs = millis();
    sendTelemetry();
  }
}

//===========================================
// POSTURE MODEL
//===========================================
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

void capturePostureWindow()
{
  for (int i = 0; i < WINDOW_SIZE; i++)
  {
    imu.accelUpdate();
    imu.gyroUpdate();
    winAccelX[i] = imu.accelX(); winAccelY[i] = imu.accelY(); winAccelZ[i] = imu.accelZ();
    winGyroX[i] = imu.gyroX();   winGyroY[i] = imu.gyroY();   winGyroZ[i] = imu.gyroZ();

    // Poll heart rate fast during this slot
    unsigned long slotStart = millis();
    while (millis() - slotStart < SAMPLE_INTERVAL_MS)
    {
      updateHeartRate();
      delay(2);
    }
    updateRespiration();
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
    mag[i] = sqrt(winAccelX[i]*winAccelX[i] + winAccelY[i]*winAccelY[i] + winAccelZ[i]*winAccelZ[i]);
  computeStats(mag, WINDOW_SIZE, mean, stdDev, mn, mx); feats[24] = mean; feats[25] = stdDev;

  float gyroMagSum = 0;
  for (int i = 0; i < WINDOW_SIZE; i++)
    gyroMagSum += sqrt(winGyroX[i]*winGyroX[i] + winGyroY[i]*winGyroY[i] + winGyroZ[i]*winGyroZ[i]);
  float normalized = (gyroMagSum / WINDOW_SIZE) / 250.0;
  currentMotion = normalized < 0 ? 0 : (normalized > 1 ? 1 : normalized);
  currentPosture = String(postureModel.predictLabel(feats));
}

//===========================================
// HEART RATE
//===========================================
void updateHeartRate()
{
  irValue = particleSensor.getIR();
  fingerDetected = (irValue > 50000);

  if (!fingerDetected)
  {
    beatsPerMinute = 0;
    beatAvg = 0;
    validReadings = 0;
    rateSpot = 0;
    return;
  }

  if (checkForBeat(irValue))
  {
    long delta = millis() - lastBeat;
    lastBeat = millis();
    beatsPerMinute = 60.0 / (delta / 1000.0);

    if (beatsPerMinute > 35 && beatsPerMinute < 220)
    {
      rates[rateSpot++] = (byte)beatsPerMinute;
      rateSpot %= RATE_SIZE;
      if (validReadings < RATE_SIZE) validReadings++;

      beatAvg = 0;
      for (byte i = 0; i < validReadings; i++)
        beatAvg += rates[i];
      beatAvg /= validReadings;
    }
  }
}

//===========================================
// RESPIRATORY RATE (FLEX SENSOR)
//===========================================
void updateRespiration()
{
  int rawValue = analogRead(FLEX_PIN);

  if (rawValue >= BREATH_THRESHOLD && readyForNextBreath)
  {
    breathCount++;
    readyForNextBreath = false;
  }
  else if (rawValue < (BREATH_THRESHOLD - 40))
  {
    readyForNextBreath = true;
  }

  // Calculate breaths per minute every 6 seconds
  if (millis() - lastRespiration >= 6000)
  {
    respiratoryRate = breathCount * 10; // scale 6s to 60s
    breathCount = 0;
    lastRespiration = millis();
  }
}

//===========================================
// WIFI & TIME
//===========================================
void connectWifi()
{
  Serial.print("Connecting WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED)
  {
    delay(400);
    Serial.print(".");
  }
  Serial.println();
  Serial.print("Connected : ");
  Serial.println(WiFi.localIP());
}

void syncTime()
{
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  struct tm timeinfo;
  while (!getLocalTime(&timeinfo))
  {
    delay(400);
    Serial.print(".");
  }
  Serial.println("\nTime Synced (UTC)");
}

//===========================================
// SERIAL MONITOR
//===========================================
void printReadings()
{
  Serial.println();
  Serial.println("======================================");
  Serial.print("Temperature      : "); Serial.println(temperature);
  Serial.print("Humidity         : "); Serial.println(humidity);
  Serial.print("Heart Rate       : "); Serial.print(beatAvg); Serial.println(" BPM");
  Serial.print("Respiratory Rate : "); Serial.print(respiratoryRate); Serial.println(" BPM");
  Serial.print("Flex Value       : "); Serial.println(analogRead(FLEX_PIN));
  Serial.print("Motion           : "); Serial.println(currentMotion, 3);
  Serial.print("Posture          : "); Serial.println(currentPosture);
  Serial.println("======================================");
}

//===========================================
// SUPABASE TELEMETRY TRANSMISSION
//===========================================
void sendTelemetry()
{
  if (WiFi.status() != WL_CONNECTED)
  {
    connectWifi();
    return;
  }

  struct tm timeinfo;
  if (!getLocalTime(&timeinfo))
    return;

  char capturedAt[30];
  strftime(capturedAt, sizeof(capturedAt), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);

  char payload[700];
  int len = snprintf(
    payload, sizeof(payload),
    "{\"device_code\":\"%s\","
    "\"captured_at\":\"%s\","
    "\"motion_activity\":%.3f,"
    "\"posture\":\"%s\"",
    DEVICE_CODE, capturedAt, currentMotion, currentPosture.c_str()
  );

  if (fingerDetected && beatAvg > 0)
  {
    len += snprintf(payload + len, sizeof(payload) - len, ",\"heart_rate_bpm\":%.0f", beatAvg);
  }
  if (respiratoryRate > 0)
  {
    len += snprintf(payload + len, sizeof(payload) - len, ",\"respiratory_rate_bpm\":%d", respiratoryRate);
  }
  if (!isnan(temperature))
  {
    len += snprintf(payload + len, sizeof(payload) - len, ",\"ambient_temperature_c\":%.1f", temperature);
  }
  if (!isnan(humidity))
  {
    len += snprintf(payload + len, sizeof(payload) - len, ",\"humidity_percent\":%.1f", humidity);
  }
  snprintf(payload + len, sizeof(payload) - len, "}");

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient https;
  https.begin(client, FUNCTION_URL);
  https.addHeader("Content-Type", "application/json");
  https.addHeader("x-device-key", DEVICE_KEY);

  int code = https.POST((uint8_t*)payload, strlen(payload));
  Serial.println();
  Serial.println("========== SUPABASE ==========");
  Serial.print("HTTP Status : ");
  Serial.println(code);
  Serial.print("Payload     : ");
  Serial.println(payload);
  Serial.println("==============================");
  https.end();
}
