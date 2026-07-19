---
title: "Database Schema"
type: schema
project: FurFeel
created: 2026-07-09
updated: 2026-07-10
tags: [furfeel, database, backend]
---

# Database Schema

Build-ready schema for Supabase PostgreSQL. Tables are plural `snake_case`. Every table has a `uuid` primary key (`id uuid primary key default gen_random_uuid()`) and, where noted, `created_at timestamptz not null default now()`. All timestamps are UTC. This note is the source of truth for the first migration.

## Enum Types

```sql
create type user_role       as enum ('owner', 'vet_staff', 'veterinarian', 'admin');
create type device_status   as enum ('active', 'inactive', 'offline', 'maintenance');
create type posture_type    as enum ('standing', 'sitting', 'lying', 'moving', 'unknown');
create type stress_level    as enum ('calm', 'mild', 'moderate', 'high');
create type alert_severity  as enum ('info', 'warning', 'critical');
create type alert_status    as enum ('open', 'acknowledged', 'resolved');
create type media_type      as enum ('video', 'image');
```

## Tables

### users
Mirrors `auth.users` (Supabase Auth owns credentials; do **not** store `password_hash` here — Supabase handles it). `id` equals the `auth.uid()`.

| column | type | constraints |
|---|---|---|
| id | uuid | PK, references `auth.users(id)` |
| name | text | not null |
| email | text | not null, unique |
| role | user_role | not null, default `'owner'` |
| clinic_id | uuid | null, FK → clinics(id) — set for vet_staff/veterinarian |
| avatar_path | text | null (Supabase Storage — user profile photo) |
| phone | text | null (owner contact; clinic staff can read via existing select policies) |
| emergency_contact | text | null (free text "name and number") |
| created_at | timestamptz | not null, default now() |

### user_settings
Per-user preferences (a "full app" needs these; sync across devices). One row per user.
| column | type | constraints |
|---|---|---|
| user_id | uuid | PK, FK → users(id) |
| theme | text | check in ('system','light','dark'), default 'system' |
| temperature_unit | text | check in ('c','f'), default 'c' |
| notifications_enabled | boolean | not null, default true |
| muted_alert_types | text[] | not null, default `'{}'` (per-type push mute, e.g. `{high_stress,device_offline}`) |
| quiet_hours_start | time | null (mute non-critical push) |
| quiet_hours_end | time | null |
| updated_at | timestamptz | not null, default now() |

RLS: a user reads/writes only their own row (`user_id = auth.uid()`).

### push_tokens
Registered device push tokens (FCM/APNs) per user; the notification dispatcher reads these.
| column | type | constraints |
|---|---|---|
| id | uuid | PK |
| user_id | uuid | not null, FK → users(id) on delete cascade |
| platform | text | not null, check in ('ios','android','web') |
| token | text | not null, unique |
| created_at | timestamptz | not null, default now() |
| updated_at | timestamptz | not null, default now() |

RLS: a user reads/writes only their own tokens (`user_id = auth.uid()`).

### clinics
| column | type | constraints |
|---|---|---|
| id | uuid | PK |
| name | text | not null |
| address | text | null |
| contact_number | text | null |
| created_at | timestamptz | not null, default now() |

### dogs
| column | type | constraints |
|---|---|---|
| id | uuid | PK |
| owner_user_id | uuid | not null, FK → users(id) |
| clinic_id | uuid | null, FK → clinics(id) |
| name | text | not null |
| breed | text | null |
| birthdate | date | null (prefer over free-text age; compute age) |
| sex | text | check in ('male','female','unknown') |
| weight_kg | numeric(5,2) | null |
| notes | text | null |
| created_at | timestamptz | not null, default now() |

**Dog ↔ clinic linkage:** `owner_user_id` = who owns the dog; `clinic_id` = which clinic monitors it (nullable). A clinic's dashboard board = all dogs where `clinic_id` = that clinic. So an owner-created dog only appears on a clinic board once `clinic_id` is set (owner selects a clinic at Pet Creation / Device Pairing, or Admin assigns). `clinic_id = null` = home-only. Many dogs per clinic is the normal case. (A future `enrollments` table could model repeated boarding visits; MVP uses a single `clinic_id`.)

### dog_baselines
Per-dog resting reference values used by the classifier. Optional; classifier falls back to global defaults (see `08 AI Classification Pipeline`).

| column | type | constraints |
|---|---|---|
| id | uuid | PK |
| dog_id | uuid | not null, unique, FK → dogs(id) |
| resting_heart_rate_bpm | int | null |
| resting_respiratory_rate_bpm | int | null |
| normal_body_temperature_c | numeric(3,1) | null |
| updated_at | timestamptz | not null, default now() |

