# Harness Wi-Fi setup verification

## Arduino upload

Create a separate sketch folder named `furfeel_sensor`, containing only
`furfeel_sensor.ino` and the matching `posture_model.h`. Do not include
`imu_logger.ino`: Arduino compiles all `.ino` tabs in a sketch together.
Set `DEVICE_KEY` to the provisioned key for `DEVICE_CODE` before uploading;
the checked-in sketch deliberately contains a placeholder. Wi-Fi credentials
are entered in the phone app and saved in NVS only after a successful join.

The sketch preserves the supplied OLED (SSD1306), MAX17048 battery monitor,
optional MAX30102, MPU9250, DHT22, flex sensor and posture feature extraction.
Install their libraries in Arduino IDE alongside the ESP32 board package.
BLE/Preferences/WiFi/HTTPClient are supplied by that board package.

At first setup, Serial Monitor (115200 baud) reports Bluetooth ready with the
name `FURFEEL-DEV-0002`. On restart, saved working Wi-Fi is tried first. To
change networks while connected, make the old network unavailable so BLE setup
reopens. After a successful app setup, BLE closes after 30 seconds.

## Checks

Flash firmware/esp32/furfeel_sensor.ino and install the updated Flutter app together. Android/iOS Bluetooth hardware is required; web setup is unsupported. The normal flow is Settings → Harness & Hardware → Connect Harness to Home Wi-Fi.

Acceptance checklist:
- With no usable saved Wi-Fi, the harness advertises its FurFeel BLE service.
- Multiple harnesses require the owner to select one.
- Scan lists nearby visible networks with signal strength and open/password status; duplicate SSIDs collapse to the strongest result.
- Refresh rescans; a hidden SSID can be entered manually.
- Open networks send an empty password. Password whitespace and SSID punctuation survive transport.
- Incorrect password produces a failed-join message, permits retry, and does not replace working saved credentials.
- Correct password produces Connected only after the ESP32 reports WL_CONNECTED.
- Restart reconnects using the saved credentials. If joining fails, BLE setup becomes available again.
- Missing updated firmware produces an update message rather than a false success.
- Bluetooth off, permission denial, harness out of range, and closing the sheet recover without a false success.
- At narrow phone sizes and with the keyboard open, the sheet scrolls and Connect remains reachable.
- After Wi-Fi connection, verify fresh telemetry in Supabase separately.

Protocol and architecture: docs/02 Architecture Decisions, ADR-025.
Wi-Fi scan API reference: https://docs.espressif.com/projects/arduino-esp32/en/latest/api/wifi.html

Automated app tests cover credential encoding, network decoding, open-network setup, and failed joins. Hardware testing is still required for Wi-Fi/BLE radio coexistence and actual connection results. The local environment has no Arduino compiler configured; firmware compilation must be performed with the project's ESP32 Arduino core and sensor libraries before flashing.
