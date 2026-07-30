-- Overview's clinic-wide "stress mix — last 14 days" chart (docs/05 §1)
-- previously summed together N per-dog stress_daily_summary RPC calls (one
-- per clinic dog) client-side — the exact fan-out that produced the 57014
-- statement-timeout under concurrent load (ADR-021). The fix for the board
-- data was a single embedded PostgREST query (see queries.ts
-- fetchClinicBoardSummary); the daily mix needs its own fix because it's an
-- *aggregate*, not a lookup.
--
-- The first fix attempted here was fetching raw stress_classifications rows
-- clinic-wide and bucketing by day in JavaScript instead of via RPC. That
-- was wrong on two counts, found by checking against the live database
-- rather than assuming it would scale:
--   1. Correctness: this project's PostgREST config caps responses at 1000
--      rows. A 14-day window across one active dog alone was 11,893 rows —
--      the client-side approach silently returned the chart's first ~8% of
--      the period as if it were the whole thing, no error.
--   2. Performance: even capped at 1000, the query took ~6.3s, because
--      ordering thousands of rows and evaluating the clinic-membership RLS
--      predicate per row (with no dog_id filter to seed an index scan) is
--      real work regardless of how few rows are eventually returned.
--
-- Aggregating server-side avoids both: Postgres does count(*) filter (...)
-- group by day and only ships the resulting handful of day rows over the
-- wire, this table's own dog_id/created_at index still narrows the scan
-- normally, and RLS decides which rows count without an explicit dog_id
-- list. Mirrors stress_daily_summary (20260712100000_stress_summaries.sql)
-- with the per-dog filter removed and the (irrelevant clinic-wide)
-- avg_motion column dropped.

create function public.clinic_stress_daily_summary(
  p_days int default 14,
  p_tz_offset_minutes int default 0
)
returns table (
  day date,
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
    (created_at + make_interval(mins => p_tz_offset_minutes))::date as day,
    count(*) filter (where stress_level = 'calm')     as calm,
    count(*) filter (where stress_level = 'mild')     as mild,
    count(*) filter (where stress_level = 'moderate') as moderate,
    count(*) filter (where stress_level = 'high')     as high
  from stress_classifications
  where created_at >= now() - make_interval(days => p_days)
  group by 1
  order by 1;
$$;
