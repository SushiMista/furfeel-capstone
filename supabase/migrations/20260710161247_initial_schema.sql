-- FurFeel initial schema
-- Source of truth: docs/09 Database Schema, docs/03 User Roles and Permissions.
-- Enums, tables, indexes, RLS policies, and the auth-signup trigger for a vertical-slice-ready DB.

create extension if not exists pgcrypto;

-- =========================================================================
-- Enums
-- =========================================================================

create type user_role      as enum ('owner', 'vet_staff', 'veterinarian', 'admin');
create type device_status  as enum ('active', 'inactive', 'offline', 'maintenance');
create type posture_type   as enum ('standing', 'sitting', 'lying', 'moving', 'unknown');
create type stress_level   as enum ('calm', 'mild', 'moderate', 'high');
create type alert_severity as enum ('info', 'warning', 'critical');
create type alert_status   as enum ('open', 'acknowledged', 'resolved');
create type media_type     as enum ('video', 'image');

-- =========================================================================
-- Tables
-- =========================================================================

create table clinics (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  address         text,
  contact_number  text,
  created_at      timestamptz not null default now()
);

-- Mirrors auth.users; id = auth.uid(). Populated by the handle_new_user trigger below.
create table users (
  id          uuid primary key references auth.users (id) on delete cascade,
  name        text not null,
  email       text not null unique,
  role        user_role not null default 'owner',
  clinic_id   uuid references clinics (id),
  created_at  timestamptz not null default now()
);

create table dogs (
  id             uuid primary key default gen_random_uuid(),
  owner_user_id  uuid not null references users (id),
  clinic_id      uuid references clinics (id),
  name           text not null,
  breed          text,
  birthdate      date,
  sex            text check (sex in ('male', 'female', 'unknown')),
  weight_kg      numeric(5, 2),
  notes          text,
  created_at     timestamptz not null default now()
);

-- Optional per-dog resting reference values; classifier falls back to global defaults.
create table dog_baselines (
  id                             uuid primary key default gen_random_uuid(),
  dog_id                         uuid not null unique references dogs (id),
  resting_heart_rate_bpm         int,
  resting_respiratory_rate_bpm   int,
  normal_body_temperature_c      numeric(3, 1),
  updated_at                     timestamptz not null default now()
);

create table devices (
  id                 uuid primary key default gen_random_uuid(),
  dog_id             uuid references dogs (id),
  device_code        text not null unique,
  status             device_status not null default 'inactive',
  last_seen_at       timestamptz,
  firmware_version   text,
  ingest_key_hash    text,
  created_at         timestamptz not null default now()
);

-- High-volume table; raw_payload stores exactly what the device sent (ADR-003: never delete raw telemetry).
create table telemetry_readings (
  id                      uuid primary key default gen_random_uuid(),
  device_id               uuid not null references devices (id),
  dog_id                  uuid not null references dogs (id),
  captured_at             timestamptz not null,
  received_at             timestamptz not null default now(),
  heart_rate_bpm          int,
  body_temperature_c      numeric(3, 1),
  respiratory_rate_bpm    int,
  motion_activity         numeric(4, 3) check (motion_activity is null or motion_activity between 0 and 1),
  posture                 posture_type not null default 'unknown',
  ambient_temperature_c   numeric(4, 1),
  humidity_percent        numeric(4, 1),
  is_valid                boolean not null default true,
  raw_payload             jsonb not null
);

create table stress_classifications (
  id                     uuid primary key default gen_random_uuid(),
  dog_id                 uuid not null references dogs (id),
  telemetry_reading_id   uuid not null references telemetry_readings (id),
  stress_level           stress_level not null,
  score                  numeric(4, 1),
  confidence             numeric(4, 3) check (confidence is null or confidence between 0 and 1),
  reasons                jsonb,
  model_version          text not null default 'rule-v1',
  created_at             timestamptz not null default now()
);

create table alerts (
  id                  uuid primary key default gen_random_uuid(),
  dog_id              uuid not null references dogs (id),
  classification_id   uuid references stress_classifications (id),
  severity            alert_severity not null,
  type                text not null,
  message             text not null,
  status              alert_status not null default 'open',
  acknowledged_by     uuid references users (id),
  acknowledged_at     timestamptz,
  created_at          timestamptz not null default now()
);

