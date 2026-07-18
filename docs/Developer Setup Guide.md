---
title: "Developer Setup Guide"
type: guide
project: FurFeel
created: 2026-07-12
tags: [furfeel, setup, onboarding, dev]
---

# FurFeel — Developer Setup Guide (Windows & macOS)

Get a new developer from zero to running the dashboard, the owner app, and the telemetry simulator against the shared Supabase project. Works on **Windows** and **macOS**. Read `CLAUDE.md` and `docs/18 Repository Structure` for the big picture.

## 0. What you're setting up
FurFeel is a monorepo with three runnable pieces, all pointed at one shared Supabase backend:
- `apps/dashboard` — React (Vite) veterinary dashboard.
- `apps/mobile` — Flutter owner app.
- `firmware/simulator` — Node script that posts fake telemetry (stands in for the ESP32 hardware).

**Most devs only need to read/run the apps** — that just needs the Supabase URL + anon key (both safe to share). You only need the Supabase CLI, service-role key, and `db push` / `functions deploy` if you're changing the **database or Edge Functions**.

## 1. Prerequisites
| Tool | Version | Needed for |
|---|---|---|
| Git | any recent | cloning the repo |
| Node.js | 18+ (20+ recommended) | dashboard, simulator |
| Flutter SDK | 3.12+ (Dart 3) | mobile app |
| Supabase CLI | latest | DB migrations / function deploys (backend devs only) |
| VS Code (or any editor) | — | editing |
| Google Chrome | — | running the Flutter app in the browser |

> **Docker is NOT required.** You'll see a Docker warning on `supabase db push` — it only skips a local cache step and is safe to ignore for hosted development.

