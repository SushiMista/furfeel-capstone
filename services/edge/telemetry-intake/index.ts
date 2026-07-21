import { createServiceRoleClient } from "../_shared/supabase-client.ts";
import { verifyDeviceKey } from "../_shared/device-auth.ts";
import { classifyStress, defaultConfig } from "../classifier/index.ts";
import { alertTypeForStressLevel, decideAlert, decideBatteryAlert } from "../alerts/index.ts";
import { parseTelemetryRequestBody, sanitizeTelemetry } from "./validation.ts";
import { resolveBaselines, resolveLevelThresholds } from "./baselines.ts";
import type { DogBaselinesRow } from "./baselines.ts";

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function errorResponse(code: string, message: string, status: number): Response {
  return jsonResponse({ error: { code, message } }, status);
}

// POST /telemetry — docs/10 API and Backend Services, docs/07 Sensor Data Pipeline,
// docs/08 AI Classification Pipeline. Auth: x-device-key header (device secret), not a
// Supabase JWT — this function must run with verify_jwt disabled (see supabase/config.toml).
//
// ADDED (ISO 25010 performance-efficiency evidence, docs/20): every request
// logs one structured metric line; grep the function logs for
// `"metric":"telemetry_intake_ms"` and compute p50/p95 over the ms values.
// The simulator prints client-observed percentiles at the end of a run too.
Deno.serve(async (req) => {
  const startedAt = performance.now();
  const res = await handleTelemetry(req);
  console.log(JSON.stringify({
    metric: "telemetry_intake_ms",
    ms: Math.round(performance.now() - startedAt),
    status: res.status,
  }));
  return res;
});

