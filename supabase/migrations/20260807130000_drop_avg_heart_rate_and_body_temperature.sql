-- Amends ADR-021 (docs/02): drops telemetry_readings.body_temperature_c
-- outright, reversing the earlier "keep it for raw telemetry history
-- (ADR-003)" call -- any body-temperature readings already collected are
-- deleted along with the column. Owner decision, 2026-08-07.
--
-- avg_heart_rate_bpm is dropped for the first time here: it was never a
-- classifier input (rule-v1 scores heart_rate_bpm only, docs/08) and was
-- never displayed in either client -- write-only since it was added.

alter table telemetry_readings
  drop column if exists body_temperature_c,
  drop column if exists avg_heart_rate_bpm;
