import { defaultConfig } from "../classifier/index.ts";
import {
  checkCapturedAtSkew,
  parseTelemetryRequestBody,
  sanitizeNumericField,
  sanitizePosture,
  sanitizeTelemetry,
} from "./validation.ts";
import type { TelemetryRequestBody } from "./types.ts";

function assertEqual<T>(actual: T, expected: T, msg?: string) {
  if (actual !== expected) {
    throw new Error(msg ?? `expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

function assertArrayEqual(actual: string[], expected: string[], msg?: string) {
  const sortedActual = [...actual].sort();
  const sortedExpected = [...expected].sort();
  if (
    sortedActual.length !== sortedExpected.length ||
    sortedActual.some((v, i) => v !== sortedExpected[i])
  ) {
    throw new Error(msg ?? `expected [${expected.join(", ")}], got [${actual.join(", ")}]`);
  }
}

const ranges = defaultConfig.validation_ranges;
const NOW = new Date("2026-07-09T08:00:00Z");

function minimalBody(overrides: Partial<TelemetryRequestBody> = {}): TelemetryRequestBody {
  return {
    device_code: "ff-device-001",
    captured_at: NOW.toISOString(),
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// sanitizeNumericField boundary tests, one block per docs/07 field
// ---------------------------------------------------------------------------

Deno.test("heart_rate_bpm: 500 is invalid (flagged, nulled)", () => {
  const result = sanitizeNumericField(500, ranges.heart_rate_bpm);
  assertEqual(result.invalid, true);
  assertEqual(result.value, null);
});

Deno.test("heart_rate_bpm: 20 valid, 19 invalid (lower boundary)", () => {
  assertEqual(sanitizeNumericField(20, ranges.heart_rate_bpm).invalid, false);
  assertEqual(sanitizeNumericField(19, ranges.heart_rate_bpm).invalid, true);
});

Deno.test("heart_rate_bpm: 300 valid, 301 invalid (upper boundary)", () => {
  assertEqual(sanitizeNumericField(300, ranges.heart_rate_bpm).invalid, false);
  assertEqual(sanitizeNumericField(301, ranges.heart_rate_bpm).invalid, true);
});

Deno.test("body_temperature_c: 30.0 valid, 29.9 invalid", () => {
  assertEqual(sanitizeNumericField(30.0, ranges.body_temperature_c).invalid, false);
  assertEqual(sanitizeNumericField(29.9, ranges.body_temperature_c).invalid, true);
});

Deno.test("body_temperature_c: 43.0 valid, 43.1 invalid", () => {
  assertEqual(sanitizeNumericField(43.0, ranges.body_temperature_c).invalid, false);
  assertEqual(sanitizeNumericField(43.1, ranges.body_temperature_c).invalid, true);
});

Deno.test("respiratory_rate_bpm: 3 valid, 2 invalid", () => {
  assertEqual(sanitizeNumericField(3, ranges.respiratory_rate_bpm).invalid, false);
  assertEqual(sanitizeNumericField(2, ranges.respiratory_rate_bpm).invalid, true);
});

Deno.test("respiratory_rate_bpm: 200 valid, 201 invalid", () => {
  assertEqual(sanitizeNumericField(200, ranges.respiratory_rate_bpm).invalid, false);
  assertEqual(sanitizeNumericField(201, ranges.respiratory_rate_bpm).invalid, true);
});

Deno.test("motion_activity: 0.0 valid, -0.01 invalid", () => {
  assertEqual(sanitizeNumericField(0.0, ranges.motion_activity).invalid, false);
  assertEqual(sanitizeNumericField(-0.01, ranges.motion_activity).invalid, true);
});

Deno.test("motion_activity: 1.0 valid, 1.01 invalid", () => {
  assertEqual(sanitizeNumericField(1.0, ranges.motion_activity).invalid, false);
  assertEqual(sanitizeNumericField(1.01, ranges.motion_activity).invalid, true);
});

Deno.test("ambient_temperature_c: -10 valid, -10.1 invalid", () => {
  assertEqual(sanitizeNumericField(-10, ranges.ambient_temperature_c).invalid, false);
  assertEqual(sanitizeNumericField(-10.1, ranges.ambient_temperature_c).invalid, true);
});

Deno.test("ambient_temperature_c: 60 valid, 60.1 invalid", () => {
  assertEqual(sanitizeNumericField(60, ranges.ambient_temperature_c).invalid, false);
  assertEqual(sanitizeNumericField(60.1, ranges.ambient_temperature_c).invalid, true);
});

Deno.test("humidity_percent: 0 valid, -1 invalid", () => {
  assertEqual(sanitizeNumericField(0, ranges.humidity_percent).invalid, false);
  assertEqual(sanitizeNumericField(-1, ranges.humidity_percent).invalid, true);
});

Deno.test("humidity_percent: 100 valid, 101 invalid", () => {
  assertEqual(sanitizeNumericField(100, ranges.humidity_percent).invalid, false);
  assertEqual(sanitizeNumericField(101, ranges.humidity_percent).invalid, true);
});

Deno.test("sanitizeNumericField: missing (undefined/null) is allowed, not flagged", () => {
  const undef = sanitizeNumericField(undefined, ranges.heart_rate_bpm);
  const nul = sanitizeNumericField(null, ranges.heart_rate_bpm);
  assertEqual(undef.invalid, false);
  assertEqual(undef.value, null);
  assertEqual(nul.invalid, false);
  assertEqual(nul.value, null);
});

Deno.test("sanitizeNumericField: wrong JSON type (string) is treated as invalid, not rejected", () => {
  const result = sanitizeNumericField("92", ranges.heart_rate_bpm);
  assertEqual(result.invalid, true);
  assertEqual(result.value, null);
});

// ---------------------------------------------------------------------------
// sanitizePosture
// ---------------------------------------------------------------------------

Deno.test("sanitizePosture: valid enum value is kept", () => {
  const result = sanitizePosture("standing");
  assertEqual(result.invalid, false);
  assertEqual(result.feature, "standing");
  assertEqual(result.dbValue, "standing");
});

Deno.test("sanitizePosture: missing -> 'unknown', not flagged invalid", () => {
  const result = sanitizePosture(undefined);
  assertEqual(result.invalid, false);
  assertEqual(result.feature, null);
  assertEqual(result.dbValue, "unknown");
});

Deno.test("sanitizePosture: unrecognized value -> 'unknown', flagged invalid", () => {
  const result = sanitizePosture("napping");
  assertEqual(result.invalid, true);
  assertEqual(result.feature, null);
  assertEqual(result.dbValue, "unknown");
});

// ---------------------------------------------------------------------------
// checkCapturedAtSkew
// ---------------------------------------------------------------------------

Deno.test("checkCapturedAtSkew: exact match is within tolerance", () => {
  assertEqual(checkCapturedAtSkew(NOW.toISOString(), NOW, 1), true);
});

Deno.test("checkCapturedAtSkew: 30 minutes in the past is within tolerance", () => {
  const capturedAt = new Date(NOW.getTime() - 30 * 60 * 1000).toISOString();
  assertEqual(checkCapturedAtSkew(capturedAt, NOW, 1), true);
});

Deno.test("checkCapturedAtSkew: 61 minutes in the past exceeds tolerance", () => {
  const capturedAt = new Date(NOW.getTime() - 61 * 60 * 1000).toISOString();
  assertEqual(checkCapturedAtSkew(capturedAt, NOW, 1), false);
});

Deno.test("checkCapturedAtSkew: 61 minutes in the future exceeds tolerance", () => {
  const capturedAt = new Date(NOW.getTime() + 61 * 60 * 1000).toISOString();
  assertEqual(checkCapturedAtSkew(capturedAt, NOW, 1), false);
});

// ---------------------------------------------------------------------------
// sanitizeTelemetry (integration of the above)
// ---------------------------------------------------------------------------

Deno.test("sanitizeTelemetry: all fields missing -> is_valid true, all features null", () => {
  const result = sanitizeTelemetry(minimalBody(), NOW);
  assertEqual(result.is_valid, true);
  assertArrayEqual(result.invalid_fields, []);
  assertEqual(result.features.heart_rate_bpm, null);
  assertEqual(result.features.respiratory_rate_bpm, null);
  assertEqual(result.features.body_temperature_c, null);
  assertEqual(result.features.motion_activity, null);
  assertEqual(result.features.posture, null);
  assertEqual(result.features.ambient_temperature_c, null);
  assertEqual(result.features.humidity_percent, null);
  assertEqual(result.posture_db, "unknown");
});

Deno.test("sanitizeTelemetry: heart_rate_bpm 500 alone -> is_valid false, only that field flagged", () => {
  const result = sanitizeTelemetry(minimalBody({ heart_rate_bpm: 500 }), NOW);
  assertEqual(result.is_valid, false);
  assertArrayEqual(result.invalid_fields, ["heart_rate_bpm"]);
  assertEqual(result.features.heart_rate_bpm, null);
});

Deno.test("sanitizeTelemetry: one valid field present, rest missing -> is_valid true", () => {
  const result = sanitizeTelemetry(minimalBody({ heart_rate_bpm: 92 }), NOW);
  assertEqual(result.is_valid, true);
  assertArrayEqual(result.invalid_fields, []);
  assertEqual(result.features.heart_rate_bpm, 92);
});

Deno.test("sanitizeTelemetry: captured_at skewed -> is_valid false, captured_at echoed verbatim", () => {
  const skewed = new Date(NOW.getTime() - 90 * 60 * 1000).toISOString();
  const result = sanitizeTelemetry(minimalBody({ captured_at: skewed }), NOW);
  assertEqual(result.is_valid, false);
  assertArrayEqual(result.invalid_fields, ["captured_at"]);
  assertEqual(result.captured_at, skewed);
});

Deno.test("sanitizeTelemetry: multiple simultaneous violations are all flagged", () => {
  const skewed = new Date(NOW.getTime() - 90 * 60 * 1000).toISOString();
  const result = sanitizeTelemetry(
    minimalBody({ heart_rate_bpm: 500, motion_activity: 5.0, captured_at: skewed }),
    NOW,
  );
  assertEqual(result.is_valid, false);
  assertArrayEqual(result.invalid_fields, ["heart_rate_bpm", "motion_activity", "captured_at"]);
  assertEqual(result.features.heart_rate_bpm, null);
  assertEqual(result.features.motion_activity, null);
});

Deno.test("sanitizeTelemetry: unrecognized posture flags is_valid false", () => {
  const result = sanitizeTelemetry(minimalBody({ posture: "napping" }), NOW);
  assertEqual(result.is_valid, false);
  assertArrayEqual(result.invalid_fields, ["posture"]);
  assertEqual(result.posture_db, "unknown");
});

// ---------------------------------------------------------------------------
// parseTelemetryRequestBody
// ---------------------------------------------------------------------------

Deno.test("parseTelemetryRequestBody: minimal valid body -> ok", () => {
  const result = parseTelemetryRequestBody({
    device_code: "ff-device-001",
    captured_at: "2026-07-09T08:00:00Z",
  });
  assertEqual(result.ok, true);
});

Deno.test("parseTelemetryRequestBody: missing device_code -> not ok", () => {
  const result = parseTelemetryRequestBody({ captured_at: "2026-07-09T08:00:00Z" });
  assertEqual(result.ok, false);
});

Deno.test("parseTelemetryRequestBody: empty-string device_code -> not ok", () => {
  const result = parseTelemetryRequestBody({
    device_code: "  ",
    captured_at: "2026-07-09T08:00:00Z",
  });
  assertEqual(result.ok, false);
});

Deno.test("parseTelemetryRequestBody: missing captured_at -> not ok", () => {
  const result = parseTelemetryRequestBody({ device_code: "ff-device-001" });
  assertEqual(result.ok, false);
});

Deno.test("parseTelemetryRequestBody: unparseable captured_at -> not ok", () => {
  const result = parseTelemetryRequestBody({
    device_code: "ff-device-001",
    captured_at: "not-a-date",
  });
  assertEqual(result.ok, false);
});

Deno.test("parseTelemetryRequestBody: non-object body -> not ok", () => {
  assertEqual(parseTelemetryRequestBody(null).ok, false);
  assertEqual(parseTelemetryRequestBody("a string").ok, false);
  assertEqual(parseTelemetryRequestBody(42).ok, false);
});

// ---------------------------------------------------------------------------
// battery_percent (QA pass: device health telemetry, docs/07)

Deno.test("sanitizeTelemetry: valid battery_percent is kept and rounded", () => {
  const result = sanitizeTelemetry(minimalBody({ battery_percent: 86.6 }), NOW);
  assertEqual(result.battery_percent, 87);
  assertEqual(result.is_valid, true);
});

Deno.test("sanitizeTelemetry: missing battery_percent -> null, still valid", () => {
  const result = sanitizeTelemetry(minimalBody(), NOW);
  assertEqual(result.battery_percent, null);
  assertEqual(result.is_valid, true);
});

Deno.test("sanitizeTelemetry: out-of-range battery_percent -> nulled and flagged", () => {
  const result = sanitizeTelemetry(minimalBody({ battery_percent: 130 }), NOW);
  assertEqual(result.battery_percent, null);
  assertEqual(result.is_valid, false);
  assertEqual(result.invalid_fields.includes("battery_percent"), true);
});
