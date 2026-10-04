-- Migration: 20261004172000_multi_owner_dog_registration.sql
-- Description: Supports multiple equal registered owners per dog profile (no owner vs co-owner hierarchy).
-- Creates public.dog_owners junction table, RLS policies for all linked owners across telemetry,
-- alerts, and dog records, an automatic sync trigger, and backfills existing dogs.

-- =========================================================================
-- 1. Create dog_owners junction table
-- =========================================================================
create table if not exists public.dog_owners (
  id uuid primary key default gen_random_uuid(),
  dog_id uuid not null references public.dogs (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint uq_dog_owners_dog_user unique (dog_id, user_id)
);

create index if not exists idx_dog_owners_user_id on public.dog_owners (user_id);
create index if not exists idx_dog_owners_dog_id on public.dog_owners (dog_id);

alter table public.dog_owners enable row level security;
grant all on public.dog_owners to authenticated;

-- =========================================================================
-- 2. Helper function: is_dog_owner(p_dog_id)
-- =========================================================================
create or replace function public.is_dog_owner(p_dog_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.dogs d
    where d.id = p_dog_id
      and (
        d.owner_user_id = auth.uid()
        or exists (
          select 1 from public.dog_owners dgo
          where dgo.dog_id = d.id and dgo.user_id = auth.uid()
        )
      )
  );
$$;

grant execute on function public.is_dog_owner(uuid) to authenticated, anon;

-- =========================================================================
-- 3. RLS policies on dog_owners
-- =========================================================================
drop policy if exists dog_owners_select on public.dog_owners;
create policy dog_owners_select on public.dog_owners
  for select using (
    user_id = auth.uid()
    or public.is_dog_owner(dog_id)
    or public.is_clinic_member(dog_id)
    or public.current_user_role() in ('vet_staff', 'veterinarian', 'admin')
  );

drop policy if exists dog_owners_insert on public.dog_owners;
create policy dog_owners_insert on public.dog_owners
  for insert with check (
    public.is_dog_owner(dog_id)
    or public.is_clinic_member(dog_id)
    or public.current_user_role() in ('vet_staff', 'veterinarian', 'admin')
  );

drop policy if exists dog_owners_update on public.dog_owners;
create policy dog_owners_update on public.dog_owners
  for update using (
    public.is_dog_owner(dog_id)
    or public.is_clinic_member(dog_id)
    or public.current_user_role() in ('vet_staff', 'veterinarian', 'admin')
  );

drop policy if exists dog_owners_delete on public.dog_owners;
create policy dog_owners_delete on public.dog_owners
  for delete using (
    public.is_dog_owner(dog_id)
    or public.is_clinic_member(dog_id)
    or public.current_user_role() in ('vet_staff', 'veterinarian', 'admin')
  );

-- =========================================================================
-- 4. Grant all linked owners access to dogs & telemetry/alerts
-- =========================================================================
drop policy if exists dogs_co_owner_select on public.dogs;
drop policy if exists dogs_linked_owner_select on public.dogs;
create policy dogs_linked_owner_select on public.dogs
  for select using (
    exists (
      select 1 from public.dog_owners dgo
      where dgo.dog_id = dogs.id and dgo.user_id = auth.uid()
    )
  );

drop policy if exists dogs_co_owner_update on public.dogs;
drop policy if exists dogs_linked_owner_update on public.dogs;
create policy dogs_linked_owner_update on public.dogs
  for update using (
    exists (
      select 1 from public.dog_owners dgo
      where dgo.dog_id = dogs.id and dgo.user_id = auth.uid()
    )
  );

drop policy if exists telemetry_readings_co_owner_select on public.telemetry_readings;
drop policy if exists telemetry_readings_linked_owner_select on public.telemetry_readings;
create policy telemetry_readings_linked_owner_select on public.telemetry_readings
  for select using (
    exists (
      select 1 from public.dog_owners dgo
      where dgo.dog_id = telemetry_readings.dog_id and dgo.user_id = auth.uid()
    )
  );

drop policy if exists stress_classifications_co_owner_select on public.stress_classifications;
drop policy if exists stress_classifications_linked_owner_select on public.stress_classifications;
create policy stress_classifications_linked_owner_select on public.stress_classifications
  for select using (
    exists (
      select 1 from public.dog_owners dgo
      where dgo.dog_id = stress_classifications.dog_id and dgo.user_id = auth.uid()
    )
  );

drop policy if exists alerts_co_owner_select on public.alerts;
drop policy if exists alerts_linked_owner_select on public.alerts;
create policy alerts_linked_owner_select on public.alerts
  for select using (
    exists (
      select 1 from public.dog_owners dgo
      where dgo.dog_id = alerts.dog_id and dgo.user_id = auth.uid()
    )
  );

drop policy if exists alerts_co_owner_update on public.alerts;
drop policy if exists alerts_linked_owner_update on public.alerts;
create policy alerts_linked_owner_update on public.alerts
  for update using (
    exists (
      select 1 from public.dog_owners dgo
      where dgo.dog_id = alerts.dog_id and dgo.user_id = auth.uid()
    )
  );

drop policy if exists devices_co_owner_select on public.devices;
drop policy if exists devices_linked_owner_select on public.devices;
create policy devices_linked_owner_select on public.devices
  for select using (
    exists (
      select 1 from public.dog_owners dgo
      where dgo.dog_id = devices.dog_id and dgo.user_id = auth.uid()
    )
  );

drop policy if exists dog_baselines_co_owner_select on public.dog_baselines;
drop policy if exists dog_baselines_linked_owner_select on public.dog_baselines;
create policy dog_baselines_linked_owner_select on public.dog_baselines
  for select using (
    exists (
      select 1 from public.dog_owners dgo
      where dgo.dog_id = dog_baselines.dog_id and dgo.user_id = auth.uid()
    )
  );

drop policy if exists vet_notes_co_owner_select on public.vet_notes;
drop policy if exists vet_notes_linked_owner_select on public.vet_notes;
create policy vet_notes_linked_owner_select on public.vet_notes
  for select using (
    exists (
      select 1 from public.dog_owners dgo
      where dgo.dog_id = vet_notes.dog_id and dgo.user_id = auth.uid()
    )
  );

drop policy if exists media_submissions_co_owner_all on public.media_submissions;
drop policy if exists media_submissions_linked_owner_all on public.media_submissions;
create policy media_submissions_linked_owner_all on public.media_submissions
  for all using (
    exists (
      select 1 from public.dog_owners dgo
      where dgo.dog_id = media_submissions.dog_id and dgo.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.dog_owners dgo
      where dgo.dog_id = media_submissions.dog_id and dgo.user_id = auth.uid()
    )
  );

drop policy if exists stress_labels_co_owner_select on public.stress_labels;
drop policy if exists stress_labels_linked_owner_select on public.stress_labels;
create policy stress_labels_linked_owner_select on public.stress_labels
  for select using (
    exists (
      select 1 from public.dog_owners dgo
      where dgo.dog_id = stress_labels.dog_id and dgo.user_id = auth.uid()
    )
  );

-- =========================================================================
-- 5. Primary owner sync trigger and backfill
-- =========================================================================
create or replace function public.handle_dog_owner_sync()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.owner_user_id is not null then
    insert into public.dog_owners (dog_id, user_id)
    values (new.id, new.owner_user_id)
    on conflict (dog_id, user_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_dog_primary_owner on public.dogs;
create trigger trg_sync_dog_primary_owner
after insert or update of owner_user_id on public.dogs
for each row execute function public.handle_dog_owner_sync();

-- Backfill all existing dogs into dog_owners
insert into public.dog_owners (dog_id, user_id)
select id, owner_user_id from public.dogs
where owner_user_id is not null
on conflict (dog_id, user_id) do nothing;
