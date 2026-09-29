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
#include <Preferences.h>

//================ BLE (APPROACH 3: DIRECT PUSH) ======
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define SERVICE_UUID           "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_CREDENTIALS_UUID  "a3c87500-8ed3-4bdf-8a39-a01bebede295"
#define CHAR_STATUS_UUID       "cba1d466-344c-4be3-ab3f-189f80dd7518"

Preferences preferences;
BLEServer* pServer = NULL;
BLECharacteristic* pCredsCharacteristic = NULL;
BLECharacteristic* pStatusCharacteristic = NULL;

bool bleActive = false;
bool shouldConnectWifi = false;
String pendingSSID = "";
String pendingPass = "";

//================ HARDWARE & CREDENTIALS =============
const char* DEVICE_CODE = "FURFEEL-DEV-0002";
const char* DEVICE_KEY  = "014561cd2c1ab0f56a5e5c3ee0814122a868837f45ec441e";
const char* FUNCTION_URL = "https://kkbumkjvltlrggfefnkp.supabase.co/functions/v1/telemetry-intake";

const unsigned long SEND_INTERVAL_MS = 2000;

String wifiSSID = "";
String wifiPassword = "";

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
const int WINDOW_SIZE = 20;                  // ~1s at 20Hz
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
void startBLE();
void stopBLE();
void loadSavedWifi();
void saveWifiCredentials(String ssid, String pass);
bool connectWifi();
void syncTime();
void updateHeartRate();
void updateRespiration();
void capturePostureWindow();
void printReadings();
void computeStats(float *arr, int n, float &mean, float &stdDev, float &mn, float &mx);
void sendTelemetry();

//================ BLE CALLBACKS ============
class CredsCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        String value = pCharacteristic->getValue().c_str();
        // Format: SSID;PASSWORD
        int delim = value.indexOf(';');
        if (delim != -1) {
            pendingSSID = value.substring(0, delim);
            pendingPass = value.substring(delim + 1);
            shouldConnectWifi = true;
            Serial.println("📥 Received Wi-Fi credentials from phone:");
            Serial.println("   SSID: " + pendingSSID);
        }
    }
};

//================ SETUP ===================
void setup()
{
    Serial.begin(115200);
    delay(1000);

    dht.begin();
    pinMode(FLEX_PIN, INPUT);

    Wire.begin(21, 22);
    imu.setWire(&Wire);
    imu.beginAccel();
    imu.beginGyro();

    I2C_MAX.begin(25, 26);
    if (!particleSensor.begin(I2C_MAX)) {
        Serial.println("⚠️ MAX30102 NOT FOUND on pins 25, 26");
    } else {
        particleSensor.setup(0x3F, 4, 2, 400, 411, 4096);
        particleSensor.setPulseAmplitudeRed(0x3F);
        particleSensor.setPulseAmplitudeIR(0x3F);
    }

    // 1. Check if we have saved Wi-Fi in Flash
    loadSavedWifi();

    // 2. Try connecting to saved Wi-Fi
    if (wifiSSID.length() > 0 && connectWifi()) {
        syncTime();
    } else {
        // 3. If no Wi-Fi or connection failed, open Bluetooth for Phone Setup
        Serial.println("📡 Starting Bluetooth so phone can push Wi-Fi credentials...");
        startBLE();
    }

    lastRespiration = millis();
    Serial.println();
    Serial.println("======================================");
    Serial.println(" FurFeel Smart Collar Ready");
    Serial.println("======================================");
}

