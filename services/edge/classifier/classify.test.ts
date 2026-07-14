// Dependency-free assertions (no jsr:/https: imports) so these tests run offline.
import { classifyStress } from "./classify.ts";
import type { Baselines, TelemetryFeatures } from "./types.ts";

function assertEqual<T>(actual: T, expected: T, msg?: string) {
  if (actual !== expected) {
    throw new Error(msg ?? `expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

function assertArrayEqual(actual: string[], expected: string[], msg?: string) {
  if (actual.length !== expected.length || actual.some((v, i) => v !== expected[i])) {
    throw new Error(
      msg ?? `expected [${expected.join(", ")}], got [${actual.join(", ")}]`,
    );
  }
}

const GLOBAL_BASELINES: Baselines = {
  heart_rate_bpm: 90,
  respiratory_rate_bpm: 24,
  body_temperature_c: 38.7,
  motion_activity: 0.3,
};

function reading(overrides: Partial<TelemetryFeatures> = {}): TelemetryFeatures {
  return {
    heart_rate_bpm: null,
    respiratory_rate_bpm: null,
    body_temperature_c: null,
    motion_activity: null,
    posture: null,
    ambient_temperature_c: null,
    humidity_percent: null,
    ...overrides,
  };
}

Deno.test("worked example from docs/08 -> high, score 7", () => {
  const result = classifyStress(
    reading({
      heart_rate_bpm: 150,
      respiratory_rate_bpm: 46,
      body_temperature_c: 39.4,
      motion_activity: 0.7,
    }),
    GLOBAL_BASELINES,
  );

  assertEqual(result.score, 7);
  assertEqual(result.stress_level, "high");
  assertEqual(result.model_version, "rule-v1");
  assertArrayEqual(result.reasons, [
    "hr_ratio>1.6",
    "rr panting",
    "temp 39.2-39.7",
    "motion 0.6-0.8",
  ]);
});

Deno.test("all readings at baseline -> calm, score 0", () => {
  const result = classifyStress(
    reading({
      heart_rate_bpm: 90,
      respiratory_rate_bpm: 24,
      body_temperature_c: 38.7,
      motion_activity: 0.3,
    }),
    GLOBAL_BASELINES,
  );

  assertEqual(result.score, 0);
  assertEqual(result.stress_level, "calm");
  assertArrayEqual(result.reasons, []);
});

Deno.test("all readings null -> calm, score 0, no rules fire", () => {
  const result = classifyStress(reading(), GLOBAL_BASELINES);

  assertEqual(result.score, 0);
  assertEqual(result.stress_level, "calm");
  assertArrayEqual(result.reasons, []);
});

Deno.test("mild: hr tier1 + rr tier1 -> score 2", () => {
  // hr_ratio = 105/90 = 1.1667 -> tier1 (+1); rr_ratio = 32/24 = 1.333 -> tier1 (+1)
  const result = classifyStress(
    reading({ heart_rate_bpm: 105, respiratory_rate_bpm: 32 }),
    GLOBAL_BASELINES,
  );

  assertEqual(result.score, 2);
  assertEqual(result.stress_level, "mild");
  assertArrayEqual(result.reasons, ["hr_ratio 1.15-1.35", "rr_ratio 1.3-1.8"]);
});

Deno.test("moderate: hr tier2 + rr tier1 + temp tier1 -> score 4", () => {
  // hr_ratio = 126/90 = 1.4 -> tier2 (+2); rr_ratio = 32/24 = 1.333 -> tier1 (+1); temp 39.4 -> tier1 (+1)
  const result = classifyStress(
    reading({ heart_rate_bpm: 126, respiratory_rate_bpm: 32, body_temperature_c: 39.4 }),
    GLOBAL_BASELINES,
  );

  assertEqual(result.score, 4);
  assertEqual(result.stress_level, "moderate");
  assertArrayEqual(result.reasons, [
    "hr_ratio 1.35-1.6",
    "rr_ratio 1.3-1.8",
    "temp 39.2-39.7",
  ]);
});

Deno.test("high: score exactly at the 7 boundary from a different combination", () => {
  // hr_ratio > 1.6 (+3), temp > 39.7 (+2), motion > 0.8 (+2) -> score 7
  const result = classifyStress(
    reading({ heart_rate_bpm: 160, body_temperature_c: 40.0, motion_activity: 0.9 }),
    GLOBAL_BASELINES,
  );

  assertEqual(result.score, 7);
  assertEqual(result.stress_level, "high");
});

Deno.test("level boundaries: score 1 is calm, score 2 is mild, score 4 is moderate, score 5 is moderate", () => {
  assertEqual(classifyStress(reading({ heart_rate_bpm: 104 }), GLOBAL_BASELINES).stress_level, "calm"); // ratio 1.1556, below 1.15 tier -> 0
  assertEqual(
    classifyStress(reading({ heart_rate_bpm: 105 }), GLOBAL_BASELINES).stress_level, // ratio 1.1667 -> +1 -> score 1, still calm's upper bound
    "calm",
  );
  assertEqual(
    classifyStress(
      reading({ heart_rate_bpm: 126, respiratory_rate_bpm: 32, body_temperature_c: 39.3 }),
      GLOBAL_BASELINES,
    ).score,
    4,
  );
  assertEqual(
    classifyStress(
      reading({ heart_rate_bpm: 145, respiratory_rate_bpm: 32, body_temperature_c: 39.3 }),
      GLOBAL_BASELINES,
    ).stress_level, // hr_ratio 1.611 -> +3, rr +1, temp +1 = 5
    "moderate",
  );
});

Deno.test("posture rule stacks with motion rule when moving + motion >= 0.6", () => {
  const result = classifyStress(
    reading({ posture: "moving", motion_activity: 0.65 }),
    GLOBAL_BASELINES,
  );

  assertEqual(result.score, 2);
  assertEqual(result.stress_level, "mild");
  assertArrayEqual(result.reasons, ["motion 0.6-0.8", "posture moving + high motion"]);
});

Deno.test("posture rule does not fire when posture is not 'moving'", () => {
  const result = classifyStress(
    reading({ posture: "standing", motion_activity: 0.65 }),
    GLOBAL_BASELINES,
  );

  assertEqual(result.score, 1);
  assertArrayEqual(result.reasons, ["motion 0.6-0.8"]);
});

Deno.test("environmental amplifier fires once even if both ambient and humidity exceed thresholds", () => {
  const result = classifyStress(
    reading({ ambient_temperature_c: 35, humidity_percent: 85 }),
    GLOBAL_BASELINES,
  );

  assertEqual(result.score, 1);
  assertArrayEqual(result.reasons, ["environmental heat stress context"]);
});

Deno.test("rising trend adds +1 when the last 3 prior scores strictly increase", () => {
  const result = classifyStress(
    reading({ heart_rate_bpm: 105 }), // +1 from hr tier1
    GLOBAL_BASELINES,
    [1, 2, 3],
  );

  assertEqual(result.score, 2);
  assertEqual(result.stress_level, "mild");
  assertArrayEqual(result.reasons, [
    "hr_ratio 1.15-1.35",
    "rising trend over last 3 readings",
  ]);
});

Deno.test("rising trend does not fire when scores are not strictly increasing", () => {
  const result = classifyStress(reading({ heart_rate_bpm: 105 }), GLOBAL_BASELINES, [3, 2, 4]);
  assertEqual(result.score, 1);
  assertArrayEqual(result.reasons, ["hr_ratio 1.15-1.35"]);
});

Deno.test("rising trend does not fire with fewer than 3 prior scores", () => {
  const result = classifyStress(reading({ heart_rate_bpm: 105 }), GLOBAL_BASELINES, [1, 2]);
  assertEqual(result.score, 1);
  assertArrayEqual(result.reasons, ["hr_ratio 1.15-1.35"]);
});

Deno.test("per-dog baselines change the ratio, not the raw thresholds", () => {
  // Same 150 bpm reading, but a dog with a naturally higher resting HR of 130 has a
  // lower hr_ratio (1.1538) than the worked example's 1.67, so it should NOT hit the high tier.
  const dogBaselines: Baselines = { ...GLOBAL_BASELINES, heart_rate_bpm: 130 };
  const result = classifyStress(reading({ heart_rate_bpm: 150 }), dogBaselines);

  assertEqual(result.score, 1);
  assertArrayEqual(result.reasons, ["hr_ratio 1.15-1.35"]);
});
