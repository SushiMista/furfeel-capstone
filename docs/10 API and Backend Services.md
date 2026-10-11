---
title: "API and Backend Services"
type: backend-design
project: FurFeel
created: 2026-07-09
updated: 2026-10-04
tags: [furfeel, api, backend]
---

# API and Backend Services

## Backend Platform
Supabase is the backend platform: Auth, PostgreSQL, Realtime, Storage, and Edge Functions. Most app reads/writes go through the **Supabase client + RLS** rather than a custom REST layer. Edge Functions cover the jobs that need server-side logic:
- **`telemetry-intake`** — validate → store raw → classify (rule-v1) → alerts (incl. low-battery) → device-offline recovery.
- **`delete-account`** — deletes the caller's own account; refuses if monitoring history exists (ADR-003).
- **`admin-create-user`** — admin-only account creation, pre-confirmed (`email_confirm: true`) with role + clinic set in one call; re-checks the caller is `admin` server-side. (Self-signup in the apps still requires confirmation.)
- **`admin-delete-user`** — admin-only deletion/deactivation/reactivation; refuses self-deletion and protects dog/telemetry history.

Aggregations and privileged writes are Postgres RPCs (see below). The endpoints below describe the intended contract; RLS-backed client queries satisfy most of them.

## Conventions
- Auth: end-user calls carry the Supabase JWT (`Authorization: Bearer <token>`). Device telemetry carries a device ingest secret, not a user JWT.
- All bodies are JSON. Timestamps are ISO-8601 UTC.
- Errors: `{ "error": { "code": string, "message": string } }` with standard HTTP codes (400 validation, 401 unauth, 403 RLS/forbidden, 404, 409 conflict, 422 unprocessable, 500).

## Backend Responsibilities
Authenticate users · manage dogs/clinics/users/devices · receive + validate telemetry · run rule-based classification · create alerts · serve mobile/dashboard data via Realtime.

## Endpoints

### Auth (Supabase Auth)
Handled by Supabase Auth SDK (`signUp`, `signInWithPassword`, `signInWithOAuth`, `signOut`). No custom endpoints needed. On sign-up, the `handle_new_user` trigger inserts the matching `users` row (default role `owner`) and a default `user_settings` row.
- **Email/password** and **Google sign-in (OAuth)** are both supported (ADR-011). Because Google returns the display name under `full_name` while email signup sends `name`, the trigger resolves the display name as `name → full_name → email prefix`, so no provider path leaves a user without a name.

### Server-side RPCs (Postgres functions, `authenticated`-only)
Called via `supabase.rpc(...)`; each runs under the caller's RLS or is `security definer` with an internal permission check. Execute is revoked from `anon`.
- `stress_daily_summary(dog_id, days, tz_offset)` — 100%-stacked daily stress mix for Trends/reports (SECURITY INVOKER; caller RLS applies).
- `stress_hourly_pattern(dog_id, days, tz_offset)` — calmest/tensest hour-of-day pattern (SECURITY INVOKER).
- `clinic_stress_daily_summary(days, tz_offset)` — clinic-wide stress mix for the dashboard Overview without client-side fan-out.
- `vet_note_feed(dog_id)` — vet notes joined with author name + avatar for the owner-facing Vet Review (owner-scoped).
- `set_dog_photo(dog_id, photo_path)` — sets a dog's profile photo (SECURITY DEFINER; owner-or-clinic check) so `dogs` UPDATE stays locked down.
- `pair_device(device_code, dog_id)` / `unpair_device(dog_id)` — device pairing without granting broad `devices` UPDATE.
- `dog_wellness_score(dog_id, day)` — optional 0–100 daily wellness score (calm-time %, activity/rest, alerts); SECURITY INVOKER, provisional/engineering (not clinical).
- `seed_dog_biotelemetry(dog_id, device_id, count, baseline_hr, baseline_rr)` — clinic-staff/admin seeding helper for new patient intake/demo vitals.

### Devices
- `POST /devices/register` → body `{ device_code, dog_id }`; returns `{ id, device_code, ingest_key }` (ingest_key shown once, stored hashed).
- `PATCH /devices/{id}` → `{ status?, dog_id?, firmware_version? }`.
- `GET /devices/{id}/status` → `{ id, status, last_seen_at, firmware_version }`.

### Telemetry (Edge Function — service role)
- `POST /telemetry` — device ingest. **Auth:** header `x-device-key: <ingest_key>`.
  Request:
  ```json
  {
    "device_code": "ff-device-001",
    "captured_at": "2026-07-09T08:00:00Z",
    "heart_rate_bpm": 92,
    "respiratory_rate_bpm": 24,
    "motion_activity": 0.62,
    "posture": "standing",
    "ambient_temperature_c": 29.1,
    "humidity_percent": 68,
    "battery_percent": 87
  }
  ```
  Behavior: resolve `device_code` → device + dog; validate ranges (`07 Sensor Data Pipeline`); store raw in `telemetry_readings` (`is_valid` set accordingly); run classifier; write `stress_classifications`; evaluate alerts (incl. low-battery); update `devices.last_seen_at` + `devices.battery_percent`. `battery_percent` is device health only, never a classifier input.
  Response `202`:
  ```json
  { "reading_id": "uuid", "stress_level": "mild", "alert_created": false }
  ```
- `GET /dogs/{dog_id}/telemetry?limit=&before=` → paginated readings (newest first).
- `GET /dogs/{dog_id}/latest` → most recent reading + latest stress level.

### Classification (read-only; writes happen in the telemetry function)
- `GET /dogs/{dog_id}/stress/latest` → `{ stress_level, score, model_version, created_at }`.
- `GET /dogs/{dog_id}/stress/history?from=&to=` → timeline for charts.

### Dogs
- `GET /dogs` (scoped by RLS to owned/clinic dogs) · `POST /dogs` · `GET /dogs/{id}` · `PATCH /dogs/{id}`.

### Alerts
- `GET /alerts?status=open` (RLS-scoped).
- `PATCH /alerts/{id}/acknowledge` → sets `status='acknowledged'`, `acknowledged_by=auth.uid()`, `acknowledged_at=now()`.

### Media (supplementary)
- `POST /dogs/{dog_id}/media` → uploads to Supabase Storage, inserts `media_submissions`.
- `GET /dogs/{dog_id}/media` · `PATCH /media/{id}/review` (clinic only).
- `media_messages` is the realtime owner↔clinic thread table under a media submission. Threads are supplementary communication and never classifier inputs.

### Bug Reports and Audit Logs
- Mobile and dashboard users can submit bug reports into `bug_reports`; admins can triage status/severity/category.
- Dashboard, mobile, Edge Functions, and selected database triggers write append-only operational events to `audit_logs`; admins can view all, clinic users see permitted clinic-scoped rows.

## Realtime
Dashboard and mobile subscribe to Postgres changes on `telemetry_readings`, `stress_classifications`, `alerts`, `dogs`, `devices`, `media_submissions`, `media_messages`, and `stress_labels` where needed, filtered/scoped by RLS so live status updates without polling.

## Where the classifier runs
Implemented decision: the rule-based classifier runs synchronously inside `telemetry-intake`. The function validates the payload, stores raw telemetry, resolves baselines/overrides, calls the shared `classifier` module, writes `stress_classifications`, evaluates alerts, and updates device health. Postgres RPCs aggregate already-written classifications for charts; they do not classify.

## Related
- [[07 Sensor Data Pipeline]]
- [[09 Database Schema]]
- [[11 Alerts and Notifications]]
- [[17 Technology Stack]]
