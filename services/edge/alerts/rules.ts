import type { StressLevel } from "../classifier/index.ts";
import type { AlertDecision, AlertType } from "./types.ts";

/** Which alert `type` a stress level maps to, or null if that level never alerts
 * (docs/11: triggers are "stress level becomes Moderate" / "becomes High" only). */
export function alertTypeForStressLevel(level: StressLevel): AlertType | null {
  if (level === "moderate") return "moderate_stress";
  if (level === "high") return "high_stress";
  return null;
}

/**
 * Decide whether telemetry-intake should create a new alert.
 *
 * Design decision (confirmed): only create a new alert when there is no existing
 * OPEN alert of the same type for this dog already — otherwise a dog stuck at
 * 'high' would get a new alert row every ~10-second telemetry tick. docs/11 frames
 * triggers as "stress level *becomes* moderate/high" (a transition), which this
 * dedup-by-open-alert approach honors without needing readings history here.
 *
 * @param hasOpenAlertOfSameType Whether an alerts row with status='open' and the
 *   type this level maps to already exists for this dog (caller queries this).
 */
export function decideAlert(
  stressLevel: StressLevel,
  hasOpenAlertOfSameType: boolean,
): AlertDecision | null {
  const type = alertTypeForStressLevel(stressLevel);
  if (type === null || hasOpenAlertOfSameType) return null;

  if (type === "moderate_stress") {
    return {
      type,
      severity: "warning",
      message: "Stress level is moderate — automatic detection from telemetry.",
    };
  }

  return {
    type,
    severity: "critical",
    message: "Stress level is high — automatic detection from telemetry, requires review.",
  };
}
