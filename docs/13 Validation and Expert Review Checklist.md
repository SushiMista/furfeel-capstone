---
title: "Validation and Expert Review Checklist"
type: validation-checklist
project: FurFeel
created: 2026-07-09
tags: [furfeel, validation, expert-review]
---

# Validation and Expert Review Checklist

## Purpose
Use this to move FurFeel from prototype logic toward expert-supported stress classification.

## Expert Review Targets
- [ ] Sensor choices.
- [ ] Stress label meanings.
- [ ] Rule-based threshold logic.
- [ ] Alert severity.
- [ ] Recommended user actions.
- [ ] Vet dashboard usefulness.
- [ ] Owner app wording.

## Data Labeling Plan
- [ ] Define labeling form.
- [ ] Define stress categories.
- [ ] Define observation protocol.
- [ ] Decide who can label data.
- [ ] Decide how disagreements are handled.
- [ ] Store label source and timestamp.

## Random Forest Preparation
- [ ] Collect enough telemetry samples.
- [ ] Pair telemetry windows with expert labels.
- [ ] Define features.
- [ ] Split training/testing data.
- [ ] Train model.
- [ ] Evaluate confusion matrix.
- [ ] Compare model against rule-based baseline.

## Defense Wording
Until expert-labeled data exists, describe the classifier as rule-based stress classification, not a validated machine learning model.
