-- =========================================================================
-- Comprehensive Admin CRUD Deletion Cascades & RPCs
-- Fixes:
-- 1. Dog Deletion (unlinks devices, cascades telemetry, classifications, stress labels, notes, media, alerts)
-- 2. Device Deletion (unlinks dogs, cleans up telemetry and orphaned classifications/alerts, deletes device)
-- 3. Clinic Deletion (unlinks staff/users, unlinks dogs, removes clinic-specific care guidance, deletes clinic)
-- =========================================================================

-- -------------------------------------------------------------------------
-- 1. FOREIGN KEY CASCADE & SET NULL CONSTRAINTS
-- -------------------------------------------------------------------------

-- Clinics linkages (Set null on staff and dogs, cascade delete clinic care guidance)
alter table public.users drop constraint if exists users_clinic_id_fkey;
alter table public.users add constraint users_clinic_id_fkey foreign key (clinic_id) references public.clinics (id) on delete set null;

alter table public.dogs drop constraint if exists dogs_clinic_id_fkey;
alter table public.dogs add constraint dogs_clinic_id_fkey foreign key (clinic_id) references public.clinics (id) on delete set null;

do $$
begin
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'care_guidance') then
    alter table public.care_guidance drop constraint if exists care_guidance_clinic_id_fkey;
    alter table public.care_guidance add constraint care_guidance_clinic_id_fkey foreign key (clinic_id) references public.clinics (id) on delete cascade;
  end if;
end $$;

-- Devices linkages (Cascade telemetry when a device is deleted)
alter table public.telemetry_readings drop constraint if exists telemetry_readings_device_id_fkey;
alter table public.telemetry_readings add constraint telemetry_readings_device_id_fkey foreign key (device_id) references public.devices (id) on delete cascade;

-- Dogs linkages (Set null on devices, cascade delete telemetry, clinical data, notes, media)
alter table public.devices drop constraint if exists devices_dog_id_fkey;
alter table public.devices add constraint devices_dog_id_fkey foreign key (dog_id) references public.dogs (id) on delete set null;

alter table public.dog_baselines drop constraint if exists dog_baselines_dog_id_fkey;
alter table public.dog_baselines add constraint dog_baselines_dog_id_fkey foreign key (dog_id) references public.dogs (id) on delete cascade;

alter table public.telemetry_readings drop constraint if exists telemetry_readings_dog_id_fkey;
alter table public.telemetry_readings add constraint telemetry_readings_dog_id_fkey foreign key (dog_id) references public.dogs (id) on delete cascade;

alter table public.stress_classifications drop constraint if exists stress_classifications_dog_id_fkey;
alter table public.stress_classifications add constraint stress_classifications_dog_id_fkey foreign key (dog_id) references public.dogs (id) on delete cascade;

alter table public.stress_classifications drop constraint if exists stress_classifications_telemetry_reading_id_fkey;
alter table public.stress_classifications add constraint stress_classifications_telemetry_reading_id_fkey foreign key (telemetry_reading_id) references public.telemetry_readings (id) on delete cascade;

alter table public.alerts drop constraint if exists alerts_dog_id_fkey;
alter table public.alerts add constraint alerts_dog_id_fkey foreign key (dog_id) references public.dogs (id) on delete cascade;

alter table public.alerts drop constraint if exists alerts_classification_id_fkey;
alter table public.alerts add constraint alerts_classification_id_fkey foreign key (classification_id) references public.stress_classifications (id) on delete cascade;

alter table public.vet_notes drop constraint if exists vet_notes_dog_id_fkey;
alter table public.vet_notes add constraint vet_notes_dog_id_fkey foreign key (dog_id) references public.dogs (id) on delete cascade;

alter table public.media_submissions drop constraint if exists media_submissions_dog_id_fkey;
alter table public.media_submissions add constraint media_submissions_dog_id_fkey foreign key (dog_id) references public.dogs (id) on delete cascade;

