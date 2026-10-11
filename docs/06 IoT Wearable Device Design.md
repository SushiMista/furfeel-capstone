---
title: "IoT Wearable Device Design"
type: hardware-design
project: FurFeel
created: 2026-07-09
tags: [furfeel, iot, hardware]
---

# IoT Wearable Device Design

## Device Purpose
The wearable harness collects physiological, behavioral, and environmental data from the dog and sends it to the FurFeel backend.

## Proposed Components
- ESP32 microcontroller for processing and wireless communication.
- MAX30102 PPG sensor for heart rate.
- MPU9250 IMU for motion and posture.
- Flex sensor for respiratory movement.
- DHT22 sensor for ambient temperature and humidity.

> Body temperature sensing was dropped (ADR-021) — FurFeel doesn't promote invasive procedures to gather stress data, so the harness only carries non-invasive wearable/environmental sensors.

## Firmware Responsibilities
- Initialize sensors.
- Read sensor values at configured intervals.
- Validate readings.
- Package readings into a telemetry payload.
- Send payload to Supabase/backend through Wi-Fi.
- Retry failed sends.
- Report device status and battery if available.

## Hardware Questions
- [ ] What power source and expected battery life?
- [x] Will the ESP32 send directly to Wi-Fi, Bluetooth phone relay, or both? Decision: Wi-Fi direct telemetry.
- [ ] What casing or harness material will hold sensors safely?
- [ ] How will sensor placement differ across dog sizes?

## Related
- [[07 Sensor Data Pipeline]]
- [[09 Database Schema]]

## BLE Wi-Fi provisioning (ADR-025)
The ESP32 scans nearby 2.4 GHz networks for the Flutter setup screen and exposes individual scan results over BLE. Keep BLE active during the Wi-Fi join so the app can read success or failure. Store credentials in NVS only after a successful join; retain setup access on failure. Reopen BLE when Wi-Fi is lost. Direct Wi-Fi telemetry remains the device link. See firmware/esp32/WIFI_SETUP.md for the protocol verification checklist.
