-- ADR-025: ambient temperature is the sole active environmental input.
-- Keep historical values and old-client schema compatibility; never delete raw telemetry.
comment on column public.telemetry_readings.humidity_percent is
  'Deprecated by ADR-025. Historical only; current intake and classifier ignore humidity.';
comment on column public.dog_baselines.humidity_heat_pct is
  'Deprecated by ADR-025. Retained for history; no longer an active threshold override.';
