---
title: "Software MVP Checklist"
type: checklist
project: FurFeel
created: 2026-07-09
updated: 2026-07-12
tags: [furfeel, checklist, software-mvp]
---

# Software MVP Checklist

> [!summary]
> The single active checklist for FurFeel software. As of 2026-07-12 the software MVP is **built and live** — remaining open items are demo/defense evidence. See [[Build Status]]. Hardware stays simulated until the ESP32 is ready.

## 0. Current Strategy
- [x] Prioritize software first.
- [x] Build both Flutter mobile and React web dashboard.
- [x] Use Supabase for backend, database, auth, storage, and realtime.
- [x] Use simulated telemetry while hardware is not ready.
- [x] Use rule-based stress classification before expert-labeled data exists.
- [x] Treat videos/media as supplementary vet-owner communication, not classifier input.

## 1. Project Setup
- [x] Create or confirm repository structure (monorepo, `docs/18`).
- [x] Create Flutter app folder.
- [x] Create React dashboard folder.
- [x] Create Supabase folder for SQL, policies, and functions.
- [x] Create shared documentation folder.
- [x] Add setup README (+ [[Developer Setup Guide]], Windows/macOS).
- [x] Add `.env.example` files for Flutter, React, and Supabase.
- [x] Add naming rules from [[14 Naming and Documentation Rules]].

## 2. Supabase Foundation
- [x] Create Supabase project.
- [x] Create `users` / profiles table (+ `avatar_path`, `user_settings`).
- [x] Create `clinics` table.
- [x] Create `dogs` table (+ `photo_path`).
- [x] Create `devices` table.
- [x] Create `telemetry_readings` table.
- [x] Create `stress_classifications` table.
- [x] Create `alerts` table.
- [x] Create `vet_notes` table (+ `stress_labels`, `care_guidance`).
- [x] Create `media_submissions` table.
- [x] Configure Supabase Storage (private `avatars` + `media` buckets, scoped policies).
- [x] Enable Row Level Security.
- [x] Add initial RLS policies for owner, veterinary staff, veterinarian, and admin.
- [x] Add seed data (clinic, owner, veterinarian, dog, simulated device, baseline).

## 3. Simulated Telemetry
- [x] Define telemetry JSON payload.
- [x] Create a software telemetry simulator (`--sweep`).
- [x] Generate calm / mild / moderate / high sample readings.
- [x] Insert simulated telemetry into Supabase.
- [x] Store both captured and received timestamps.
- [x] Flag missing or impossible values (`is_valid`).

## 4. Rule-Based Stress Classification
- [x] Decide where rules run (Supabase Edge Function — `telemetry-intake`).
- [x] Define Calm / Mild / Moderate / High rules (`rule-v1`).
- [x] Store classification result + rule version + `reasons` + `primary_reason`.
- [x] Create alerts for Moderate and High Stress.
- [x] Document limitations + future Random Forest path ([[08 AI Classification Pipeline]]).

## 5. Flutter Owner App
- [x] Login + Supabase Auth; onboarding/sign-up flow.
- [x] Personalized Home: status, "why", 2×2 vital cards + detail, calm-ring.
- [x] Current stress classification + alert list/detail.
- [x] Health history → Trends (7/14/30d, honesty-guarded insights).
- [x] Pet Creation, Device Pairing, Vet Review, Care Insights, Observation upload.
- [x] Account + Settings (theme, °C/°F, notifications), dark mode.
- [x] Loading, empty, and error states.

## 6. React Veterinary Dashboard
- [x] Login + Supabase Auth.
- [x] Clinic overview + multi-dog monitoring board (photo dog-cards, grid ⇄ table).
- [x] Dog detail page + latest telemetry + stress timeline.
- [x] Alert queue + acknowledgement.
- [x] Vet notes + Vet Review confirm/override → `stress_labels`.
- [x] Reports (DSS) + Admin.
- [x] Loading, empty, and error states.

## 7. Shared Product Behavior
- [x] Mobile and dashboard show the same stress status for a dog.
- [x] Consistent timestamps.
- [x] Moderate/High alerts visible in both apps.
- [x] Media labeled supplementary.
- [x] No medical-diagnosis claims (asserted by tests).
- [x] Classifier not called "Random Forest" until trained.

## 8. Testing
- [x] Supabase login per role.
- [x] Owner sees only owned dogs; clinic users only their clinic (RLS).
- [x] Simulated telemetry insert.
- [x] Rule-based classification for all four labels.
- [x] Alert creation + acknowledgement.
- [x] Flutter status flow; React dashboard flow.
- [~] RLS policy tests (covered via app tests; a dedicated RLS test pass is worth adding).
- Current: Mobile 55/55 · Dashboard 32/32 · Edge 67/67.

## 9. Demo and Defense Evidence (main remaining work)
- [x] Golden demo dog (Biscuit) + stable sample telemetry via simulator.
- [ ] Save sample telemetry JSON + Supabase table screenshots.
- [ ] Save Flutter + React screenshots.
- [ ] Save classification examples (Calm/Mild/Moderate/High) + alert example.
- [ ] Prepare demo script.
- [ ] Prepare hardware-not-ready + rule-based/future-RF explanations.
- [ ] ISO/IEC 25010 evaluation + response-time measurement + usability test.

## 10. Hardware Later
- [x] Simulator payload kept compatible with the future ESP32 payload.
- [x] Documented ESP32 Wi-Fi telemetry path ([[07 Sensor Data Pipeline]]).
- [ ] Real firmware (out of active software scope until hardware is available).

## Related
- [[Build Status]]
- [[16 MVP Development Plan]]
- [[08 Definition of Done]]
- [[10 Defense Evidence Checklist]]
- [[17 Technology Stack]]
