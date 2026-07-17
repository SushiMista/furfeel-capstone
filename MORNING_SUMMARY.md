# Morning Summary — Owner-app QA + enhancement pass, 2026-07-17

All four phases are **finished and committed on `main`**. Every suite is green at HEAD:
**mobile `flutter analyze` clean + 103 tests · edge 76 deno tests + `deno check` · dashboard tsc + 32 vitest · simulator tsc**.
Nothing was deployed — the migrations and edge redeploy need your hands (below).

## Commits (oldest first)
- `f3a0b5f` — Phase 1: light-mode default + both crash fixes (+ test repairs)
- `1526bb1` — Phase 2: battery / consents / media threads / care combos / wellness (schema + backend)
- `95f63e8` — Phase 3: all owner-app features
- (this commit) — Phase 4: docs 04/07/08/09/11/12 updated + this summary

## What shipped

### Phase 1 — defaults & crashes
- **Light by default:** `user_settings.theme` default → `'light'` (migration `20260717090000`), app model/fallback → light, unknown values fall back to light (never the OS), Settings order Light / Dark / System. Existing users' saved choice untouched.
- **DropdownButton assert (dropdown.dart:1852)** — reproduced in a widget test: editing a dog whose `clinic_id` wasn't yet in the still-loading clinic items. Fixed by keeping the selected value present exactly once (a "Your current clinic" placeholder while loading **and** when the clinic is missing from the partner list — so we never silently unlink a clinic) + deduping clinics by id. 3 regression tests.
- **TextPainter assert (text_painter.dart:1351, `debugSize == size`)** — root-caused to two contributors: (a) google_fonts loading Inter *after* first layout, so a paint-only (color) text change re-laid-out with different metrics (flutter#79084); (b) the header dog-name chip Text was unconstrained in the AppBar actions row and overflowed with long names. Fixed by **preloading all four Inter weights before `runApp`** and capping/ellipsizing the chip (long-name regression test). The exact assert isn't reproducible under the deterministic test font — the overflow half is test-covered, the font-race half is eliminated by construction.
- Also repaired 4 pre-existing test failures (offscreen taps on the grown login page; dog-switcher tooltip restored — also an a11y win) and the one pre-existing analyze info.

### Phase 2 — schema & backend (migration `20260717100000`, additive, full RLS)
- **Battery:** `telemetry_readings.battery_percent` + `devices.battery_percent` (0–100 checks); intake validates, stores, mirrors latest to the device row; **`low_battery` alert** at ≤15% (provisional, `classifier_config.json → device_alerts`), deduped while open, **auto-resolves on recharge**. Simulator emits a draining battery + `--low-battery` flag.
- **`consents`** table (user_id, policy_version, accepted_at; unique pair; own-row select/insert RLS, append-only).
- **`media_messages`** table (thread under a media submission; RLS = dog's owner + clinic staff via the parent submission; realtime-enabled).
- **Care combinations:** `care_guidance.context_key` (stress_level now nullable, keyed-check constraint) + 6 provisional global seeds: `cold_stressed`, `hot_stressed`, `panting_hot`, `restless_high_hr`, `cold_calm`, `hot_calm`.
- **`environmental_cold`** context rule in `classifier_config.json` (ambient < 8 °C): emits a reason code, **never changes the score** (docs/08 scores heat only).
- **`dog_wellness_score(dog_id, day)`** SECURITY INVOKER RPC — 0–100: `60×calm_share + 40×(1−|active_share−0.30|) − min(10×alerts, 30)`, no row when the day has no classifications. Documented in docs/08 as provisional engineering, not clinical.
- **Friendly alert copy** now generated server-side: names the dog + the sensed reason ("Biscuit seems quite stressed right now — they're breathing fast. Please check on them soon.").

### Phase 3 — owner-app features
- **Multi-dog Home:** card per dog (photo, stress pill, wellness score, key vital, battery w/ low state, last-updated) → tap opens a self-loading, realtime **dog detail** page reusing the rich Home. Single-dog owners land straight on rich detail.
- **Biometric insights:** every vital shows Low / Normal / Elevated / High from the dog's own baseline (`dog_baselines`, else global), token colors; the vital detail page says e.g. "Heart rate 92 bpm — Normal for Biscuit". Logic in `lib/insights/biometrics.dart`.
- **Combination Care Insights:** context key derived from level + reading (heat/cold/panting/restless×HR); context row > level row, clinic > global.
- **Media conversations:** every observation opens a thread — media, owner note, clinic review, `media_messages` replies + composer.
- **Detailed Log redesign:** per-vital fl_chart mini-dashboards (min/avg/max), 24h/7d/30d + custom range picker, **CSV export** + **PDF health report** (`pdf` + `share_plus`; share sheet on mobile, browser download on web via `package:web`).
- **Battery surfaced** on Home cards, the status-hero device chip, and Device Pairing ("Battery 12% — time for a charge"); `low_battery` joined the Alerts "Harness" group + per-type mute.
- **Wellness card** (score ring + active/rest/calm balance bar, "engineering estimate, not a medical score") on Trends.
- **Consent gate:** RootShell checks `consents` before *anything* loads — no dog fetch, no realtime subscription, no telemetry UI until the current policy version (`2026-07-17.v1`) is accepted. Accepting records the version; bumping the constant forces re-consent.

### Phase 4 — docs + tests
- Updated `docs/04, 07, 08, 09, 11, 12` to match everything above (vet-tunable items called out in each).
- New tests: crash regressions ×4, biometric statuses, combination selection, guidance precedence, consent gating (incl. **no subscription before consent** — this test caught a real gap and the fix is in), media threads, multi-dog cards, CSV/PDF builders, and a **no-diagnosis/no-causal-language scan** over every new copy source (migration seeds, edge alert copy, app screens).

## ASSUMPTIONS (all reversible; flag anything wrong)
1. **Cold threshold 8.0 °C** — provisional, vet-tunable; cold is context-only and never scores (docs/08 scores heat only).
2. **Low battery ≤ 15%** — provisional; `classifier_config.json → device_alerts.low_battery_percent`.
3. **Wellness formula** (60/40 weights, active = motion ≥ 0.4, rest < 0.15, target active share 0.30, 10 pts/alert capped at 30) — engineering defaults; constants sit in the migration SQL for tuning.
4. **Biometric status bands** (HR 0.7/1.15/1.35 ratios, RR 0.5/1.3/1.8, temp 37.5/39.2/39.7 °C) mirror `classifier_config.json` **by hand** — no Dart codegen yet, so they can drift; noted in docs/08.
5. **Combination-tip copy is my draft**, seeded as "vet-authored defaults, clearly provisional" — a vet must review wording (it passes the no-diagnosis scan, but tone/accuracy is theirs to call).
6. **Consent is client-side gating only.** Device ingest keeps flowing server-side (the harness has no user identity). Server-side enforcement is logged as an open question in docs/12.
7. If the consent check itself fails (offline), the app shows the gate rather than risking un-consented data display.
8. Editing a dog whose clinic vanished from the partner list keeps the linkage via a "Your current clinic" placeholder instead of silently clearing `clinic_id`.
9. Multi-dog cards load on open + pull-to-refresh (no per-card realtime); the opened detail page and the selected dog do subscribe live.
10. In media threads, messages not authored by the dog's owner display as "Your care team" (owners may not be able to read clinic users' names under users RLS; the real name shows when RLS allows it).
11. CSV keeps temperature in °C (a raw data export shouldn't depend on a display preference); the PDF is the friendly artifact. Range fetches cap at the 1000 (readings) / 2000 (classifications) most recent rows in range.
12. Old alert rows keep their old server-generated copy; only new alerts get the friendly wording.
13. Dashboard: only its test fixtures changed (`battery_percent: null` on the reading fixture); no dashboard feature work was in scope.

## Needs your hands
1. **`supabase db push`** — two new migrations: `20260717090000_theme_default_light.sql`, `20260717100000_battery_consents_media_threads_care_combos.sql` (remote push is permission-blocked for me).
2. **Redeploy edge functions** — `supabase functions deploy telemetry-intake` (battery + friendly copy + low-battery alert path).
3. **Verify RLS live** (no local Docker here, so `consents` / `media_messages` policies got SQL review + app-level tests only): as owner A try reading owner B's consents/messages; as clinic staff read/reply on a linked dog's thread.
4. **FCM/APNs** — unchanged pending step; push will pick up the friendly copy automatically once wired (`lib/data/push_registration.dart`).
5. **Real battery sensor wiring** in the ESP32 firmware — only the simulator emits `battery_percent` today.
6. **Vet review** of: combination-tip copy, cold/low-battery thresholds, wellness formula, biometric bands (all marked provisional).
7. Smoke the deployed stack with the simulator: `npm start -- --low-battery --max-ticks=3` → low_battery alert appears; a normal run afterwards resolves it.

## Exact resume prompt
> FurFeel owner-app pass continuation. The 2026-07-17 QA/enhancement pass (MORNING_SUMMARY.md) is committed on main; migrations `20260717090000` + `20260717100000` are pushed and telemetry-intake is redeployed [adjust if not]. Next: [pick one] (a) server-side consent enforcement in telemetry-intake per the docs/12 open question, (b) apply vet feedback to care-combination copy/thresholds in classifier_config.json + the care_guidance seeds, (c) dashboard-side media_messages thread UI so clinic staff can reply from the Vet Review screen, (d) FCM wiring. Keep flutter analyze + flutter test + deno test + tsc green; guardrails as in CLAUDE.md (no diagnosis language, never weaken RLS, colors from tokens only, media never a classifier input).
