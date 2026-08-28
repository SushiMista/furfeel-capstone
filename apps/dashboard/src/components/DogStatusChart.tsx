import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from "recharts";
import { AlertTriangle, CheckCircle2, PawPrint } from "lucide-react";
import type { Device, Dog } from "../../../../packages/shared/types/index.ts";
import { EmptyState } from "./ui/empty-state.tsx";

export interface DogStatusChartProps {
  dogs: Dog[];
  devices: Device[];
}

export function DogStatusChart({ dogs, devices }: DogStatusChartProps) {
  if (dogs.length === 0) {
    return <EmptyState>No registered dogs in the clinic database yet 🐾</EmptyState>;
  }

  // Calculate Dog Monitoring Status
  const totalDogs = dogs.length;

  let monitoredActive = 0;
  let monitoredOffline = 0;
  let missingDevice = 0;

  for (const dog of dogs) {
    const pairedDevice = devices.find((d) => d.dog_id === dog.id);
    if (!pairedDevice) {
      missingDevice++;
    } else if (pairedDevice.status === "active") {
      monitoredActive++;
    } else {
      monitoredOffline++;
    }
  }

  const data = [
    {
      name: "Monitored & Active",
      value: monitoredActive,
      fill: "var(--ff-status-calm-fg, #0C7C6F)",
    },
    {
      name: "Monitored & Offline",
      value: monitoredOffline,
      fill: "var(--ff-status-mild-fg, #956603)",
    },
    {
      name: "Missing Device (Unassigned)",
      value: missingDevice,
      fill: "var(--ff-status-high-fg, #CA2323)",
    },
  ].filter((item) => item.value > 0);

  return (
    <div className="flex flex-col gap-5">
      {/* Top Protocol Status Metric */}
      <div className="flex items-center justify-between rounded-lg border border-hairline bg-surface-alt p-3.5 shadow-2xs">
        <div className="flex items-center gap-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-md bg-brand-soft text-brand">
            <PawPrint size={20} />
          </div>
          <div>
            <div className="text-xs font-bold uppercase tracking-wider text-ink-muted">
              Dog Protocol Compliance
            </div>
            <div className="text-sm font-semibold text-ink">
              {monitoredActive} of {totalDogs} dogs actively streaming
            </div>
          </div>
        </div>
        <span
          className={
            missingDevice > 0
              ? "rounded-full bg-high-soft px-3 py-1 text-xs font-bold text-high-fg flex items-center gap-1.5"
              : "rounded-full bg-calm-soft px-3 py-1 text-xs font-bold text-calm-fg flex items-center gap-1.5"
          }
        >
          {missingDevice > 0 ? (
            <>
              <AlertTriangle size={13} /> {missingDevice} Missing Collar{missingDevice === 1 ? "" : "s"}
            </>
          ) : (
            <>
              <CheckCircle2 size={13} /> 100% Collar Coverage
            </>
          )}
        </span>
      </div>

      {/* Donut Chart & Side Breakdown */}
      <div className="grid grid-cols-1 items-center gap-4 sm:grid-cols-2">
        {/* Interactive Donut Chart */}
        <div className="relative h-60 w-full flex items-center justify-center">
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie
                data={data}
                cx="50%"
                cy="50%"
                innerRadius={60}
                outerRadius={90}
                paddingAngle={4}
                dataKey="value"
              >
                {data.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={entry.fill} stroke="var(--surface)" strokeWidth={2} />
                ))}
              </Pie>
              <Tooltip
                content={({ active, payload }) => {
                  if (!active || !payload || !payload.length) return null;
                  const item = payload[0];
                  return (
                    <div className="rounded-md border border-hairline bg-surface p-2.5 shadow-md text-xs">
                      <div className="font-bold text-ink">{item.name}</div>
                      <div className="text-ink-muted mt-1">
                        Count: <span className="font-extrabold text-ink tabular-nums">{item.value}</span> dogs
                      </div>
                    </div>
                  );
                }}
              />
            </PieChart>
          </ResponsiveContainer>

          {/* Center Donut Label */}
          <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
            <span className="text-2xl font-extrabold tabular-nums text-ink">{totalDogs}</span>
            <span className="text-[11px] font-bold uppercase tracking-wider text-ink-muted">Total Dogs</span>
          </div>
        </div>

        {/* Legend / Status Breakdown List */}
        <div className="flex flex-col gap-3">
          <div className="flex items-center justify-between rounded-md bg-surface p-2.5 border border-hairline shadow-2xs">
            <div className="flex items-center gap-2">
              <span className="h-3 w-3 rounded-full bg-calm-fg" />
              <span className="text-xs font-semibold text-ink">Monitored &amp; Active</span>
            </div>
            <span className="text-xs font-extrabold tabular-nums text-ink">{monitoredActive}</span>
          </div>

          <div className="flex items-center justify-between rounded-md bg-surface p-2.5 border border-hairline shadow-2xs">
            <div className="flex items-center gap-2">
              <span className="h-3 w-3 rounded-full bg-mild-fg" />
              <span className="text-xs font-semibold text-ink">Monitored &amp; Offline</span>
            </div>
            <span className="text-xs font-extrabold tabular-nums text-ink">{monitoredOffline}</span>
          </div>

          <div className="flex items-center justify-between rounded-md bg-surface p-2.5 border border-hairline shadow-2xs">
            <div className="flex items-center gap-2">
              <span className="h-3 w-3 rounded-full bg-high-fg" />
              <span className="text-xs font-semibold text-ink">Missing Collar / Unassigned</span>
            </div>
            <span className="text-xs font-extrabold tabular-nums text-ink">{missingDevice}</span>
          </div>
        </div>
      </div>
    </div>
  );
}
