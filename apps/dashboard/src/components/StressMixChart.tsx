import { Area, AreaChart, CartesianGrid, XAxis, YAxis } from "recharts";
import type { DailyStressSummaryRow } from "../lib/queries.ts";
import { EmptyState } from "./ui/empty-state.tsx";
import {
  ChartContainer,
  ChartLegend,
  ChartLegendContent,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from "./ui/chart.tsx";

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

const chartConfig = {
  Calm: {
    label: "Calm",
    color: "var(--ff-status-calm-fg, #0C7C6F)",
  },
  Mild: {
    label: "Mild",
    color: "var(--ff-status-mild-fg, #956603)",
  },
  Moderate: {
    label: "Moderate",
    color: "var(--ff-status-moderate-fg, #A85311)",
  },
  High: {
    label: "High",
    color: "var(--ff-status-high-fg, #CA2323)",
  },
} satisfies ChartConfig;

/** Daily stress mix interactive area chart using shadcn UI & Recharts.
 * Renders stacked composition areas in status colors. */
export function StressMixChart({ summary }: { summary: DailyStressSummaryRow[] }) {
  if (summary.length === 0) {
    return <EmptyState>No classifications in this window yet 🐾</EmptyState>;
  }

  const chartData = buildStressMixRows(summary);

  return (
    <ChartContainer config={chartConfig} className="aspect-auto h-64 w-full">
      <AreaChart data={chartData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
        <defs>
          <linearGradient id="fillCalm" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="var(--color-Calm)" stopOpacity={0.8} />
            <stop offset="95%" stopColor="var(--color-Calm)" stopOpacity={0.15} />
          </linearGradient>
          <linearGradient id="fillMild" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="var(--color-Mild)" stopOpacity={0.8} />
            <stop offset="95%" stopColor="var(--color-Mild)" stopOpacity={0.15} />
          </linearGradient>
          <linearGradient id="fillModerate" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="var(--color-Moderate)" stopOpacity={0.8} />
            <stop offset="95%" stopColor="var(--color-Moderate)" stopOpacity={0.15} />
          </linearGradient>
          <linearGradient id="fillHigh" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="var(--color-High)" stopOpacity={0.8} />
            <stop offset="95%" stopColor="var(--color-High)" stopOpacity={0.15} />
          </linearGradient>
        </defs>
        <CartesianGrid vertical={false} strokeDasharray="3 3" opacity={0.3} />
        <XAxis
          dataKey="day"
          tickLine={false}
          axisLine={false}
          tickMargin={8}
          className="text-xs font-medium text-ink-muted"
        />
        <YAxis
          tickLine={false}
          axisLine={false}
          domain={[0, 100]}
          tickFormatter={(v) => `${v}%`}
          className="text-xs font-medium text-ink-muted"
        />
        <ChartTooltip cursor={false} content={<ChartTooltipContent indicator="dot" />} />
        <Area
          dataKey="High"
          type="monotone"
          fill="url(#fillHigh)"
          stroke="var(--color-High)"
          stackId="1"
          strokeWidth={1.5}
        />
        <Area
          dataKey="Moderate"
          type="monotone"
          fill="url(#fillModerate)"
          stroke="var(--color-Moderate)"
          stackId="1"
          strokeWidth={1.5}
        />
        <Area
          dataKey="Mild"
          type="monotone"
          fill="url(#fillMild)"
          stroke="var(--color-Mild)"
          stackId="1"
          strokeWidth={1.5}
        />
        <Area
          dataKey="Calm"
          type="monotone"
          fill="url(#fillCalm)"
          stroke="var(--color-Calm)"
          stackId="1"
          strokeWidth={1.5}
        />
        <ChartLegend content={<ChartLegendContent />} />
      </AreaChart>
    </ChartContainer>
  );
}
