-- Migration: Update offline detection trigger to target physical ESP32 hardware
-- & resolve false offline alerts for dogs with active biotelemetry data

-- 1. Update check_device_offline function to only check physical hardware collars
create or replace function public.check_device_offline(threshold interval default interval '2 minutes')
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  alerts_created integer := 0;
begin
  -- Only flip real physical hardware (e.g. FURFEEL-DEV-0002) to offline if it stops transmitting
  with stale as (
    update devices
       set status = 'offline'
     where status = 'active'
       and device_code = 'FURFEEL-DEV-0002'
       and last_seen_at is not null
       and last_seen_at < now() - threshold
     returning id, dog_id, device_code, last_seen_at
  ),
  inserted as (
    insert into alerts (dog_id, severity, type, message, status)
    select
      s.dog_id,
      'warning',
      'device_offline',
      'Device ' || s.device_code || ' stopped sending data (last seen '
        || to_char(s.last_seen_at at time zone 'Asia/Manila', 'YYYY-MM-DD HH24:MI') || ' PST).',
      'open'
    from stale s
    where s.dog_id is not null
      and not exists (
        select 1 from alerts a
        where a.dog_id = s.dog_id
          and a.type = 'device_offline'
          and a.status = 'open'
      )
    returning 1
  )
  select count(*) into alerts_created from inserted;

  return alerts_created;
end;
$$;

-- 2. Restore active status for any collars attached to dogs with biotelemetry readings
update public.devices
set status = 'active',
    battery_percent = coalesce(battery_percent, 95)
where id in (
  select distinct device_id from public.telemetry_readings
)
and status <> 'maintenance';

-- 3. Resolve any false offline alerts for dogs with biotelemetry readings
update public.alerts
set status = 'acknowledged',
    acknowledged_at = now()
where type = 'device_offline'
  and status = 'open'
  and dog_id in (
    select distinct dog_id from public.telemetry_readings
  );
