import { defaultConfig } from "../classifier/index.ts";
import type { Baselines, ClassifierConfig } from "../classifier/index.ts";

/** The subset of a dog_baselines row this function needs (docs/09: all three value
 * columns are nullable, and the row itself may not exist for a given dog). */
export interface DogBaselinesRow {
  resting_heart_rate_bpm: number | null;
  resting_respiratory_rate_bpm: number | null;
  normal_body_temperature_c: number | null;
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
