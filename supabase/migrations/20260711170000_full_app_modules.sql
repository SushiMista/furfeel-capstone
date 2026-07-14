-- FurFeel full-app modules (build order steps 8-9).
-- Source of truth: docs/09 Database Schema (stress_labels, care_guidance),
-- docs/04 Mobile App Design (pairing, observation assessment, push), docs/05
-- Veterinary Dashboard Design (vet review, admin).
--
-- Everything here only ADDS capability; no existing policy is weakened.

-- =========================================================================
-- stress_labels — vet-confirmed ground truth (docs/09).
-- The confirm/override control writes here; this is the labeled data that will
-- train the future Random Forest. Never skipped, never deleted by clients.
-- =========================================================================

create table stress_labels (
  id                     uuid primary key default gen_random_uuid(),
  dog_id                 uuid not null references dogs (id),
  classification_id      uuid references stress_classifications (id),
  telemetry_reading_id   uuid references telemetry_readings (id),
  vet_user_id            uuid not null references users (id),
  confirmed_level        stress_level not null,
  agreed_with_model      boolean,
  note                   text,
  created_at             timestamptz not null default now()
);

create index idx_stress_labels_dog_created on stress_labels (dog_id, created_at desc);

alter table stress_labels enable row level security;

-- docs/09: insert/select restricted to clinic staff of the dog's clinic
-- (is_clinic_member = vet_staff/veterinarian/admin scoped to the dog's clinic).
create policy stress_labels_select_clinic_staff on stress_labels
  for select using (public.is_clinic_member(stress_labels.dog_id));

-- ASSUMPTION: docs/04 module 5 ("Vet Review — owner side") requires owners to read
-- "any confirmed stress assessments" for their own dog, so owners get SELECT on their
-- own dog's labels. This widens visibility to the dog's owner only — clinic scoping
-- for staff is unchanged, and no write access is granted to owners.
create policy stress_labels_select_owner on stress_labels
  for select using (
    exists (select 1 from dogs d where d.id = stress_labels.dog_id and d.owner_user_id = auth.uid())
  );

create policy stress_labels_insert_clinic_staff on stress_labels
  for insert with check (
    vet_user_id = auth.uid()
    and public.current_user_role() in ('vet_staff', 'veterinarian', 'admin')
    and public.is_clinic_member(stress_labels.dog_id)
  );

-- =========================================================================
-- care_guidance — vet-authored plain-language guidance shown by the owner
-- app's Care Insights (docs/09). Informational only, never diagnosis.
-- =========================================================================

create table care_guidance (
  id            uuid primary key default gen_random_uuid(),
  stress_level  stress_level not null,
  clinic_id     uuid references clinics (id),   -- null = global default
  title         text not null,
  body          text not null,
  updated_by    uuid references users (id),
  updated_at    timestamptz not null default now()
);

create index idx_care_guidance_level_clinic on care_guidance (stress_level, clinic_id);

alter table care_guidance enable row level security;

-- docs/09: readable by any authenticated user for their dog's clinic (or global).
create policy care_guidance_select on care_guidance
  for select using (
    clinic_id is null
    or clinic_id = public.current_clinic_id()
    or exists (
      select 1 from dogs d
      where d.owner_user_id = auth.uid() and d.clinic_id = care_guidance.clinic_id
    )
  );

-- Writable by vets (their own clinic's rows) and admin (anything, incl. globals).
create policy care_guidance_manage on care_guidance
  for all using (
    public.current_user_role() = 'admin'
    or (
      public.current_user_role() = 'veterinarian'
      and clinic_id is not null
      and clinic_id = public.current_clinic_id()
    )
  )
  with check (
    (updated_by is null or updated_by = auth.uid())
    and (
      public.current_user_role() = 'admin'
      or (
        public.current_user_role() = 'veterinarian'
        and clinic_id is not null
        and clinic_id = public.current_clinic_id()
      )
    )
  );

-- Global defaults so Care Insights works out of the box (plain-language,
-- decision-support wording only — no diagnosis/treatment claims).
insert into care_guidance (stress_level, clinic_id, title, body) values
  ('calm', null, 'All is well',
   'Your dog''s readings look settled. Keep up the usual routine — fresh water, regular walks, and the comforts they know. No action needed right now.'),
  ('mild', null, 'A little uneasy',
   'Your dog seems slightly unsettled. This is common around new sounds, places, or visitors. Offer a quiet spot and a familiar toy or blanket, and give them a calm moment with you. If this continues for several hours, mention it to your clinic at the next visit.'),
  ('moderate', null, 'Could use some comfort',
   'Your dog is showing signs of ongoing stress. Move them somewhere quiet, remove obvious stressors (loud noise, unfamiliar animals), and stay nearby — your presence helps. Offer water and avoid strenuous play. If readings stay at this level, consider contacting your clinic for advice.'),
  ('high', null, 'Needs your attention',
   'Your dog''s readings suggest significant stress right now. Check on them promptly: bring them to a calm, familiar space and look for anything unusual (panting, pacing, trembling). This information supports your judgement — it is not a medical assessment. If your dog seems unwell or the level does not come down, contact your veterinary clinic.');

-- =========================================================================
-- media_submissions — vet annotation (docs/05 vet review: "view, mark
-- reviewed, annotate"). Column-level grant extended; row policies unchanged.
-- =========================================================================

alter table media_submissions add column review_note text;

grant update (reviewed_by_user_id, reviewed_at, review_note) on media_submissions to authenticated;

-- =========================================================================
-- dogs.photo_path — docs/04 Pet Creation includes a profile photo (Storage).
-- Stored as a path in the private `media` bucket (dogs/<dog_id>/profile.*);
-- clients resolve it with a signed URL. Additive column; dogs RLS unchanged.
-- =========================================================================

alter table dogs add column photo_path text;

-- =========================================================================
-- push_tokens — device push registration (docs/04 notifications). The app
-- registers FCM/APNs tokens here; delivery wiring is a server-side concern.
-- =========================================================================

create table push_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references users (id) on delete cascade,
  platform    text not null check (platform in ('ios', 'android', 'web')),
  token       text not null unique,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table push_tokens enable row level security;

create policy push_tokens_own_all on push_tokens
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- =========================================================================
-- Admin module (docs/05 §4): admins manage users' role + clinic from the
-- dashboard. The initial schema deferred this to the service role; a proper
-- admin-only UPDATE policy is strictly additive (users_update_own still pins
-- role/clinic for everyone else, so self-promotion stays impossible).
-- =========================================================================

create policy users_update_admin on users
  for update using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

-- =========================================================================
-- Device pairing (docs/04 module 6). Owners can't be granted broad UPDATE on
-- devices (admin-managed, docs/03), so pairing goes through security-definer
-- RPCs that validate ownership explicitly instead of weakening devices RLS.
-- =========================================================================

create function public.pair_device(p_device_code text, p_dog_id uuid)
returns devices
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_device devices;
begin
  -- The dog must belong to the caller.
  if not exists (
    select 1 from dogs d where d.id = p_dog_id and d.owner_user_id = auth.uid()
  ) then
    raise exception 'DOG_NOT_OWNED';
  end if;

  select * into v_device from devices where device_code = upper(trim(p_device_code));
  if v_device.id is null then
    raise exception 'DEVICE_NOT_FOUND';
  end if;
  if v_device.dog_id is not null and v_device.dog_id <> p_dog_id then
    raise exception 'DEVICE_ALREADY_PAIRED';
  end if;

  update devices set dog_id = p_dog_id where id = v_device.id
  returning * into v_device;
  -- Never expose the ingest secret hash, even through the RPC.
  v_device.ingest_key_hash := null;
  return v_device;
end;
$$;

create function public.unpair_device(p_device_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1
    from devices dev
    join dogs d on d.id = dev.dog_id
    where dev.id = p_device_id and d.owner_user_id = auth.uid()
  ) then
    raise exception 'DEVICE_NOT_OWNED';
  end if;

  update devices set dog_id = null, status = 'inactive' where id = p_device_id;
end;
$$;

revoke execute on function public.pair_device(text, uuid) from public, anon;
revoke execute on function public.unpair_device(uuid) from public, anon;
grant execute on function public.pair_device(text, uuid) to authenticated;
grant execute on function public.unpair_device(uuid) to authenticated;

-- =========================================================================
-- Storage: private `media` bucket for owner observation photos/videos
-- (docs/04 module 3). Path convention: dogs/<dog_id>/<file>. Supplementary
-- material only — NEVER a classifier input (ADR-010).
-- =========================================================================

insert into storage.buckets (id, name, public)
values ('media', 'media', false)
on conflict (id) do nothing;

-- Owners upload into their own dog's folder only.
create policy media_objects_insert_owner on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'dogs'
    and exists (
      select 1 from public.dogs d
      where d.id::text = (storage.foldername(name))[2]
        and d.owner_user_id = auth.uid()
    )
  );

-- Owners can replace/remove their own dog's objects (profile photo re-upload).
create policy media_objects_update_owner on storage.objects
  for update to authenticated
  using (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'dogs'
    and exists (
      select 1 from public.dogs d
      where d.id::text = (storage.foldername(name))[2]
        and d.owner_user_id = auth.uid()
    )
  );

create policy media_objects_delete_owner on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'dogs'
    and exists (
      select 1 from public.dogs d
      where d.id::text = (storage.foldername(name))[2]
        and d.owner_user_id = auth.uid()
    )
  );

-- Owner + the dog's clinic staff can view media objects.
create policy media_objects_select_owner_or_clinic on storage.objects
  for select to authenticated
  using (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'dogs'
    and exists (
      select 1 from public.dogs d
      where d.id::text = (storage.foldername(name))[2]
        and (d.owner_user_id = auth.uid() or public.is_clinic_member(d.id))
    )
  );

-- =========================================================================
-- Realtime: docs/05 board must show a newly clinic-linked dog live, the
-- pairing screen reflects device status live, and the owner's Vet Review /
-- Observation views update as clinicians respond. RLS still gates delivery.
-- =========================================================================

alter publication supabase_realtime add table public.dogs;
alter publication supabase_realtime add table public.devices;
alter publication supabase_realtime add table public.vet_notes;
alter publication supabase_realtime add table public.media_submissions;
alter publication supabase_realtime add table public.stress_labels;

-- UPDATE events (dog clinic linkage, device status flips, media review) need the
-- full old row on the wire for filtered subscriptions to work reliably.
alter table public.dogs replica identity full;
alter table public.devices replica identity full;
alter table public.media_submissions replica identity full;
