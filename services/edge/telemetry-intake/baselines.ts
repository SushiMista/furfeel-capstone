import { defaultConfig } from "../classifier/index.ts";
import type { Baselines, ClassifierConfig } from "../classifier/index.ts";

/** The subset of a dog_baselines row this function needs (docs/09: all value
 * columns are nullable, and the row itself may not exist for a given dog). */
export interface DogBaselinesRow {
  resting_heart_rate_bpm: number | null;
  resting_respiratory_rate_bpm: number | null;
  normal_body_temperature_c: number | null;
  threshold_mild_min: number | null;
  threshold_moderate_min: number | null;
  threshold_high_min: number | null;
  hr_ratio_elevated_min: number | null;
  hr_ratio_moderate_min: number | null;
  hr_ratio_high_min: number | null;
  rr_ratio_elevated_min: number | null;
  rr_ratio_high_min: number | null;
  body_temp_elevated_c: number | null;
  body_temp_high_c: number | null;
  motion_elevated_min: number | null;
  motion_high_min: number | null;
  ambient_heat_c: number | null;
  humidity_heat_pct: number | null;
}

/**
 * Resolve per-dog baselines, falling back per-field to the global defaults (docs/08:
 * "use dog_baselines if present, else the global defaults"). motion_activity has no
 * per-dog column in the schema, so it always uses the global default.
 */
export function resolveBaselines(
  row: DogBaselinesRow | null,
  config: ClassifierConfig = defaultConfig,
): Baselines {
  const globals = config.global_baselines;
  return {
    heart_rate_bpm: row?.resting_heart_rate_bpm ?? globals.heart_rate_bpm,
    respiratory_rate_bpm: row?.resting_respiratory_rate_bpm ?? globals.respiratory_rate_bpm,
    body_temperature_c: row?.normal_body_temperature_c ?? globals.body_temperature_c,
    motion_activity: globals.motion_activity,
  };
}

/**
 * Resolve per-dog score->level thresholds, falling back per-field to the global defaults
 * (docs/08) -- same "per-dog row if present, else global default" shape as
 * [resolveBaselines], just for the three level cut points instead of the resting values.
 * A dog_baselines row with all three threshold columns null (no override) reproduces
 * config.level_thresholds exactly.
 */
export function resolveLevelThresholds(
  row: DogBaselinesRow | null,
  config: ClassifierConfig = defaultConfig,
): ClassifierConfig["level_thresholds"] {
  const globals = config.level_thresholds;
  const mildMin = row?.threshold_mild_min ?? globals.mild.min;
  const moderateMin = row?.threshold_moderate_min ?? globals.moderate.min;
  const highMin = row?.threshold_high_min ?? globals.high.min;
  return {
    calm: { min: globals.calm.min, max: mildMin - 1 },
    mild: { min: mildMin, max: moderateMin - 1 },
    moderate: { min: moderateMin, max: highMin - 1 },
    high: { min: highMin, max: null },
  };
}

/**
 * Resolve per-dog scoring-rule tier floors, same fallback shape as
 * [resolveLevelThresholds] but one level finer: this overrides where each
 * individual SIGNAL (heart rate, respiratory rate, temperature, motion,
 * ambient heat/humidity) starts scoring, as opposed to how many total points
 * it takes to reach a stress level. Both are vet-tunable independently.
 *
 * Only each tier's `min` (and posture_moving_with_high_motion's inferred
 * floor) is overridable -- `points` and `reason` always come from the global
 * config, so a custom cutoff still reports using the same labels the rest of
 * the app understands. Every tier's `max` is recomputed from the next tier's
 * (possibly overridden) `min` so tiers stay contiguous -- an override can
 * never leave a scoring gap or overlap.
 */
export function resolveScoringRules(
  row: DogBaselinesRow | null,
  config: ClassifierConfig = defaultConfig,
): ClassifierConfig["scoring_rules"] {
  const g = config.scoring_rules;

  const hr1 = row?.hr_ratio_elevated_min ?? g.heart_rate_elevated.tiers[0].min;
  const hr2 = row?.hr_ratio_moderate_min ?? g.heart_rate_elevated.tiers[1].min;
  const hr3 = row?.hr_ratio_high_min ?? g.heart_rate_elevated.tiers[2].min;

  const rr1 = row?.rr_ratio_elevated_min ?? g.respiratory_elevated.tiers[0].min;
  const rr2 = row?.rr_ratio_high_min ?? g.respiratory_elevated.tiers[1].min;

  const temp1 = row?.body_temp_elevated_c ?? g.body_temperature.tiers[0].min;
  const temp2 = row?.body_temp_high_c ?? g.body_temperature.tiers[1].min;

  const motion1 = row?.motion_elevated_min ?? g.motion_restlessness.tiers[0].min;
  const motion2 = row?.motion_high_min ?? g.motion_restlessness.tiers[1].min;

  const ambientAbove = row?.ambient_heat_c ?? g.environmental_amplifier.ambient_temperature_c_above;
  const humidityAbove = row?.humidity_heat_pct ?? g.environmental_amplifier.humidity_percent_above;

  return {
    ...g,
    heart_rate_elevated: {
      ...g.heart_rate_elevated,
      tiers: [
        { ...g.heart_rate_elevated.tiers[0], min: hr1, max: hr2 },
        { ...g.heart_rate_elevated.tiers[1], min: hr2, max: hr3 },
        { ...g.heart_rate_elevated.tiers[2], min: hr3, max: null },
      ],
    },
    respiratory_elevated: {
      ...g.respiratory_elevated,
      tiers: [
        { ...g.respiratory_elevated.tiers[0], min: rr1, max: rr2 },
        { ...g.respiratory_elevated.tiers[1], min: rr2, max: null },
      ],
    },
    body_temperature: {
      ...g.body_temperature,
      tiers: [
        { ...g.body_temperature.tiers[0], min: temp1, max: temp2 },
        { ...g.body_temperature.tiers[1], min: temp2, max: null },
      ],
    },
    motion_restlessness: {
      ...g.motion_restlessness,
      tiers: [
        { ...g.motion_restlessness.tiers[0], min: motion1, max: motion2 },
        { ...g.motion_restlessness.tiers[1], min: motion2, max: null },
      ],
    },
    posture_moving_with_high_motion: {
      ...g.posture_moving_with_high_motion,
      // Same inference classifier_config.json's own comment documents for the
      // global case: reuse the (possibly overridden) motion tier-1 floor.
      motion_activity_min: motion1,
    },
    environmental_amplifier: {
      ...g.environmental_amplifier,
      ambient_temperature_c_above: ambientAbove,
      humidity_percent_above: humidityAbove,
    },
  };
}
