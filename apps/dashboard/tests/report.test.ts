import { describe, expect, it } from "vitest";
import { buildDogReport, buildHighlights } from "../src/lib/report.ts";
import type {
  Alert,
  StressClassification,
  TelemetryReading,
} from "../../../packages/shared/types/index.ts";

function reading(overrides: Partial<TelemetryReading>): TelemetryReading {
  return {
    id: "r1",
    device_id: "d1",
    dog_id: "dog1",
    captured_at: "2026-07-11T08:00:00Z",
    received_at: "2026-07-11T08:00:01Z",
    heart_rate_bpm: 90,
    body_temperature_c: 38.5,
    respiratory_rate_bpm: 22,
    motion_activity: 0.3,
    posture: "standing",
    ambient_temperature_c: 24,
    humidity_percent: 55,
    battery_percent: null,
    is_valid: true,
    raw_payload: {},
    ...overrides,
  };
}

function classification(level: StressClassification["stress_level"]): StressClassification {
  return {
    id: `c-${Math.random()}`,
    dog_id: "dog1",
    telemetry_reading_id: "r1",
    stress_level: level,
    score: 1,
    confidence: null,
    reasons: [],
    model_version: "rule-v1",
    created_at: "2026-07-11T08:00:00Z",
  };
}

function alert(status: Alert["status"], severity: Alert["severity"]): Alert {
  return {
    id: `a-${Math.random()}`,
    dog_id: "dog1",
    classification_id: null,
    severity,
    type: "high_stress",
    message: "m",
    status,
    acknowledged_by: null,
    acknowledged_at: null,
    created_at: "2026-07-11T08:00:00Z",
  };
}

describe("buildDogReport", () => {
  it("summarizes vitals with avg/min/max, skipping nulls", () => {
    const report = buildDogReport(
      [
        reading({ heart_rate_bpm: 80 }),
        reading({ heart_rate_bpm: 120 }),
        reading({ heart_rate_bpm: null }),
      ],
      [],
      [],
    );
    expect(report.readingCount).toBe(3);
    expect(report.heartRate).toEqual({ avg: 100, min: 80, max: 120 });
  });

  it("returns null vital summaries when there are no values", () => {
    const report = buildDogReport([reading({ heart_rate_bpm: null })], [], []);
    expect(report.heartRate).toBeNull();
  });

  it("zero-fills the stress breakdown and picks the dominant level", () => {
    const report = buildDogReport(
      [],
      [classification("calm"), classification("calm"), classification("high")],
      [],
    );
    expect(report.stressBreakdown).toEqual({ calm: 2, mild: 0, moderate: 0, high: 1 });
    expect(report.dominantLevel).toBe("calm");
  });

  it("dominant level is null with no classifications", () => {
    expect(buildDogReport([], [], []).dominantLevel).toBeNull();
  });

  it("counts alerts by status and severity and flags invalid readings", () => {
    const report = buildDogReport(
      [reading({ is_valid: false }), reading({})],
      [],
      [alert("open", "critical"), alert("acknowledged", "warning"), alert("open", "critical")],
    );
    expect(report.invalidReadingCount).toBe(1);
    expect(report.alertCount).toBe(3);
    expect(report.openAlertCount).toBe(2);
    expect(report.alertsBySeverity).toEqual({ critical: 2, warning: 1 });
  });
});

describe("buildHighlights (docs/05 abnormal-pattern highlights)", () => {
  it("flags elevated stress share, open alerts, and invalid readings — observationally", () => {
    const report = buildDogReport(
      [reading({ is_valid: false }), reading({})],
      [classification("calm"), classification("moderate"), classification("high")],
      [alert("open", "critical"), alert("acknowledged", "warning")],
    );
    const highlights = buildHighlights(report, "Biscuit");
    expect(highlights).toHaveLength(3);
    expect(highlights[0]).toContain("Biscuit");
    expect(highlights[0]).toContain("2 of 3 classifications (67%)");
    expect(highlights[1]).toContain("1 of 2 alerts");
    expect(highlights[2]).toContain("1 readings were flagged invalid");
    // No diagnosis language anywhere (CLAUDE.md guardrail).
    for (const h of highlights) expect(h.toLowerCase()).not.toMatch(/diagnos/);
  });

  it("returns nothing to flag for an all-calm, all-clear period", () => {
    const report = buildDogReport(
      [reading({})],
      [classification("calm")],
      [alert("acknowledged", "info")],
    );
    expect(buildHighlights(report, "Biscuit")).toEqual([]);
  });

  it("flags readings without classifications", () => {
    const report = buildDogReport([reading({})], [], []);
    expect(buildHighlights(report, "Biscuit")).toEqual([
      "Readings arrived in this period but no stress classifications were recorded.",
    ]);
  });
});