//================ LOOP ====================
void loop()
{
    // Handle Wi-Fi credentials received from phone app
    if (shouldConnectWifi) {
        shouldConnectWifi = false;
        wifiSSID = pendingSSID;
        wifiPassword = pendingPass;
        saveWifiCredentials(wifiSSID, wifiPassword);

        delay(600);

        // Turn OFF Bluetooth to prevent radio conflict
        stopBLE();

        Serial.println("🌐 Connecting to received Wi-Fi...");
        if (connectWifi()) {
            syncTime();
        } else {
            Serial.println("⚠️ Could not connect to Wi-Fi. Restarting Bluetooth...");
            startBLE();
        }
    }

    capturePostureWindow();

    if (millis() - lastDHT >= 2000) {
        lastDHT = millis();
        humidity = dht.readHumidity();
        temperature = dht.readTemperature();
    }

    if (millis() - lastPrint >= 5000) {
        lastPrint = millis();
        printReadings();
    }

    if (millis() - lastSendMs >= SEND_INTERVAL_MS) {
        lastSendMs = millis();
        sendTelemetry();
    }
}

//================ BLE FUNCTIONS ============
void startBLE()
{
    if (bleActive) return;

    String devName = "FurFeel-" + String(DEVICE_CODE);
    BLEDevice::init(devName.c_str());
    pServer = BLEDevice::createServer();

    BLEService *pService = pServer->createService(SERVICE_UUID);

    pCredsCharacteristic = pService->createCharacteristic(
        CHAR_CREDENTIALS_UUID,
        BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
    );
    pCredsCharacteristic->setCallbacks(new CredsCallbacks());

    pStatusCharacteristic = pService->createCharacteristic(
        CHAR_STATUS_UUID,
        BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
    );
    pStatusCharacteristic->addDescriptor(new BLE2902());

    pService->start();

    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);
    BLEDevice::startAdvertising();

    bleActive = true;
    Serial.println("📶 Bluetooth ready for setup: " + devName);
}

void stopBLE()
{
    if (!bleActive) return;
    BLEDevice::deinit(true);
    bleActive = false;
    pServer = NULL;
    pCredsCharacteristic = NULL;
    pStatusCharacteristic = NULL;
    Serial.println("📴 Bluetooth turned OFF to prioritize Wi-Fi & telemetry.");
}

//================ FLASH STORAGE (NVS) ======
void loadSavedWifi()
{
    preferences.begin("furfeel-wifi", true); // read-only mode
    wifiSSID = preferences.getString("ssid", "");
    wifiPassword = preferences.getString("pass", "");
    preferences.end();

    if (wifiSSID.length() > 0) {
        Serial.println("💾 Loaded saved Wi-Fi from Flash: " + wifiSSID);
    } else {
        Serial.println("💾 No Wi-Fi credentials in Flash.");
    }
}

void saveWifiCredentials(String ssid, String pass)
{
    preferences.begin("furfeel-wifi", false); // read-write mode
    preferences.putString("ssid", ssid);
    preferences.putString("pass", pass);
    preferences.end();
    Serial.println("💾 Saved new Wi-Fi credentials to Flash!");
}

//================ WIFI & TIME ==============
bool connectWifi()
{
    Serial.print("Connecting to Wi-Fi: " + wifiSSID);
    WiFi.mode(WIFI_STA);
    WiFi.begin(wifiSSID.c_str(), wifiPassword.c_str());

    unsigned long startAttempt = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - startAttempt < 12000) {
        delay(500);
        Serial.print(".");
    }

    if (WiFi.status() == WL_CONNECTED) {
        Serial.println();
        Serial.print("✅ Connected! IP: ");
        Serial.println(WiFi.localIP());
        return true;
    } else {
        Serial.println("\n⚠️ Failed to connect to Wi-Fi.");
        return false;
    }
}

void syncTime()
{
    configTime(0, 0, "pool.ntp.org", "time.nist.gov");
    struct tm timeinfo;
    unsigned long start = millis();
    while (!getLocalTime(&timeinfo) && millis() - start < 6000) {
        delay(500);
        Serial.print(".");
    }
    Serial.println("\n🕒 Time Synced (UTC)");
}

