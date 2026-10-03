---
title: "System Overview"
type: architecture
project: FurFeel
created: 2026-07-09
updated: 2026-10-04
tags: [furfeel, architecture, overview]
---

# System Overview

FurFeel is a real-time canine stress monitoring system made of four major parts:

- Wearable IoT harness for collecting dog and environment readings.
- Backend and cloud database for receiving, storing, and serving telemetry.
- Rule-based classification layer for converting telemetry into stress levels.
- Mobile and web applications for dog owners, veterinary staff, and veterinarians.

## Core Loop
1. The dog wears the [[06 IoT Wearable Device Design]].
2. The device captures sensor readings.
3. The device sends telemetry through the [[07 Sensor Data Pipeline]].
4. The backend stores readings using the [[09 Database Schema]].
5. The [[08 AI Classification Pipeline]] assigns a stress level.
6. [[11 Alerts and Notifications]] sends important changes to users.
7. Users review status in [[04 Mobile App Design]] or [[05 Veterinary Dashboard Design]].

## Primary Architecture Style
Use a modular client-server architecture:

- Device client: ESP32 firmware.
- Mobile client: dog-owner and staff app.
- Web client: veterinary dashboard.
- Backend platform: Supabase for authentication, database, realtime updates, storage, and service logic.
- Database: Supabase PostgreSQL.
- Classification module: `rule-v1` inside the Supabase telemetry Edge Function, with a future Random Forest path only after expert-labeled `stress_labels` exist.

## Development Principle
The original vertical slice is complete: simulated/ESP32-style telemetry reaches Supabase, raw readings are stored, `rule-v1` classifications and alerts are written, and both Flutter/mobile and React/dashboard clients render live status. Current work should extend full app modules from the relevant spec while preserving that slice.

## Related
- [[02 Architecture Decisions]]
- [[16 MVP Development Plan]]
- [[17 Technology Stack]]