async function handleTelemetry(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return errorResponse("validation_error", "only POST is supported", 400);
  }

  const deviceKey = req.headers.get("x-device-key");
  if (!deviceKey) {
    return errorResponse("unauthorized", "x-device-key header is required", 401);
  }

  let rawBody: unknown;
  try {
    rawBody = await req.json();
  } catch {
    return errorResponse("invalid_json", "request body must be valid JSON", 400);
  }

  const parsed = parseTelemetryRequestBody(rawBody);
  if (!parsed.ok) {
    return errorResponse("validation_error", parsed.message, 400);
  }
  const body = parsed.value;

  const supabase = createServiceRoleClient();

  try {
    const { data: device, error: deviceError } = await supabase
      .from("devices")
      .select("id, dog_id, ingest_key_hash, status, dogs(name)")
      .eq("device_code", body.device_code)
      .maybeSingle();

    if (deviceError) {
      console.error("device lookup failed", deviceError);
      return errorResponse("internal_error", "failed to look up device", 500);
    }
    if (!device) {
      return errorResponse("not_found", "unknown device_code", 404);
    }

    const keyOk = await verifyDeviceKey(deviceKey, device.ingest_key_hash);
    if (!keyOk) {
      return errorResponse("unauthorized", "invalid device key", 401);
    }

    if (!device.dog_id) {
      return errorResponse("unprocessable", "device is not assigned to a dog", 422);
    }

    // Sanitize/validate (docs/07): never silently clamp a bad value, null it out and flag
    // the row. is_valid is logged (per-field detail has no DB column, only the aggregate).
    const sanitized = sanitizeTelemetry(body, new Date());
    if (!sanitized.is_valid) {
      console.log("telemetry validation flagged fields", {
        device_code: body.device_code,
        invalid_fields: sanitized.invalid_fields,
      });
    }

    const { data: baselineRow, error: baselineError } = await supabase
      .from("dog_baselines")
      .select(
        "resting_heart_rate_bpm, resting_respiratory_rate_bpm, normal_body_temperature_c, " +
          "threshold_mild_min, threshold_moderate_min, threshold_high_min",
      )
      .eq("dog_id", device.dog_id)
      .maybeSingle();

    if (baselineError) {
      console.error("dog_baselines lookup failed", baselineError);
      return errorResponse("internal_error", "failed to look up dog baselines", 500);
    }

    const typedBaselineRow = baselineRow as DogBaselinesRow | null;
    const baselines = resolveBaselines(typedBaselineRow);
    // Per-dog score->level thresholds (docs/08): NULL columns fall back to
    // the global defaults, same shape as the baseline resolver above.
    const levelThresholds = resolveLevelThresholds(typedBaselineRow);
    const config = { ...defaultConfig, level_thresholds: levelThresholds };

    const { data: recentRows, error: recentError } = await supabase
      .from("stress_classifications")
      .select("score")
      .eq("dog_id", device.dog_id)
      .order("created_at", { ascending: false })
      .limit(5);

    if (recentError) {
      console.error("recent stress_classifications lookup failed", recentError);
      return errorResponse("internal_error", "failed to look up recent classifications", 500);
    }

    // Reverse to oldest->newest, most-recent-last, as classifyStress's trend rule expects.
    const recentScores = (recentRows ?? [])
      .map((r: { score: number | null }) => r.score)
      .filter((s: number | null): s is number => s !== null)
      .reverse();

    const classification = classifyStress(sanitized.features, baselines, recentScores, config);

    // Raw payload stored verbatim regardless of validity (ADR-003: raw before classification).
    const { data: readingRow, error: readingError } = await supabase
      .from("telemetry_readings")
      .insert({
        device_id: device.id,
        dog_id: device.dog_id,
        captured_at: sanitized.captured_at,
        heart_rate_bpm: sanitized.features.heart_rate_bpm,
        body_temperature_c: sanitized.features.body_temperature_c,
        respiratory_rate_bpm: sanitized.features.respiratory_rate_bpm,
        motion_activity: sanitized.features.motion_activity,
        posture: sanitized.posture_db,
        ambient_temperature_c: sanitized.features.ambient_temperature_c,
        humidity_percent: sanitized.features.humidity_percent,
        battery_percent: sanitized.battery_percent,
        is_valid: sanitized.is_valid,
        raw_payload: rawBody,
      })
      .select("id")
      .single();

    if (readingError || !readingRow) {
      console.error("telemetry_readings insert failed", readingError);
      return errorResponse("internal_error", "failed to store telemetry reading", 500);
    }

    const { data: classificationRow, error: classificationError } = await supabase
      .from("stress_classifications")
      .insert({
        dog_id: device.dog_id,
        telemetry_reading_id: readingRow.id,
        stress_level: classification.stress_level,
        score: classification.score,
        confidence: null,
        reasons: classification.reasons,
        model_version: classification.model_version,
      })
      .select("id")
      .single();

    if (classificationError || !classificationRow) {
      console.error("stress_classifications insert failed", classificationError);
      return errorResponse("internal_error", "failed to store stress classification", 500);
    }

    // Alert evaluation (docs/11): dedup against an already-open alert of the same type so a
    // dog stuck at one elevated level doesn't get a new alert every ~10-second telemetry tick.
    // Friendly copy names the dog (QA pass: warm, observational notification language).
    const dogName =
      (device as { dogs?: { name?: string } | null }).dogs?.name ?? "Your dog";
    let alertCreated = false;
    const alertType = alertTypeForStressLevel(classification.stress_level);
    if (alertType) {
      const { data: openAlerts, error: openAlertError } = await supabase
        .from("alerts")
        .select("id")
        .eq("dog_id", device.dog_id)
        .eq("type", alertType)
        .eq("status", "open")
        .limit(1);

      if (openAlertError) {
        console.error("open alert lookup failed", openAlertError);
      } else {
        const decision = decideAlert(
          classification.stress_level,
          (openAlerts ?? []).length > 0,
          dogName,
          classification.reasons,
        );
        if (decision) {
          const { error: alertInsertError } = await supabase.from("alerts").insert({
            dog_id: device.dog_id,
            classification_id: classificationRow.id,
            severity: decision.severity,
            type: decision.type,
            message: decision.message,
          });
          if (alertInsertError) {
            console.error("alerts insert failed", alertInsertError);
          } else {
            alertCreated = true;
          }
        }
      }
    }

    // Partial-failure semantics (confirmed): device liveness update failing doesn't fail
    // the request — telemetry+classification succeeding is the core contract.
    // Recovery (docs/11): a reading from an 'offline' device flips it back to 'active'
    // and resolves the open device_offline alert raised by check_device_offline().
    // 'inactive'/'maintenance' are deliberate operator states and stay untouched.
    const wasOffline = device.status === "offline";
    const { error: deviceUpdateError } = await supabase
      .from("devices")
      .update({
        last_seen_at: new Date().toISOString(),
        ...(wasOffline ? { status: "active" } : {}),
        // Mirror the latest battery reading so clients can show it without
        // scanning telemetry (docs/04 pairing screen, Home battery chip).
        ...(sanitized.battery_percent !== null
          ? { battery_percent: sanitized.battery_percent }
          : {}),
      })
      .eq("id", device.id);

    if (deviceUpdateError) {
      console.error("devices liveness update failed", deviceUpdateError);
    }

    if (wasOffline) {
      const { error: resolveError } = await supabase
        .from("alerts")
        .update({ status: "resolved" })
        .eq("dog_id", device.dog_id)
        .eq("type", "device_offline")
        .eq("status", "open");
      if (resolveError) {
        console.error("device_offline alert resolve failed", resolveError);
      }
    }

    // Low-battery alert (docs/11): raise once under the provisional threshold
    // (classifier_config.json device_alerts), resolve automatically once charged.
    // Never fails the request — battery alerting is best-effort like liveness.
    if (sanitized.battery_percent !== null) {
      const { data: openBattery, error: openBatteryError } = await supabase
        .from("alerts")
        .select("id")
        .eq("dog_id", device.dog_id)
        .eq("type", "low_battery")
        .eq("status", "open")
        .limit(1);

      if (openBatteryError) {
        console.error("open low_battery alert lookup failed", openBatteryError);
      } else {
        const batteryDecision = decideBatteryAlert(
          sanitized.battery_percent,
          defaultConfig.device_alerts.low_battery_percent,
          (openBattery ?? []).length > 0,
          dogName,
        );
        if (batteryDecision === "resolve") {
          const { error: resolveBatteryError } = await supabase
            .from("alerts")
            .update({ status: "resolved" })
            .eq("dog_id", device.dog_id)
            .eq("type", "low_battery")
            .eq("status", "open");
          if (resolveBatteryError) {
            console.error("low_battery alert resolve failed", resolveBatteryError);
          }
        } else if (batteryDecision) {
          const { error: batteryInsertError } = await supabase.from("alerts").insert({
            dog_id: device.dog_id,
            severity: batteryDecision.severity,
            type: batteryDecision.type,
            message: batteryDecision.message,
          });
          if (batteryInsertError) {
            console.error("low_battery alert insert failed", batteryInsertError);
          }
        }
      }
    }

    return jsonResponse(
      {
        reading_id: readingRow.id,
        stress_level: classification.stress_level,
        alert_created: alertCreated,
      },
      202,
    );
  } catch (err) {
    console.error("unhandled error in telemetry-intake", err);
    return errorResponse("internal_error", "unexpected server error", 500);
  }
}
