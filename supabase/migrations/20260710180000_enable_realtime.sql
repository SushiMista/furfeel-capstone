-- Dashboard/mobile subscribe to Postgres changes on these three tables, filtered by dog_id
-- (docs/10 API and Backend Services, "Realtime" section). Tables must be added to the
-- supabase_realtime publication for postgres_changes events to fire. RLS still applies to
-- Realtime delivery, so no filter is needed here for row-level scoping.

alter publication supabase_realtime add table public.telemetry_readings;
alter publication supabase_realtime add table public.stress_classifications;
alter publication supabase_realtime add table public.alerts;
