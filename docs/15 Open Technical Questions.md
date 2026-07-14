---
title: "Open Technical Questions"
type: questions
project: FurFeel
created: 2026-07-09
tags: [furfeel, questions, development]
---

# Open Technical Questions

These are the questions to answer before or during the first development sprint.

## Stack
- [x] What technology will be used for the mobile app? Decision: Flutter.
- [x] What technology will be used for the web dashboard? Decision: React.
- [x] What technology will be used for the backend API? Decision: Supabase.
- [x] What database will be used? Decision: Supabase PostgreSQL.
- [ ] Where will the rule-based classifier run: Supabase Edge Function, database function, or separate backend service?

## Hardware
- [x] Will the ESP32 send telemetry directly over Wi-Fi? Decision: yes, ESP32 sends through Wi-Fi.
- [x] Will Bluetooth be used for phone pairing? Decision: not part of the current telemetry path.
- [ ] What is the required battery life?
- [ ] What sampling interval will each sensor use?

## AI and Data
- [x] Where will labeled training data come from? Decision: not available yet; needs expert validation.
- [ ] Who confirms stress labels?
- [ ] Will there be dog-specific baselines?
- [ ] What metrics will prove model performance?
- [x] What classifier will be used before expert-labeled data exists? Decision: rule-based stress classification using collected sensor data.

## Product
- [x] Is the MVP for clinic use, home use, or both? Decision: both simple versions should be prioritized.
- [x] Which user role should be built first? Decision: build both dog-owner mobile and clinic web flows in MVP scope.
- [x] Are owner-submitted images/videos part of MVP? Decision: supplementary communication/assessment only, not tied to classifier.
- [ ] What reports are required for Capstone 2?

## Remaining High-Priority Questions
- [ ] Should the rule-based classifier live in Supabase Edge Functions?
- [ ] What exact rules define Calm, Mild Stress, Moderate Stress, and High Stress?
- [ ] What telemetry sampling interval should the ESP32 use?
- [ ] What Supabase tables and RLS policies should be built first?
- [ ] What reports/screens are required for Capstone 2 defense evidence?
