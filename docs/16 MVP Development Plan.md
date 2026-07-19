---
title: "MVP Development Plan"
type: development-plan
project: FurFeel
created: 2026-07-09
updated: 2026-07-18
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

> Progress as of 2026-07-18 — the vertical slice is complete and both apps are full products. See [[Build Status]].

## Sprint 1: Foundation
- [x] Choose stack: Flutter mobile, React web, Supabase backend/database.
- [x] Set up repository (monorepo, `18 Repository Structure`).
- [x] Define database schema (schema + enums + indexes + RLS + auth trigger, live).
- [x] Create Supabase telemetry intake path (`telemetry-intake` Edge Function).
- [x] Create basic dog/device records (seed: clinic, owner, vet, dog, device, baseline).

## Sprint 2: Telemetry
- [x] Build ESP32 Wi-Fi or simulator payload sender (simulator done; firmware pending hardware).
- [x] Store telemetry readings (raw payload stored before classification, ADR-003).
- [x] Display latest reading in React dashboard.
- [x] Display latest reading in Flutter app.
- [x] Add validation for impossible values (flagged `is_valid=false`, never silently replaced).

## Sprint 3: Classification
- [x] Build rule-based stress classifier using collected sensor data (`rule-v1`).
- [x] Store stress classification result (score + reasons + model_version).
- [x] Display stress level (both clients, with a plain-language "why").
- [x] Create alerts from stress levels (moderate/high, plus device-offline and low-battery).
- [x] Document future Random Forest upgrade path for expert-labeled data ([[08 AI Classification Pipeline]]).

## Sprint 4: User Experience
- [x] Build mobile owner view (multi-dog home, vital detail, Trends, Care Insights, account/settings).
- [x] Build clinic dashboard view (photo dog-cards board, dog detail, alerts, reports, vet review, admin).
- [x] Add alert acknowledgement (both clients, RLS-enforced).
- [x] Add history view (Detailed Log + Trends, with CSV/PDF export).
- [x] Add supplementary video/media submission (owner uploads + owner↔vet threads; never a classifier input).

## Sprint 5: Evaluation
- [ ] Run ISO/IEC 25010 evaluation.
- [ ] Measure response time.
- [x] Test reliability and security basics (RLS on every table/bucket; mobile/edge/dashboard test suites green).
- [ ] Prepare development evidence for Capstone 2 (screenshots, sample telemetry, classification examples, demo script).

## Related
- [[00 System Design and Architecture Index]]
- [[Build Status]]
- [[15 Open Technical Questions]]
- [[13 Testing Strategy]]
