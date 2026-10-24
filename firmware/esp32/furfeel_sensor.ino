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
#define CHAR_CONTROL_UUID      "f58dc8aa-6f17-4ef2-96bc-b359187d0021"
#define CHAR_STATUS_UUID       "cba1d466-344c-4be3-ab3f-189f80dd7518"

Preferences preferences;
BLEServer* pServer = NULL;
BLECharacteristic* pCredsCharacteristic = NULL;
BLECharacteristic* pStatusCharacteristic = NULL;

volatile bool scanRequested = false;
unsigned long bleCloseAt = 0;
int networkCount = 0;
bool bleActive = false;
volatile bool shouldConnectWifi = false;
String pendingSSID = "";
String pendingPass = "";

#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_MAX1704X.h>

//================ WIFI ====================

String wifiSSID = "";
String wifiPassword = "";

const char* DEVICE_CODE = "FURFEEL-DEV-0002";
const char* DEVICE_KEY = "YOUR_DEVICE_KEY";

const char* FUNCTION_URL =
    "https://kkbumkjvltlrggfefnkp.supabase.co/functions/v1/telemetry-intake";

const unsigned long SEND_INTERVAL_MS = 2000;

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

const int WINDOW_SIZE = 20;
const unsigned long SAMPLE_INTERVAL_MS = 50;

float winAccelX[WINDOW_SIZE];
float winAccelY[WINDOW_SIZE];
float winAccelZ[WINDOW_SIZE];

float winGyroX[WINDOW_SIZE];
float winGyroY[WINDOW_SIZE];
float winGyroZ[WINDOW_SIZE];

String currentPosture = "unknown";
float currentMotion = 0;

//================ MAX30102 ================

MAX30105 particleSensor;
TwoWire I2C_MAX = TwoWire(1);

bool max30102Ready = false;

//================ OLED + BATTERY ==========

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_ADDR 0x3C

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);
Adafruit_MAX17048 maxlipo;

bool oledReady = false;
bool batteryGaugeReady = false;

float batteryVoltage = NAN;
float batteryPercent = NAN;

unsigned long lastDisplayMs = 0;

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
void handleWifiSetup();
void syncTime();
void updateHeartRate();
void updateRespiration();
void printReadings();
void capturePostureWindow();
void updateBatteryAndDisplay();
void sendTelemetry();

void computeStats(
    float *arr,
    int n,
    float &mean,
    float &stdDev,
    float &mn,
    float &mx
);

// Setup commands are handled in loop; never scan or join Wi-Fi in a BLE callback.
void setupStatus(String value) {
    if (pStatusCharacteristic) pStatusCharacteristic->setValue(value.c_str());
}
String hexText(String value) {
    const char* digits = "0123456789abcdef";
    String encoded;
    for (unsigned int i = 0; i < value.length(); i++) {
        uint8_t c = value[i]; encoded += digits[c >> 4]; encoded += digits[c & 15];
    }
    return encoded;
}
int hexDigit(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    return -1;
}
bool decodeText(String hex, String &decoded) {
    decoded = "";
    if (hex.length() % 2) return false;
    for (unsigned int i = 0; i < hex.length(); i += 2) {
        int a = hexDigit(hex[i]), b = hexDigit(hex[i + 1]);
        if (a < 0 || b < 0 || (a == 0 && b == 0)) return false;
        decoded += char((a << 4) | b);
    }
    return true;
}
class SetupServerCallbacks: public BLEServerCallbacks {
    void onDisconnect(BLEServer*) {
        if (WiFi.status() != WL_CONNECTED) BLEDevice::startAdvertising();
    }
};
class ControlCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *characteristic) {
        String command = characteristic->getValue().c_str();
        if (shouldConnectWifi || scanRequested) { setupStatus("ERROR:Harness is busy. Retry shortly."); return; }
        if (command == "SCAN") {
            Serial.println("[SETUP] Phone requested Wi-Fi scan");
            bleCloseAt = 0;
            setupStatus("SCANNING"); scanRequested = true;
        } else if (command.startsWith("NETWORK:")) {
            String indexText = command.substring(8);
            if (indexText.length() == 0) { setupStatus("ERROR:Invalid network index"); return; }
            for (unsigned int i = 0; i < indexText.length(); i++) {
                if (!isDigit(indexText[i])) { setupStatus("ERROR:Invalid network index"); return; }
            }
            int i = indexText.toInt();
            if (i < 0 || i >= networkCount) { setupStatus("ERROR:Refresh the Wi-Fi list"); return; }
            setupStatus("N:" + String(i) + ":" + String(WiFi.RSSI(i)) + ":" +
                String(WiFi.encryptionType(i) == WIFI_AUTH_OPEN ? 0 : 1) + ":" + hexText(WiFi.SSID(i)));
        } else { setupStatus("ERROR:Unknown setup command"); }
    }
};
class CredsCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *characteristic) {
        String value = characteristic->getValue().c_str();
        if (shouldConnectWifi || scanRequested) { setupStatus("ERROR:Harness is busy. Retry shortly."); return; }
        String ssid, password;
        if (value.startsWith("C:")) {
            int delim = value.indexOf(':', 2);
            if (delim < 0 || !decodeText(value.substring(2, delim), ssid) ||
                !decodeText(value.substring(delim + 1), password)) {
                setupStatus("ERROR:Invalid Wi-Fi credentials"); return;
            }
        } else {
            // Compatibility with the previous mobile app.
            int delim = value.indexOf(';');
            if (delim < 0) { setupStatus("ERROR:Invalid Wi-Fi credentials"); return; }
            ssid = value.substring(0, delim); password = value.substring(delim + 1);
        }
        if (ssid.length() == 0 || ssid.length() > 32 || password.length() > 63 ||
            (password.length() > 0 && password.length() < 8)) {
            setupStatus("ERROR:Invalid Wi-Fi name or password length"); return;
        }
        bleCloseAt = 0;
        pendingSSID = ssid; pendingPass = password;
        setupStatus("CONNECTING"); shouldConnectWifi = true;
    }
};

