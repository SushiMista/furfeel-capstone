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

**Amended 2026-07-24 (same day):** the Care Team tab referenced above was retired once Chat took over the vet-note feed, leaving the dog page with **Vitals · Activity**. Care Insights moved to **Vitals** — the reasoning is unchanged (rule-derived, so it must not look like a clinician's message), only its address. The retirement also deleted `HomeTab.vetNotes`, the `_QuickLink` widget, and the `fetchVetNoteFeed` call plus the `onVetNote` realtime callback in both `RootShell` and `DogDetailPage`, so Home is one query lighter per dog load.

Linked notes:
- [[04 Mobile App Design]]
- [[09 Database Schema]]

## ADR-019: The Launch Screen Is Two Stages Pretending to Be One
Status: Accepted (2026-07-24)

Decision: Treat the cold start as a single brand moment split across two renderers. **Stage 1** is the Android 12+ system splash — the OS draws the launcher icon before Flutter exists, so it cannot be a Flutter animation; `values-v31/styles.xml` (+ `values-night-v31`) sets `windowSplashScreenBackground` so at least the canvas is brand-correct. **Stage 2** is Flutter's `SplashPage`, rendered on the *same* background with the same mark (`FurFeelLogo.auth`, the gradient paw + two-tone wordmark the auth screens already use), so the handoff reads as continuation rather than a second screen.

Consequence for the token pipeline: `generate_design_tokens.mjs` gained a fourth output, `apps/mobile/android/.../res/values{,-night}/colors.xml`. The OS paints stage 1 before any Dart runs, so it cannot read `furfeel_tokens.dart` — without generated colour resources the splash background would be a hardcoded hex in XML, drifting from `design_tokens.json` the first time the palette moves. Only the two colours the splash theme needs are emitted; everything else stays in Dart.

Launch timing: the minimum splash was **1500 ms → 400 ms**, with a 320 ms cross-fade into the first real screen. The floor exists only so a fast start doesn't flash the logo for a single frame; the old value taxed every cold start by ~1.1 s even when everything resolved in 200 ms, and the fade solves the flicker the floor was defending against.

A loader appears **only** on the signed-in settings load — a real network call that can hang — and only after 600 ms, so a quick load never flashes a bar. It is not built before then rather than built-and-transparent, since a zero-opacity widget still flashes into view on a slow frame. That 600 ms delay applies under reduced motion too: avoiding a flash is not a motion preference, and skipping it would hand reduced-motion users the worse behaviour. Reduced motion only drops the fade.

Rejected: an animated native splash via `windowSplashScreenAnimatedIcon`. It is Android 12+ only, capped around one second, and the API deliberately refuses branding text in the icon slot — so it could not show the wordmark, which is the thing the splash exists to show.

Linked notes:
- [[04 Mobile App Design]]
- [[19 Design System]]
- [[14 Deployment Plan]]

## ADR-020: Bound the Font Preload With a Timeout — an Unbounded Await Can Strand a Cold Start Forever
Status: Accepted (2026-07-25)

Decision: Wrap the pre-first-frame `GoogleFonts.pendingFonts([...])` call in `main()` with a 3-second `.timeout()`, catching failure and proceeding on the system font fallback rather than letting it block `runApp()`.

Reason: found via a real report — an installed (not `flutter run`) build stuck indefinitely on the native Android splash screen added in ADR-019. Traced to `google_fonts` 8.1.0's HTTP fetch (`google_fonts_base.dart`, `_httpFetchFontAndSaveToDevice`): `await client.get(uri)` carries **no timeout of its own**. On a dropped connection — a silently-blocking network rather than a fast failure, which some restrictive Wi-Fi/carriers produce, or simply no signal at first launch — that `await` never resolves and never throws. Since it sits before `runApp()` in `main()`, Flutter never paints a first frame, and Android never dismisses the splash it drew before Flutter existed. The bug was always latent; it only became *visible* once ADR-019 gave the native splash a real background instead of stock white, since previously the failure mode was presumably a silent stall on a blank/default screen that looked the same as "still launching."

Why this fix is safe to make unilaterally: `GoogleFonts.inter()` already sets `fontFamilyFallback` to the system font (visible in the package source), and the preload's own doc comment states its only purpose is dodging a `TextPainter` relayout assert (flutter#79084) on the very first frame — not making text render at all. Timing it out costs that one guard on a slow network, never app functionality.

Deliberately NOT applied the same way to the following `await Supabase.initialize(...)`: `Supabase.instance.client` is `late final` and read from many call sites across the app with no null-safety net. A version of this fix that lets `main()` proceed after a failed/timed-out `Supabase.initialize()` would trade a visible "stuck on splash" for a `LateInitializationError` the first time any screen touches `Supabase.instance`, which is harder to diagnose, not easier. That needs an audit of every `Supabase.instance` access site before touching it — flagged as follow-up work, not fixed here.

Linked notes:
- [[19 Design System]]
- [[02 Architecture Decisions]] (ADR-019)

## ADR-021: Drop Body Temperature as a Data Point
Status: Accepted

Decision: Remove body temperature entirely — as a wearable sensor, a telemetry field, a classifier input, a per-dog threshold override, and a displayed vital — across firmware/simulator, telemetry-intake, the classifier, the dashboard, and the mobile app. `dog_baselines.normal_body_temperature_c`/`body_temp_elevated_c`/`body_temp_high_c` are dropped by migration. `telemetry_readings.body_temperature_c` is left in place but no longer written, since raw telemetry history is never deleted (ADR-003) — only config/override columns are safe to drop outright.

Reason: FurFeel doesn't promote invasive procedures to gather stress data. Heart rate, respiratory rate, motion/posture, and ambient conditions stay as non-invasive wearable/environmental signals.

**Amendment (2026-08-07):** `telemetry_readings.body_temperature_c` is now dropped outright (`20260807130000_drop_avg_heart_rate_and_body_temperature.sql`), overriding the "keep it for raw telemetry history" call above — an explicit owner decision, made knowing it deletes any body-temperature readings already collected. The same migration also drops `avg_heart_rate_bpm` (added by ADR-024's predecessor work, `20260802031230_add_avg_heart_rate_bpm.sql`): a device-reported rolling average alongside `heart_rate_bpm`, never a classifier input, and never displayed in either client — write-only from the day it was added, so dropping it loses no user-facing functionality. Every layer that referenced either column (`packages/shared/types/telemetry.ts`, `classifier_config.json`'s `validation_ranges`, `telemetry-intake`'s types/validation/insert, and their tests) was updated in the same pass so nothing references a column that no longer exists.

Linked notes:
- [[06 IoT Wearable Device Design]]
- [[07 Sensor Data Pipeline]]
- [[08 AI Classification Pipeline]]
- [[09 Database Schema]]

## ADR-022: Extend Palette A Rather Than Adopt the Mood Board's Warm Palette
Status: Accepted (2026-08-01)

Decision: Keep the docs/19 blue + white brand exactly as-is and **extend** it, rather than re-theming to the cream/amber/terracotta direction of the Furfeel Dream Board. Four additions to `design_tokens.json`, both light and dark: (1) a full teal accent family — `accentStrong` / `accentInk` / `accentSoft` — so `accent` is no longer a lone hex usable only as a dot or chart stroke; (2) a `mid` stop per status level, for chart fills; (3) a cool `tint` set (blue / teal / periwinkle / slate) as the ground behind pet photography; (4) `warm` demoted in-file to encouragement copy only — no longer available for frames, avatars, chips, or decoration. `generate_design_tokens.mjs` now emits all four through CSS custom properties, the Tailwind theme, the Flutter `FurFeelPalette`, and Android splash resources.

Reason: the board is overwhelmingly warm and blue appears in it exactly twice, both times as a *data* colour, never as brand — following it literally meant abandoning blue. Three things argued against that. The manuscript's Chapter 3 trade-off study already selected Design 1 on documented grounds ("healthcare, calm, technological reliability"), so a warm re-theme contradicts a defended decision for a preference. Blue is the only cool hue in the system, which makes it unambiguously *interface* and frees every warm hue to mean *status* alone — a warm-branded app fights itself every time it renders a `moderate` chip, because the action colour and the warning colour become the same family. And an audit of the board found that nearly everything making it feel human is structural (radii, the arch frame, photography, the big-number-plus-sparkline card), not chromatic, so the warmth was obtainable without the palette. Warm subjects on cool tinted grounds is the resolution: dog fur is overwhelmingly brown/gold/cream, and the `tint` set is a deliberate complementary contrast rather than an accident.

Chart `mid` stops answer to a **different contrast rule than the rest of the ramp**, and this is the part worth remembering. `docs/19` §9 and `contrast.test.ts` enforced WCAG AA 4.5:1 on every token pairing, which is the rule for *text*. A sparkline bar is not text — it is a graphical object, governed by WCAG 1.4.11 at 3:1. Applying the text rule to chart fills would have forced them almost as dark as the `fg` stops and destroyed the tonal separation the chart depends on; applying no rule at all was the actual pre-existing state, and it is why the ramp had no usable chart colour and the first candidate mids landed at 2.94:1 (calm) and 2.75:1 (mild) — visible on screen in review, invisible on a white card to anyone with low vision. Both were darkened to clear 3:1 and `contrast.test.ts` gained a second assertion block so CI now enforces 4.5:1 on text pairs and 3:1 on chart fills as separate rules. `accent` itself is deliberately **not** asserted as text: at 2.3:1 on white it is a fill colour and always was, and `accentInk` is the stop that carries type.

Discovered while implementing, worth stating because it defeats eyeballing: `#0C7C6F` — the existing `calm` foreground, and the obvious candidate to reuse as `accentInk` — measures 4.48:1 against the new `accentSoft` ground and fails AA by 0.02. `#0F766E` was used instead. A token that passes against one soft background does not necessarily pass against a neighbouring one.

Deliberately NOT done: the board's composite "94% health score" ring and its AI-assistant-as-chat-character card. The first is a one-number verdict on an animal's wellbeing, which is a diagnostic claim in all but name and the line ADR-002 draws; the per-metric card in `21 Redesign Plan` §4 Phase 2 is the replacement, and no screen blends metrics into a single figure. The second was already rejected in ADR-018 for `care_guidance` on the grounds that presenting a rule engine as a person misrepresents what it is — that reasoning is unchanged by a new visual reference.

Linked notes:
- [[19 Design System]]
- [[21 Redesign Plan]]
- [[02 Architecture Decisions]] (ADR-002, ADR-018)

## ADR-023: Generate the Illustration Set as One Flat-Vector System, Tinted from Tokens
Status: Accepted (2026-08-01)

Decision: FurFeel's imagery is a single **generated flat-vector illustration set**, not sourced stock and not a per-screen grab-bag. It lives under `apps/mobile/assets/illustrations/`, registered as a directory in `pubspec.yaml`, named `snake_case` by content (`dog_resting.svg`), and drawn from the design tokens' cool palette with the dog as the only warm element in frame. Priority order — empty states first (a new user sees those first and they are currently bare), then onboarding, then the `DogAvatar` placeholder mark, then milestone/encouragement moments (the one place `warm` survives). Single-colour line marks use SVG `currentColor` so the app tints them from a token (`context.ff.*`) exactly the way Dart and CSS already do, instead of baking a hex into the asset. A seed — `placeholder_pet.svg`, a friendly mixed-breed-ambiguous dog head — is committed as the reference for line weight (matched to the Material outline icons already in use) and the `currentColor` convention.

Reason: the app currently ships **zero imagery**, and that is the single biggest reason it still reads clinical after the structural redesign (radii, tints, sparklines) is largely in place. A coherent set is a design system, not a pile of pictures: one line weight, one palette, one level of geometric abstraction, so a new empty-state illustration added in six months still belongs. Recording the approach in an ADR is what makes the set *extensible* rather than a one-off that gets replaced the next time someone needs a frame.

Update (2026-08-02) — **rendering is now wired.** `flutter_svg` (2.3.0) added; `DogAvatar`'s photoless fallback swapped from `Icons.pets` to `placeholder_pet.svg`, tinted to `brandInk` via a `ColorFilter` (the mark's `currentColor` is overridden by srcIn, so one asset serves every tint). Verified rendering in-app across circle/squircle/arch and both themes. Empty-state illustrations (`dog_sitting`, `dog_in_arch`) remain to be wired into their screens — the next apply step. Also deliberately refused, and these matter more than the aesthetics: no photorealistic generated dog ever stands in for a user's own pet (a generated photo in a profile slot invites the owner to believe they are looking at their dog — placeholders must look like illustrations), and no illustration depicts the harness reporting a diagnosis or a vet delivering a verdict (the product is decision support — ADR-002 — and illustration is exactly where that line gets crossed by accident).

Generation seeds (for extending the set consistently): flat vector, clean geometry, generous whitespace; no gradients, drop shadows, 3D render, or glossy mascot; cool ground from `brand` / `accent` / the `tint` set with a warm mixed-breed-ambiguous dog; stroke weight matched to Material outline icons; transparent background tested on both the light ground and the dark `#0B1220`.

Amendment (2026-08-02) — **real photography for generic slots.** Illustration is not the only imagery: welcome/onboarding/marketing slots take real dog photography, which carries emotional warmth the flat set deliberately does not. Decided against **AI-generated** photos — an over-rendered generated dog is precisely the "looks AI" failure the imagery gap was meant to fix, and it costs trust in a decision-support product; curated permissively-licensed **stock** (single coherent set) is the starting point, replaceable with an owned shoot later. Wired as `BrandPhotoFrame` (arch/squircle/circle, tinted ground, `Image.asset` with an `errorBuilder` fallback to the tinted mark so an un-sourced slot reads as intentional, not broken), assets under `apps/mobile/assets/photos/`. The identity rule above is unchanged and is the reason this is scoped to *generic* slots only: stock or generated photography must **never** land in a dog-identity slot (profile, avatar, monitoring cards), because a stock dog there reads as *the owner's* dog. Those slots stay owner-upload-or-illustration.

Linked notes:
- [[22 Redesign Style Prompt]]
- [[21 Redesign Plan]] §5 (imagery is the largest open item)
- [[02 Architecture Decisions]] (ADR-002)

## ADR-024: Immersive Status Hero + Per-Metric Chart Colour (owner Home)
Status: Accepted (2026-08-02)

Decision: The owner Home and the vital-detail screens adopt an **immersive full-bleed header** (docs/22 v7): the whole top is the status colour (Home) or the metric colour (detail), carrying a big value, a bold one-line description, translucent chips, and a wide curved divider (`CurvedStatusHeader` + a `CustomPainter` whose curve endpoints run past both edges so only the smooth middle shows). Home's tab bar (*Vitals · Activity · Care*) is retired — Home is one scroll: hero → health-overview list → care → activity. Each health-overview row is a `WaveSparkline` (a smooth curved line + soft fill) in that metric's own colour, tapping through to the detail. Vital detail gains the vet baseline as a dashed **coloured line** on the graph with the value highlighted on the axis, replacing the wordy callout.

Two things this **deliberately keeps** from earlier ADRs, because the mood board pushes against both: the hero shows the **classification word** ("Calm"), never a blended 0–100 number — a one-number verdict is the ADR-002 line, and "FurFeel score" here is just the `rule-v1` classification rendered large. And status still never rides on colour alone (docs/19 §9): the score hero pairs colour with the word, and an out-of-range vital still gets a worded read.

Deliberately overridden: the **monochrome-chart rule** (ADR-022 / docs/22). Health-overview waveforms now use per-metric identity colours — heart rose, breathing teal, temperature amber, activity violet — added as a `vital` token group (`context.ff.vitalHeart` …, both themes) so there is still zero hardcoded hex. This was the owner's explicit call, made against a flagged trade-off. The mitigation that keeps it safe: the **stress status** (the thing that means *how bad*) lives in the score hero and its colour, not in the individual metric hues (which mean *which metric*); so the two colour systems don't compete the way they would if a vital's hue implied severity. If that separation ever blurs in testing, revisit.

**Note (integration-test merge, ADR-021 supersedes the "temperature amber" line above):** ADR-021 (accepted first, from `jed-vet-dashboard`) drops body temperature entirely as a displayed vital. This ADR was written on a branch that predates that decision. The `vital` token group and the redesigned vitals/home screens keep heart/breathing/activity colours only — temperature is not implemented as a fourth identity colour. See flagged follow-up in the merge notes.

Linked notes:
- [[22 Redesign Style Prompt]] (v1–v7 iterations)
- [[02 Architecture Decisions]] (ADR-002, ADR-021, ADR-022)
