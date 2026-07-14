-- Owner-facing trends & insights (docs/04 "simple graphical visualizations",
-- docs/19 §6). Raw classifications are far too high-volume to ship to a phone
-- for a 14-day trend, so these summary functions aggregate server-side.
--
-- Both are SECURITY INVOKER (the default): the caller's RLS on
-- stress_classifications / telemetry_readings still decides which rows are
-- visible, so no scoping is re-implemented (and none is weakened) here.
-- p_tz_offset_minutes shifts bucketing into the viewer's local day/hour.

-- Stress-level mix per local day (+ average motion, for activity insights).
create function public.stress_daily_summary(
  p_dog_id uuid,
  p_days int default 14,
  p_tz_offset_minutes int default 0
)
returns table (
  day date,
  calm bigint,
  mild bigint,
  moderate bigint,
  high bigint,
  avg_motion numeric
)
language sql
stable
set search_path = public, pg_temp
as $$
  with levels as (
    select
      (created_at + make_interval(mins => p_tz_offset_minutes))::date as day,
      count(*) filter (where stress_level = 'calm')     as calm,
      count(*) filter (where stress_level = 'mild')     as mild,
      count(*) filter (where stress_level = 'moderate') as moderate,
      count(*) filter (where stress_level = 'high')     as high
    from stress_classifications
    where dog_id = p_dog_id
      and created_at >= now() - make_interval(days => p_days)
    group by 1
  ),
  motion as (
    select
      (captured_at + make_interval(mins => p_tz_offset_minutes))::date as day,
      round(avg(motion_activity), 3) as avg_motion
    from telemetry_readings
    where dog_id = p_dog_id
      and captured_at >= now() - make_interval(days => p_days)
      and is_valid
    group by 1
  )
  select l.day, l.calm, l.mild, l.moderate, l.high, m.avg_motion
  from levels l
  left join motion m using (day)
  order by l.day;
$$;

-- Stress-level mix by local hour of day (0-23), pooled over the window —
-- powers "calmest in the evening / most tense mid-morning" insights.
create function public.stress_hourly_pattern(
  p_dog_id uuid,
  p_days int default 14,
  p_tz_offset_minutes int default 0
)
returns table (
  hour int,
  calm bigint,
  mild bigint,
  moderate bigint,
  high bigint
)
language sql
stable
set search_path = public, pg_temp
as $$
  select
    extract(hour from created_at + make_interval(mins => p_tz_offset_minutes))::int as hour,
    count(*) filter (where stress_level = 'calm')     as calm,
    count(*) filter (where stress_level = 'mild')     as mild,
    count(*) filter (where stress_level = 'moderate') as moderate,
    count(*) filter (where stress_level = 'high')     as high
  from stress_classifications
  where dog_id = p_dog_id
    and created_at >= now() - make_interval(days => p_days)
  group by 1
  order by 1;
$$;

revoke execute on function public.stress_daily_summary(uuid, int, int) from public, anon;
revoke execute on function public.stress_hourly_pattern(uuid, int, int) from public, anon;
grant execute on function public.stress_daily_summary(uuid, int, int) to authenticated;
grant execute on function public.stress_hourly_pattern(uuid, int, int) to authenticated;
