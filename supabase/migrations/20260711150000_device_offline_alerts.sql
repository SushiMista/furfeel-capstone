-- Device-offline detection (docs/11 "Device stops sending data", docs/03 Sprint 2
-- "Device offline state is detectable").
--
-- A pg_cron job runs every minute and flips 'active' devices whose last_seen_at is
-- older than the threshold to 'offline', raising one 'device_offline' alert per dog
-- (deduped against an already-open alert of the same type, mirroring the stress-alert
-- dedup rule in services/edge/alerts). Recovery is handled by telemetry-intake: when
-- a reading arrives from an offline device it flips the device back to active and
-- resolves the open device_offline alert.
--
-- ASSUMPTION (docs/15 leaves the sampling interval open): devices transmit every ~10s
-- (docs/07 provisional default), so "stopped sending" = no data for 2 minutes
-- (12 missed payloads). Tune by re-scheduling with a different threshold argument.

create or replace function public.check_device_offline(threshold interval default interval '2 minutes')
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  alerts_created integer := 0;
begin
  with stale as (
    update devices
       set status = 'offline'
     where status = 'active'
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
        || to_char(s.last_seen_at at time zone 'utc', 'YYYY-MM-DD HH24:MI') || ' UTC).',
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

comment on function public.check_device_offline(interval) is
  'Marks active devices with stale last_seen_at as offline and raises deduped device_offline alerts. Invoked by pg_cron every minute.';

-- security definer: keep this out of client hands (it is not a client API).
revoke execute on function public.check_device_offline(interval) from public, anon, authenticated;

create extension if not exists pg_cron;

-- pg_cron >= 1.4 upserts by job name, so re-running this migration is safe.
select cron.schedule(
  'furfeel-device-offline-check',
  '* * * * *',
  $$select public.check_device_offline()$$
);
