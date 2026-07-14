---
title: "Cloud Database and Data Flow"
type: architecture
project: FurFeel
source: Capstone1_FinalManuscript
created: 2026-07-09
tags: [furfeel, cloud, data]
---

# Cloud Database and Data Flow

## Role
The cloud layer stores and retrieves accounts, dogs, telemetry records, classifications, monitoring history, and system records used by the dashboard and mobile app.

## Data Flow
1. Sensors collect raw readings.
2. ESP32 transmits data wirelessly.
3. Cloud database stores telemetry and user records.
4. Classification layer processes readings.
5. Interfaces retrieve stress status, histories, and alerts.

## Candidate Data Entities
- User
- Dog
- Clinic
- Device
- TelemetryReading
- StressClassification
- Alert
- VetReview
- Report

## Related
- [[06 System Architecture]]
- [[08 Sensor Data Model]]
- [[11 Veterinary Dashboard]]
