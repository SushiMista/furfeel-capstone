---
title: "Sprint 3 - Classification Checklist"
type: sprint-checklist
project: FurFeel
created: 2026-07-09
tags: [furfeel, sprint, classification]
---

# Sprint 3 - Classification Checklist

## Goal
Implement rule-based stress classification and connect it to alerts.

## Tasks
- [ ] Define threshold rules for Calm.
- [ ] Define threshold rules for Mild Stress.
- [ ] Define threshold rules for Moderate Stress.
- [ ] Define threshold rules for High Stress.
- [ ] Decide whether rules run in Supabase Edge Function, database function, or app/backend layer.
- [ ] Store stress classification output.
- [ ] Store rule version.
- [ ] Trigger alerts for Moderate and High Stress.
- [ ] Display stress status in Flutter.
- [ ] Display stress status in React.

## Rule Documentation
- [ ] Explain which sensor values affect classification.
- [ ] Explain how missing sensor values affect classification.
- [ ] Explain limitations of rule-based classification.
- [ ] Explain future Random Forest path.

## Exit Criteria
- [ ] Given sample telemetry, the system produces a stress label.
- [ ] Moderate or High Stress creates an alert.
- [ ] Stress status appears in both mobile and dashboard.
- [ ] Rule logic is documented for defense.

## Evidence
- [ ] Test cases for sample telemetry.
- [ ] Screenshot of classification record.
- [ ] Screenshot of alert created from classification.
