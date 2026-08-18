import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { StressTimeline } from "../src/components/StressTimeline.tsx";
import type { StressClassification } from "../../../packages/shared/types/index.ts";

vi.mock("recharts", () => {
  return {
    ResponsiveContainer: ({ children }: any) => <div>{children}</div>,
    LineChart: ({ children, data }: any) => (
      <div data-testid="line-chart" data-data={JSON.stringify(data)}>
        {children}
      </div>
    ),
    Line: () => <div />,
    XAxis: () => <div />,
    YAxis: () => <div />,
    CartesianGrid: () => <div />,
    Tooltip: () => <div />,
  };
});

vi.mock("../src/components/ui/chart.tsx", () => {
  return {
    ChartContainer: ({ children }: any) => <div>{children}</div>,
    ChartTooltip: ({ children }: any) => <div>{children}</div>,
  };
});

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

  it("renders one item per classification on the line chart", () => {
    render(
      <StressTimeline
        classifications={[
          classification({ id: "c1", stress_level: "calm", score: 1 }),
          classification({ id: "c2", stress_level: "high", score: 7 }),
        ]}
      />,
    );
    const chart = screen.getByTestId("line-chart");
    expect(chart).toBeInTheDocument();
    const data = JSON.parse(chart.getAttribute("data-data") || "[]");
    expect(data).toHaveLength(2);
    expect(data[0].level).toBe("calm");
    expect(data[0].score).toBe(1);
    expect(data[1].level).toBe("high");
    expect(data[1].score).toBe(7);
  });
});
