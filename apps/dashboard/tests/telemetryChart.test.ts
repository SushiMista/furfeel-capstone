import { describe, expect, it } from "vitest";
import {
  buildTelemetryChartRows,
  HR_SERIES,
  RR_SERIES,
} from "../src/components/TelemetryChart.tsx";
import type { TelemetryReading } from "../../../packages/shared/types/index.ts";

function reading(overrides: Partial<TelemetryReading>): TelemetryReading {
  return {
    id: "r1",
    device_id: "d1",
    dog_id: "dog1",
    captured_at: "2026-07-09T08:00:00Z",
    received_at: "2026-07-09T08:00:01Z",
    heart_rate_bpm: 90,
    body_temperature_c: 38.5,
    respiratory_rate_bpm: 22,
    motion_activity: 0.3,
    posture: "standing",
    ambient_temperature_c: 24,
    humidity_percent: 55,
    is_valid: true,
    raw_payload: {},
    ...overrides,
  };
}

describe("buildTelemetryChartRows", () => {
  it("returns no rows for an empty reading list", () => {
    expect(buildTelemetryChartRows([])).toEqual([]);
  });

  it("builds one row per reading carrying both hr and rr series", () => {
    const rows = buildTelemetryChartRows([
      reading({ captured_at: "2026-07-09T08:00:00Z", heart_rate_bpm: 90, respiratory_rate_bpm: 20 }),
      reading({ captured_at: "2026-07-09T08:00:10Z", heart_rate_bpm: 150, respiratory_rate_bpm: 40 }),
    ]);
    expect(rows).toHaveLength(2);
    expect(rows[0][HR_SERIES]).toBe(90);
    expect(rows[0][RR_SERIES]).toBe(20);
    expect(rows[1][HR_SERIES]).toBe(150);
    expect(rows[1][RR_SERIES]).toBe(40);
  });

  it("keeps null values as nulls (chart shows a gap) without throwing", () => {
    const rows = buildTelemetryChartRows([
      reading({ captured_at: "2026-07-09T08:00:00Z", heart_rate_bpm: null }),
      reading({ captured_at: "2026-07-09T08:00:10Z", heart_rate_bpm: 120 }),
    ]);
    expect(rows[0][HR_SERIES]).toBeNull();
    expect(rows[1][HR_SERIES]).toBe(120);
  });

  it("preserves the caller's oldest-first ordering with readable time labels", () => {
    const rows = buildTelemetryChartRows([
      reading({ captured_at: "2026-07-09T08:00:00Z" }),
      reading({ captured_at: "2026-07-09T08:01:00Z" }),
    ]);
    expect(rows[0].time).not.toBe(rows[1].time);
  });
});
