import type { StressLevel } from "../classifier/index.ts";
import type { AlertDecision, AlertType } from "./types.ts";

/** Which alert `type` a stress level maps to, or null if that level never alerts
 * (docs/11: triggers are "stress level becomes Moderate" / "becomes High" only). */
export function alertTypeForStressLevel(level: StressLevel): AlertType | null {
  if (level === "moderate") return "moderate_stress";
  if (level === "high") return "high_stress";
  return null;
}

/** Owner-friendly phrase for the strongest reason the classifier logged
 * (docs/08 reason codes -> owner-facing "why"). Observational only — describes
 * what the sensors see, never why medically. */
export function friendlyReasonPhrase(reasons: string[]): string | null {
  const has = (needle: string) => reasons.some((r) => r.includes(needle));
  if (has("environmental heat")) return "it's warm and humid";
  if (has("rr panting") || has("rr_ratio")) return "they're breathing fast";
  if (has("hr_ratio")) return "their heart rate is up";
  if (has("temp")) return "their temperature is a little high";
  if (has("motion") || has("posture moving")) return "they're restless and moving a lot";
  if (has("rising trend")) return "their stress has been climbing";
  return null;
}

/**
 * Decide whether telemetry-intake should create a new stress alert.
 *
 * Design decision (confirmed): only create a new alert when there is no existing
 * OPEN alert of the same type for this dog already — otherwise a dog stuck at
 * 'high' would get a new alert row every ~10-second telemetry tick. docs/11 frames
 * triggers as "stress level *becomes* moderate/high" (a transition), which this
 * dedup-by-open-alert approach honors without needing readings history here.
 *
 * Copy is warm and plain (docs/04/docs/11 QA pass): name the dog, say what the
 * sensors observed, suggest a simple check-in. Never diagnosis or causal claims.
 *
 * @param hasOpenAlertOfSameType Whether an alerts row with status='open' and the
 *   type this level maps to already exists for this dog (caller queries this).
 */
export function decideAlert(
  stressLevel: StressLevel,
  hasOpenAlertOfSameType: boolean,
  dogName = "Your dog",
  reasons: string[] = [],
): AlertDecision | null {
  const type = alertTypeForStressLevel(stressLevel);
  if (type === null || hasOpenAlertOfSameType) return null;

  const why = friendlyReasonPhrase(reasons);
  const whyPart = why ? ` — ${why}` : "";

  if (type === "moderate_stress") {
    return {
      type,
      severity: "warning",
      message: `${dogName} seems a bit stressed${whyPart}. Maybe check on them when you can.`,
    };
  }

  return {
    type,
    severity: "critical",
    message: `${dogName} seems quite stressed right now${whyPart}. Please check on them soon.`,
  };
}

/**
 * Low-battery alert (docs/11 "Battery is low, if battery telemetry is
 * available"). Threshold lives in classifier_config.json (device_alerts) —
 * provisional and tunable. Same open-alert dedup as stress alerts.
 * Returns "resolve" when battery recovered above threshold and an open
 * low_battery alert exists (e.g. after a charge).
 */
export function decideBatteryAlert(
  batteryPercent: number | null,
  lowThresholdPercent: number,
  hasOpenLowBatteryAlert: boolean,
  dogName = "your dog",
): AlertDecision | "resolve" | null {
  if (batteryPercent === null) return null;
  if (batteryPercent <= lowThresholdPercent) {
    if (hasOpenLowBatteryAlert) return null;
    return {
      type: "low_battery",
      severity: "warning",
      message:
        `The harness battery is getting low (${batteryPercent}%). ` +
        `Give it a charge soon so ${dogName}'s monitoring doesn't pause.`,
    };
  }
  return hasOpenLowBatteryAlert ? "resolve" : null;
}
