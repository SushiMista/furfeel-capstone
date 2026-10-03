---
title: "Open Technical Questions"
type: questions
project: FurFeel
created: 2026-07-09
updated: 2026-10-04
tags: [furfeel, questions, development]
---

# Open Technical Questions

These are the questions to answer before or during the first development sprint.

## Stack
- [x] What technology will be used for the mobile app? Decision: Flutter.
- [x] What technology will be used for the web dashboard? Decision: React.
- [x] What technology will be used for the backend API? Decision: Supabase.
- [x] What database will be used? Decision: Supabase PostgreSQL.
- [x] Where will the rule-based classifier run? Decision: synchronously inside the `telemetry-intake` Supabase Edge Function.

## Hardware
- [x] Will the ESP32 send telemetry directly over Wi-Fi? Decision: yes, ESP32 sends through Wi-Fi.
- [x] Will Bluetooth be used for phone pairing? Decision: not part of the current telemetry path.
- [ ] What is the required battery life?
- [ ] What sampling interval will each sensor use?
- [x] **Body temperature has no dedicated sensor.** Raised 2026-07-30 (MAX30102's on-die temperature was never a valid stand-in for core/skin body temp). Resolved by ADR-021 (2026-08-02): dropped as a classifier input, threshold override, and displayed vital; the raw `telemetry_readings.body_temperature_c` column itself was dropped outright in the 2026-08-07 amendment. No dedicated temp sensor is needed unless body temperature is reintroduced later.

## AI and Data
- [x] Where will labeled training data come from? Decision: not available yet; needs expert validation.
- [x] Who confirms stress labels? Decision: clinic `vet_staff`/`veterinarian`/`admin` through dashboard confirm/override; rows are stored in `stress_labels`.
- [x] Will there be dog-specific baselines? Decision: yes, `dog_baselines` stores resting values plus nullable per-dog score and per-variable threshold overrides.
- [ ] What metrics will prove model performance?
- [x] What classifier will be used before expert-labeled data exists? Decision: rule-based stress classification using collected sensor data.

## Product
- [x] Is the MVP for clinic use, home use, or both? Decision: both simple versions should be prioritized.
- [x] Which user role should be built first? Decision: build both dog-owner mobile and clinic web flows in MVP scope.
- [x] Are owner-submitted images/videos part of MVP? Decision: supplementary communication/assessment only, not tied to classifier.
- [ ] What reports are required for Capstone 2?

## Remaining High-Priority Questions
- [x] Should the rule-based classifier live in Supabase Edge Functions? Decision: yes, `telemetry-intake`.
- [x] What exact rules define Calm, Mild Stress, Moderate Stress, and High Stress? Decision: `docs/08 AI Classification Pipeline` + `packages/shared/classifier_config.json`.
- [ ] What telemetry sampling interval should the ESP32 use?
- [x] What Supabase tables and RLS policies should be built first? Decision: the vertical-slice schema is implemented in `supabase/migrations`; new modules add migrations without editing shipped ones.
- [ ] What reports/screens are required for Capstone 2 defense evidence?
- [ ] Resolve schema direction for dashboard ward/admission + `clinical_interventions`: dashboard code references them, but `20260830130001_rollback_ward_locations_and_interventions.sql` removes the table/columns after the add migration.
