---
title: "Architecture Decisions"
type: adr-log
project: FurFeel
created: 2026-07-09
tags: [furfeel, architecture, decisions]
---

# Architecture Decisions

Use this note as the decision log. Each important development choice should be recorded here so the team remembers why it was chosen.

## ADR-001: Build Around a Vertical Slice First
Status: Proposed

Decision: Build one end-to-end telemetry flow before expanding features.

Reason: FurFeel has hardware, software, cloud, and AI risk. A vertical slice exposes integration issues early.

Linked notes:
- [[01 System Overview]]
- [[16 MVP Development Plan]]

## ADR-002: Treat AI as Decision Support
Status: Proposed

Decision: The stress classifier should support veterinary judgment, not replace it.

Reason: The manuscript positions FurFeel as a decision support system. Clinical interpretation should remain with professionals.

Linked notes:
- [[08 AI Classification Pipeline]]
- [[12 Security and Privacy]]

## ADR-003: Store Raw Telemetry Before Classification
Status: Proposed

Decision: Save raw and cleaned telemetry before storing AI classification output.

Reason: Raw history helps debugging, retraining, audit, and future research.

Linked notes:
- [[07 Sensor Data Pipeline]]
- [[09 Database Schema]]

## ADR-004: Keep Owner and Clinic Views Separate
Status: Proposed

Decision: The mobile app and veterinary dashboard should share data but present role-specific views.

Reason: Owners need clarity and reassurance. Clinics need multi-dog monitoring, review, and reports.

Linked notes:
- [[03 User Roles and Permissions]]
- [[04 Mobile App Design]]
- [[05 Veterinary Dashboard Design]]

## ADR-005: Use Flutter for Mobile
Status: Accepted

Decision: Build the dog-owner and mobile staff app with Flutter.

Reason: Flutter provides a single mobile codebase and is practical for building a polished MVP quickly.

Linked notes:
- [[04 Mobile App Design]]
- [[17 Technology Stack]]

## ADR-006: Use React for Web Dashboard
Status: Accepted

Decision: Build the veterinary web dashboard with React.

Reason: React is a strong fit for live dashboard screens, reusable components, and Supabase realtime integration.

Linked notes:
- [[05 Veterinary Dashboard Design]]
- [[17 Technology Stack]]

## ADR-007: Use Supabase as Backend Platform
Status: Accepted

Decision: Use Supabase for the backend platform, including PostgreSQL database, authentication, realtime updates, storage, and service logic where appropriate.

Reason: Supabase gives the team a fast development path without building auth, database, and realtime infrastructure from scratch.

Linked notes:
- [[09 Database Schema]]
- [[10 API and Backend Services]]
- [[17 Technology Stack]]

## ADR-008: ESP32 Sends Telemetry Through Wi-Fi
Status: Accepted

Decision: The ESP32 will connect through Wi-Fi and transmit telemetry directly into the backend/database flow.

Reason: Direct Wi-Fi transmission removes the need for a phone relay during MVP testing and keeps the telemetry path easier to validate.

Linked notes:
- [[06 IoT Wearable Device Design]]
- [[07 Sensor Data Pipeline]]

## ADR-009: Start With Rule-Based Stress Classification
Status: Accepted

Decision: Use rule-based stress classification during MVP because the team does not yet have expert-validated labeled training data.

Reason: This allows development of telemetry, alerting, UI, and evaluation workflows immediately while leaving a clear upgrade path to Random Forest once labels are validated.

Linked notes:
- [[08 AI Classification Pipeline]]
- [[13 Testing Strategy]]

## ADR-010: Treat Submitted Videos as Supplementary Assessment Material
Status: Accepted

Decision: Owner-submitted videos are supplementary communication material for veterinarians and dog owners. They are not part of the Random Forest input pipeline.

Reason: Videos provide clinical context and communication support, but the stress classifier should remain based on structured telemetry data.

Linked notes:
- [[04 Mobile App Design]]
- [[05 Veterinary Dashboard Design]]
- [[12 Security and Privacy]]

## ADR-011: Google Sign-In via Supabase OAuth (Browser Flow)
Status: Accepted

