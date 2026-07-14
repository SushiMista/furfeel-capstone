-- RLS is row-level, not column-level: the existing devices_select_owner_or_clinic /
-- devices_admin_all policies correctly scope WHICH rows a client can read, but do nothing
-- to stop a client from selecting ingest_key_hash on a row it can already see. That column
-- holds the device's hashed ingest secret and should never be client-readable, even hashed.
-- This only tightens access (never weakens RLS): row-level policies are untouched.

revoke select on public.devices from authenticated;
grant select (id, dog_id, device_code, status, last_seen_at, firmware_version, created_at)
  on public.devices to authenticated;
