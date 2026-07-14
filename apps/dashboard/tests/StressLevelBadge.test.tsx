import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import { StressLevelBadge, stressLevelColor } from "../src/components/StressLevelBadge.tsx";

describe("stressLevelColor", () => {
  it("returns a distinct color for each stress level", () => {
    const colors = new Set(
      (["calm", "mild", "moderate", "high"] as const).map((level) => stressLevelColor(level)),
    );
    expect(colors.size).toBe(4);
  });
});

describe("StressLevelBadge", () => {
  it("renders the stress level text", () => {
    render(<StressLevelBadge level="high" />);
    expect(screen.getByText("high")).toBeInTheDocument();
  });
});
