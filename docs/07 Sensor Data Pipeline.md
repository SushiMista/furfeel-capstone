---
title: "Sensor Data Pipeline"
type: data-pipeline
project: FurFeel
created: 2026-07-09
updated: 2026-07-10
tags: [furfeel, telemetry, data]
---

# Sensor Data Pipeline

## Pipeline Stages
1. Sensor read (device).
2. Device-side validation.
3. Payload creation.
4. Wi-Fi transmission from ESP32 (`POST /telemetry`, header `x-device-key`).
5. Supabase Edge Function intake.
6. Server-side validation.
7. Raw telemetry storage (`raw_payload` kept verbatim, ADR-003).
8. Feature preparation.
9. Rule-based stress classification (`08 AI Classification Pipeline`).
10. Alert evaluation (`11 Alerts and Notifications`).

## Sampling Intervals (provisional — validate on hardware)
| Signal | Sensor | Sample rate | Sent to backend |
|---|---|---|---|
| Heart rate | MAX30102 | 1 Hz internal | aggregated every 10 s |
| Body temperature | MAX30102 | 0.2 Hz | every 10 s |
| Respiratory rate | Flex sensor | 1 Hz internal | every 10 s |
| Motion / posture | MPU9250 | 20 Hz internal | summarized every 10 s |
| Ambient temp / humidity | DHT22 | 0.1 Hz | every 10 s |

**Default transmit interval: one aggregated payload every 10 seconds.** The device computes `motion_activity` (0–1 normalized) and a posture label on-board so the payload stays small. Sampling rates are engineering defaults pending battery/thermal testing; keep them in device config.

## Final Telemetry Payload
```json
{
  "device_code": "ff-device-001",
  "captured_at": "2026-07-09T08:00:00Z",
  "heart_rate_bpm": 92,
  "body_temperature_c": 38.4,
  "respiratory_rate_bpm": 24,
  "motion_activity": 0.62,
  "posture": "standing",
  "ambient_temperature_c": 29.1,
  "humidity_percent": 68,
  "battery_percent": 87
}
```
`dog_id`/`device_id` are resolved server-side from `device_code` — the device does not need to know them. `posture` ∈ `standing|sitting|lying|moving|unknown`.

`battery_percent` (0–100, optional) is **device health only — never a classifier input**. The intake function stores it on the reading, mirrors the latest value onto `devices.battery_percent` for the apps, and drives the low-battery alert (see `11 Alerts and Notifications`). The simulator emits a slowly draining battery; `--low-battery` pins it near-empty.

## Validation Ranges (reject or flag `is_valid=false`)
| Field | Accept if | Else |
|---|---|---|
| heart_rate_bpm | 20–300 | flag |
| body_temperature_c | 30.0–43.0 | flag |
| respiratory_rate_bpm | 3–200 | flag |
| motion_activity | 0.0–1.0 | clamp/flag |
| ambient_temperature_c | -10–60 | flag |
| humidity_percent | 0–100 | flag |
| battery_percent | 0–100 | flag |
| captured_at | within ±1 h of server time | flag |

## Rules
- Reject impossible values; **flag** (never silently replace) out-of-range or missing values via `is_valid=false`.
- Store both `captured_at` (device) and `received_at` (server).
- Keep the raw payload for audit and future model training.
- Missing single fields are allowed (stored null); the classifier skips rules for null fields.

## Related
- [[06 IoT Wearable Device Design]]
- [[08 AI Classification Pipeline]]
- [[09 Database Schema]]
- [[17 Technology Stack]]