//================ SETUP ===================

void setup() {
    Serial.begin(115200);
    WiFi.persistent(false);
    delay(1000);

    Serial.println("Starting FurFeel...");

    dht.begin();
    pinMode(FLEX_PIN, INPUT);

    // Main I2C bus: OLED, MAX17048, MPU9250
    Wire.begin(21, 22);

    oledReady = display.begin(
        SSD1306_SWITCHCAPVCC,
        OLED_ADDR
    );

    if (oledReady) {
        display.clearDisplay();
        display.setTextColor(SSD1306_WHITE);
        display.setTextSize(1);
        display.setCursor(0, 0);
        display.println("FurFeel Starting...");
        display.display();
    } else {
        Serial.println("OLED NOT FOUND");
    }

    // Initialize MAX17048 battery monitor
    batteryGaugeReady = maxlipo.begin();

    if (batteryGaugeReady) {
        Serial.println("MAX17048 detected");
    } else {
        Serial.println("MAX17048 NOT FOUND");
    }

    // Initialize MPU9250
    imu.setWire(&Wire);
    imu.beginAccel();
    imu.beginGyro();

    // Initialize MAX30102 on separate I2C bus
    I2C_MAX.begin(25, 26);

    max30102Ready = particleSensor.begin(I2C_MAX);

    if (max30102Ready) {
        particleSensor.setup(0x3F, 4, 2, 400, 411, 4096);
        particleSensor.setPulseAmplitudeRed(0x3F);
        particleSensor.setPulseAmplitudeIR(0x3F);
        particleSensor.setPulseAmplitudeGreen(0);

        Serial.println("MAX30102 detected");
    } else {
        Serial.println("MAX30102 NOT FOUND");
        Serial.println("Continuing without heart-rate readings.");
    }

    // Use saved credentials; otherwise advertise setup for the mobile app.
    loadSavedWifi();
    if (wifiSSID.length() > 0 && connectWifi()) {
        syncTime();
    } else {
        startBLE();
    }

    lastRespiration = millis();

    Serial.println("FurFeel Ready");

    if (oledReady) {
        display.clearDisplay();
        display.setTextSize(1);
        display.setCursor(0, 0);
        display.println("FurFeel Ready");
        display.println("Reading sensors...");
        display.display();
    }
}

//================ LOOP ====================

void loop() {
    handleWifiSetup();
    capturePostureWindow();

    // Read temperature and humidity every 2 seconds
    if (millis() - lastDHT >= 2000) {
        lastDHT = millis();

        humidity = dht.readHumidity();
        temperature = dht.readTemperature();
    }

    // Update OLED and battery every 2 seconds
    if (millis() - lastDisplayMs >= 2000) {
        lastDisplayMs = millis();
        updateBatteryAndDisplay();
    }

    // Print sensor readings every 5 seconds
    if (millis() - lastPrint >= 5000) {
        lastPrint = millis();
        printReadings();
    }

    // Attempt telemetry upload every 2 seconds
    if (millis() - lastSendMs >= SEND_INTERVAL_MS) {
        lastSendMs = millis();
        sendTelemetry();
    }
}

