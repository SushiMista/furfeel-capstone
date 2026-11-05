-- Raw telemetry outlives its dog (ADR-003, ADR-027). dog_id stays as a plain
-- uuid so readings remain attributable after the dogs row is gone.
alter table public.telemetry_readings
  drop constraint telemetry_readings_dog_id_fkey;

-- The foreign key was also what rejected unknown dog_ids on insert.
drop policy telemetry_insert_clinic_staff on public.telemetry_readings;
create policy telemetry_insert_clinic_staff on public.telemetry_readings
  for insert to authenticated
  with check (
    public.current_user_role() in ('admin', 'veterinarian', 'vet_staff')
    and exists (select 1 from public.dogs d where d.id = telemetry_readings.dog_id)
  );

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

  -- 4. Delete dog profile
  delete from public.dogs where id = p_dog_id;
end;
$$;

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

  delete from public.dogs where id = any(p_dog_ids);
end;
$$;