create table vet_notes (
  id                uuid primary key default gen_random_uuid(),
  dog_id            uuid not null references dogs (id),
  author_user_id    uuid not null references users (id),
  note              text not null,
  created_at        timestamptz not null default now()
);

-- Supplementary only. Never a classifier input (ADR-010).
create table media_submissions (
  id                      uuid primary key default gen_random_uuid(),
  dog_id                  uuid not null references dogs (id),
  submitted_by_user_id    uuid not null references users (id),
  storage_path            text not null,
  media_type              media_type not null,
  note                    text,
  reviewed_by_user_id     uuid references users (id),
  reviewed_at             timestamptz,
  created_at              timestamptz not null default now()
);

-- =========================================================================
-- Indexes
-- =========================================================================

create index idx_telemetry_readings_dog_captured on telemetry_readings (dog_id, captured_at desc);
create index idx_telemetry_readings_device_captured on telemetry_readings (device_id, captured_at desc);
create index idx_stress_classifications_dog_created on stress_classifications (dog_id, created_at desc);
create index idx_alerts_dog_status_created on alerts (dog_id, status, created_at desc);

-- =========================================================================
-- RLS helper functions
-- security definer + fixed search_path so these can read `users`/`dogs` without
-- being blocked by (or recursing into) the RLS policies of the calling role.
-- =========================================================================

create function public.current_user_role()
returns user_role
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select role from public.users where id = auth.uid();
$$;

create function public.current_clinic_id()
returns uuid
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select clinic_id from public.users where id = auth.uid();
$$;

-- True if the caller is clinic staff/vet assigned to this dog's clinic, or an admin.
create function public.is_clinic_member(p_dog_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.dogs d
    where d.id = p_dog_id
      and public.current_user_role() in ('vet_staff', 'veterinarian', 'admin')
      and (
        public.current_user_role() = 'admin'
        or d.clinic_id = public.current_clinic_id()
      )
  );
$$;

grant execute on function public.current_user_role() to authenticated;
grant execute on function public.current_clinic_id() to authenticated;
grant execute on function public.is_clinic_member(uuid) to authenticated;

-- =========================================================================
-- RLS: clinics
-- =========================================================================

alter table clinics enable row level security;

create policy clinics_select_authenticated on clinics
  for select using (auth.role() = 'authenticated');

create policy clinics_admin_manage on clinics
  for all using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

-- =========================================================================
-- RLS: users
-- =========================================================================

alter table users enable row level security;

create policy users_select_own on users
  for select using (id = auth.uid());

create policy users_select_admin on users
  for select using (public.current_user_role() = 'admin');

create policy users_select_clinic_staff on users
  for select using (
    public.current_user_role() in ('vet_staff', 'veterinarian')
    and clinic_id is not null
    and clinic_id = public.current_clinic_id()
  );

-- Self-update only; role/clinic_id must stay unchanged here so a user can't self-promote.
-- Role/clinic_id changes are an admin operation performed via the service role, not this policy.
create policy users_update_own on users
  for update using (id = auth.uid())
  with check (
    id = auth.uid()
    and role = (select u.role from public.users u where u.id = auth.uid())
    and clinic_id is not distinct from (select u.clinic_id from public.users u where u.id = auth.uid())
  );

-- =========================================================================
-- RLS: dogs
-- =========================================================================

alter table dogs enable row level security;

create policy dogs_owner_all on dogs
  for all using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

create policy dogs_select_clinic_staff on dogs
  for select using (public.is_clinic_member(dogs.id));

create policy dogs_admin_all on dogs
  for all using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

-- =========================================================================
-- RLS: dog_baselines
-- =========================================================================

alter table dog_baselines enable row level security;

create policy dog_baselines_select on dog_baselines
  for select using (
    exists (select 1 from dogs d where d.id = dog_baselines.dog_id and d.owner_user_id = auth.uid())
    or public.is_clinic_member(dog_baselines.dog_id)
  );

create policy dog_baselines_insert on dog_baselines
  for insert with check (
    exists (select 1 from dogs d where d.id = dog_baselines.dog_id and d.owner_user_id = auth.uid())
    or public.is_clinic_member(dog_baselines.dog_id)
  );

create policy dog_baselines_update on dog_baselines
  for update using (
    exists (select 1 from dogs d where d.id = dog_baselines.dog_id and d.owner_user_id = auth.uid())
    or public.is_clinic_member(dog_baselines.dog_id)
  )
  with check (
    exists (select 1 from dogs d where d.id = dog_baselines.dog_id and d.owner_user_id = auth.uid())
    or public.is_clinic_member(dog_baselines.dog_id)
  );

