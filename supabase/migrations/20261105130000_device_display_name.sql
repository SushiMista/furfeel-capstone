-- Editable collar name for staff (QA). device_code stays the hardware identity
-- that firmware sends and telemetry-intake looks up, so it must not be renamed.
alter table public.devices
  add column display_name text
  check (display_name is null or length(trim(display_name)) between 1 and 60);

-- devices uses column-level select grants, so a new column needs its own.
grant select (display_name) on public.devices to authenticated;
