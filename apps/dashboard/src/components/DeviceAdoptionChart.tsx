import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { Cpu, PawPrint, Radio, ShieldAlert } from "lucide-react";
import type { Device, Dog } from "../../../../packages/shared/types/index.ts";
import { EmptyState } from "./ui/empty-state.tsx";

export interface DeviceAdoptionChartProps {
  devices: Device[];
  dogs: Dog[];
}

export function DeviceAdoptionChart({ devices, dogs }: DeviceAdoptionChartProps) {
  if (devices.length === 0 && dogs.length === 0) {
    return <EmptyState>No device or dog records registered in the fleet yet 🐾</EmptyState>;
  }

  // Calculate Device Allocation Stats
  const totalDevices = devices.length;
  const equippedDevices = devices.filter((d) => d.dog_id !== null);
  const unassignedDevices = devices.filter((d) => d.dog_id === null);

  const equippedActive = equippedDevices.filter((d) => d.status === "active").length;
  const equippedOffline = equippedDevices.filter((d) => d.status === "offline").length;
  const equippedMaintenance = equippedDevices.filter(
    (d) => d.status === "maintenance" || d.status === "inactive",
  ).length;

  const unassignedAvailable = unassignedDevices.filter(
    (d) => d.status === "active" || d.status === "inactive",
  ).length;
  const unassignedMaintenance = unassignedDevices.filter(
    (d) => d.status === "maintenance" || d.status === "offline",
  ).length;

  // Calculate Dog Adoption Stats
  const totalDogs = dogs.length;
  const dogsWithDeviceCount = dogs.filter((dog) =>
    devices.some((d) => d.dog_id === dog.id),
  ).length;
  const dogsWithoutDeviceCount = Math.max(0, totalDogs - dogsWithDeviceCount);

  const dogAdoptionPct = totalDogs > 0 ? Math.round((dogsWithDeviceCount / totalDogs) * 100) : 0;
  const deviceFleetAllocatedPct =
    totalDevices > 0 ? Math.round((equippedDevices.length / totalDevices) * 100) : 0;

  // Data for Chart 1: Device Assignment & Status Breakdown
  const deviceStatusData = [
    {
      category: "Equipped (Active)",
      count: equippedActive,
      fill: "var(--ff-status-calm-fg, #0C7C6F)",
    },
    {
      category: "Equipped (Offline)",
      count: equippedOffline,
      fill: "var(--ff-status-mild-fg, #956603)",
    },
    {
      category: "Available (In Stock)",
      count: unassignedAvailable,
      fill: "var(--brand, #2563EB)",
    },
    {
      category: "Maintenance / Inactive",
      count: unassignedMaintenance + equippedMaintenance,
      fill: "var(--ff-status-high-fg, #CA2323)",
    },
  ];

  // Data for Chart 2: Dog Device Adoption Breakdown
  const dogAdoptionData = [
    {
      group: "Dog Adoption",
      Equipped: dogsWithDeviceCount,
      "Awaiting Device": dogsWithoutDeviceCount,
    },
  ];

  return (
    <div className="flex flex-col gap-6">
      {/* KPI Top Cards */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        {/* Dog Adoption Metric Card */}
        <div className="flex flex-col gap-2 rounded-xl border border-hairline bg-surface p-4 shadow-xs">
          <div className="flex items-center justify-between text-ink-muted">
            <span className="text-xs font-bold uppercase tracking-wider">Dog Device Adoption</span>
            <PawPrint size={18} className="text-brand" />
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-3xl font-extrabold tabular-nums text-ink">
              {dogsWithDeviceCount} <span className="text-lg font-normal text-ink-muted">/ {totalDogs}</span>
            </span>
            <span className="rounded-full bg-brand-soft px-2 py-0.5 text-xs font-bold text-brand-strong">
              {dogAdoptionPct}% Equipped
            </span>
          </div>
          <div className="h-2 w-full overflow-hidden rounded-full bg-surface-alt">
            <div
              className="h-full bg-brand transition-all duration-500"
              style={{ width: `${dogAdoptionPct}%` }}
            />
          </div>
          <span className="text-[11px] text-ink-muted">
            {dogsWithoutDeviceCount === 0
              ? "All registered dogs have active devices!"
              : `${dogsWithoutDeviceCount} ${dogsWithoutDeviceCount === 1 ? "dog is" : "dogs are"} awaiting device pairing.`}
          </span>
        </div>

        {/* Fleet Allocation Metric Card */}
        <div className="flex flex-col gap-2 rounded-xl border border-hairline bg-surface p-4 shadow-xs">
          <div className="flex items-center justify-between text-ink-muted">
            <span className="text-xs font-bold uppercase tracking-wider">Hardware Allocation</span>
            <Cpu size={18} className="text-calm-fg" />
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-3xl font-extrabold tabular-nums text-ink">
              {equippedDevices.length} <span className="text-lg font-normal text-ink-muted">/ {totalDevices}</span>
            </span>
            <span className="rounded-full bg-calm-soft px-2 py-0.5 text-xs font-bold text-calm-fg">
              {deviceFleetAllocatedPct}% Deployed
            </span>
          </div>
          <div className="h-2 w-full overflow-hidden rounded-full bg-surface-alt">
            <div
              className="h-full bg-calm-fg transition-all duration-500"
              style={{ width: `${deviceFleetAllocatedPct}%` }}
            />
          </div>
          <span className="text-[11px] text-ink-muted">
            {unassignedDevices.length} available device{unassignedDevices.length === 1 ? "" : "s"} ready in inventory.
          </span>
        </div>

        {/* Fleet Health & Maintenance Card */}
        <div className="flex flex-col gap-2 rounded-xl border border-hairline bg-surface p-4 shadow-xs">
          <div className="flex items-center justify-between text-ink-muted">
            <span className="text-xs font-bold uppercase tracking-wider">Fleet Operational Health</span>
            <Radio size={18} className={equippedOffline > 0 ? "text-high-fg" : "text-brand"} />
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-3xl font-extrabold tabular-nums text-ink">{equippedActive}</span>
            <span className="text-xs font-medium text-ink-muted">Online &amp; Transmitting</span>
          </div>
          <div className="flex items-center gap-3 text-xs">
            <span className="flex items-center gap-1 text-high-fg font-medium">
              <ShieldAlert size={13} /> {equippedOffline} Offline
            </span>
            <span className="text-ink-muted">·</span>
            <span className="text-ink-muted font-medium">
              {unassignedAvailable} Idle / Ready
            </span>
          </div>
          <span className="text-[11px] text-ink-muted">
            {equippedOffline > 0
              ? `${equippedOffline} equipped device(s) currently offline.`
              : "All equipped devices actively streaming telemetries."}
          </span>
        </div>
      </div>

      {/* Visual Charts Container */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        {/* Device Status & Allocation Breakdown */}
        <div className="flex flex-col gap-3 rounded-xl border border-hairline bg-surface p-5 shadow-xs">
          <h3 className="text-sm font-bold text-ink">Device Status &amp; Assignment Breakdown</h3>
          <p className="text-xs text-ink-muted m-0">
            Current distribution of hardware across active dog pairings, unassigned inventory, and maintenance states.
          </p>
          <div className="h-64 w-full pt-2">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={deviceStatusData} layout="vertical" margin={{ top: 5, right: 20, left: 15, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" horizontal opacity={0.3} />
                <XAxis type="number" allowDecimals={false} className="text-xs text-ink-muted" />
                <YAxis
                  dataKey="category"
                  type="category"
                  width={130}
                  tickLine={false}
                  axisLine={false}
                  className="text-xs font-medium text-ink"
                />
                <Tooltip
                  cursor={{ fill: "var(--surface-alt, rgba(0,0,0,0.04))" }}
                  content={({ active, payload }) => {
                    if (!active || !payload || !payload.length) return null;
                    const data = payload[0].payload;
                    return (
                      <div className="rounded-md border border-hairline bg-surface p-2.5 shadow-md text-xs">
                        <div className="font-bold text-ink">{data.category}</div>
                        <div className="text-ink-muted mt-1">
                          Count: <span className="font-extrabold text-ink tabular-nums">{data.count}</span> devices
                        </div>
                      </div>
                    );
                  }}
                />
                <Bar dataKey="count" radius={[0, 4, 4, 0]} barSize={22}>
                  {deviceStatusData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.fill} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Dog Device Adoption Ratio */}
        <div className="flex flex-col gap-3 rounded-xl border border-hairline bg-surface p-5 shadow-xs">
          <h3 className="text-sm font-bold text-ink">Dog Population Device Coverage</h3>
          <p className="text-xs text-ink-muted m-0">
            Comparison of dogs actively equipped with monitoring collars versus total clinic dog registrations.
          </p>
          <div className="h-64 w-full pt-2">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={dogAdoptionData} margin={{ top: 20, right: 30, left: 0, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" opacity={0.3} />
                <XAxis dataKey="group" tickLine={false} axisLine={false} className="text-xs font-medium text-ink" />
                <YAxis allowDecimals={false} className="text-xs text-ink-muted" />
                <Tooltip
                  cursor={{ fill: "var(--surface-alt, rgba(0,0,0,0.04))" }}
                  content={({ active, payload }) => {
                    if (!active || !payload || !payload.length) return null;
                    return (
                      <div className="rounded-md border border-hairline bg-surface p-2.5 shadow-md text-xs">
                        <div className="font-bold text-ink mb-1">Dog Population Coverage</div>
                        {payload.map((item, idx) => (
                          <div key={idx} className="flex items-center gap-2 text-ink-muted">
                            <span className="h-2 w-2 rounded-full" style={{ backgroundColor: item.color }} />
                            <span>{item.name}:</span>
                            <span className="font-bold text-ink tabular-nums">{item.value} dogs</span>
                          </div>
                        ))}
                      </div>
                    );
                  }}
                />
                <Legend className="text-xs" />
                <Bar dataKey="Equipped" fill="var(--ff-status-calm-fg, #0C7C6F)" radius={[4, 4, 0, 0]} barSize={40} />
                <Bar dataKey="Awaiting Device" fill="var(--brand-soft, #DBEAFE)" radius={[4, 4, 0, 0]} barSize={40} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  );
}
