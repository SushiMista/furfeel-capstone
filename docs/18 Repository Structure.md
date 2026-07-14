---
title: "Repository Structure"
type: architecture
project: FurFeel
created: 2026-07-10
tags: [furfeel, repo, structure]
---

# Repository Structure

Single **monorepo** so the shared telemetry contract, types, and docs stay in sync across firmware, backend, and clients.

```
furfeel/
  README.md
  .env.example
  apps/
    mobile/                 # Flutter — owner + staff app
      lib/
        features/           # dog_status, alerts, history, auth, device_pairing
        services/           # supabase client, realtime subscriptions
        models/
      test/
    dashboard/              # React (Vite) — veterinary dashboard
      src/
        pages/              # overview, monitoring_board, dog_detail, alerts, reports
        components/
        lib/                # supabase client, realtime hooks
      tests/
  services/
    edge/                   # Supabase Edge Functions (Deno/TypeScript)
      telemetry-intake/     # validate → store → classify → alert
      classifier/           # rule-v1 scoring (importable, unit-tested)
      alerts/               # alert evaluation helpers
  supabase/
    migrations/             # numbered SQL: schema, enums, RLS policies, indexes
    seed/                   # local dev seed data (1 clinic, 1 owner, 1 dog, 1 device)
    config.toml
  firmware/
    esp32/                  # device firmware (Arduino/PlatformIO)
    simulator/              # payload simulator posting to /telemetry (stands in for hardware)
  packages/
    shared/                 # shared TS types: telemetry payload, enums, classifier config
  docs/                     # exported specs (source of truth remains the Obsidian vault)
```

## Conventions
- One migration per change, numbered; never edit a shipped migration.
- `packages/shared/classifier_config.json` holds the provisional thresholds from `08 AI Classification Pipeline` so vet-tunable values live in one place.
- The **simulator** lets all software sprints proceed before hardware is ready — treat it as a first-class dev tool.
- `.env.example` lists every required key (Supabase URL, anon key; service role only in Edge Function env).

## Suggested build sequence
`supabase/migrations` → `services/edge/telemetry-intake` + `classifier` → `firmware/simulator` → `dashboard` latest-reading view → `mobile` status view → alerts → history/reports.

## Related
- [[09 Database Schema]]
- [[10 API and Backend Services]]
- [[16 MVP Development Plan]]
- [[17 Technology Stack]]