//================ STATISTICS ==============

void computeStats(
    float *arr,
    int n,
    float &mean,
    float &stdDev,
    float &mn,
    float &mx
) {
    float sum = 0;
    float sumSq = 0;

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

//================ POSTURE MODEL ===========

void capturePostureWindow() {
    for (int i = 0; i < WINDOW_SIZE; i++) {
        imu.accelUpdate();
        imu.gyroUpdate();

        winAccelX[i] = imu.accelX();
        winAccelY[i] = imu.accelY();
        winAccelZ[i] = imu.accelZ();

        winGyroX[i] = imu.gyroX();
        winGyroY[i] = imu.gyroY();
        winGyroZ[i] = imu.gyroZ();

        unsigned long slotStart = millis();

        while (millis() - slotStart < SAMPLE_INTERVAL_MS) {
            updateHeartRate();
            delay(2);
        }

        updateRespiration();
    }

    float feats[26];
    float mean, stdDev, mn, mx;

    computeStats(winAccelX, WINDOW_SIZE, mean, stdDev, mn, mx);
    feats[0] = mean;
    feats[1] = stdDev;
    feats[2] = mn;
    feats[3] = mx;

    computeStats(winAccelY, WINDOW_SIZE, mean, stdDev, mn, mx);
    feats[4] = mean;
    feats[5] = stdDev;
    feats[6] = mn;
    feats[7] = mx;

    computeStats(winAccelZ, WINDOW_SIZE, mean, stdDev, mn, mx);
    feats[8] = mean;
    feats[9] = stdDev;
    feats[10] = mn;
    feats[11] = mx;

    computeStats(winGyroX, WINDOW_SIZE, mean, stdDev, mn, mx);
    feats[12] = mean;
    feats[13] = stdDev;
    feats[14] = mn;
    feats[15] = mx;

    computeStats(winGyroY, WINDOW_SIZE, mean, stdDev, mn, mx);
    feats[16] = mean;
    feats[17] = stdDev;
    feats[18] = mn;
    feats[19] = mx;

    computeStats(winGyroZ, WINDOW_SIZE, mean, stdDev, mn, mx);
    feats[20] = mean;
    feats[21] = stdDev;
    feats[22] = mn;
    feats[23] = mx;

    float mag[WINDOW_SIZE];

    for (int i = 0; i < WINDOW_SIZE; i++) {
        mag[i] = sqrt(
            winAccelX[i] * winAccelX[i] +
            winAccelY[i] * winAccelY[i] +
            winAccelZ[i] * winAccelZ[i]
        );
    }

    computeStats(mag, WINDOW_SIZE, mean, stdDev, mn, mx);
    feats[24] = mean;
    feats[25] = stdDev;

    float gyroMagSum = 0;

    for (int i = 0; i < WINDOW_SIZE; i++) {
        gyroMagSum += sqrt(
            winGyroX[i] * winGyroX[i] +
            winGyroY[i] * winGyroY[i] +
            winGyroZ[i] * winGyroZ[i]
        );
    }

    float normalized = (gyroMagSum / WINDOW_SIZE) / 250.0;

    currentMotion = normalized < 0 ? 0 :
                    (normalized > 1 ? 1 : normalized);

    currentPosture = String(postureModel.predictLabel(feats));
}

//================ HEART RATE ==============

void updateHeartRate() {
    if (!max30102Ready) {
        fingerDetected = false;
        beatsPerMinute = 0;
        beatAvg = 0;
        return;
    }

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

            if (beatsPerMinute > 35 && beatsPerMinute < 220) {
                rates[rateSpot++] = (byte)beatsPerMinute;
                rateSpot %= RATE_SIZE;

                if (validReadings < RATE_SIZE) {
                    validReadings++;
                }

                beatAvg = 0;

                for (byte i = 0; i < validReadings; i++) {
                    beatAvg += rates[i];
                }

                beatAvg /= validReadings;
            }
        }
    }
}

//================ RESPIRATORY RATE =========

