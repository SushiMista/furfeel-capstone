---
title: "Veterinary Dashboard Design"
type: product-design
project: FurFeel
created: 2026-07-09
updated: 2026-07-18
tags: [furfeel, dashboard, veterinary]
---

# Veterinary Dashboard Design (React — Clinic)

Full clinic-app spec covering the manuscript's three vet modules plus Admin. Style: follow [[19 Design System]] (blue brand, clinical Design 2 density, shadcn/ui + Tremor). Anon key only; RLS-scoped to the staff member's `clinic_id`. No diagnosis language.

## Navigation
Left sidebar: **Overview · Monitoring Board · Alerts · Reports · Admin** (Admin visible to `admin` role only).

## Modules (manuscript)

### 1. Veterinary Dashboard Module (Monitoring Board)
- Multi-dog live board = **all dogs where `dogs.clinic_id` = the staff member's clinic** (RLS `is_clinic_member`). When an owner creates/links a dog to this clinic, it appears here **live via Realtime** with no refresh. Stress-sorted so above-calm floats up.
- **Photo dog-cards (make it feel full-fledged):** each dog shows as a rich card with its **profile photo** (`dogs.photo_path`), name/breed, a status ring in its stress color, current vitals, and a mini trend. A clinic can **upload/replace a dog's photo** from the dashboard (Storage), so monitored dogs are recognizable at a glance, not just rows. Offer both a **card grid** and a compact table view (toggle).
- Vet **account menu + settings** (theme, profile photo via `users.avatar_path`, sign out) so the dashboard is a real signed-in product too.
- Columns: dog, device status (online dot), current stress pill, HR, RR, temp, motion, last reading, open-alert count.
- Live via Realtime. Filter: all / needs attention.
- **Dog detail:** header + current stress pill, vital cards, vitals trend chart (Tremor), stress classification timeline, a **14-day stress-mix chart** (same 100%-stacked composition as the owner app, via `stress_daily_summary`), open alerts, vet-notes panel.
- **Overview page:** greets the vet, a **"Calm today" KPI**, and a **clinic-wide 14-day stress-mix** chart aggregated across the clinic's dogs.

### 2. Vet Review Module
- Review biometrics + stress history + **owner-submitted media** (`media_submissions`): view, mark reviewed, annotate.
- **Confirm/override stress**: a control letting a vet confirm or correct a classification. Writes a **ground-truth label** (see `stress_labels` in [[09 Database Schema]]) — this is the data that will train the future Random Forest. Highest-value new feature.

### 3. Vet Reports Module (DSS)
- Per-dog period summary: stress distribution, abnormal-pattern highlights, vitals trends.
- Printable/exportable (PDF/print stylesheet).

### 4. Admin (as built)
Four tabs, offered to the `admin` role only as UX — the `users_update_admin` / `clinics_admin_manage` / `devices_admin_all` RLS policies are the actual gate.
- **Users:** assign role + clinic per user, and **add accounts** from the dashboard — a throwaway anon-key client signs the account up (the `handle_new_user` trigger mirrors it into `public.users` as `owner`), then the admin's session sets role/clinic through `users_update_admin`. No service key ever reaches the browser; with email confirmations on, the new user confirms before first login. Role changes work with the plain anon key: the permissive admin policy ORs with `users_update_own`, and self-promotion by non-admins stays blocked (verified end-to-end).
- **Clinics:** create + list.
- **Devices:** register harnesses, assign to dogs, set status; plus dog ↔ clinic assignment.
- **System Health** (docs/03 "view system health", read-only): device fleet online/offline counts (from `devices.status`, which pg_cron already maintains), telemetry ingest volume (last hour / 24 h + last-received time), open-alert count, and user/clinic/dog totals. Fleet + totals derive from the already-loaded admin data; only telemetry and alerts add queries (`fetchSystemHealth`).

## Alerts queue
Triage list grouped by severity; acknowledge (sets `acknowledged_by`/`acknowledged_at`); device-offline + stress alerts.

## MVP priority order
Board (done) → Dog detail (done) → Alerts queue (done) → Vet notes (done) → Reports (done) → Vet Review media + confirm/override (done) → Admin incl. add-user + System Health (done).

## Related
- [[19 Design System]]
- [[03 User Roles and Permissions]]
- [[07 Sensor Data Pipeline]]
- [[11 Alerts and Notifications]]
- [[09 Database Schema]]
