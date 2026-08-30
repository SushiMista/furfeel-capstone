-- Enable cascade deletion for dogs so admin can delete dog profiles seamlessly
-- Devices are unlinked (set null) while historical child records cascade delete.

-- 1. Unlink devices automatically when a dog is deleted
alter table public.devices drop constraint if exists devices_dog_id_fkey;
alter table public.devices add constraint devices_dog_id_fkey foreign key (dog_id) references public.dogs (id) on delete set null;

-- 2. Cascade delete clinical records
alter table public.dog_baselines drop constraint if exists dog_baselines_dog_id_fkey;
alter table public.dog_baselines add constraint dog_baselines_dog_id_fkey foreign key (dog_id) references public.dogs (id) on delete cascade;

alter table public.telemetry_readings drop constraint if exists telemetry_readings_dog_id_fkey;
alter table public.telemetry_readings add constraint telemetry_readings_dog_id_fkey foreign key (dog_id) references public.dogs (id) on delete cascade;

alter table public.stress_classifications drop constraint if exists stress_classifications_dog_id_fkey;
alter table public.stress_classifications add constraint stress_classifications_dog_id_fkey foreign key (dog_id) references public.dogs (id) on delete cascade;

alter table public.alerts drop constraint if exists alerts_dog_id_fkey;
alter table public.alerts add constraint alerts_dog_id_fkey foreign key (dog_id) references public.dogs (id) on delete cascade;

alter table public.vet_notes drop constraint if exists vet_notes_dog_id_fkey;
alter table public.vet_notes add constraint vet_notes_dog_id_fkey foreign key (dog_id) references public.dogs (id) on delete cascade;

alter table public.media_submissions drop constraint if exists media_submissions_dog_id_fkey;
alter table public.media_submissions add constraint media_submissions_dog_id_fkey foreign key (dog_id) references public.dogs (id) on delete cascade;

alter table public.handover_notes drop constraint if exists handover_notes_dog_id_fkey;
alter table public.handover_notes add constraint handover_notes_dog_id_fkey foreign key (dog_id) references public.dogs (id) on delete cascade;

-- 3. Security Definer helper RPC for admin atomic dog deletion
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

  update public.devices set dog_id = null where dog_id = p_dog_id;
  delete from public.alerts where dog_id = p_dog_id;
  delete from public.vet_notes where dog_id = p_dog_id;
  delete from public.handover_notes where dog_id = p_dog_id;
  delete from public.media_submissions where dog_id = p_dog_id;
  delete from public.dog_baselines where dog_id = p_dog_id;
  delete from public.stress_classifications where dog_id = p_dog_id;
  delete from public.telemetry_readings where dog_id = p_dog_id;
  delete from public.dogs where id = p_dog_id;
end;
$$;

grant execute on function public.admin_delete_dog(uuid) to authenticated;

-- 4. Security Definer helper RPC for admin bulk dog deletion
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
  delete from public.alerts where dog_id = any(p_dog_ids);
  delete from public.vet_notes where dog_id = any(p_dog_ids);
  delete from public.handover_notes where dog_id = any(p_dog_ids);
  delete from public.media_submissions where dog_id = any(p_dog_ids);
  delete from public.dog_baselines where dog_id = any(p_dog_ids);
  delete from public.stress_classifications where dog_id = any(p_dog_ids);
  delete from public.telemetry_readings where dog_id = any(p_dog_ids);
  delete from public.dogs where id = any(p_dog_ids);
end;
$$;

grant execute on function public.admin_bulk_delete_dogs(uuid[]) to authenticated;
