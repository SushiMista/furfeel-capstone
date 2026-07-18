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

### 4. Admin (as built) — full CRUD on Users, Clinics, Devices
Four tabs, offered to the `admin` role only as UX. RLS (`users_update_admin` / `clinics_admin_manage` / `devices_admin_all`) is the real gate for Clinics/Devices and for role/clinic updates on Users; Users create/delete need the service role (Auth admin API), so those two go through dedicated Edge Functions instead of a client-held service key.
- **Users — Create, Read, Update, Delete:**
  - Create: **`admin-create-user`** Edge Function creates the account **pre-confirmed** (`email_confirm: true`) and sets role + clinic in one call. Auto-confirming is safe specifically because the *admin* is picking the email, not the account owner — self-signup in the mobile/dashboard apps still requires confirmation. The function re-checks the caller is `admin` server-side (never trusts the client), so the UI call is a convenience, not the gate.
  - Update: role + clinic via the plain anon-key client — the permissive `users_update_admin` policy ORs with `users_update_own`, and self-promotion by non-admins stays blocked (verified end-to-end).
  - Delete: **`admin-delete-user`** Edge Function. Guards: an admin can't delete their own account through this panel (this alone also prevents ever locking Admin out — the caller is always a *different*, still-existing admin than the target, so a separate "last admin" head-count would be dead code and isn't implemented); a user who still owns dog profiles is refused (`dogs.owner_user_id` is `NOT NULL` with no cascade, and ADR-003 rules out cascading through monitoring history); any other remaining FK reference (authored vet notes, acknowledged alerts, reviewed media) surfaces as a generic "still has linked records" error.
- **Clinics — Create, Read, Update, Delete:** plain RLS-backed CRUD (`clinics_admin_manage` is `for all`). Update edits name/address/contact via a dialog; delete is blocked with a friendly message when the clinic is still referenced by a user or a dog (Postgres FK violation `23503`, reworded client-side rather than shown raw).
- **Devices — Create, Read, Update, Delete:** register, assign to a dog, set status (Update), plus dog ↔ clinic assignment. Delete is blocked the same way when the device has telemetry history (`telemetry_readings.device_id` is `NOT NULL` with no cascade, protecting ADR-003) — the message points at setting status to inactive/maintenance instead, since a never-used device deletes cleanly.
- **System Health** (docs/03 "view system health", read-only): device fleet online/offline counts (from `devices.status`, which pg_cron already maintains), telemetry ingest volume (last hour / 24 h + last-received time), open-alert count, and user/clinic/dog totals. Fleet + totals derive from the already-loaded admin data; only telemetry and alerts add queries (`fetchSystemHealth`).

Every delete in the UI routes through a shared confirmation dialog (`ConfirmDeleteDialog`) — the one Admin action that can't be undone doesn't fire on a single click.

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