Decision: Add "Continue with Google" to the mobile app's auth screens using Supabase's OAuth browser flow (`signInWithOAuth`) for all platforms, rather than the native `google_sign_in` SDK. The deep link `io.furfeel.app://login-callback` returns mobile users to the app; web passes `redirectTo: Uri.base.origin` explicitly — with no `redirect_to`, GoTrue falls back to the project **Site URL** (the dashboard's port), which surfaces as "this site can't be reached" when that app isn't running. Every return URL must be on the Auth redirect allow-list, and Supabase doesn't support port wildcards, so Flutter-web dev runs pin their port (`--web-port 5175`, allow-listed alongside the dashboard's 5173/5174 and the deep link). The `handle_new_user` trigger falls back to `full_name` metadata so Google signups get a proper display name.

Reason: One code path covers web, Android, and iOS with zero client-held secrets (the Google client secret lives only in the Supabase provider config). The native SDK flow can be added later purely as a UX upgrade without schema or provider changes. Google accounts sharing an email with an existing password account are auto-linked by Supabase, so no duplicate-user handling is needed.

Linked notes:
- [[04 Mobile App Design]]
- [[09 Database Schema]]
- [[12 Security and Privacy]]

## ADR-012: Flutter Theming via ThemeExtension (FurFeelPalette)
Status: Accepted (2026-07-19)

Decision: The mobile color tokens are a Material `ThemeExtension` (`FurFeelPalette`, generated from `design_tokens.json` with `light`/`dark` instances, `copyWith`, `lerp`) registered on `ThemeData.extensions`. Widgets read colors through `context.ff`; `MaterialApp` receives `theme` + `darkTheme` + `themeMode`, so light/dark/system switching is Flutter's own mechanism. The previous `FurFeelTokens.isDark` mutable static and full-tree rebuild are removed. Non-color tokens (spacing, radius, type, motion) stay compile-time consts on `FurFeelTokens`.

Reason: Theme now flows through context (per-subtree theming possible, e.g. a forced-light PDF preview), no global mutable state, and `lerp` gives free cross-fade on theme change. Helpers that return colors take a `BuildContext` (or use `FurFeelPalette.light` explicitly, as the print-oriented PDF exporter does).

Linked notes:
- [[19 Design System]]

## ADR-013: Classifier-Derived Codegen for Client Thresholds
Status: Accepted (2026-07-19)

Decision: Client-side copies of classifier thresholds are code-generated, never hand-mirrored. `generate_classifier_bands.mjs` emits `apps/mobile/lib/insights/biometric_bands.g.dart` from `classifier_config.json`; the Elevated/High status-band floors are derived from the scoring tiers themselves (tier 1 min → Elevated, tier 2 min → High), and only the app-specific Low floors are new config (`biometric_status_bands`). A staleness test re-derives every constant from the JSON in CI.

Reason: The bands can no longer drift from what actually scores (retired QA assumption 4); a vet tuning the config only touches one file, and CI fails until the generated file is refreshed.

Linked notes:
- [[08 AI Classification Pipeline]]

## ADR-014: Demo Mode as a Local Repository Implementation
Status: Accepted (2026-07-19)

Decision: Demo mode is a second implementation of the existing `FurFeelRepository` interface (`DemoRepository`) with a deterministic generated week of sample telemetry, running entirely in memory — no demo account, no seeded server data, no network. The real `RootShell` renders it behind a persistent "Demo mode — sample data" banner; writes throw friendly read-only errors; the consent gate auto-passes because it protects real monitoring data, not synthetic samples.

Reason: Zero server surface (no demo credentials to leak, no RLS special cases, no cleanup jobs), works offline for defense demos, and exercises the exact production UI code paths.

Linked notes:
- [[04 Mobile App Design]]
- [[12 Security and Privacy]]

## ADR-015: Per-Dog Classifier Thresholds on `dog_baselines`, Not a New Table
Status: Accepted (2026-07-21)

Decision: A vet can override this dog's score→level cut points via three new nullable columns on the existing `dog_baselines` row (`threshold_mild_min`, `threshold_moderate_min`, `threshold_high_min`) rather than a new table. Three cut points, not four (min, max) pairs — calm is implicit below `threshold_mild_min`, and each level's max is simply the next level's min, so the boundaries can't drift out of sync. NULL means "use `classifier_config.json`'s `level_thresholds`," resolved per-field exactly like the existing resting-value baseline columns (`services/edge/telemetry-intake/baselines.ts`'s `resolveLevelThresholds`, mirroring `resolveBaselines`). No new RLS: `dog_baselines_select/insert/update` already gate on `is_clinic_member(dog_id)` for these same rows.

Reason: `dog_baselines` is already per-dog, already clinic-scoped, and already read on every classification — reusing it avoids a second table, a second set of policies, and a second resolver mechanism for what is conceptually the same kind of override (a per-dog number that falls back to a global default).

Linked notes:
- [[08 AI Classification Pipeline]]
- [[09 Database Schema]]
- [[05 Veterinary Dashboard Design]]

## ADR-016: Per-Variable Scoring Thresholds, Alongside (Not Replacing) Per-Level Cutoffs
Status: Accepted (2026-07-23)

Decision: Add 11 more nullable columns to `dog_baselines` — `hr_ratio_elevated_min`/`_moderate_min`/`_high_min`, `rr_ratio_elevated_min`/`_high_min`, `body_temp_elevated_c`/`_high_c`, `motion_elevated_min`/`_high_min`, `ambient_heat_c`, `humidity_heat_pct` — one per tier floor in `classifier_config.json.scoring_rules`. These let a vet override *when an individual signal starts scoring* (e.g. this dog's heart rate counts as elevated above a 1.10 ratio, not the global 1.15), independent of ADR-015's score-level cutoffs, which only control *how many total points* reach mild/moderate/high. Both mechanisms coexist in the same dashboard "Thresholds" tab, grouped by variable. Resolved by `resolveScoringRules` (`services/edge/telemetry-intake/baselines.ts`), mirroring `resolveLevelThresholds`'s per-field fallback shape: only each tier's `min` is overridable — `points` and `reason` always come from the global config, and every tier's `max` is recomputed from the next tier's (possibly overridden) `min` so a partial override can never leave a scoring gap or overlap. No new RLS (same `dog_baselines` row, same `is_clinic_member` gate).

Reason: dogs vary enough by size/breed that a single global "elevated heart rate" ratio is wrong for many of them (a large dog's calm resting rate can sit close to a small dog's already-elevated one) — this was surfaced directly by veterinary review of the initial per-level-only design. Reusing `dog_baselines` again (rather than a new table, or a JSONB blob) keeps one row per dog, one resolver pattern, and no new authorization surface, at the cost of a wider table — judged acceptable since every column is a single nullable numeric with no relational complexity.

Linked notes:
- [[08 AI Classification Pipeline]]
- [[09 Database Schema]]
- [[05 Veterinary Dashboard Design]]
- [[Threshold Validation Document]]

## ADR-017: `shadcn_flutter` Piloted Locally, Not Adopted as the App Root
Status: Accepted (2026-07-24)

Decision: Add `shadcn_flutter` as a dependency and use its `Card`, `Divider`, and `NumberTicker` in `overview_stats_card.dart` and `settings_group.dart`, scoped to those widgets via a local `shadcn.Theme` wrapper (`lib/theme/shadcn_bridge.dart` maps `FurFeelTokens` onto a `shadcn.ThemeData`/`ColorScheme` — docs/19 stays authoritative for color; no shadcn stock palette). The app root stays `MaterialApp`; `ShadcnApp` is NOT adopted. This is possible because shadcn_flutter's `Theme`/`ComponentTheme` are plain `InheritedTheme`s (confirmed by reading the installed 0.0.53 source) that these three components read via `Theme.of`/`ComponentTheme.maybeOf` (null-safe) — none of the three touch `Localizations`, `Overlay`, or `Navigator`, so they don't need `ShadcnApp`'s `WidgetsApp` machinery.

Reason: `ShadcnApp` wraps `WidgetsApp` directly — it's an architectural peer of `MaterialApp`, not a themeable component layer, despite pub.dev's README claiming components can be mixed into an existing `MaterialApp` (the package's own example app only ever shows `ShadcnApp` as literal root; this claim wasn't found demonstrated anywhere in the source). Adopting it app-wide would mean a root swap, re-deriving the Material-specific fade-through `pageTransitionsTheme`, fixing 81 `Theme.of` call sites, and rewriting the 24 test files that wrap in `MaterialApp` — a multi-day, high-regression-risk change for what the user actually wanted (two specific components' visual upgrade). Verify per-component before relying on this pattern again: not every shadcn widget is dependency-free the way these three are (e.g. anything overlay-based — Toast, Popover, Dialog, Tooltip — almost certainly needs `ShadcnApp`'s handlers and was not attempted here).

Linked notes:
- [[19 Design System]]
- [[overview_stats_card.dart]]
- [[settings_group.dart]]

## ADR-018: Chat Is a Detached Nav Box Over the Existing `media_messages` Substrate
Status: Accepted (2026-07-24)

Decision: Give owner↔clinic messaging a top-level entry point — a **detached box beside the four-pill floating bar**, not a fifth pill — opening a per-dog conversation view built on the **existing** `media_messages` threads. No new table, no new policy: `media_messages` is already RLS'd to the dog's owner + that dog's clinic staff (`media_messages_select/insert_owner_or_clinic`), already in the realtime publication, and already has author-only edit/delete from `20260721090000_media_conversation_crud.sql`. `FloatingNavBar` gained one `detachLast` flag; indices are unchanged, so the detached destination is still just `destinations.length - 1`.

Reason (detached, not a fifth pill): five labelled items don't fit a 375pt-wide fixed-height bar once labels scale — the first build overflowed by 4px because "Chat" wrapped to a second line. Beyond the layout, messaging is a different *kind* of destination than a view switch, so a distinct affordance reads correctly. Labels now carry `maxLines: 1` + `softWrap: false`, since in a fixed-height bar a wrap is a layout error rather than a cosmetic one; `floating_nav_bar_test.dart` pins that (verified by mutation — removing the wrap guard reproduces the overflow).

The care-team reminder pinned above the threads is the latest **`vet_notes`** entry, not `care_guidance`. Both were candidates; only `vet_notes` is written by an identifiable clinician. `care_guidance` is rule-derived from the stress level, so rendering it as a chat bubble with an author would present an algorithm as a person's message — the same decision-support line ADR-002 draws. It stays on the dog's Care Team tab under its "general guidance — not a diagnosis" label.

Known limits, deliberately shipped: (1) `media_submissions.storage_path` is `not null`, so a thread can only be *started* by sharing media — the empty state states this instead of offering a composer that cannot work; making that column and `media_type` nullable is the phase-3 change that unlocks text-only messages while reusing every existing policy. (2) No unread badge, because no per-user read state exists on either table and a badge that never clears is worse than none — `last_read_at` is the prerequisite.

Linked notes:
- [[04 Mobile App Design]]
- [[09 Database Schema]]
