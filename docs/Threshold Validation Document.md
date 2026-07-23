---
title: "Threshold Validation Document"
type: validation-checklist
project: FurFeel
created: 2026-07-23
tags: [furfeel, validation, expert-review, thresholds]
---

# FurFeel Threshold Validation Document

**Purpose:** every numeric cutoff the `rule-v1` stress classifier uses today, in one place, for a veterinarian to review, correct, or approve. This document satisfies the **"Rule-based threshold logic"** review target in [[13 Validation and Expert Review Checklist]]. Nothing here is invented for this document — every value is transcribed directly from `packages/shared/classifier_config.json`, the single file the classifier itself reads at runtime. Change a number in that file (with a vet's sign-off) and it changes the system; this document does not need editing to reflect a tuning change, only to record that the review happened.

**Companion file:** [[Sample Telemetry Dataset]] (CSV) — 54 example raw payloads across three illustrative dog sizes, each with the classifier's expected score/level worked out, so every threshold below can be checked against a concrete number instead of read in the abstract.

> ⚠️ **Current status: provisional engineering defaults, not clinically validated.** Per CLAUDE.md and `classifier_config.json`'s own `_disclaimer`, treat every threshold below as a defensible starting point, not a diagnosis boundary. FurFeel is decision support, never a diagnosis, regardless of how these numbers are tuned.

---

## 1. Raw signal validation ranges

These are **sensor/hardware plausibility bounds** (docs/07), not clinical thresholds — they decide whether a raw reading gets stored and used at all, before any stress scoring happens. A value outside range is never silently replaced: it's flagged `is_valid=false` and the field is stored as `null` (the classifier then skips any rule needing that field). The true received value is always kept in `raw_payload` regardless (ADR-003, audit trail).

| Field | Accept range | Source | Reviewer note |
|---|---|---|---|
| `heart_rate_bpm` | 20 – 300 | MAX30102 plausibility bound | |
| `body_temperature_c` | 30.0 – 43.0 | MAX30102 plausibility bound | |
| `respiratory_rate_bpm` | 3 – 200 | Flex sensor plausibility bound | |
| `motion_activity` | 0.0 – 1.0 | Normalized index (0 = still, 1 = constant motion) | |
| `ambient_temperature_c` | -10 – 60 | DHT22 plausibility bound | |
| `humidity_percent` | 0 – 100 | DHT22 plausibility bound | |
| `battery_percent` | 0 – 100 | Device health only — **never a classifier input** | |
| `captured_at` | within ±1 h of server receipt time | Clock-drift / stale-payload guard | |

See rows 15–17, 33–35, 51–53 of the sample dataset for a worked example of each rejection case (out-of-range HR, a missing field, and a stale timestamp).

**Reviewer question:** are these ranges wide enough to never reject a real dog's genuine extreme (e.g. a toy breed's naturally fast heart rate), while still catching sensor faults?

---

## 2. Global default baselines (medium adult dog, resting)

Used when a dog has no `dog_baselines` row (or a null field within one) — a per-dog value always overrides these.

| Signal | Normal resting range (general reference) | Baseline used |
|---|---|---|
| Heart rate | 60–100 bpm | **90 bpm** |
| Respiratory rate | 10–35 bpm | **24 bpm** |
| Body temperature | 38.3–39.2 °C | **38.7 °C** |
| Motion activity | 0.0–1.0 | **0.3** |

**Size matters here.** A global "medium dog" baseline is a compromise — a small dog's genuinely normal resting heart rate can run well above 90 bpm, and a large dog's can run well below it, purely from body size, not stress. The sample dataset illustrates this directly with three example dogs and their own baselines:

| Dog | Size class | Illustrative baseline HR | Illustrative baseline RR | Baseline temp |
|---|---|---|---|---|
| Mochi (Shiba Inu, 9.8 kg) | small | 110 bpm | 26 | 38.6 °C |
| Rio (Border Collie, 18 kg) | medium | 90 bpm (= global default) | 24 | 38.7 °C |
| Duke (Great Dane, 55 kg) | large | 72 bpm | 18 | 38.4 °C |

The dataset makes the consequence concrete: a reading of **95 bpm** scores as calm (below Mochi's or Rio's baseline-derived elevated threshold) but scores **+1 elevated** for Duke, whose baseline is lower — the same raw number means something different depending on the dog. This is exactly what the existing per-dog `dog_baselines` mechanism (and its threshold-override columns) exists to correct; there is currently no formal `small/medium/large` schema field, so these three are illustrative baselines entered the same way a vet would enter any dog's real resting values.

**Reviewer question:** are these three illustrative baselines (and the global default) realistic per-size resting values, or should they be adjusted?

---

## 3. Scoring rules (rule-v1) — every point-scoring cutoff

`hr_ratio = heart_rate_bpm / baseline_hr`. `rr_ratio = respiratory_rate_bpm / baseline_rr`. Rules are skipped (not scored, not penalized) when their input field is `null`. Tiers are `[min, max)` unless `max` is unbounded.

