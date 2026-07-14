# FurFeel — Claude Code Build Playbook

Copy-paste these into Claude Code (`claude` in the repo folder), one at a time, in order.
Finish and verify each against `docs/08 Definition of Done` before starting the next.
Keep the telemetry **simulator** as your data source so every UI sprint works before hardware exists.

---

## Sprint 0 — Scaffold the repo
```
Read CLAUDE.md and docs/18 Repository Structure. Scaffold the monorepo folders exactly as
described. Initialise git, add a root README, a .env.example listing SUPABASE_URL,
SUPABASE_ANON_KEY, and SUPABASE_SERVICE_ROLE_KEY, and a .gitignore for Node/Flutter/Deno.
Create empty package folders with placeholder READMEs. Do not write feature code yet.
```

## Sprint 1 — Database + RLS
```
Read docs/09 Database Schema and docs/03 User Roles and Permissions. Create a Supabase
migration in supabase/migrations/ that defines every enum, table, constraint, index, and
RLS policy. Add a trigger that inserts a users row on auth signup with default role 'owner'.
Add supabase/seed/ with one clinic, one owner, one vet, one dog, one device, and a
dog_baselines row. Show me the SQL and the exact `supabase db` commands to apply it.
```

## Sprint 2 — Telemetry intake + rule-based classifier
```
Read docs/07 Sensor Data Pipeline, docs/10 API and Backend Services, and
docs/08 AI Classification Pipeline. Build the Supabase Edge Function `telemetry-intake`:
authenticate with x-device-key, resolve device_code -> device+dog, validate ranges (flag
is_valid=false, never silently replace), store raw payload, run the rule-v1 classifier,
write stress_classifications with reasons, evaluate alerts. Put the classifier in
services/edge/classifier as an importable, unit-tested module. Put thresholds in
packages/shared/classifier_config.json. Add unit tests including the worked example
(HR 150, RR 46, temp 39.4, motion 0.7 -> high).
```

## Sprint 3 — Simulator
```
Read docs/07 Sensor Data Pipeline. Build firmware/simulator: a small Node script that POSTs
telemetry payloads to the telemetry-intake function every 10 seconds for one device_code,
with a flag to sweep from calm -> high so I can watch classifications and alerts change.
Document how to run it.
```

## Sprint 4 — React dashboard (latest reading + monitoring board)
```
Read docs/05 Veterinary Dashboard Design and docs/10 API and Backend Services. In
apps/dashboard (React + Vite), build auth (Supabase), a multi-dog monitoring board with the
listed fields, and a dog detail page with a live telemetry chart and stress timeline, all
updating via Supabase Realtime. Scope data by the staff member's clinic via RLS. Run it
against the simulator.
```

## Sprint 5 — Flutter owner app (status view)
```
Read docs/04 Mobile App Design and docs/10 API and Backend Services. In apps/mobile (Flutter),
build login, a dog status overview (current stress + latest vitals + last-updated), a recent
readings list, and an alert list — updating via Supabase Realtime, scoped by RLS. Run it
against the simulator.
```

## Sprint 6 — Alerts + acknowledge + history
```
Read docs/11 Alerts and Notifications. Implement alert creation on moderate/high and on
device-offline, the acknowledge flow (sets acknowledged_by + acknowledged_at) in both
clients, and a history view. Add happy-path tests.
```

---

## Rules for every sprint
- Start each session by telling Claude which sprint and pointing it at the checklist in `docs/`.
- Ask it to restate the acceptance criteria before coding.
- Migrations first, then backend, then client.
- If it wants to change the stack, the classifier name, or an RLS policy — stop and confirm.
- Commit per feature; note the spec doc in the message.
