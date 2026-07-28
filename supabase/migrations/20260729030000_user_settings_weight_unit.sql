-- Settings page "Weight" unit toggle was UI-only; give it a real column
-- (same pattern as temperature_unit).
alter table user_settings
  add column weight_unit text not null default 'kg' check (weight_unit in ('kg', 'lbs'));