void updateRespiration() {
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

//================ WIFI =====================

void handleWifiSetup() {
    if (scanRequested) {
        WiFi.mode(WIFI_STA);
        // Stop retries to an unavailable saved router before starting a scan.
        if (WiFi.status() != WL_CONNECTED) {
            WiFi.setAutoReconnect(false);
            WiFi.disconnect(false, false);
            delay(200);
        }
        WiFi.scanDelete();
        Serial.println("[SETUP] Scanning nearby Wi-Fi networks...");
        networkCount = WiFi.scanNetworks(false, false);
        Serial.printf("[SETUP] Wi-Fi scan result: %d\n", networkCount);
        // Release the busy guard before publishing results to the phone.
        scanRequested = false;
        if (networkCount < 0) {
            int errorCode = networkCount;
            networkCount = 0;
            setupStatus("ERROR:Wi-Fi scan failed (" + String(errorCode) + "). Refresh to retry.");
        } else {
            for (int i = 0; i < networkCount; i++) {
                Serial.printf("[SETUP] Network %d: %s (channel %d, RSSI %d)\n",
                    i, WiFi.SSID(i).c_str(), WiFi.channel(i), WiFi.RSSI(i));
            }
            setupStatus("SCAN_DONE:" + String(networkCount));
        }
    }
    if (shouldConnectWifi) {
        wifiSSID = pendingSSID;
        wifiPassword = pendingPass;
        // Keep BLE alive until the phone reads the actual connection result.
        if (connectWifi()) {
            saveWifiCredentials(wifiSSID, wifiPassword);
            setupStatus("CONNECTED");
            bleCloseAt = millis() + 30000;
            syncTime();
        } else {
            WiFi.disconnect();
            setupStatus("ERROR:Could not join Wi-Fi. Check the password and signal, then retry.");
        }
        pendingPass = "";
        shouldConnectWifi = false;
    }
    if (bleCloseAt && WiFi.status() == WL_CONNECTED && (long)(millis() - bleCloseAt) >= 0) {
        bleCloseAt = 0; stopBLE();
    }
    if (!bleActive && WiFi.status() != WL_CONNECTED) startBLE();

}

//================ BLE FUNCTIONS ============
void startBLE()
{
    if (bleActive) return;

    String devName = String(DEVICE_CODE);
    BLEDevice::init(devName.c_str());
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new SetupServerCallbacks());

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

    BLECharacteristic *control = pService->createCharacteristic(
        CHAR_CONTROL_UUID, BLECharacteristic::PROPERTY_WRITE);
    control->setCallbacks(new ControlCallbacks());
    setupStatus("READY");
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
    BLEDevice::deinit(false); // Keep BLE memory available for later setup after Wi-Fi loss.
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
    WiFi.setAutoReconnect(false);
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
        WiFi.setAutoReconnect(true);
        return true;
    } else {
        WiFi.disconnect(false, false);
        Serial.println("\n⚠️ Failed to connect to Wi-Fi.");
        return false;
    }
}

//================ TIME SYNC ================

void syncTime() {
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("Time sync skipped: Wi-Fi unavailable.");
        return;
    }

    configTime(0, 0, "pool.ntp.org", "time.nist.gov");

    struct tm timeinfo;
    unsigned long started = millis();

    while (
        !getLocalTime(&timeinfo, 10) &&
        millis() - started < 10000
    ) {
        delay(500);
        Serial.print(".");
    }

    if (getLocalTime(&timeinfo, 10)) {
        Serial.println("\nTime synced.");
    } else {
        Serial.println("\nTime sync failed; continuing locally.");
    }
}

//================ SERIAL MONITOR ============

void printReadings() {
    Serial.println();
    Serial.println("======================================");

    Serial.print("Temperature: ");
    if (isnan(temperature)) Serial.println("Unavailable");
    else {
        Serial.print(temperature, 1);
        Serial.println(" C");
    }

    Serial.print("Humidity: ");
    if (isnan(humidity)) Serial.println("Unavailable");
    else {
        Serial.print(humidity, 1);
        Serial.println(" %");
    }

    Serial.print("Heart Rate: ");
    if (beatAvg > 0) {
        Serial.print(beatAvg, 0);
        Serial.println(" BPM");
    } else {
        Serial.println("Unavailable");
    }

    Serial.print("Respiratory Rate: ");
    Serial.print(respiratoryRate);
    Serial.println(" breaths/min");

    Serial.print("Flex Value: ");
    Serial.println(analogRead(FLEX_PIN));

    Serial.print("Motion: ");
    Serial.println(currentMotion, 3);

    Serial.print("Posture: ");
    Serial.println(currentPosture);

    Serial.print("Battery Percentage: ");
    if (batteryGaugeReady && !isnan(batteryPercent)) {
        Serial.print(batteryPercent, 0);
        Serial.println(" %");
    } else {
        Serial.println("Unavailable");
    }

    Serial.println("======================================");
}