### devices
| column | type | constraints |
|---|---|---|
| id | uuid | PK |
| dog_id | uuid | null, FK → dogs(id) |
| device_code | text | not null, unique |
| status | device_status | not null, default `'inactive'` |
| last_seen_at | timestamptz | null |
| firmware_version | text | null |
| battery_percent | int | null, check 0–100 (latest reported battery, mirrored from telemetry by intake) |
| ingest_key_hash | text | null (hashed device secret for telemetry auth) |
| created_at | timestamptz | not null, default now() |

> **`devices` uses COLUMN-level select grants**, not table-wide (table select was revoked so `ingest_key_hash` is never client-readable). **Any new client-readable column must be added to that grant list**, or every client query naming it fails with a permission error. This bit us once: `battery_percent` was missing from the grant and Home couldn't load (fixed in `20260718090000_grant_devices_battery_select`). Currently granted to `authenticated`: `id, dog_id, device_code, status, last_seen_at, firmware_version, created_at, battery_percent`.

### telemetry_readings
High-volume table. Index on `(dog_id, captured_at desc)` and `(device_id, captured_at desc)`.

| column | type | constraints |
|---|---|---|
| id | uuid | PK |
| device_id | uuid | not null, FK → devices(id) |
| dog_id | uuid | not null, FK → dogs(id) |
| captured_at | timestamptz | not null (device clock) |
| received_at | timestamptz | not null, default now() (server clock) |
| heart_rate_bpm | int | null |
| body_temperature_c | numeric(3,1) | null |
| respiratory_rate_bpm | int | null |
| motion_activity | numeric(4,3) | null (0.000–1.000) |
| posture | posture_type | not null, default `'unknown'` |
| ambient_temperature_c | numeric(4,1) | null |
| humidity_percent | numeric(4,1) | null |
| battery_percent | int | null, check 0–100 (device health only — never a classifier input) |
| is_valid | boolean | not null, default true (set false if validation failed) |
| raw_payload | jsonb | not null (store exactly what the device sent) |

### stress_classifications
| column | type | constraints |
|---|---|---|
| id | uuid | PK |
| dog_id | uuid | not null, FK → dogs(id) |
| telemetry_reading_id | uuid | not null, FK → telemetry_readings(id) |
| stress_level | stress_level | not null |
| score | numeric(4,1) | null (rule-based total, for transparency) |
| confidence | numeric(4,3) | null (0–1; from model when available) |
| reasons | jsonb | null (which rules fired, for defense evidence) |
| model_version | text | not null, default `'rule-v1'` |
| created_at | timestamptz | not null, default now() |

### alerts
| column | type | constraints |
|---|---|---|
| id | uuid | PK |
| dog_id | uuid | not null, FK → dogs(id) |
| classification_id | uuid | null, FK → stress_classifications(id) |
| severity | alert_severity | not null |
| type | text | not null (e.g. 'high_stress','device_offline','out_of_range') |
| message | text | not null |
| status | alert_status | not null, default `'open'` |
| acknowledged_by | uuid | null, FK → users(id) |
| acknowledged_at | timestamptz | null |
| created_at | timestamptz | not null, default now() |

### stress_labels
Vet-confirmed ground truth (the confirm/override action in the dashboard). This is the labeled data that will train the **future Random Forest** — do not skip it.
| column | type | constraints |
|---|---|---|
| id | uuid | PK |
| dog_id | uuid | not null, FK → dogs(id) |
| classification_id | uuid | null, FK → stress_classifications(id) |
| telemetry_reading_id | uuid | null, FK → telemetry_readings(id) |
| vet_user_id | uuid | not null, FK → users(id) |
| confirmed_level | stress_level | not null |
| agreed_with_model | boolean | null (confirmed == model output?) |
| note | text | null |
| created_at | timestamptz | not null, default now() |

RLS: insert + select for `veterinarian`/`vet_staff`/`admin` of the dog's clinic. **Owners get read-only select on their own dog's labels** (`owner_user_id = auth.uid()`) so the owner-side Vet Review module can show confirmed assessments; owners cannot write labels.

### care_guidance
Vet-authored guidance shown by the owner app's Care Insights (informational only, never diagnosis). Rows are keyed **either** by `stress_level` (per-level default) **or** by `context_key` (a combination of signals — e.g. `cold_stressed`, `hot_stressed`, `panting_hot`, `restless_high_hr`, `cold_calm`, `hot_calm`; see `08 AI Classification Pipeline`). The app prefers a matching context row, then falls back to the level row; clinic rows override globals in both cases.
| column | type | constraints |
|---|---|---|
| id | uuid | PK |
| stress_level | stress_level | null (null allowed for context rows) |
| context_key | text | null (combination key; check: at least one of stress_level/context_key set) |
| clinic_id | uuid | null, FK → clinics(id) (null = global default) |
| title | text | not null |
| body | text | not null |
| updated_by | uuid | null, FK → users(id) |
| updated_at | timestamptz | not null, default now() |

