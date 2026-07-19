# Morning Summary — Master improvement pass, 2026-07-19

All work is **committed on `main`**, one commit per step. Every suite is green at HEAD:
**mobile `flutter analyze` clean + 134 tests · edge 81 deno tests (+1 opt-in live suite) + `deno check` · dashboard `tsc` + 54 vitest · simulator `tsc`.**
Nothing was deployed; nothing here needs `supabase db push` — **this pass added no migrations.**

## Commits (oldest first)
- `1cdc095` — **P1.1** Theme via `ThemeExtension` (`FurFeelPalette`, `context.ff`), MaterialApp `theme`/`darkTheme`/`themeMode`; `FurFeelTokens.isDark` static + full-tree rebuild gone (ADR-012)
- `c2c9a69` — **P1.2** Biometric bands code-generated from `classifier_config.json` + staleness test (ADR-013; retires old assumption 4)
- `7bb16d9` — **P1.3+P1.4** Devices column-grant CI guard (vitest, mutation-tested) + dead-code sweep (`features/*`, `lib/services`, unused `vital_number.dart`)
- `cb6ee50` — **P1.5** Error-state audit: `util/errors.dart` maps true causes (offline / session expired / permission denied / timeout…), shared `RetryMessage`, dog-detail no longer masquerades failure as "no data"
- `e7a3db8` — **P2.6** RLS suite: static policy audit in CI + opt-in live cross-tenant proof (`services/edge/rls_audit/`)
- `221b5fc` — **P2.7** p50/p95 instrumentation (intake log metric, simulator round-trip summary, dashboard `board_load`, mobile `home_load`) + new `docs/20 Quality Evidence ISO 25010`
- `21fc913` — **P2.8** A11y: light-mode status/warm text tokens darkened to pass 4.5:1 (docs/19 updated; CI contrast test), PDF palette de-hardcoded, Semantics labels, 2× dynamic-type test (caught + fixed a nav-bar overflow)
- `082b292` — **P2.9** Offline cache: last-known snapshot + "showing last known reading" banner; consent stays the gate (only server-confirmed acceptance is cached)
- `8faf3fb` — **P3.10** Demo mode: local `DemoRepository`, "Explore the demo" on Welcome, persistent sample-data banner (ADR-014)
- `fbf0e69` — **P3.14** "Download everything (JSON)": complete per-dog archive, paged past the row cap
- `610f11d` — **P4.16** Board saved filters (persisted) + alerts bulk-acknowledge
- `da22f5a` — **P4.17 (+18 clinic half)** Printable Shift-handover page (last 8/12/24 h per dog)
- (this commit) — **P5** docs 02/04/05/08/09/10/12/16/19/20 + this summary

## Design/token change you should eyeball
Light-mode **status text colors got darker** to meet docs/19's own ≥4.5:1 rule (they failed as text on their soft backgrounds and on white): calm `#0F9D8C→#0C7C6F`, mild `#CA8A04→#956603`, moderate `#EA7317→#A85311`, high `#DC2626→#CA2323`, owner-coral `#E5533D→#B74231`, warm `#F59E0B→#9A6407`. Same hues, deeper. Dark palette was already compliant and is unchanged. If any of these feel too heavy, tune `design_tokens.json`, run the generator — the CI contrast test will tell you if a tweak breaks readability.

## ASSUMPTIONS / ADDED (all reversible)
1. **Demo mode is fully local** (ADR-014) — no demo account or server seeds; consent gate auto-passes there because the data is synthetic. Demo dog "Buddy the Aspin"; copy is labeled sample data and passes the no-diagnosis scan.
2. **Offline consent cache**: a *server-confirmed* acceptance of the exact current policy version is remembered on-device so an offline cold start can show cached data. Unconfirmed users still get the gate offline. If you consider even that too permissive, delete the `_consentCacheKey` block in `root_shell.dart`.
3. **`biometric_status_bands` (low floors) added to `classifier_config.json`** — vet-tunable like everything else there; Elevated/High floors now *derive* from the scoring tiers.
4. **Full export includes media as metadata only** (paths + notes, not bytes) — private-bucket objects can't be bundled client-side into one file.
5. **Handover page doubles as the clinic-period report** (step 18): per-dog printable reports already existed in Reports.
6. **Step 15 (breed/size "typical" reference) deliberately not built**: we have no reference dataset, and inventing per-breed norms would violate the "don't invent thresholds silently" guardrail. "Vs last week" already ships on Trends. Revisit when a vet supplies reference ranges.
7. `@types/node` added to dashboard devDependencies (the new fs-reading guard tests need it).

## NOT DONE (deliberately deferred, in priority order for next session)
- **P3.11 Localization (EN + Filipino)** — externalizing every user-facing string across ~27 screens is a full session on its own; doing it partially would leave a bilingual mess.
- **P3.12 Care reminders** (new table + RLS + local notifications).
- **P3.13 Caregiver sharing** (new `caregivers` table + *additive* scoped RLS on ~7 tables — security-sensitive, deserves fresh context, needs its own ADR).
- **P4.19 Responsive/tablet pass** on the dashboard.

## Needs your hands
1. **Redeploy `telemetry-intake`** — it now logs the `telemetry_intake_ms` metric line (only change to edge functions this pass).
2. **Run the live RLS proof once for the defense record** (from `services/edge`):
   `RLS_LIVE=1 SUPABASE_URL=… SUPABASE_ANON_KEY=… SUPABASE_SERVICE_ROLE_KEY=… deno test --allow-read --allow-env --allow-net rls_audit/rls_live.test.ts`
   (creates + deletes its own throwaway rows; safe against the hosted project). Screenshot the output.
3. **Collect the perf numbers** for docs/20: `npm start -- --max-ticks=30` in `firmware/simulator` (round-trip p50/p95 printed at the end); watch `[perf]` lines in the dashboard console and `flutter run` log.
4. **Eyeball the darkened status colors** (see above) and the demo-mode story on a device.
5. Unchanged pending items from before: FCM/APNs wiring, real ESP32 battery sensor, vet review of all provisional copy/thresholds.

## Exact resume prompt
> FurFeel improvement pass continuation. The 2026-07-19 master pass (MORNING_SUMMARY.md) is committed on main — no new migrations; telemetry-intake redeployed [adjust if not]. Next, in order: (a) P3.11 localization EN + Filipino (externalize all owner-app strings via flutter gen-l10n, language picker in Settings, default from device locale, clinical/observational tone in both languages, extend the no-diagnosis scan to both); (b) P3.12 care reminders (new table + RLS + local notifications); (c) P3.13 caregiver sharing (new caregivers table, additive scoped RLS — do NOT widen existing policies — plus ADR); (d) P4.19 dashboard responsive/tablet pass. Keep flutter analyze + flutter test, deno test, dashboard tsc + vitest, simulator tsc green; guardrails per CLAUDE.md (no diagnosis language, never weaken RLS, never delete raw telemetry, media never a classifier input, colors only from docs/19 tokens, thresholds vet-tunable in config).
