---
title: "Naming and Documentation Rules"
type: documentation-standard
project: FurFeel
created: 2026-07-09
tags: [furfeel, naming, documentation]
---

# Naming and Documentation Rules

## Preferred Terms
- Use “FurFeel” for the system name.
- Use “canine stress classification” for stress labels.
- Use “telemetry reading” for one captured sensor record.
- Use “stress classification” for Calm/Mild/Moderate/High output.
- Use “supplementary media” for owner-submitted videos/images.
- Use “veterinary dashboard” for the React web app.
- Use “owner mobile app” for the Flutter app.

## Avoid
- Do not call the MVP classifier Random Forest until a trained model exists.
- Do not imply FurFeel diagnoses illness.
- Do not say videos feed the model.
- Do not mix “stress detection” and “stress classification” casually in formal docs.

## File and Feature Naming
- Use clear feature names that match the brain notes.
- Keep database table names plural and snake_case.
- Keep API or function names action-oriented.
- Keep UI labels understandable to non-technical users.

## Documentation Rule
Every major feature should have:
- purpose
- user
- data used
- output
- limitation
- evidence for defense
