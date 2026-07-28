-- clinic_stress_daily_summary (20260729020000_clinic_stress_daily_summary.sql)
-- filters stress_classifications by created_at ONLY, across every clinic-
-- visible dog — no dog_id predicate. The only existing index on this table,
-- idx_stress_classifications_dog_created (dog_id, created_at desc), can't
-- help a query with no dog_id filter: a composite index's leading column
-- must be constrained for it to be usable at all. Without a matching index,
-- Postgres falls back to a full sequential scan of a table that is already
-- 13,000+ rows for one dog alone and grows continuously from live telemetry
-- (confirmed live: the RPC took ~6.4s even after fixing the query-count
-- fan-out, right at the edge of the statement timeout — ADR-021).
--
-- CONCURRENTLY avoids taking a lock that would block the firmware's ongoing
-- inserts while the index builds; it cannot run inside a transaction block,
-- so run this statement on its own (the Supabase SQL Editor already does).

create index concurrently if not exists idx_stress_classifications_created_at
  on stress_classifications (created_at);
