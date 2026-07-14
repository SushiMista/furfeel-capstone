import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import { StressTimeline } from "../src/components/StressTimeline.tsx";
import type { StressClassification } from "../../../packages/shared/types/index.ts";

function classification(overrides: Partial<StressClassification>): StressClassification {
  return {
    id: "c1",
    dog_id: "dog1",
    telemetry_reading_id: "r1",
    stress_level: "calm",
    score: 0,
    confidence: null,
    reasons: [],
    model_version: "rule-v1",
    created_at: "2026-07-09T08:00:00Z",
    ...overrides,
  };
}

describe("StressTimeline", () => {
  it("shows an empty state with no classifications", () => {
    render(<StressTimeline classifications={[]} />);
    expect(screen.getByText(/no stress readings yet/i)).toBeInTheDocument();
  });

  it("renders one item per classification", () => {
    render(
      <StressTimeline
        classifications={[
          classification({ id: "c1", stress_level: "calm" }),
          classification({ id: "c2", stress_level: "high", score: 7 }),
        ]}
      />,
    );
    expect(screen.getByText("calm")).toBeInTheDocument();
    expect(screen.getByText("high")).toBeInTheDocument();
    expect(screen.getByText("score 7")).toBeInTheDocument();
  });
});
