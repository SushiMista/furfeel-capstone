import { defaultConfig } from "../classifier/index.ts";
import { resolveBaselines, resolveLevelThresholds } from "./baselines.ts";
import type { DogBaselinesRow } from "./baselines.ts";

function assertEqual<T>(actual: T, expected: T, msg?: string) {
  if (actual !== expected) {
    throw new Error(msg ?? `expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

const globals = defaultConfig.global_baselines;
const levelGlobals = defaultConfig.level_thresholds;

/** Full row with everything null except the given overrides — keeps each
 * test's row literal focused on the fields it actually cares about. */
function row(overrides: Partial<DogBaselinesRow>): DogBaselinesRow {
  return {
    resting_heart_rate_bpm: null,
    resting_respiratory_rate_bpm: null,
    normal_body_temperature_c: null,
    threshold_mild_min: null,
    threshold_moderate_min: null,
    threshold_high_min: null,
    ...overrides,
  };
}

Deno.test("resolveBaselines: no dog_baselines row -> all global defaults", () => {
  const result = resolveBaselines(null);
  assertEqual(result.heart_rate_bpm, globals.heart_rate_bpm);
  assertEqual(result.respiratory_rate_bpm, globals.respiratory_rate_bpm);
  assertEqual(result.body_temperature_c, globals.body_temperature_c);
  assertEqual(result.motion_activity, globals.motion_activity);
});

Deno.test("resolveBaselines: full row -> per-dog values used", () => {
  const result = resolveBaselines(row({
    resting_heart_rate_bpm: 110,
    resting_respiratory_rate_bpm: 30,
    normal_body_temperature_c: 39.0,
  }));
  assertEqual(result.heart_rate_bpm, 110);
  assertEqual(result.respiratory_rate_bpm, 30);
  assertEqual(result.body_temperature_c, 39.0);
  // No per-dog motion column exists at all -> always the global default.
  assertEqual(result.motion_activity, globals.motion_activity);
});

Deno.test("resolveBaselines: partial row -> per-field fallback to global defaults", () => {
  const result = resolveBaselines(row({
    resting_heart_rate_bpm: 110,
    resting_respiratory_rate_bpm: null,
    normal_body_temperature_c: null,
  }));
  assertEqual(result.heart_rate_bpm, 110);
  assertEqual(result.respiratory_rate_bpm, globals.respiratory_rate_bpm);
  assertEqual(result.body_temperature_c, globals.body_temperature_c);
});

Deno.test("resolveLevelThresholds: no row -> reproduces the global config exactly", () => {
  const result = resolveLevelThresholds(null);
  assertEqual(JSON.stringify(result), JSON.stringify(levelGlobals));
});

Deno.test("resolveLevelThresholds: no threshold columns set -> reproduces the global config", () => {
  const result = resolveLevelThresholds(row({ resting_heart_rate_bpm: 110 }));
  assertEqual(JSON.stringify(result), JSON.stringify(levelGlobals));
});

Deno.test("resolveLevelThresholds: full override -> a small, easily-stressed dog's cut points", () => {
  // A small anxious breed: mild/moderate/high should trip at lower scores
  // than the global medium-dog defaults.
  const result = resolveLevelThresholds(row({
    threshold_mild_min: 1,
    threshold_moderate_min: 3,
    threshold_high_min: 5,
  }));
  assertEqual(result.calm.min, 0);
  assertEqual(result.calm.max, 0);
  assertEqual(result.mild.min, 1);
  assertEqual(result.mild.max, 2);
  assertEqual(result.moderate.min, 3);
  assertEqual(result.moderate.max, 4);
  assertEqual(result.high.min, 5);
  assertEqual(result.high.max, null);
});

Deno.test("resolveLevelThresholds: partial override -> per-field fallback to global defaults", () => {
  const result = resolveLevelThresholds(row({ threshold_high_min: 9 }));
  assertEqual(result.mild.min, levelGlobals.mild.min);
  assertEqual(result.moderate.min, levelGlobals.moderate.min);
  assertEqual(result.high.min, 9);
});
