---
title: "Technology Stack"
type: stack
project: FurFeel
created: 2026-07-09
updated: 2026-07-12
tags: [furfeel, stack, development]
---

# Technology Stack

## Confirmed Stack
- Mobile app: **Flutter** (Dart 3, Material 3).
- Web dashboard: **React + Vite** (TypeScript).
- Backend and database: **Supabase** (PostgreSQL, Auth, Realtime, Storage, Edge Functions).
- Device connectivity: **ESP32 over Wi-Fi**; simulator (`firmware/simulator`, Node) stands in until hardware exists.
- Initial classification: **rule-based** (`rule-v1`, thresholds in `packages/shared/classifier_config.json`).
- Future classification: **Random Forest** after expert-validated labeled data (collected via the dashboard's confirm/override → `stress_labels`).

## As-built implementation detail (2026-07-12)
| Layer | What's actually used |
|---|---|
| Dashboard UI | React + Vite + Tailwind, shadcn-style primitives, **Tremor** charts, lucide icons |
| Mobile UI | Flutter Material 3, `fl_chart`, `flutter_animate`, `google_fonts`, `shadcn_flutter` (scoped locally, not the app root — ADR-017) |
| Design tokens | `packages/shared/design_tokens.json` → generates dashboard CSS vars + Tailwind theme and Flutter `ThemeData` (light + dark, AA-checked). Font **Inter**. Blue + white brand (see [[19 Design System]]) |
| Edge Functions (Deno/TS) | `telemetry-intake` (validate → store → classify → alert → offline-recovery), `delete-account` (ADR-003-safe) |
| Server-side logic | SQL RPCs: `stress_daily_summary`, `stress_hourly_pattern`, `vet_note_feed`, `set_dog_photo`, `pair_device`; pg_cron device-offline job |
| Storage | Private `avatars` (own-folder) + `media` (owner/clinic-scoped) buckets |
| Shared code | `packages/shared` — types + classifier config + design tokens (one source of truth for both apps) |

## Supabase Responsibilities
PostgreSQL · Auth + user roles · Row Level Security (every table + storage) · Realtime (telemetry/classifications/alerts) · Storage (avatars, supplementary media) · Edge Functions for telemetry intake, classification, alerts, and account deletion.

## Development Implication
Supabase is the central backend platform — avoid duplicating auth, database, storage, and realtime logic elsewhere unless a specific limitation appears (record it as an ADR). Both clients use the **anon/publishable key only**; the service-role key lives solely in Edge Function env.

## Related
- [[09 Database Schema]]
- [[10 API and Backend Services]]
- [[07 Sensor Data Pipeline]]
- [[08 AI Classification Pipeline]]
- [[19 Design System]]
- [[Developer Setup Guide]]
