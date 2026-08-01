-- Rolling-average heart rate alongside the existing instantaneous heart_rate_bpm
-- (docs/07): device-reported smoothing over the last few beats, stored verbatim
-- like every other structured telemetry field. Not fed into the classifier --
-- rule-v1 scores on heart_rate_bpm only (docs/08) -- just captured for display/QA.
alter table telemetry_readings add column avg_heart_rate_bpm int;