| # | Rule | Condition | Points | Reviewer note |
|---|---|---|---|---|
| 1 | Heart rate elevated | `hr_ratio` 1.15 – 1.35 | +1 | |
| | | `hr_ratio` 1.35 – 1.6 | +2 | |
| | | `hr_ratio` > 1.6 | +3 | |
| 2 | Respiratory elevated | `rr_ratio` 1.3 – 1.8 | +1 | |
| | | `rr_ratio` > 1.8 (panting) | +2 | |
| 3 | Body temperature | 39.2 – 39.7 °C | +1 | |
| | | > 39.7 °C | +2 | |
| 4 | Motion / restlessness | `motion_activity` 0.6 – 0.8 | +1 | |
| | | `motion_activity` > 0.8 | +2 | |
| 5 | Posture + high motion | posture = `moving` **and** motion ≥ 0.6 | +1 | *Inference, not numerically specified in the original spec — reuses rule 4's 0.6 floor. Flagged for explicit confirmation.* |
| 6 | Environmental amplifier (heat) | ambient > 32 °C **or** humidity > 80% | +1 | Heat only; cold is deliberately never scored (see §5) |
| 7 | Rising trend | stress score strictly increased across the last 3 readings | +1 | |

**Score → level mapping** (§4 below) determines the final `calm`/`mild`/`moderate`/`high` label from the total.

**Reviewer question, per row:** does the point value and cutoff match your clinical judgment of severity? Rule 5 in particular has no independent numeric definition in the original spec and should get explicit confirmation or a real number.

---

## 4. Score → stress level mapping

| Total score | Level |
|---|---|
| 0 – 1 | **calm** |
| 2 – 3 | **mild** |
| 4 – 6 | **moderate** |
| ≥ 7 | **high** |

**Worked example** (from the spec, and reproduced in the sample dataset): baseline HR 90, RR 24. Reading HR 150 (`hr_ratio` 1.67 → +3), RR 46 (`rr_ratio` 1.92 → +2), temp 39.4 °C (+1), motion 0.7 (+1) → **score 7 → high**.

**Reviewer question:** do these four bands, and the point totals that separate them, correspond to real, distinguishable levels of canine stress in practice?

---

## 5. Context rules (never change the score)

| Rule | Condition | Effect |
|---|---|---|
| Environmental cold | ambient temperature < 8.0 °C | Adds a `environmental_cold` reason code for the owner's "why" and Care Insights (e.g. suggests a warm bed) — **does not add points.** |

**Reviewer question:** should cold ever contribute to the stress score itself (currently: no, by design), or is context-only correct?

---

## 6. Biometric status bands (owner-facing Low / Normal / Elevated / High)

Shown per-vital in the apps, independent of the overall stress level. Elevated/High floors are **derived directly from §3's scoring tiers** (they cannot drift out of sync); only the Low floor is separate config.

| Vital | Low (below) | Normal | Elevated (§3 tier 1 floor) | High (§3 tier 2 floor) |
|---|---|---|---|---|
| HR ratio | 0.7 | 0.7 – 1.15 | 1.15 | 1.35 |
| RR ratio | 0.5 | 0.5 – 1.3 | 1.3 | 1.8 |
| Body temperature | 37.5 °C | 37.5 – 39.2 °C | 39.2 °C | 39.7 °C |

**Reviewer question:** is the "Low" floor (the one number here not already covered by §3) clinically reasonable for each vital?

---

## 7. Device-health threshold (not a stress signal)

| Threshold | Value | Effect |
|---|---|---|
| Low battery | ≤ 15% | Raises a `device_low_battery` alert. **Never influences the stress classification** — battery is device health only (docs/07). |

---

## 8. Daily Wellness Score constants (engineering composite, not clinical)

Explicitly labeled in-app as an engineering metric, not a clinical measure — included here only for completeness since it uses tunable constants too.

| Constant | Value | Role |
|---|---|---|
| Calm weight | 60 | % of score from calm-classification share that day |
| Balance weight | 40 | % of score from activity balance |
| Target active share | 0.30 | "Healthy" fraction of readings with motion ≥ 0.4 |
| Alert penalty | 10 per alert, capped at 30 | Deducted from the day's score |

---

## 9. How to use this document

1. Read a threshold row above alongside the matching rows in [[Sample Telemetry Dataset]] — see the raw numbers that would trigger it.
2. Mark each reviewer question: **Approve as-is**, or **Revise to: ___**.
3. Any revision gets applied to `packages/shared/classifier_config.json` (the single source of truth) and logged as an ADR in `docs/02 Architecture Decisions.md` — never changed silently.
4. Sign below.

**Reviewed by:** _______________________ (name, credentials)
**Date:** _______________________
**Overall disposition:** ☐ Approved as provisional defaults ☐ Approved with noted revisions ☐ Needs further discussion

## Related
- [[13 Validation and Expert Review Checklist]]
- [[08 AI Classification Pipeline]]
- [[07 Sensor Data Pipeline]]
- [[09 Database Schema]]