### macOS install
Install [Homebrew](https://brew.sh) if you don't have it, then:
```
brew install node git
brew install --cask flutter
brew install --cask google-chrome
npm install -g supabase
```
Run `flutter doctor` and follow any prompts (Xcode is only needed for the iOS simulator; Chrome/web is enough to start).

### Windows install
Use **winget** (built into Windows 11 / recent 10) in PowerShell:
```
winget install Git.Git
winget install OpenJS.NodeJS.LTS
winget install Google.Chrome
winget install Supabase.CLI
```
Then install **Flutter** manually (winget's Flutter is unofficial): download the SDK zip from https://docs.flutter.dev/get-started/install/windows, extract to `C:\src\flutter`, and add `C:\src\flutter\bin` to your **PATH** (Settings → "Edit environment variables"). Close and reopen your terminal, then run:
```
flutter doctor
```
Enable **Developer Mode** if it asks (Settings → Privacy & security → For developers). No Android Studio needed to start — Chrome/web is enough.

> If `flutter` / `node` / `supabase` "isn't recognized," your PATH didn't refresh — open a **new** terminal.

## 2. Get the code
```
git clone <your-repo-url> furfeel
cd furfeel
```
Install JS dependencies for the two Node projects:
```
cd apps/dashboard && npm install && cd ../..
cd firmware/simulator && npm install && cd ../..
```
Flutter dependencies are fetched automatically on first `flutter run` (or run `flutter pub get` inside `apps/mobile`).

## 3. Configuration (env files)
Get these two values from the Supabase project (Project Settings → API), or ask a teammate:
- **Project URL** (e.g. `https://xxxx.supabase.co`)
- **anon / publishable key** (safe to share; RLS is the real gate)

Create the env files by copying each `.example` and filling values. **Never commit real keys** — all these files are gitignored.

**`apps/dashboard/.env`**
```
VITE_SUPABASE_URL=https://xxxx.supabase.co
VITE_SUPABASE_ANON_KEY=<anon key>
```

**`apps/mobile/env.json`** (copy from `env.json.example`)
```
{
  "SUPABASE_URL": "https://xxxx.supabase.co",
  "SUPABASE_ANON_KEY": "<anon key>"
}
```

**`firmware/simulator/.env`** (copy from `.env.example`)
```
FURFEEL_FUNCTION_URL=https://xxxx.supabase.co/functions/v1/telemetry-intake
FURFEEL_DEVICE_CODE=FURFEEL-DEV-0001
FURFEEL_DEVICE_KEY=<ask a teammate — the plaintext device ingest key>
```
> `FURFEEL_DEVICE_KEY` is the one secret that isn't derivable — it's the plaintext ingest key for the seed device, stored only as a hash in the DB. Get it from whoever provisioned the device, or re-provision a device (see §6).

**Root `.env`** (only if you deploy Edge Functions) — copy from `.env.example`, add `SUPABASE_SERVICE_ROLE_KEY` (secret; Edge-Function env only, never in a client).

## 4. Test accounts (shared dev data)
- Owner (mobile app): `owner@example.com` / `password123`
- Vet (dashboard): `vet@example.com` / `password123`
- Admin (dashboard → Admin module): `admin@example.com` / `password123`

## 5. Run it
Open a separate terminal tab per piece.

**Dashboard:**
```
cd apps/dashboard
npm run dev
```
Open the printed `localhost` URL → sign in as the vet.

**Owner app (Chrome):**
```
cd apps/mobile
flutter run -d chrome --web-port 5175 --dart-define-from-file=env.json
```
Sign in as the owner. **Keep `--web-port 5175`** — Google sign-in only redirects back to allow-listed URLs, and `http://localhost:5175` is the port on the Supabase Auth allow-list (a random port ends in "this site can't be reached" after the Google screen). No Chrome device? Use `flutter run -d web-server --web-port 5175 --dart-define-from-file=env.json` and open the URL in any browser. (On Windows you can also target the desktop app with `-d windows`.)
In the run terminal: `r` = hot reload, `R` = hot restart, `q` = quit.

**Simulator (live data):**
```
cd firmware/simulator
npm start -- --sweep
```
Watch stress climb calm → high on both clients. `--sweep-ticks=N` and `--interval-ms=N` tune it; omit `--sweep` for steady readings.

## 6. Backend changes (migrations & functions) — backend devs only
Requires the Supabase CLI logged in and linked:
```
supabase login
supabase link --project-ref <project-ref>   # the xxxx from the Project URL; prompts for the DB password
```
- Apply new SQL migrations: `supabase db push --linked`
- Deploy an Edge Function (functions live in `services/edge/`, wired via `supabase/config.toml`): `supabase functions deploy <name> --use-api`
- Provision a simulator device (generates a fresh ingest key): see the device-register flow in `docs/10 API and Backend Services` / the project's provisioning script.

## 7. Running tests
```
cd apps/dashboard && npm test        # vitest
cd apps/mobile && flutter test       # Flutter unit/widget tests
cd services/edge && deno test        # Edge Function + classifier tests (needs Deno)
```

## 8. AI-assisted development (Claude Code + design skills)
FurFeel is built with **Claude Code** (the terminal CLI), steered by `CLAUDE.md` and the specs in `docs/`. Optional, but this is how the project was made — set it up the same way for consistent results.

### Install Claude Code
```
npm install -g @anthropic-ai/claude-code
```
Run `claude` inside the repo root the first time to sign in. It auto-reads `CLAUDE.md`. Useful commands: `/model` (pick a model — Fable for big multi-file builds, Sonnet-high for scoped work), `/reload-plugins`, `/exit`. For long unattended runs, launch with `claude --dangerously-skip-permissions` (it runs commands without asking — fine here since the repo is git-committed and the dev DB holds only seed data), or press Shift+Tab for auto-accept edits.

### Design "taste" skills (how the UI avoids generic AI slop)
Skills are portable instruction files installed with the `npx skills add` CLI (from `vercel-labs/agent-skills` — browse that registry for the exact add commands). The four this project uses:

- **`design-taste-frontend`** — "Taste Skill," anti-slop layout/typography/motion. Install directly:
  ```
  npx skills add https://github.com/Leonxlnx/taste-skill --skill "design-taste-frontend"
  ```
- **`frontend-design`** — Anthropic's official frontend-design skill (breaks generic-AI-UI patterns).
- **`web-design-guidelines`** — Vercel's 100+ accessibility/typography/UX rules.
- **`vercel-react-best-practices`** — React performance rules for the Vite dashboard.

Add the last three via `npx skills add` from the `vercel-labs/agent-skills` registry (search by name). Keep the skill set **coherent** — install `design-taste-frontend` only; do NOT also load its conflicting aesthetic variants (brutalist / minimalist / high-end), because contradictory taste skills average out to mush. Tune the dials at the top of the taste skill for a calm health app: `DESIGN_VARIANCE ~3`, `MOTION_INTENSITY ~3`, `VISUAL_DENSITY ~2` for the owner app (`~6` for the clinic dashboard).

### The one rule when using these skills
`docs/19 Design System` is authoritative for **color, the stress palette, and contrast** (tokens only, no hardcoded hex). The skills handle layout, spacing, typography, and motion — they must not override the blue brand or reduce contrast. Also honor the hard guardrails in `CLAUDE.md` (no diagnosis language, never weaken RLS, media is supplementary only).

### Reusable prompts
`BUILD_PROMPTS.md` (repo root) has the sprint/feature prompts used to build FurFeel — a good starting point for new work.

## 9. Troubleshooting
- **"Docker daemon" warning on `db push`** — harmless; the push still applies. Docker isn't needed for hosted dev.
- **`flutter` / `node` / `supabase` not recognized (Windows)** — PATH not refreshed; open a new terminal, or re-check the PATH entry.
- **No Chrome device in `flutter run`** — install Chrome, or set `CHROME_EXECUTABLE`, or use `-d web-server` and open in any browser.
- **Google sign-in ends on "this site can't be reached"** — the app is running on a port that isn't on the Auth redirect allow-list, so Supabase fell back to the Site URL (the dashboard's port). Run the Flutter web app with `--web-port 5175`, or add your origin under Supabase dashboard → Authentication → URL Configuration.
- **Login shows "Database error querying schema"** — the auth user is misconfigured; recreate it via Supabase dashboard → Authentication → Users (auto-confirm on).
- **Photo/observation upload fails with a permission error** — make sure the latest storage migrations are applied (`supabase db push`).
- **Line endings (cross-platform)** — set `git config --global core.autocrlf input` (macOS/Linux) or `true` (Windows) to avoid noisy diffs.

## Related
- [[CLAUDE]] · [[18 Repository Structure]] · [[17 Technology Stack]] · [[09 Database Schema]] · [[Build Status]]
