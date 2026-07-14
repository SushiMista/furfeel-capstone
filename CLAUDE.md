# CLAUDE.md — FurFeel (code repository)

> Repo-root instructions for Claude Code. The full specs live in `docs/` (copied from the FurFeel Obsidian vault). Where this file and any doc disagree, **this file and the Locked Direction win.**

## What FurFeel Is
Real-time **canine stress monitoring** for vet clinics and dog owners. A wearable ESP32 harness streams telemetry to Supabase; a **rule-based** classifier assigns a stress level (**calm / mild / moderate / high**) and raises alerts. Owners use a Flutter app; clinics use a React dashboard. **Decision support, not diagnosis.**

## Locked Direction (do not change without an ADR in docs/)
| Area | Decision |
|---|---|
| Mobile app | **Flutter** (owner + staff) |
| Web dashboard | **React (Vite)** (veterinary) |
| Backend + DB | **Supabase** (Postgres, Auth, Realtime, Storage, Edge Functions) |
| Device link | **ESP32 over Wi-Fi**, direct telemetry (no phone relay in MVP) |
| Initial classifier | **Rule-based** (`rule-v1`) — NOT "Random Forest" yet |
| Future classifier | Random Forest, only after expert-labeled data exists |
| Owner media | Supplementary only — **never a classifier input** |

## Monorepo Layout
```
furfeel/
  apps/mobile/          # Flutter owner + staff app
  apps/dashboard/       # React (Vite) veterinary dashboard
  services/edge/        # Supabase Edge Functions: telemetry-intake, classifier, alerts
  supabase/migrations/  # SQL schema + RLS + indexes
  supabase/seed/        # local dev seed data
  firmware/esp32/       # device firmware
  firmware/simulator/   # payload simulator (use this before hardware exists)
  packages/shared/      # shared types + classifier_config.json
  docs/                 # finalized specs (source of truth = Obsidian vault)
```

## Build Order
Vertical slice (steps 1–6) is **done and live**. Current phase: **full-fledged apps** — re-theme to the design guide, then build the remaining manuscript modules.
1. ✅ Supabase migration from `docs/09 Database Schema` (schema + RLS + seed).
2. ✅ `services/edge/telemetry-intake` + `classifier` (rule-v1).
3. ✅ `firmware/simulator`.
4. ✅ React dashboard (board, dog detail, alerts, reports, vet notes).
5. ✅ Flutter owner app (status, alerts, history).
6. ✅ Alerts on moderate/high + device-offline + acknowledge + history.
7. **Design guide re-theme (blue + white):** `docs/19 Design System` → `packages/shared/design_tokens.json` → generated CSS/Tailwind + Material 3 theme. Dashboard = shadcn/ui + Tremor; mobile = Material 3 + fl_chart. No hardcoded hex.
8. **Dashboard modules:** Vet Review media + **confirm/override → `stress_labels`** (ground truth), Admin (`docs/05`).
9. **Mobile modules:** Pet Creation, Device Pairing, Vet Review (owner), Care Insights (`care_guidance`), Observation Assessment, push notifications (`docs/04`).

> Full app scope + new tables: `docs/04 Mobile App Design`, `docs/05 Veterinary Dashboard Design`, `docs/09 Database Schema` (`stress_labels`, `care_guidance`). All UI follows `docs/19 Design System`.

## Coding Conventions
- Tables plural `snake_case`; every table `id uuid default gen_random_uuid()`, `created_at timestamptz default now()`; UTC.
- Validate every input server-side; **never trust device payloads**.
- **Store raw telemetry before classification** (ADR-003). Never delete raw telemetry.
- Secrets in `.env` (commit `.env.example`); service role key only in Edge Function env, never in a client.
- Provisional thresholds live in `packages/shared/classifier_config.json` so a vet can tune them.
- Small, scoped commits; one feature per PR; reference the spec doc.

## Definition of Done (summary)
Meets its checklist criteria; validates + stores data; enforces RLS; has a happy-path test; renders in the right client; doesn't break the vertical slice. Full: `docs/08 Definition of Done`.

## Hard Guardrails
- No media into the classifier. No "diagnosis" language. Don't rename the MVP classifier "Random Forest".
- Don't weaken RLS to make something work — fix the policy.
- Don't invent thresholds silently — use `docs/08 AI Classification Pipeline` and flag changes.
- When you hit an unresolved item in `docs/15 Open Technical Questions`, stop and ask.

## How to Work
Confirm the target sprint → open its checklist + matching spec in `docs/` → restate acceptance criteria → write migration/schema first, then backend, then client → log any architectural choice as an ADR in `docs/02 Architecture Decisions`.
