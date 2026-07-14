import { BarChart } from "@tremor/react";
import type { DailyStressSummaryRow } from "../lib/queries.ts";
import { EmptyState } from "./ui/empty-state.tsx";

export const MIX_CATEGORIES = ["Calm", "Mild", "Moderate", "High"] as const;

export interface StressMixRow {
  day: string;
  Calm: number;
  Mild: number;
  Moderate: number;
  High: number;
}

/** Pure row builder: each day normalized to a 100% composition — the clinical
 * question is "how much of the day was calm", not sample volume. */
export function buildStressMixRows(summary: DailyStressSummaryRow[]): StressMixRow[] {
  return summary.map((d) => {
    const total = d.calm + d.mild + d.moderate + d.high;
    const pct = (n: number) => (total === 0 ? 0 : Math.round((n / total) * 100));
    return {
      day: new Date(d.day).toLocaleDateString(undefined, { weekday: "short", day: "numeric" }),
      Calm: pct(d.calm),
      Mild: pct(d.mild),
      Moderate: pct(d.moderate),
      High: pct(d.high),
    };
  });
}

/** Daily stress mix, 100%-stacked (docs/19 §6: banded strip in status colors).
 * Colors come from the generated token scales ("calm"…"high" → -500 classes). */
export function StressMixChart({ summary }: { summary: DailyStressSummaryRow[] }) {
  if (summary.length === 0) {
    return <EmptyState>No classifications in this window yet 🐾</EmptyState>;
  }

  return (
    <BarChart
      className="h-56"
      data={buildStressMixRows(summary)}
      index="day"
      categories={[...MIX_CATEGORIES]}
      colors={["calm", "mild", "moderate", "high"]}
      stack
      valueFormatter={(v) => `${v}%`}
      maxValue={100}
      yAxisWidth={40}
      showAnimation={false}
      aria-label="Daily stress-level mix over the last 14 days"
    />
  );
}
