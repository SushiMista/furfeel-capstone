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
