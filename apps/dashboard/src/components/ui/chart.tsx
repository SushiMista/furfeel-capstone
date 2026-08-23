import * as React from "react";
import { Legend, ResponsiveContainer, Tooltip } from "recharts";

export type ChartConfig = Record<
  string,
  {
    label?: React.ReactNode;
    color?: string;
    icon?: React.ComponentType;
  }
>;

const ChartContext = React.createContext<{ config: ChartConfig } | null>(null);

export function ChartContainer({
  config,
  children,
  className,
  ...props
}: React.ComponentProps<"div"> & {
  config: ChartConfig;
  children: React.ReactNode;
}) {
  return (
    <ChartContext.Provider value={{ config }}>
      <div
        className={className}
        style={
          {
            "--color-desktop": "var(--chart-1)",
            "--color-mobile": "var(--chart-2)",
            ...Object.entries(config).reduce<Record<string, string>>(
              (acc, [key, val]) => {
                if (val.color) {
                  acc[`--color-${key}`] = val.color;
                }
                return acc;
              },
              {}
            ),
          } as React.CSSProperties
        }
        {...props}
      >
        <ResponsiveContainer width="100%" height={300}>
          {children as React.ReactElement}
        </ResponsiveContainer>
      </div>
    </ChartContext.Provider>
  );
}

export const ChartTooltip = Tooltip;

export function ChartTooltipContent({
  active,
  payload,
  label,
  hideLabel = false,
  indicator = "dot",
}: any) {
  if (!active || !payload || !payload.length) return null;

  return (
    <div className="rounded-lg border border-hairline bg-surface p-2.5 shadow-md text-xs">
      {!hideLabel && <div className="font-semibold text-ink mb-1.5">{label}</div>}
      <div className="flex flex-col gap-1">
        {payload.map((item: any, index: number) => {
          return (
            <div key={index} className="flex items-center gap-2 text-ink-muted">
              <span
                className="h-2 w-2 rounded-full"
                style={{ backgroundColor: item.color || item.stroke || item.fill }}
              />
              <span className="capitalize">{item.name}:</span>
              <span className="font-bold text-ink tabular-nums">{item.value}%</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

export const ChartLegend = Legend;

export function ChartLegendContent({ payload }: any) {
  if (!payload || !payload.length) return null;
  return (
    <div className="flex items-center justify-end gap-4 pt-2 text-xs">
      {payload.map((item: any, index: number) => (
        <div key={index} className="flex items-center gap-1.5 font-medium text-ink-muted">
          <span
            className="h-2.5 w-2.5 rounded-sm"
            style={{ backgroundColor: item.color || item.fill }}
          />
          <span className="capitalize">{item.value}</span>
        </div>
      ))}
    </div>
  );
}
