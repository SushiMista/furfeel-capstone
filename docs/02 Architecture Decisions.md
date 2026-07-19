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
