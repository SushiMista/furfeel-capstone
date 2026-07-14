import { describe, expect, it } from "vitest";
import { buildStressMixRows } from "../src/components/StressMixChart.tsx";

describe("buildStressMixRows", () => {
  it("normalizes each day to a 100% composition", () => {
    const rows = buildStressMixRows([
      { day: "2026-07-10", calm: 30, mild: 10, moderate: 5, high: 5, avg_motion: 0.4 },
    ]);
    expect(rows[0].Calm).toBe(60);
    expect(rows[0].Mild).toBe(20);
    expect(rows[0].Moderate).toBe(10);
    expect(rows[0].High).toBe(10);
    expect(rows[0].Calm + rows[0].Mild + rows[0].Moderate + rows[0].High).toBe(100);
  });

  it("renders an empty day as zeros instead of dividing by zero", () => {
    const rows = buildStressMixRows([
      { day: "2026-07-10", calm: 0, mild: 0, moderate: 0, high: 0, avg_motion: null },
    ]);
    expect(rows[0].Calm).toBe(0);
    expect(rows[0].High).toBe(0);
  });
});
