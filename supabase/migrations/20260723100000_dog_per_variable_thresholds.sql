-- Per-VARIABLE classifier threshold overrides (docs/08 AI Classification
-- Pipeline), on top of the per-LEVEL score cutoffs added in
-- 20260721091500_dog_threshold_overrides.sql. Those three columns only move
-- where the aggregate SCORE crosses into mild/moderate/high; a vet asked for
-- something more granular: "let me set the threshold for each variable
-- itself (heart rate, respiratory rate, body temperature, motion activity,
-- ambient temperature, humidity) for this specific dog, and if I don't,
-- leave it at the clinic-wide default." Both mechanisms are complementary,
-- not a replacement of one another: this controls when an individual signal
-- starts scoring; the earlier columns control how many points it takes to
-- reach a level.
--
-- Same table, same nullable-column pattern, same RLS (dog_baselines_select/
-- insert/update already gate on is_clinic_member(dog_id) -- no new policy
-- needed). One column per scoring-rule tier floor in
-- classifier_config.json.scoring_rules, named after the rule + tier it
-- overrides. NULL = use that global tier's min. Points and reason text are
-- NOT overridable here -- only where each tier starts.

alter table dog_baselines
  add column hr_ratio_elevated_min   numeric(4, 2), -- heart_rate_elevated tier 1 (global 1.15)
  add column hr_ratio_moderate_min   numeric(4, 2), -- heart_rate_elevated tier 2 (global 1.35)
  add column hr_ratio_high_min       numeric(4, 2), -- heart_rate_elevated tier 3 (global 1.60)
  add column rr_ratio_elevated_min   numeric(4, 2), -- respiratory_elevated tier 1 (global 1.30)
  add column rr_ratio_high_min       numeric(4, 2), -- respiratory_elevated tier 2, panting (global 1.80)
  add column body_temp_elevated_c    numeric(3, 1), -- body_temperature tier 1 (global 39.2)
  add column body_temp_high_c        numeric(3, 1), -- body_temperature tier 2 (global 39.7)
  add column motion_elevated_min     numeric(3, 2), -- motion_restlessness tier 1 (global 0.60)
  add column motion_high_min         numeric(3, 2), -- motion_restlessness tier 2 (global 0.80)
  add column ambient_heat_c          numeric(4, 1), -- environmental_amplifier ambient leg (global 32)
  add column humidity_heat_pct       numeric(4, 1); -- environmental_amplifier humidity leg (global 80)

-- Ordering constraints only where a rule has more than one tier -- same
-- "null-safe strictly increasing" shape as dog_baselines_thresholds_ordered.
alter table dog_baselines
  add constraint dog_baselines_hr_tiers_ordered check (
    (hr_ratio_elevated_min is null or hr_ratio_moderate_min is null
      or hr_ratio_elevated_min < hr_ratio_moderate_min)
    and (hr_ratio_moderate_min is null or hr_ratio_high_min is null
      or hr_ratio_moderate_min < hr_ratio_high_min)
    and (hr_ratio_elevated_min is null or hr_ratio_high_min is null
      or hr_ratio_elevated_min < hr_ratio_high_min)
  ),
  add constraint dog_baselines_rr_tiers_ordered check (
    rr_ratio_elevated_min is null or rr_ratio_high_min is null
      or rr_ratio_elevated_min < rr_ratio_high_min
  ),
  add constraint dog_baselines_temp_tiers_ordered check (
    body_temp_elevated_c is null or body_temp_high_c is null
      or body_temp_elevated_c < body_temp_high_c
  ),
  add constraint dog_baselines_motion_tiers_ordered check (
    motion_elevated_min is null or motion_high_min is null
      or motion_elevated_min < motion_high_min
  );