//================ OLED + MAX17048 ===========

void updateBatteryAndDisplay() {
    if (batteryGaugeReady) {
        batteryVoltage = maxlipo.cellVoltage();
        batteryPercent = maxlipo.cellPercent();
    }

    if (!oledReady) return;

    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    display.setTextSize(1);

    // Row 1: Title
    display.setCursor(0, 0);
    display.println("FurFeel Monitor");

    // Row 2: Temperature and humidity
    display.setCursor(0, 9);
    display.print("Temp:");
    if (isnan(temperature)) display.print("--");
    else {
        display.print(temperature, 1);
        display.print("C");
    }

    display.print(" Hum:");
    if (isnan(humidity)) display.print("--");
    else {
        display.print(humidity, 0);
        display.print("%");
    }

    // Row 3: Heart rate
    display.setCursor(0, 18);
    display.print("Heart Rate:");
    if (beatAvg > 0) {
        display.print((int)beatAvg);
        display.print(" BPM");
    } else {
        display.print("-- BPM");
    }

    // Row 4: Respiratory rate
    display.setCursor(0, 27);
    display.print("Resp Rate:");
    display.print(respiratoryRate);
    display.print("/min");

    // Row 5: Posture
    display.setCursor(0, 36);
    display.print("Posture:");
    display.print(currentPosture);

    // Row 6: Motion
    display.setCursor(0, 45);
    display.print("Motion:");
    display.print(currentMotion, 2);

    // Row 7: Battery percentage only
    display.setCursor(0, 54);
    display.print("Battery:");
    if (batteryGaugeReady && !isnan(batteryPercent)) {
        display.print(batteryPercent, 0);
        display.print("%");
    } else {
        display.print("--%");
    }

    display.display();
}

//================ SUPABASE TELEMETRY ========

void sendTelemetry() {
    if (WiFi.status() != WL_CONNECTED) {
        return;
    }

    struct tm timeinfo;

    if (!getLocalTime(&timeinfo, 10)) {
        return;
    }

    char capturedAt[30];

    strftime(
        capturedAt,
        sizeof(capturedAt),
        "%Y-%m-%dT%H:%M:%SZ",
        &timeinfo
    );

    char payload[700];

    int len = snprintf(
        payload,
        sizeof(payload),
        "{\"device_code\":\"%s\","
        "\"captured_at\":\"%s\","
        "\"motion_activity\":%.3f,"
        "\"posture\":\"%s\"",
        DEVICE_CODE,
        capturedAt,
        currentMotion,
        currentPosture.c_str()
    );

    if (len < 0 || len >= (int)sizeof(payload)) {
        Serial.println("Telemetry payload creation failed.");
        return;
    }

    if (fingerDetected && beatAvg > 0) {
        len += snprintf(
            payload + len,
            sizeof(payload) - len,
            ",\"heart_rate_bpm\":%.0f",
            beatAvg
        );
    }

    if (respiratoryRate > 0) {
        len += snprintf(
            payload + len,
            sizeof(payload) - len,
            ",\"respiratory_rate_bpm\":%d",
            respiratoryRate
        );
    }

    if (!isnan(temperature)) {
        len += snprintf(
            payload + len,
            sizeof(payload) - len,
            ",\"ambient_temperature_c\":%.1f",
            temperature
        );
    }

    if (!isnan(humidity)) {
        len += snprintf(
            payload + len,
            sizeof(payload) - len,
            ",\"humidity_percent\":%.1f",
            humidity
        );
    }

    if (len < 0 || len >= (int)sizeof(payload)) {
        Serial.println("Telemetry payload too large.");
        return;
    }

    snprintf(
        payload + len,
        sizeof(payload) - len,
        "}"
    );

    WiFiClientSecure client;
    client.setInsecure();

    HTTPClient https;

    if (!https.begin(client, FUNCTION_URL)) {
        Serial.println("Could not start HTTPS connection.");
        return;
    }

    https.addHeader("Content-Type", "application/json");
    https.addHeader("x-device-key", DEVICE_KEY);

    int code = https.POST(
        (uint8_t*)payload,
        strlen(payload)
    );

    Serial.println();
    Serial.println("========== SUPABASE ==========");
    Serial.print("HTTP: ");
    Serial.println(code);
    Serial.println(https.getString());
    Serial.println("==============================");

    https.end();
}
