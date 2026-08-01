# Phase 1 — Data Collection (manual, pre-hardware)

Fill one row of `phase1_data_collection_template.csv` per observation. This is
throwaway-format now; Phase 2's export script will join it (or its Supabase
equivalent, once `stress_labels`/`telemetry_readings` are populated) into the
actual training set.

## Equipment per session
- Pulse check or stethoscope — heart rate (bpm)
- Stopwatch — count breaths for 15s, x4 for respiratory rate (bpm)
- Thermometer — body temperature (°C)
- Ambient thermometer/hygrometer if available (else leave blank)
- The vet's own eyes for posture

## Columns
- `size_class`: small / medium / large (bucketed breed, not the raw breed string used for scoring)
- `posture`: resting / walking / running / trembling_shaking (matches the doc's encoding: 0/1/2/3)
- `fas_score`: 0–5, per the vet's standard Fear/Anxiety/Stress scale assessment — **not** invented here
- `stress_label`: derived from fas_score per the locked mapping — 0→calm, 1–2→mild, 3–4→moderate, 5→high
- `notes`: anything about context (e.g. "leash reactive," "thunderstorm," "nail trim")

## Rules
1. Every field is a snapshot at the **same moment** — HR/RR/temp/posture and the FAS score must describe the same instant, not "sometime during the visit."
2. Don't wait for high-stress dogs to show up on their own — schedule sessions likely to produce moderate/high (leash reactivity, exams, loud-noise exposure) per the vet's judgment of what's safe and legitimate to observe.
3. After each session, update the running count by `stress_label`. Watch the smallest bucket, not the total row count.

## Gate before Phase 2
Every one of calm / mild / moderate / high needs more than a handful of real rows — "high" especially, since it won't occur naturally in most visits.
