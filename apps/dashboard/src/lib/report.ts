import type {
  Alert,
  StressClassification,
  StressLevel,
  TelemetryReading,
} from "../../../../packages/shared/types/index.ts";

// ASSUMPTION: docs/05 lists "Reports" as a core view but no doc defines their content.
// This report is a per-dog period summary for clinic review: reading coverage, vital
// ranges, time-at-stress-level breakdown, and alert counts. Decision support, not
// diagnosis — the page carries that framing explicitly.

export interface VitalSummary {
  avg: number;
  min: number;
  max: number;
}

export interface DogReport {
  readingCount: number;
  invalidReadingCount: number;
  heartRate: VitalSummary | null;
  respiratoryRate: VitalSummary | null;
  temperature: VitalSummary | null;
  /** Classification counts per level (every level present, zero-filled). */
  stressBreakdown: Record<StressLevel, number>;
  classificationCount: number;
  /** Level with the most classifications in the period, ties going to the calmer level. */
  dominantLevel: StressLevel | null;
  alertCount: number;
  openAlertCount: number;
  alertsBySeverity: Record<string, number>;
}

const LEVELS: StressLevel[] = ["calm", "mild", "moderate", "high"];

function summarize(values: number[]): VitalSummary | null {
  if (values.length === 0) return null;
  const sum = values.reduce((a, b) => a + b, 0);
  return {
    avg: Math.round((sum / values.length) * 10) / 10,
    min: Math.min(...values),
    max: Math.max(...values),
  };
}

/** Abnormal-pattern highlights (docs/05 §3). Strictly observational: surfaces
 * only nonzero facts the pipeline already produced (classifier levels, alert
 * status, intake validation) — no clinical thresholds are invented here and
 * nothing reads as a diagnosis. Empty array = nothing flagged. */
export function buildHighlights(report: DogReport, dogName: string): string[] {
  const highlights: string[] = [];
  const elevated = report.stressBreakdown.moderate + report.stressBreakdown.high;
  if (elevated > 0) {
    const pct = Math.round((elevated / report.classificationCount) * 100);
    highlights.push(
      `${dogName} was classified at moderate or high stress in ${elevated} of ` +
        `${report.classificationCount} classifications (${pct}%).`,
    );
  }
  if (report.openAlertCount > 0) {
    highlights.push(
      `${report.openAlertCount} of ${report.alertCount} alerts from this period ` +
        `${report.openAlertCount === 1 ? "is" : "are"} still open.`,
    );
  }
  if (report.invalidReadingCount > 0) {
    highlights.push(
      `${report.invalidReadingCount} readings were flagged invalid by intake validation ` +
        `and excluded from classification.`,
    );
  }
  if (report.readingCount > 0 && report.classificationCount === 0) {
    highlights.push("Readings arrived in this period but no stress classifications were recorded.");
  }
  return highlights;
}

export function buildDogReport(
  readings: TelemetryReading[],
  classifications: StressClassification[],
  alerts: Alert[],
): DogReport {
  const stressBreakdown = Object.fromEntries(LEVELS.map((l) => [l, 0])) as Record<
    StressLevel,
    number
  >;
  for (const c of classifications) stressBreakdown[c.stress_level] += 1;

  let dominantLevel: StressLevel | null = null;
  for (const level of LEVELS) {
    if (
      classifications.length > 0 &&
      (dominantLevel === null || stressBreakdown[level] > stressBreakdown[dominantLevel])
    ) {
      dominantLevel = level;
    }
  }

  const alertsBySeverity: Record<string, number> = {};
  for (const a of alerts) {
    alertsBySeverity[a.severity] = (alertsBySeverity[a.severity] ?? 0) + 1;
  }

  const pick = (get: (r: TelemetryReading) => number | null) =>
    readings.map(get).filter((v): v is number => v !== null);

  return {
    readingCount: readings.length,
    invalidReadingCount: readings.filter((r) => !r.is_valid).length,
    heartRate: summarize(pick((r) => r.heart_rate_bpm)),
    respiratoryRate: summarize(pick((r) => r.respiratory_rate_bpm)),
    temperature: summarize(pick((r) => r.body_temperature_c)),
    stressBreakdown,
    classificationCount: classifications.length,
    dominantLevel,
    alertCount: alerts.length,
    openAlertCount: alerts.filter((a) => a.status === "open").length,
    alertsBySeverity,
  };
}
