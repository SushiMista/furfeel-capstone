-- FurFeel doesn't promote invasive procedures to gather stress data (ADR-021).
-- Body temperature is dropped as a classifier input and a per-dog override.
--
-- telemetry_readings.body_temperature_c is left in place: it's raw sensor
-- history, not config, and ADR-003 says raw telemetry is never deleted. New
-- rows simply stop populating it (services/edge/telemetry-intake no longer
-- writes to it). dog_baselines' temperature columns are config/override
-- data, not raw telemetry, so they're safe to drop outright.

alter table dog_baselines
  drop constraint if exists dog_baselines_temp_tiers_ordered;

alter table dog_baselines
  drop column if exists normal_body_temperature_c,
  drop column if exists body_temp_elevated_c,
  drop column if exists body_temp_high_c;
