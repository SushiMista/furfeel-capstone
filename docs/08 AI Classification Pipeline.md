---
title: "AI Classification Pipeline"
type: ml-pipeline
project: FurFeel
created: 2026-07-09
updated: 2026-07-10
tags: [furfeel, ai, rule-based, random-forest]
---

# AI Classification Pipeline

## Classification Goal
Classify canine stress into actionable levels using physiological, behavioral, and environmental features.

## Target Labels
`calm` · `mild` · `moderate` · `high`

## MVP Pipeline
1. Load the newest telemetry reading (and the last N=5 readings for trend).
2. Drop/flag impossible or missing values (`07 Sensor Data Pipeline`).
3. Resolve baselines: use `dog_baselines` if present, else the **global defaults** below.
4. Compute a **stress score** from feature rules.
5. Map score → stress level.
6. Store result in `stress_classifications` (`score`, `reasons`, `model_version='rule-v1'`).
7. Evaluate alert rules (`11 Alerts and Notifications`).

> **These thresholds are provisional engineering defaults, not vet-validated ground truth.** Keep them in one config file (e.g. `classifier_config.json`) so a veterinarian can tune them without code changes. They are a defensible starting point for the vertical slice, to be revised once expert-labeled data exists.

## Global Default Baselines (medium adult dog, resting)

| Signal | Normal resting range | Baseline used |
|---|---|---|
| Heart rate | 60–100 bpm | 90 bpm |
| Respiratory rate | 10–35 bpm | 24 bpm |
| Body temperature | 38.3–39.2 °C | 38.7 °C |
| Motion activity | 0.0–1.0 (0=still) | 0.3 |

Per-dog values in `dog_baselines` override these when available.

## Scoring Rules (rule-v1)

Each rule adds points. `hr_ratio = heart_rate / baseline_hr`, `rr_ratio = respiratory_rate / baseline_rr`.

| Rule | Condition | Points |
|---|---|---|
| Heart rate elevated | `hr_ratio` 1.15–1.35 | +1 |
|  | `hr_ratio` 1.35–1.6 | +2 |
|  | `hr_ratio` > 1.6 | +3 |
| Respiratory elevated | `rr_ratio` 1.3–1.8 | +1 |
|  | `rr_ratio` > 1.8 (panting) | +2 |
| Body temperature | 39.2–39.7 °C | +1 |
|  | > 39.7 °C | +2 |
| Motion / restlessness | `motion_activity` 0.6–0.8 | +1 |
|  | `motion_activity` > 0.8 | +2 |
| Posture | `posture = 'moving'` sustained with high motion | +1 |
| Environmental amplifier | ambient > 32 °C **or** humidity > 80% (heat stress context) | +1 |
| Rising trend | stress score rose across last 3 readings | +1 |

**Score → level mapping:**

| Total score | Stress level |
|---|---|
| 0–1 | `calm` |
| 2–3 | `mild` |
| 4–6 | `moderate` |
| ≥ 7 | `high` |

Store which rules fired in `reasons` (jsonb) for transparency and Capstone defense evidence. `confidence` stays null for `rule-v1` (populated later by the model).

### Reason codes → owner-facing "why"
Each rule emits a stable `code` plus the raw detail. Classifications also expose a **`primary_reason`** = the highest-point rule that fired (ties broken by this order: environmental → heart_rate → respiratory → temperature → motion → trend). The owner app maps `primary_reason` to plain, non-clinical language; the dashboard can show the full technical list.

| reason code | owner-facing phrase |
|---|---|
| `environmental_heat` | "Feeling the heat — it's warm and humid" |
| `environmental_cold` | "It's chilly out — worth a warm spot" (context only, see below) |
| `heart_rate_elevated` | "Heart rate is higher than usual" |
| `respiratory_elevated` | "Breathing fast / panting" |
| `body_temperature` | "Body temperature is up" |
| `motion_restlessness` | "Restless and moving a lot" |
| `rising_trend` | "Stress has been climbing" |
| (none — calm) | "Relaxed and comfortable" |

