-- Bugfix: devices uses COLUMN-level select grants (20260710171500 revoked
-- table-wide select so ingest_key_hash stays unreadable). The new
-- battery_percent column wasn't in that grant list, so every client select
-- naming it failed with a permission error and Home couldn't load. Additive
-- grant only; ingest_key_hash stays revoked.
grant select (battery_percent) on public.devices to authenticated;
