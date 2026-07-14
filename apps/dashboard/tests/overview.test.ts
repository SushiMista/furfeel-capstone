import { describe, expect, it } from "vitest";
import { aggregateDailySummaries } from "../src/pages/overview/Overview.tsx";

const day = (d: string, calm: number, high = 0) => ({
  day: d,
  calm,
  mild: 0,
  moderate: 0,
  high,
  avg_motion: null,
});

describe("aggregateDailySummaries", () => {
  it("sums per-dog mixes by day and sorts chronologically", () => {
    const merged = aggregateDailySummaries([
      [day("2026-07-11", 10, 2), day("2026-07-12", 5)],
      [day("2026-07-12", 3, 1)],
    ]);
    expect(merged).toHaveLength(2);
    expect(merged[0]).toMatchObject({ day: "2026-07-11", calm: 10, high: 2 });
    expect(merged[1]).toMatchObject({ day: "2026-07-12", calm: 8, high: 1 });
  });

  it("returns empty for no dogs", () => {
    expect(aggregateDailySummaries([])).toEqual([]);
  });
});