do $$
begin
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'stress_labels') then
    alter table public.stress_labels drop constraint if exists stress_labels_dog_id_fkey;
    alter table public.stress_labels add constraint stress_labels_dog_id_fkey foreign key (dog_id) references public.dogs (id) on delete cascade;

    alter table public.stress_labels drop constraint if exists stress_labels_telemetry_reading_id_fkey;
    alter table public.stress_labels add constraint stress_labels_telemetry_reading_id_fkey foreign key (telemetry_reading_id) references public.telemetry_readings (id) on delete cascade;

    alter table public.stress_labels drop constraint if exists stress_labels_classification_id_fkey;
    alter table public.stress_labels add constraint stress_labels_classification_id_fkey foreign key (classification_id) references public.stress_classifications (id) on delete cascade;
  end if;

  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'handover_notes') then
    alter table public.handover_notes drop constraint if exists handover_notes_dog_id_fkey;
    alter table public.handover_notes add constraint handover_notes_dog_id_fkey foreign key (dog_id) references public.dogs (id) on delete cascade;
  end if;
end $$;

-- -------------------------------------------------------------------------
-- 2. RPC FUNCTIONS: DOG MANAGEMENT
-- -------------------------------------------------------------------------

create or replace function public.admin_delete_dog(p_dog_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if public.current_user_role() != 'admin' then
    raise exception 'Unauthorized: Only administrators can delete dogs';
  end if;

  -- 1. Unlink any device
  update public.devices set dog_id = null where dog_id = p_dog_id;

  -- 2. Delete media messages
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'media_messages') then
    delete from public.media_messages where media_submission_id in (
      select id from public.media_submissions where dog_id = p_dog_id
    );
  end if;

  -- 3. Delete clinical & interaction records
  delete from public.media_submissions where dog_id = p_dog_id;
  delete from public.vet_notes where dog_id = p_dog_id;

  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'handover_notes') then
    delete from public.handover_notes where dog_id = p_dog_id;
  end if;

  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'stress_labels') then
    delete from public.stress_labels where dog_id = p_dog_id;
  end if;

  delete from public.alerts where dog_id = p_dog_id;
  delete from public.stress_classifications where dog_id = p_dog_id;
  delete from public.dog_baselines where dog_id = p_dog_id;
  delete from public.telemetry_readings where dog_id = p_dog_id;

  -- 4. Delete dog profile
  delete from public.dogs where id = p_dog_id;
end;
$$;

grant execute on function public.admin_delete_dog(uuid) to authenticated;

create or replace function public.admin_bulk_delete_dogs(p_dog_ids uuid[])
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if public.current_user_role() != 'admin' then
    raise exception 'Unauthorized: Only administrators can delete dogs';
  end if;

  update public.devices set dog_id = null where dog_id = any(p_dog_ids);

  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'media_messages') then
    delete from public.media_messages where media_submission_id in (
      select id from public.media_submissions where dog_id = any(p_dog_ids)
    );
  end if;

  delete from public.media_submissions where dog_id = any(p_dog_ids);
  delete from public.vet_notes where dog_id = any(p_dog_ids);

  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'handover_notes') then
    delete from public.handover_notes where dog_id = any(p_dog_ids);
  end if;

  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'stress_labels') then
    delete from public.stress_labels where dog_id = any(p_dog_ids);
  end if;

  delete from public.alerts where dog_id = any(p_dog_ids);
  delete from public.stress_classifications where dog_id = any(p_dog_ids);
  delete from public.dog_baselines where dog_id = any(p_dog_ids);
  delete from public.telemetry_readings where dog_id = any(p_dog_ids);

  delete from public.dogs where id = any(p_dog_ids);
end;
$$;

grant execute on function public.admin_bulk_delete_dogs(uuid[]) to authenticated;

-- -------------------------------------------------------------------------
-- 3. RPC FUNCTIONS: DEVICE MANAGEMENT
-- -------------------------------------------------------------------------

