<div align="center">

# 🐾 FurFeel

**Real-time canine stress monitoring for veterinary clinics and dog owners.**

A wearable ESP32 harness streams physiological, behavioral, and environmental telemetry to Supabase. A rule-based classifier (`rule-v1`) assigns a stress level — **calm / mild / moderate / high** — explains *why*, and raises alerts. Dog owners use a Flutter app; clinics use a React dashboard.

> **Decision support, not diagnosis.** FurFeel never diagnoses illness; clinical judgment stays with veterinarians.

![status](https://img.shields.io/badge/status-active%20development-2563EB)
![mobile](https://img.shields.io/badge/mobile-Flutter-02569B)
![dashboard](https://img.shields.io/badge/dashboard-React%20%2B%20Vite-61DAFB)
![backend](https://img.shields.io/badge/backend-Supabase-3ECF8E)
![license](https://img.shields.io/badge/license-MIT-green)

</div>

---

## What it does

- **Wearable telemetry** — heart rate, respiratory rate, body temperature, motion/posture, ambient temperature & humidity (ESP32 over Wi-Fi; a software simulator stands in until hardware is ready).
- **Rule-based stress classification** (`rule-v1`) with transparent scoring, a plain-language "why," and a clear upgrade path to a **Random Forest** once expert-labeled data exists.
- **Alerts** on moderate/high stress and device-offline, with acknowledge + history.
- **Owner mobile app (Flutter)** — personalized home, trends & insights, care guidance, pet profiles, device pairing, accounts, settings, dark mode.
- **Veterinary dashboard (React)** — multi-dog monitoring board with photo cards, dog detail, alerts queue, vet notes, reports, an admin surface, and a **confirm/override** flow that collects vet-labeled ground truth.
- **Supabase backend** — Postgres + Auth + Realtime + Storage + Edge Functions, with Row Level Security on every table and bucket.

## Monorepo layout

```
furfeel/
  apps/mobile/         # Flutter owner app
  apps/dashboard/      # React (Vite) veterinary dashboard
  services/edge/       # Supabase Edge Functions (telemetry-intake, classifier, alerts, delete-account)
  supabase/            # SQL migrations, seed, config
  firmware/esp32/      # device firmware (WIP)
  firmware/simulator/  # telemetry simulator (use before hardware exists)
  packages/shared/     # shared types, classifier config, design tokens
  docs/                # full specs, design guide, setup guide, build plan
```

## Quick start

Full cross-platform instructions (Windows + macOS), including the AI toolchain used to build this, are in **[`docs/Developer Setup Guide.md`](docs/Developer%20Setup%20Guide.md)**. Short version:

```bash
# 1. install: Node 18+, Flutter 3.12+, (Supabase CLI for backend work). Docker NOT required.
# 2. configure env files (copy each .example, add your Supabase URL + anon key)
cp apps/dashboard/.env.example apps/dashboard/.env
cp apps/mobile/env.json.example apps/mobile/env.json
cp firmware/simulator/.env.example firmware/simulator/.env

# 3. run
cd apps/dashboard && npm install && npm run dev          # dashboard
cd apps/mobile && flutter run -d chrome --dart-define-from-file=env.json   # owner app
cd firmware/simulator && npm install && npm start -- --sweep               # live data
```

Seed logins: owner `owner@example.com` · vet `vet@example.com` — both `password123`.

## Testing

```bash
cd apps/dashboard && npm test      # vitest + tsc + build
cd apps/mobile && flutter test     # flutter analyze + widget/unit tests
cd services/edge && deno test      # Edge Function + classifier tests
```

## Architecture & specs

`CLAUDE.md` holds the locked architecture decisions and guardrails. `docs/` contains the full specs — database schema, API, classification pipeline, design system, and the sprint-by-sprint build plan. Source of truth for the specs is the project's Obsidian vault; `docs/` is the exported copy.

## Status & roadmap

The software MVP is built and running on both surfaces (see `docs/Build Status`). Deliberately deferred: real ESP32 firmware (simulator stands in) and the Random Forest model (rule-v1 until the vet-labeling loop collects enough ground truth). Remaining project work is largely evaluation and defense evidence.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) and the Developer Setup Guide. Key rules: never weaken Row Level Security, never commit secrets, keep colors token-driven (`docs/19 Design System`), and no "diagnosis" language.

## Security

Both clients use the Supabase **anon/publishable key only**; the service-role key lives solely in Edge Function environments. Never commit `.env` files or device keys. To report a vulnerability, open a private security advisory rather than a public issue.

## License

Released under the [MIT License](LICENSE). *(Capstone team: change this if your program requires a different license.)*

---

<div align="center">
FurFeel — a canine stress classification and monitoring capstone project.
</div>
