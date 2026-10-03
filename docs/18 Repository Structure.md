---
title: "Repository Structure"
type: architecture
project: FurFeel
created: 2026-07-10
updated: 2026-10-04
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
        data/               # repository, auth helpers, cache, audit, push token registration
        screens/            # auth, home, dogs, vitals, observations, settings
        widgets/            # reusable owner-app UI
        theme/              # generated/bridged design tokens + Material theme
        models/
      test/
    dashboard/              # React (Vite) — veterinary dashboard
      src/
        pages/              # overview, board, dog detail, alerts, reports, vet review, admin, devices, teams, intake
        components/
        lib/                # Supabase client, queries, admin/audit/bug-report helpers
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
    shared/                 # shared types, classifier config, design tokens
  ml/                       # research/training utilities only; not runtime classifier-v1
  docs/                     # exported specs (source of truth remains the Obsidian vault)
```

## Conventions
- One migration per change, numbered; never edit a shipped migration.
- `packages/shared/classifier_config.json` holds the provisional thresholds from `08 AI Classification Pipeline` so vet-tunable values live in one place.
- The **simulator** lets all software sprints proceed before hardware is ready — treat it as a first-class dev tool.
- `.env.example` lists every required key (Supabase URL, anon key; service role only in Edge Function env).

## Suggested build sequence
The original vertical slice is complete. Current work should follow the target module's spec first, then update migrations/RLS, Edge Functions/RPCs, and the relevant client. The runtime classifier remains `rule-v1`; `ml/` utilities are future/research support until expert-labeled data exists.

## Related
- [[09 Database Schema]]
- [[10 API and Backend Services]]
- [[16 MVP Development Plan]]
- [[17 Technology Stack]]