Keep the phrase table in config alongside the thresholds so it's tunable and translatable. Care Insights should key its tip off the same `primary_reason` (e.g. heat → "move to a cooler, shaded spot and offer water").

### Context rules (no score impact)
`classifier_config.json` has a `context_rules` section for signals that inform the owner and Care Insights but **never change the stress score**. Implemented: `environmental_cold` — ambient below **8 °C (provisional, vet-tunable)** appends the `environmental_cold` reason code. Cold is deliberately not scored (this table scores heat only); revisit with veterinary input if cold stress should ever contribute points.

### Care Insights combinations
The owner app derives a *combination context* from the latest reading + classification and prefers a matching `care_guidance.context_key` row over the per-level default: `cold_stressed`, `hot_stressed`, `panting_hot`, `restless_high_hr`, `cold_calm`, `hot_calm`. Hot/cold use the environmental amplifier + cold-context thresholds; "restless" = motion ≥ 0.6; "high HR / panting" use the biometric status bands below. Seeded copy is provisional and clinic-overridable — **a vet should review it**.

### Biometric status bands (owner-facing, provisional)
Each vital shows a plain status word (Low / Normal / Elevated / High) relative to the dog's baseline (`dog_baselines`, else the global defaults). Bands align with the rule tiers: HR ratio <0.7 Low · <1.15 Normal · <1.35 Elevated · else High; RR ratio <0.5 / <1.3 / <1.8; temperature <37.5 / <39.2 / <39.7 °C. The Elevated/High floors are **derived from the scoring tiers**; only the Low floors are separate config (`classifier_config.json → biometric_status_bands`). All of it is **code-generated** into `apps/mobile/lib/insights/biometric_bands.g.dart` by `node packages/shared/scripts/generate_classifier_bands.mjs`, and a staleness test (`biometric_bands_codegen_test.dart`) fails CI if the config changes without regenerating — no hand-mirroring. Strictly observational wording.

## Daily Wellness Score (provisional engineering metric)
`dog_wellness_score(dog_id, day)` (SECURITY INVOKER RPC) returns a 0–100 daily score — **an engineering composite, not a clinical measure**, and labeled as such in the app:

```
calm_component    = 60 × (calm classifications / all classifications that day)
balance_component = 40 × (1 − |active_share − 0.30|)   # active = motion ≥ 0.4; 0.30 = provisional healthy activity share
alert_penalty     = 10 per alert that day, capped at 30
score             = clamp(round(calm + balance − penalty), 0, 100)
```
Returns no row when the day has no classifications. Every constant here is vet-tunable in the migration; log changes as ADRs.

## Worked Example
Baseline HR 90, RR 24. Reading: HR 150 (`hr_ratio`=1.67 → +3), RR 46 (`rr_ratio`=1.92 → +2), temp 39.4 (+1), motion 0.7 (+1) → score 7 → **high**. Reasons: `["hr_ratio>1.6","rr panting","temp 39.2-39.7","motion 0.6-0.8"]`.

## Future Random Forest Pipeline
After expert validation and labeled-data collection, add a Random Forest trained on the structured features below. It **replaces the score→level step**, not the ingestion/storage/alert steps. Keep `rule-v1` available as a fallback and for comparison. Bump `model_version` (e.g. `rf-v1`).

### Candidate Features
Current heart rate · HR change from baseline · body temperature · respiratory rate · motion intensity · posture category · ambient temperature · humidity · recent trend over the time window.

## Evaluation Metrics
Accuracy · precision/recall per class · confusion matrix · false-alert rate · classification latency.

## Open Questions (human decisions)
- Source of expert-labeled ground truth; who confirms labels.
- Per-dog vs global baselines as the standard (defaults provided; per-dog supported).
- Final threshold tuning after pilot data.

## Related
- [[07 Sensor Data Pipeline]]
- [[13 Testing Strategy]]
- [[11 Alerts and Notifications]]
- [[09 AI Stress Classification]]
