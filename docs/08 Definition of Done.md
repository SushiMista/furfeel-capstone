---
title: "Definition of Done"
type: quality-standard
project: FurFeel
created: 2026-07-09
tags: [furfeel, done, quality]
---

# Definition of Done

A FurFeel feature is done only when it passes these checks.

## Feature Done
- [ ] The feature works in the intended app or service.
- [ ] It uses the confirmed stack: Flutter, React, Supabase, ESP32/simulator as relevant.
- [ ] It handles loading, empty, and error states.
- [ ] It stores or reads data from the correct Supabase table when applicable.
- [ ] It follows the agreed naming rules.
- [ ] It has at least one manual test case.
- [ ] It is documented in the brain if it affects architecture, scope, or defense.

## Data Feature Done
- [ ] Schema is defined.
- [ ] Example data exists.
- [ ] Security policy is considered.
- [ ] Invalid data behavior is known.
- [ ] Evidence screenshot or sample record is saved for defense if needed.

## Classifier Feature Done
- [ ] Rule inputs are documented.
- [ ] Rule outputs are documented.
- [ ] Edge cases are listed.
- [ ] Limitations are stated clearly.
- [ ] Future Random Forest path is not contradicted.

## UI Feature Done
- [ ] User can understand what happened.
- [ ] Important status has clear wording.
- [ ] No screen depends on fake data unless labeled as demo/simulation.
- [ ] Mobile and dashboard behavior match their role.

## Manager Rule
If a feature cannot pass this note, mark it as “in progress,” not done.
