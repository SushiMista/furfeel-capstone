---
title: "System Overview"
type: architecture
project: FurFeel
created: 2026-07-09
tags: [furfeel, architecture, overview]
---

# System Overview

FurFeel is a real-time canine stress monitoring system made of four major parts:

- Wearable IoT harness for collecting dog and environment readings.
- Backend and cloud database for receiving, storing, and serving telemetry.
- AI classification layer for converting telemetry into stress levels.
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
- ML service or module: Random Forest inference.

## Development Principle
Build a working vertical slice first: one ESP32 or simulated device, one dog, one Wi-Fi telemetry stream into Supabase, one stored reading, one rule-based stress result, one Flutter status view, and one React dashboard display.

## Related
- [[02 Architecture Decisions]]
- [[16 MVP Development Plan]]
- [[17 Technology Stack]]
