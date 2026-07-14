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
- MAX30102 PPG sensor for heart rate and body temperature.
- MPU9250 IMU for motion and posture.
- Flex sensor for respiratory movement.
- DHT22 sensor for ambient temperature and humidity.

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
