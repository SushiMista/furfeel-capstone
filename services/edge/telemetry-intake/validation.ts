import { defaultConfig } from "../classifier/index.ts";
import type { ClassifierConfig, Posture, TelemetryFeatures } from "../classifier/index.ts";
import type { TelemetryRequestBody } from "./types.ts";

const VALID_POSTURES: readonly Posture[] = [
  "standing",
  "sitting",
  "lying",
  "moving",
  "unknown",
];

export type ParsedTelemetryRequestBody =
  | { ok: true; value: TelemetryRequestBody }
  | { ok: false; message: string };

/** Structural gate: only device_code and captured_at are required to proceed at all. */
export function parseTelemetryRequestBody(raw: unknown): ParsedTelemetryRequestBody {
  if (typeof raw !== "object" || raw === null) {
    return { ok: false, message: "request body must be a JSON object" };
  }

  const body = raw as Record<string, unknown>;

  const deviceCode = body.device_code;
  if (typeof deviceCode !== "string" || deviceCode.trim().length === 0) {
    return { ok: false, message: "device_code is required and must be a non-empty string" };
  }

  const capturedAt = body.captured_at;
  if (typeof capturedAt !== "string" || Number.isNaN(new Date(capturedAt).getTime())) {
    return {
      ok: false,
      message: "captured_at is required and must be a parseable ISO-8601 timestamp",
    };
  }

  return {
    ok: true,
    value: { ...body, device_code: deviceCode, captured_at: capturedAt } as TelemetryRequestBody,
  };
}

export interface SanitizedNumericField {
  value: number | null;
  invalid: boolean;
}

/**
 * docs/07: out-of-range or wrong-typed values are flagged, never silently replaced with a
 * clamped/corrected number. Missing (undefined/null) is allowed and not flagged. A present
 * value that's the wrong type or out of [min,max] is nulled out and flagged invalid so the
 * classifier skips it (docs/07: "the classifier skips rules for null fields") while the raw
 * value the device sent is still preserved verbatim in raw_payload by the caller.
 */
export function sanitizeNumericField(
  value: unknown,
  range: { min: number; max: number },
): SanitizedNumericField {
  if (value === undefined || value === null) {
    return { value: null, invalid: false };
  }
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return { value: null, invalid: true };
  }
  if (value < range.min || value > range.max) {
    return { value: null, invalid: true };
  }
  return { value, invalid: false };
}

export interface SanitizedPosture {
  feature: Posture | null;
  dbValue: Posture;
  invalid: boolean;
}

/** posture_type is NOT NULL in the schema, so 'unknown' (its own column default) is the
 * closest analog to "null" for missing or unrecognized posture values. */
export function sanitizePosture(value: unknown): SanitizedPosture {
  if (value === undefined || value === null) {
    return { feature: null, dbValue: "unknown", invalid: false };
  }
  if (typeof value === "string" && (VALID_POSTURES as readonly string[]).includes(value)) {
    const posture = value as Posture;
    return { feature: posture, dbValue: posture, invalid: false };
  }
  return { feature: null, dbValue: "unknown", invalid: true };
}

/** True if capturedAtIso is within maxSkewHours of serverNow, in either direction. */
export function checkCapturedAtSkew(
  capturedAtIso: string,
  serverNow: Date,
  maxSkewHours: number,
): boolean {
  const capturedAtMs = new Date(capturedAtIso).getTime();
  if (Number.isNaN(capturedAtMs)) return false;
  const diffMs = Math.abs(serverNow.getTime() - capturedAtMs);
  return diffMs <= maxSkewHours * 60 * 60 * 1000;
}

export interface SanitizedTelemetry {
  features: TelemetryFeatures;
  posture_db: Posture;
  is_valid: boolean;
  invalid_fields: string[];
  captured_at: string;
}

export function sanitizeTelemetry(
  body: TelemetryRequestBody,
  serverNow: Date,
  config: ClassifierConfig = defaultConfig,
): SanitizedTelemetry {
  const ranges = config.validation_ranges;
  const invalidFields: string[] = [];

  const hr = sanitizeNumericField(body.heart_rate_bpm, ranges.heart_rate_bpm);
  if (hr.invalid) invalidFields.push("heart_rate_bpm");

  const temp = sanitizeNumericField(body.body_temperature_c, ranges.body_temperature_c);
  if (temp.invalid) invalidFields.push("body_temperature_c");

  const rr = sanitizeNumericField(body.respiratory_rate_bpm, ranges.respiratory_rate_bpm);
  if (rr.invalid) invalidFields.push("respiratory_rate_bpm");

  const motion = sanitizeNumericField(body.motion_activity, ranges.motion_activity);
  if (motion.invalid) invalidFields.push("motion_activity");

  const ambient = sanitizeNumericField(body.ambient_temperature_c, ranges.ambient_temperature_c);
  if (ambient.invalid) invalidFields.push("ambient_temperature_c");

  const humidity = sanitizeNumericField(body.humidity_percent, ranges.humidity_percent);
  if (humidity.invalid) invalidFields.push("humidity_percent");

  const posture = sanitizePosture(body.posture);
  if (posture.invalid) invalidFields.push("posture");

  const capturedAtOk = checkCapturedAtSkew(
    body.captured_at,
    serverNow,
    ranges.captured_at_max_skew_hours,
  );
  if (!capturedAtOk) invalidFields.push("captured_at");

  return {
    features: {
      heart_rate_bpm: hr.value,
      respiratory_rate_bpm: rr.value,
      body_temperature_c: temp.value,
      motion_activity: motion.value,
      posture: posture.feature,
      ambient_temperature_c: ambient.value,
      humidity_percent: humidity.value,
    },
    posture_db: posture.dbValue,
    is_valid: invalidFields.length === 0,
    invalid_fields: invalidFields,
    captured_at: body.captured_at,
  };
}
