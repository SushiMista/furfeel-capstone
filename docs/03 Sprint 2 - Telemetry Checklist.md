---
title: "Sprint 2 - Telemetry Checklist"
type: sprint-checklist
project: FurFeel
created: 2026-07-09
tags: [furfeel, sprint, telemetry]
---

# Sprint 2 - Telemetry Checklist

## Goal
Prove that telemetry can move from ESP32 or simulator into Supabase and appear in the apps.

## Tasks
- [ ] Finalize telemetry payload fields.
- [ ] Build simulated telemetry sender.
- [ ] Build ESP32 Wi-Fi sender when hardware is ready.
- [ ] Validate incoming payloads.
- [ ] Store raw telemetry in Supabase.
- [ ] Store server received timestamp.
- [ ] Show latest reading in React dashboard.
- [ ] Show latest reading in Flutter mobile app.

## Quality Checks
- [ ] Missing values are visible, not hidden.
- [ ] Impossible values are rejected or flagged.
- [ ] Device offline state is detectable.
- [ ] Readings include dog and device identity.

## Exit Criteria
- [ ] One test dog has live or simulated readings.
- [ ] React dashboard shows the latest reading.
- [ ] Flutter app shows the latest reading.
- [ ] Supabase contains telemetry history.

## Evidence
- [ ] Supabase telemetry table screenshot.
- [ ] Dashboard latest reading screenshot.
- [ ] Mobile latest reading screenshot.
- [ ] Sample telemetry JSON saved in documentation.
