// One word for a day, matching mobile (month_summary.dart).
import type { StressLevel } from "../../../../packages/shared/types/index.ts";
import type { DailyStressSummaryRow } from "./queries.ts";

const MOSTLY_CALM_SHARE = 0.7;

/** Calm when mostly calm, otherwise the most common non-calm level, the higher
 * one on a tie. Null when there's no data. */
export function dayLevel(day: DailyStressSummaryRow | undefined): StressLevel | null {
  if (!day) return null;
  const total = day.calm + day.mild + day.moderate + day.high;
  if (total === 0) return null;
  if (day.calm / total >= MOSTLY_CALM_SHARE) return "calm";
  if (day.high >= day.moderate && day.high >= day.mild && day.high > 0) return "high";
  if (day.moderate >= day.mild && day.moderate > 0) return "moderate";
  return day.mild > 0 ? "mild" : "calm";
}

export function dayWord(level: StressLevel | null): string {
  switch (level) {
    case null:
      return "No readings this day";
    case "high":
      return "A high-stress day";
    default:
      return `A ${level} day`;
  }
}
