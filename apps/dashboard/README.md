# apps/dashboard — React (Vite) Veterinary Dashboard

React dashboard for clinic staff: monitoring board, dog detail, alerts, and reports, backed by Supabase Realtime.

See `docs/05 Veterinary Dashboard Design` and `docs/06 Sprint 5 - Web Dashboard Checklist`.

## MVP scope built so far

- **Auth**: Supabase Auth email/password sign-in (`src/pages/login`), session-gated routes.
- **Monitoring board** (`src/pages/monitoring_board`): all dogs visible to the signed-in
  user (RLS-scoped), with device status, latest stress level, latest vitals, last reading
  time, and open alert count. Live-updates via Realtime `INSERT` subscriptions on
  `telemetry_readings` / `stress_classifications` / `alerts`.
- **Dog detail** (`src/pages/dog_detail`): live heart-rate/respiratory-rate chart, stress
  classification timeline, and open alerts for one dog, filtered Realtime subscriptions.

Not yet built (out of this sprint's scope): alerts queue page, vet review notes, media
review, reports.

## Setup

```
npm install
cp .env.example .env   # fill in VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY (anon key only)
npm run dev
```

`npm run typecheck`, `npm test`, and `npm run build` all need to pass before committing.
The dashboard client only ever uses the **anon key** — every query is scoped by the signed-in
user's RLS policies, never a service role key (CLAUDE.md guardrail).
