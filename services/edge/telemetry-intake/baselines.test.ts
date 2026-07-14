import { defaultConfig } from "../classifier/index.ts";
import { resolveBaselines } from "./baselines.ts";

function assertEqual<T>(actual: T, expected: T, msg?: string) {
  if (actual !== expected) {
    throw new Error(msg ?? `expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

const globals = defaultConfig.global_baselines;

Deno.test("resolveBaselines: no dog_baselines row -> all global defaults", () => {
  const result = resolveBaselines(null);
  assertEqual(result.heart_rate_bpm, globals.heart_rate_bpm);
  assertEqual(result.respiratory_rate_bpm, globals.respiratory_rate_bpm);
  assertEqual(result.body_temperature_c, globals.body_temperature_c);
  assertEqual(result.motion_activity, globals.motion_activity);
});

Deno.test("resolveBaselines: full row -> per-dog values used", () => {
  const result = resolveBaselines({
    resting_heart_rate_bpm: 110,
    resting_respiratory_rate_bpm: 30,
    normal_body_temperature_c: 39.0,
  });
  assertEqual(result.heart_rate_bpm, 110);
  assertEqual(result.respiratory_rate_bpm, 30);
  assertEqual(result.body_temperature_c, 39.0);
  // No per-dog motion column exists at all -> always the global default.
  assertEqual(result.motion_activity, globals.motion_activity);
});

Deno.test("resolveBaselines: partial row -> per-field fallback to global defaults", () => {
  const result = resolveBaselines({
    resting_heart_rate_bpm: 110,
    resting_respiratory_rate_bpm: null,
    normal_body_temperature_c: null,
  });
  assertEqual(result.heart_rate_bpm, 110);
  assertEqual(result.respiratory_rate_bpm, globals.respiratory_rate_bpm);
  assertEqual(result.body_temperature_c, globals.body_temperature_c);
});