create or replace function public.admin_delete_device(p_device_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  reading_ids uuid[];
  classification_ids uuid[];
begin
  if public.current_user_role() != 'admin' then
    raise exception 'Unauthorized: Only administrators can delete devices';
  end if;

  -- 1. Unlink any dog currently paired with this device
  update public.devices set dog_id = null where id = p_device_id;

  -- 2. Collect reading and classification IDs
  select array_agg(id) into reading_ids from public.telemetry_readings where device_id = p_device_id;

  if reading_ids is not null and array_length(reading_ids, 1) > 0 then
    select array_agg(id) into classification_ids from public.stress_classifications where telemetry_reading_id = any(reading_ids);

    -- Delete stress labels referencing these readings or classifications
    if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'stress_labels') then
      delete from public.stress_labels where telemetry_reading_id = any(reading_ids);
      if classification_ids is not null and array_length(classification_ids, 1) > 0 then
        delete from public.stress_labels where classification_id = any(classification_ids);
      end if;
    end if;

    -- Delete alerts referencing classifications of these readings
    if classification_ids is not null and array_length(classification_ids, 1) > 0 then
      delete from public.alerts where classification_id = any(classification_ids);
    end if;

    -- Delete classifications and telemetry readings
    delete from public.stress_classifications where telemetry_reading_id = any(reading_ids);
    delete from public.telemetry_readings where device_id = p_device_id;
  end if;

  -- 3. Delete the device
  delete from public.devices where id = p_device_id;
end;
$$;

grant execute on function public.admin_delete_device(uuid) to authenticated;

create or replace function public.admin_bulk_delete_devices(p_device_ids uuid[])
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  reading_ids uuid[];
  classification_ids uuid[];
begin
  if public.current_user_role() != 'admin' then
    raise exception 'Unauthorized: Only administrators can delete devices';
  end if;

  update public.devices set dog_id = null where id = any(p_device_ids);

  select array_agg(id) into reading_ids from public.telemetry_readings where device_id = any(p_device_ids);

  if reading_ids is not null and array_length(reading_ids, 1) > 0 then
    select array_agg(id) into classification_ids from public.stress_classifications where telemetry_reading_id = any(reading_ids);

    if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'stress_labels') then
      delete from public.stress_labels where telemetry_reading_id = any(reading_ids);
      if classification_ids is not null and array_length(classification_ids, 1) > 0 then
        delete from public.stress_labels where classification_id = any(classification_ids);
      end if;
    end if;

    if classification_ids is not null and array_length(classification_ids, 1) > 0 then
      delete from public.alerts where classification_id = any(classification_ids);
    end if;

    delete from public.stress_classifications where telemetry_reading_id = any(reading_ids);
    delete from public.telemetry_readings where device_id = any(p_device_ids);
  end if;

  delete from public.devices where id = any(p_device_ids);
end;
$$;

grant execute on function public.admin_bulk_delete_devices(uuid[]) to authenticated;

-- -------------------------------------------------------------------------
-- 4. RPC FUNCTIONS: CLINIC MANAGEMENT
-- -------------------------------------------------------------------------

create or replace function public.admin_delete_clinic(p_clinic_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if public.current_user_role() != 'admin' then
    raise exception 'Unauthorized: Only administrators can delete partner clinics';
  end if;

  -- 1. Unlink staff/vets and dogs from this clinic
  update public.users set clinic_id = null where clinic_id = p_clinic_id;
  update public.dogs set clinic_id = null where clinic_id = p_clinic_id;

  -- 2. Delete clinic-specific care guidance
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'care_guidance') then
    delete from public.care_guidance where clinic_id = p_clinic_id;
  end if;

  -- 3. Unlink audit logs
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'audit_logs') then
    update public.audit_logs set clinic_id = null where clinic_id = p_clinic_id;
  end if;

  -- 4. Delete the clinic
  delete from public.clinics where id = p_clinic_id;
end;
$$;

grant execute on function public.admin_delete_clinic(uuid) to authenticated;

create or replace function public.admin_bulk_delete_clinics(p_clinic_ids uuid[])
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if public.current_user_role() != 'admin' then
    raise exception 'Unauthorized: Only administrators can delete partner clinics';
  end if;

  update public.users set clinic_id = null where clinic_id = any(p_clinic_ids);
  update public.dogs set clinic_id = null where clinic_id = any(p_clinic_ids);

  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'care_guidance') then
    delete from public.care_guidance where clinic_id = any(p_clinic_ids);
  end if;

  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'audit_logs') then
    update public.audit_logs set clinic_id = null where clinic_id = any(p_clinic_ids);
  end if;

  delete from public.clinics where id = any(p_clinic_ids);
end;
$$;

grant execute on function public.admin_bulk_delete_clinics(uuid[]) to authenticated;
