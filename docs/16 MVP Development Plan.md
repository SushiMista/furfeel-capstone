---
title: "MVP Development Plan"
type: development-plan
project: FurFeel
created: 2026-07-09
tags: [furfeel, mvp, development]
---

# MVP Development Plan

## MVP Goal
Build a working FurFeel prototype that proves the full telemetry-to-alert loop.

## MVP Vertical Slice
1. One dog profile.
2. One ESP32 Wi-Fi device or simulated ESP32 payload sender.
3. Telemetry sent to Supabase.
4. Telemetry stored in Supabase PostgreSQL.
5. Rule-based stress classification created.
6. Alert created for Moderate or High Stress.
7. Flutter mobile screen displays owner-facing current status.
8. React web dashboard displays clinic-facing monitoring status.

## Sprint 1: Foundation
- [x] Choose stack: Flutter mobile, React web, Supabase backend/database.
- [ ] Set up repository.
- [ ] Define database schema.
- [ ] Create Supabase telemetry intake path.
- [ ] Create basic dog/device records.

## Sprint 2: Telemetry
- [ ] Build ESP32 Wi-Fi or simulator payload sender.
- [ ] Store telemetry readings.
- [ ] Display latest reading in React dashboard.
- [ ] Display latest reading in Flutter app.
- [ ] Add validation for impossible values.

## Sprint 3: Classification
- [ ] Build rule-based stress classifier using collected sensor data.
- [ ] Store stress classification result.
- [ ] Display stress level.
- [ ] Create alerts from stress levels.
- [ ] Document future Random Forest upgrade path for expert-labeled data.

## Sprint 4: User Experience
- [ ] Build mobile owner view.
- [ ] Build clinic dashboard view.
- [ ] Add alert acknowledgement.
- [ ] Add history view.
- [ ] Add supplementary video/media submission only after core telemetry is stable.

## Sprint 5: Evaluation
- [ ] Run ISO/IEC 25010 evaluation.
- [ ] Measure response time.
- [ ] Test reliability and security basics.
- [ ] Prepare development evidence for Capstone 2.

## Related
- [[00 System Design and Architecture Index]]
- [[15 Open Technical Questions]]
- [[13 Testing Strategy]]