//================ SENSORS & POSTURE ========
void computeStats(float *arr, int n, float &mean, float &stdDev, float &mn, float &mx)
{
    float sum = 0, sumSq = 0;
    mn = arr[0];
    mx = arr[0];
    for (int i = 0; i < n; i++) {
        sum += arr[i];
        if (arr[i] < mn) mn = arr[i];
        if (arr[i] > mx) mx = arr[i];
    }
    mean = sum / n;
    for (int i = 0; i < n; i++) {
        float d = arr[i] - mean;
        sumSq += d * d;
    }
    stdDev = sqrt(sumSq / n);
}

void capturePostureWindow()
{
    for (int i = 0; i < WINDOW_SIZE; i++) {
        imu.accelUpdate();
        imu.gyroUpdate();
        winAccelX[i] = imu.accelX(); winAccelY[i] = imu.accelY(); winAccelZ[i] = imu.accelZ();
        winGyroX[i] = imu.gyroX();   winGyroY[i] = imu.gyroY();   winGyroZ[i] = imu.gyroZ();

        unsigned long slotStart = millis();
        while (millis() - slotStart < SAMPLE_INTERVAL_MS) {
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
    computeStats(mag, WINDOW_SIZE, mean, stdDev, mn, mx); feats[24]=mean; feats[25]=stdDev;

    float gyroMagSum = 0;
    for (int i = 0; i < WINDOW_SIZE; i++)
        gyroMagSum += sqrt(winGyroX[i]*winGyroX[i] + winGyroY[i]*winGyroY[i] + winGyroZ[i]*winGyroZ[i]);
    float normalized = (gyroMagSum / WINDOW_SIZE) / 250.0;
    currentMotion = normalized < 0 ? 0 : (normalized > 1 ? 1 : normalized);

    currentPosture = String(postureModel.predictLabel(feats));
}

void updateHeartRate()
{
    irValue = particleSensor.getIR();
    fingerDetected = (irValue > 50000);

    if (!fingerDetected) {
        beatsPerMinute = 0;
        beatAvg = 0;
        validReadings = 0;
        rateSpot = 0;
        return;
    }

    if (checkForBeat(irValue)) {
        long delta = millis() - lastBeat;
        lastBeat = millis();
        if (delta > 0) {
            beatsPerMinute = 60.0 / (delta / 1000.0);
        }

        if (beatsPerMinute > 35 && beatsPerMinute < 220) {
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

void updateRespiration()
{
    long total = 0;
    for (int i = 0; i < 5; i++) {
        total += analogRead(FLEX_PIN);
        delay(2);
    }
    int rawValue = total / 5;

    if (rawValue >= BREATH_THRESHOLD && readyForNextBreath) {
        breathCount++;
        readyForNextBreath = false;
    }
    if (rawValue < BREATH_THRESHOLD) {
        readyForNextBreath = true;
    }

    if (millis() - lastRespiration >= 10000) {
        respiratoryRate = breathCount * 6;
        breathCount = 0;
        lastRespiration = millis();
    }
}

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
    Serial.print("Wi-Fi Status     : "); Serial.println(WiFi.status() == WL_CONNECTED ? "Connected" : "Disconnected");
    Serial.println("======================================");
}

//================ SUPABASE TRANSMISSION ====
void sendTelemetry()
{
    if (WiFi.status() != WL_CONNECTED)
        return;

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

    if (fingerDetected && beatAvg > 0) {
        len += snprintf(payload + len, sizeof(payload) - len, ",\"heart_rate_bpm\":%.0f", beatAvg);
    }
    if (respiratoryRate > 0) {
        len += snprintf(payload + len, sizeof(payload) - len, ",\"respiratory_rate_bpm\":%d", respiratoryRate);
    }
    if (!isnan(temperature)) {
        len += snprintf(payload + len, sizeof(payload) - len, ",\"ambient_temperature_c\":%.1f", temperature);
    }
    if (!isnan(humidity)) {
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
    Serial.print("Response    : ");
    Serial.println(https.getString());
    Serial.println("==============================");
    https.end();
}
