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

  const data = buildTelemetryChartRows(readings);

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h3 className="text-sm font-semibold text-ink-muted mb-2">{HR_SERIES}</h3>
        <LineChart
          className="h-44"
          data={data}
          index="time"
          categories={[HR_SERIES]}
          colors={["rose"]}
          curveType="monotone"
          showAnimation={false}
          yAxisWidth={36}
          aria-label="Heart rate over time"
        />
      </div>
      <div>
        <h3 className="text-sm font-semibold text-ink-muted mb-2">{RR_SERIES}</h3>
        <LineChart
          className="h-44"
          data={data}
          index="time"
          categories={[RR_SERIES]}
          colors={["teal"]}
          curveType="monotone"
          showAnimation={false}
          yAxisWidth={36}
          aria-label="Respiratory rate over time"
        />
      </div>
    </div>
  );
}
