import type { StressClassification } from "../../../../packages/shared/types/index.ts";
import { EmptyState } from "./ui/empty-state.tsx";
import { CartesianGrid, Line, LineChart, XAxis, YAxis } from "recharts";
import { ChartContainer, ChartTooltip, type ChartConfig } from "./ui/chart.tsx";

const chartConfig = {
  score: {
    label: "Stress Score",
    color: "#2563eb", // FurFeel brand blue
  },
} satisfies ChartConfig;

const CustomTooltip = ({ active, payload }: any) => {
  if (active && payload && payload.length) {
    const data = payload[0].payload;
    return (
      <div className="rounded-lg border border-hairline bg-surface p-3 shadow-md text-xs">
        <div className="font-bold text-ink mb-1">{data.time}</div>
        <div className="flex flex-col gap-1">
          <div className="flex items-center gap-1.5">
            <span className="text-ink-muted">Stress Level:</span>
            <span className="font-semibold capitalize text-brand-strong">{data.level}</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="text-ink-muted">Score:</span>
            <span className="font-bold text-ink">{data.score}</span>
          </div>
        </div>
      </div>
    );
  }
  return null;
};

export function StressTimeline({ classifications }: { classifications: StressClassification[] }) {
  if (classifications.length === 0) {
    return <EmptyState>No stress readings yet — we&apos;ll chart them as they arrive 🐾</EmptyState>;
  }

  // Format classification data for the chart, oldest-first (which classifications already is)
  const chartData = classifications.map((c) => ({
    time: new Date(c.created_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" }),
    score: Number(c.score ?? 0),
    level: c.stress_level,
  }));

  return (
    <div className="h-64 w-full mt-2">
      <ChartContainer config={chartConfig} className="h-full w-full">
        <LineChart
          data={chartData}
          margin={{
            top: 10,
            left: -20,
            right: 10,
            bottom: 5,
          }}
        >
          <CartesianGrid vertical={false} strokeDasharray="3 3" className="stroke-hairline" />
          <XAxis
            dataKey="time"
            tickLine={false}
            axisLine={false}
            tickMargin={8}
            className="text-[10px] fill-ink-muted"
          />
          <YAxis
            tickLine={false}
            axisLine={false}
            tickMargin={8}
            className="text-[10px] fill-ink-muted"
            allowDecimals={false}
          />
          <ChartTooltip content={<CustomTooltip />} />
          <Line
            dataKey="score"
            type="monotone"
            stroke="var(--color-score)"
            strokeWidth={2}
            dot={{
              fill: "var(--color-score)",
              r: 4,
            }}
            activeDot={{
              r: 6,
            }}
          />
        </LineChart>
      </ChartContainer>
    </div>
  );
}