-- =========================================================================
-- RLS: devices
-- Admin manages devices (docs/03); owners/clinic staff get read-only visibility.
-- =========================================================================

alter table devices enable row level security;

create policy devices_select_owner_or_clinic on devices
  for select using (
    exists (select 1 from dogs d where d.id = devices.dog_id and d.owner_user_id = auth.uid())
    or (devices.dog_id is not null and public.is_clinic_member(devices.dog_id))
  );

create policy devices_admin_all on devices
  for all using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

-- =========================================================================
-- RLS: telemetry_readings
-- No client insert/update/delete: ingestion is service-role only via the Edge Function,
-- and raw telemetry is never deleted (ADR-003).
-- =========================================================================

alter table telemetry_readings enable row level security;

create policy telemetry_select_owner_or_clinic on telemetry_readings
  for select using (
    exists (select 1 from dogs d where d.id = telemetry_readings.dog_id and d.owner_user_id = auth.uid())
    or public.is_clinic_member(telemetry_readings.dog_id)
  );

-- =========================================================================
-- RLS: stress_classifications
-- No client insert/update/delete: written by the classifier (service role).
-- =========================================================================

alter table stress_classifications enable row level security;

create policy stress_classifications_select_owner_or_clinic on stress_classifications
  for select using (
    exists (select 1 from dogs d where d.id = stress_classifications.dog_id and d.owner_user_id = auth.uid())
    or public.is_clinic_member(stress_classifications.dog_id)
  );

-- =========================================================================
-- RLS: alerts
-- No client insert: alerts are raised server-side (service role).
-- Client update is "acknowledge" only, enforced by column grants below.
-- =========================================================================

alter table alerts enable row level security;

create policy alerts_select_owner_or_clinic on alerts
  for select using (
    exists (select 1 from dogs d where d.id = alerts.dog_id and d.owner_user_id = auth.uid())
    or public.is_clinic_member(alerts.dog_id)
  );

create policy alerts_update_acknowledge on alerts
  for update using (
    exists (select 1 from dogs d where d.id = alerts.dog_id and d.owner_user_id = auth.uid())
    or public.is_clinic_member(alerts.dog_id)
  )
  with check (acknowledged_by is null or acknowledged_by = auth.uid());

revoke update on alerts from authenticated;
grant update (status, acknowledged_by, acknowledged_at) on alerts to authenticated;

-- =========================================================================
-- RLS: vet_notes
-- =========================================================================

alter table vet_notes enable row level security;

create policy vet_notes_select_owner_or_clinic on vet_notes
  for select using (
    exists (select 1 from dogs d where d.id = vet_notes.dog_id and d.owner_user_id = auth.uid())
    or public.is_clinic_member(vet_notes.dog_id)
  );

create policy vet_notes_insert_clinic_staff on vet_notes
  for insert with check (
    author_user_id = auth.uid()
    and public.current_user_role() in ('vet_staff', 'veterinarian', 'admin')
    and public.is_clinic_member(vet_notes.dog_id)
  );

-- =========================================================================
-- RLS: media_submissions
-- Owner can insert/read their dog's media; clinic staff/vets read and set review fields only.
-- =========================================================================

alter table media_submissions enable row level security;

create policy media_select_owner_or_clinic on media_submissions
  for select using (
    exists (select 1 from dogs d where d.id = media_submissions.dog_id and d.owner_user_id = auth.uid())
    or public.is_clinic_member(media_submissions.dog_id)
  );

create policy media_insert_owner on media_submissions
  for insert with check (
    submitted_by_user_id = auth.uid()
    and exists (select 1 from dogs d where d.id = media_submissions.dog_id and d.owner_user_id = auth.uid())
  );

create policy media_update_review on media_submissions
  for update using (public.is_clinic_member(media_submissions.dog_id))
  with check (reviewed_by_user_id is null or reviewed_by_user_id = auth.uid());

revoke update on media_submissions from authenticated;
grant update (reviewed_by_user_id, reviewed_at) on media_submissions to authenticated;

-- =========================================================================
-- Auth signup trigger: create a public.users row with default role 'owner'
-- =========================================================================

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.users (id, name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name', split_part(new.email, '@', 1)),
    new.email,
    'owner'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