RLS: readable by any authenticated user for their dog's clinic (or global); writable by vets/admin. Seeded combination copy is provisional — vet review expected.

### consents
Data-collection consent (docs/12). Append-only: one row per (user, accepted policy version); bumping the app's policy version forces re-consent while keeping the old acceptance on record. The owner app blocks monitoring data + media features until the current version is accepted.
| column | type | constraints |
|---|---|---|
| id | uuid | PK |
| user_id | uuid | not null, FK → users(id) on delete cascade |
| policy_version | text | not null; unique (user_id, policy_version) |
| accepted_at | timestamptz | not null, default now() |

RLS: own-row select/insert only; no update/delete (a consent is a record, not a preference).

### media_messages
Threaded conversation on an owner media submission (owner ↔ clinic, like an email chain under the media). Realtime-enabled.
| column | type | constraints |
|---|---|---|
| id | uuid | PK |
| media_submission_id | uuid | not null, FK → media_submissions(id) on delete cascade |
| author_user_id | uuid | not null, FK → users(id) |
| body | text | not null (non-blank check) |
| created_at | timestamptz | not null, default now() |

RLS: select + insert for the dog's owner and clinic staff of the dog (via the parent submission); insert requires `author_user_id = auth.uid()`.

### dog_wellness_score(dog_id, day) — RPC
SECURITY INVOKER function returning a daily 0–100 wellness snapshot (score, calm/active/rest percents, alert count, sample count). RLS on the underlying tables scopes it; formula documented in `08 AI Classification Pipeline` (provisional engineering metric, not clinical).

### vet_notes
| column | type | constraints |
|---|---|---|
| id | uuid | PK |
| dog_id | uuid | not null, FK → dogs(id) |
| author_user_id | uuid | not null, FK → users(id) |
| note | text | not null |
| created_at | timestamptz | not null, default now() |

### media_submissions
Supplementary only. **Not** a classifier input (ADR-010).

| column | type | constraints |
|---|---|---|
| id | uuid | PK |
| dog_id | uuid | not null, FK → dogs(id) |
| submitted_by_user_id | uuid | not null, FK → users(id) |
| storage_path | text | not null (Supabase Storage object path) |
| media_type | media_type | not null |
| note | text | null |
| reviewed_by_user_id | uuid | null, FK → users(id) |
| reviewed_at | timestamptz | null |
| review_note | text | null (clinician's note when reviewing owner media) |
| created_at | timestamptz | not null, default now() |

## Row Level Security (RLS)

Enable RLS on every table. Policy intent (implement as Supabase policies):

- **users:** a user can read/update their own row. Admin can read all. Vet staff/vets can read users in their `clinic_id`.
- **dogs:** owner can CRUD their own dogs (`owner_user_id = auth.uid()`). Vet staff/vets can read dogs where `dogs.clinic_id = users.clinic_id` (their clinic). Admin all.
- **devices / telemetry_readings / stress_classifications / alerts / vet_notes:** readable by the dog's owner and by clinic staff of the dog's `clinic_id`. Telemetry **insert** is done by the service role / Edge Function (device ingest), not by end users. Only vet_staff/veterinarian/admin can insert `vet_notes`; author must equal `auth.uid()`.
- **alerts update (acknowledge):** owner or clinic staff of that dog; sets `acknowledged_by = auth.uid()`.
- **media_submissions:** owner can insert/read their dog's media; clinic staff/vets can read and set review fields.

Helper: a SQL function `is_clinic_member(dog_id uuid)` returning boolean simplifies policies. Telemetry ingestion uses the **service role key** inside the Edge Function, which bypasses RLS by design — never expose that key to clients.

## Indexes

```sql
create index on telemetry_readings (dog_id, captured_at desc);
create index on telemetry_readings (device_id, captured_at desc);
create index on stress_classifications (dog_id, created_at desc);
create index on alerts (dog_id, status, created_at desc);
```

## Note
Submitted videos/media are supplementary assessment and communication material. They are **not** model inputs for the rule-based or future Random Forest classifier.

## Related
- [[03 User Roles and Permissions]]
- [[10 API and Backend Services]]
- [[07 Sensor Data Pipeline]]
- [[17 Technology Stack]]
