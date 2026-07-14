import { LineChart } from "@tremor/react";
import type { TelemetryReading } from "../../../../packages/shared/types/index.ts";
import { EmptyState } from "./ui/empty-state.tsx";

export const HR_SERIES = "Heart rate (bpm)";
export const RR_SERIES = "Respiratory rate (bpm)";

export interface TelemetryChartRow {
  time: string;
  [HR_SERIES]: number | null;
  [RR_SERIES]: number | null;
}

/** Pure row builder (no DOM) so the chart's data shaping stays unit-testable.
 * Readings arrive oldest-first (fetchTelemetryHistory reverses for charting). */
export function buildTelemetryChartRows(readings: TelemetryReading[]): TelemetryChartRow[] {
  return readings.map((r) => ({
    time: new Date(r.captured_at).toLocaleTimeString(),
    [HR_SERIES]: r.heart_rate_bpm,
    [RR_SERIES]: r.respiratory_rate_bpm,
  }));
}

/** Live heart-rate/respiratory-rate chart (docs/05, docs/19 §6): Tremor LineChart,
 * one shared bpm axis, muted grid, token-driven series colors ("high" red for HR,
 * "accent" teal for RR — both from the generated Tailwind scales). */
export function TelemetryChart({ readings }: { readings: TelemetryReading[] }) {
  if (readings.length === 0) {
    return <EmptyState>No readings yet — waiting for the harness to check in 🐾</EmptyState>;
  }

  return (
    <LineChart
      className="h-56"
      data={buildTelemetryChartRows(readings)}
      index="time"
      categories={[HR_SERIES, RR_SERIES]}
      colors={["high", "accent"]}
      curveType="monotone"
      showAnimation={false}
      yAxisWidth={36}
      aria-label="Heart rate and respiratory rate over time"
    />
  );
}
