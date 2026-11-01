# IMU logger OLED status

The collection sketch uses the existing SSD1306 128x64 OLED at 0x3C and
MAX17048 battery gauge on SDA 21 / SCL 22, shared with the MPU9250.
Install Adafruit SSD1306, Adafruit GFX and Adafruit MAX1704X libraries
with their dependencies. Compile imu_logger.ino as its own Arduino sketch.

OLED fields: Wi-Fi connection, device IP, battery charge percentage and
voltage, and the last HTTP response code. Battery charge is device status,
not battery aging/remaining capacity health. A gauge must be connected to
the battery being measured; a USB power bank alone cannot provide its charge
level through this sketch. Missing/invalid gauge values are shown explicitly.
HTTP 200 means the laptop received a batch; it may still be paused and discard it.

Manual checks, pending hardware verification:

- Boot without Wi-Fi: connection status must remain visible during joining.
- Connect: verify CONNECTED, ESP32 IP and last HTTP code after a batch.
- Disconnect Wi-Fi: verify NO WIFI / OFFLINE; reconnect and verify recovery.
- Compare battery percentage/voltage with the existing monitor sketch on the
  same hardware; disconnect the gauge before boot and verify NO GAUGE.
- Boot without OLED: serial collection must still work.
- Verify CSV rows and the six IMU axes still arrive at the laptop. OLED updates
  add I2C work to the existing loop; measure actual cadence from millis_ms.
