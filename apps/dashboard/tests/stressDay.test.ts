import { describe, expect, it } from "vitest";
import { dayLevel, dayWord } from "../src/lib/stressDay.ts";

const day = (calm: number, mild: number, moderate: number, high: number) => ({
  day: "2026-11-03",
  calm,
  mild,
  moderate,
  high,
  avg_motion: null,
});

describe("dayLevel", () => {
  it("is empty without readings, so a collar left off never looks like a good day", () => {
    expect(dayLevel(undefined)).toBeNull();
    expect(dayLevel(day(0, 0, 0, 0))).toBeNull();
    expect(dayWord(null)).toBe("No readings this day");
  });

  it("is calm at 70% calm, even with some high readings", () => {
    expect(dayLevel(day(7, 0, 0, 3))).toBe("calm");
  });

  it("otherwise uses the most common non-calm level, the higher one on a tie", () => {
    expect(dayLevel(day(1, 5, 2, 0))).toBe("mild");
    expect(dayLevel(day(1, 2, 5, 0))).toBe("moderate");
    expect(dayLevel(day(1, 3, 3, 3))).toBe("high");
    expect(dayWord("high")).toBe("A high-stress day");
  });
});
