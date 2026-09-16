-- Migration: Enforce 1 Dog 1 Device Protocol & Remove Auto Dummy Device Trigger
-- 1. Drop the automatic dummy device creation trigger and function
drop trigger if exists on_dog_created on public.dogs;
drop function if exists public.handle_new_dog();

-- 2. Clean up duplicate dummy devices where a dog already has another device assigned
-- First delete telemetry readings and stress classifications for duplicate dummy devices
delete from public.stress_classifications
where telemetry_reading_id in (
  select tr.id
  from public.telemetry_readings tr
  join public.devices d on d.id = tr.device_id
  where d.device_code like 'FF-DUMMY-%'
    and d.dog_id in (
      select dog_id
      from public.devices
      where dog_id is not null
      group by dog_id
      having count(*) > 1
    )
);

delete from public.telemetry_readings
where device_id in (
  select d.id
  from public.devices d
  where d.device_code like 'FF-DUMMY-%'
    and d.dog_id in (
      select dog_id
      from public.devices
      where dog_id is not null
      group by dog_id
      having count(*) > 1
    )
);

-- Delete the duplicate dummy devices themselves
delete from public.devices
where device_code like 'FF-DUMMY-%'
  and dog_id in (
    select dog_id
    from public.devices
    where dog_id is not null
    group by dog_id
    having count(*) > 1
  );

-- 3. In case any remaining non-dummy duplicates exist, detach older ones so only 1 device remains per dog
update public.devices
set dog_id = null, status = 'offline'
where id in (
  select id from (
    select id,
           row_number() over (partition by dog_id order by created_at desc) as rn
    from public.devices
    where dog_id is not null
  ) duplicates
  where duplicates.rn > 1
);

-- 4. Create a unique constraint index ensuring exactly 1 active device per dog at the database level
create unique index if not exists idx_devices_unique_dog_id
  on public.devices(dog_id)
  where dog_id is not null;

-- 5. Allow veterinarians to view device deletion requests in audit logs
drop policy if exists audit_logs_select_admin_or_clinic on public.audit_logs;
create policy audit_logs_select_admin_or_clinic on public.audit_logs
  for select using (
    public.current_user_role() = 'admin'
    or action = 'device.deletion_requested'
    or (
      public.current_user_role() in ('vet_staff', 'veterinarian')
      and (
        actor_id = auth.uid()
        or (audit_logs.clinic_id is not null and audit_logs.clinic_id = (select u.clinic_id from public.users u where u.id = auth.uid()))
      )
    )
  );
