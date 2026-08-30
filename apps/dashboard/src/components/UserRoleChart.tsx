import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from "recharts";
import { UserCheck, Users } from "lucide-react";
import type { User } from "../../../../packages/shared/types/index.ts";
import { EmptyState } from "./ui/empty-state.tsx";

export interface UserRoleChartProps {
  users: User[];
}

export function UserRoleChart({ users }: UserRoleChartProps) {
  if (users.length === 0) {
    return <EmptyState>No user account records loaded yet 🐾</EmptyState>;
  }

  const totalUsers = users.length;
  const ownerCount = users.filter((u) => u.role === "owner").length;
  const vetCount = users.filter((u) => u.role === "veterinarian").length;
  const staffCount = users.filter((u) => u.role === "vet_staff").length;
  const adminCount = users.filter((u) => u.role === "admin").length;

  const data = [
    {
      name: "Dog Owners",
      value: ownerCount,
      fill: "var(--brand, #2563EB)",
    },
    {
      name: "Veterinarians",
      value: vetCount,
      fill: "var(--ff-status-calm-fg, #0C7C6F)",
    },
    {
      name: "Vet Staff",
      value: staffCount,
      fill: "var(--ff-status-mild-fg, #956603)",
    },
    {
      name: "System Admins",
      value: adminCount,
      fill: "#8B5CF6",
    },
  ].filter((item) => item.value > 0);

  return (
    <div className="flex flex-col gap-5">
      {/* Top Summary Banner */}
      <div className="flex items-center justify-between rounded-lg border border-hairline bg-surface-alt p-3.5 shadow-2xs">
        <div className="flex items-center gap-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-md bg-brand-soft text-brand">
            <Users size={20} />
          </div>
          <div>
            <div className="text-xs font-bold uppercase tracking-wider text-ink-muted">
              Platform User Base
            </div>
            <div className="text-sm font-semibold text-ink">
              {totalUsers} active accounts registered
            </div>
          </div>
        </div>
        <span className="rounded-full bg-brand-soft px-3 py-1 text-xs font-bold text-brand-strong flex items-center gap-1.5">
          <UserCheck size={13} /> {vetCount + staffCount} Clinical Staff
        </span>
      </div>

      {/* Donut Chart & Legend Grid */}
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
                        Count: <span className="font-extrabold text-ink tabular-nums">{item.value}</span> users
                      </div>
                    </div>
                  );
                }}
              />
            </PieChart>
          </ResponsiveContainer>

          {/* Center Label */}
          <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
            <span className="text-2xl font-extrabold tabular-nums text-ink">{totalUsers}</span>
            <span className="text-[11px] font-bold uppercase tracking-wider text-ink-muted">Total Users</span>
          </div>
        </div>

        {/* Legend List */}
        <div className="flex flex-col gap-2.5">
          <div className="flex items-center justify-between rounded-md bg-surface p-2.5 border border-hairline shadow-2xs">
            <div className="flex items-center gap-2">
              <span className="h-3 w-3 rounded-full bg-blue-600" />
              <span className="text-xs font-semibold text-ink">Dog Owners</span>
            </div>
            <span className="text-xs font-extrabold tabular-nums text-ink">{ownerCount}</span>
          </div>

          <div className="flex items-center justify-between rounded-md bg-surface p-2.5 border border-hairline shadow-2xs">
            <div className="flex items-center gap-2">
              <span className="h-3 w-3 rounded-full bg-calm-fg" />
              <span className="text-xs font-semibold text-ink">Veterinarians</span>
            </div>
            <span className="text-xs font-extrabold tabular-nums text-ink">{vetCount}</span>
          </div>

          <div className="flex items-center justify-between rounded-md bg-surface p-2.5 border border-hairline shadow-2xs">
            <div className="flex items-center gap-2">
              <span className="h-3 w-3 rounded-full bg-amber-600" />
              <span className="text-xs font-semibold text-ink">Vet Staff</span>
            </div>
            <span className="text-xs font-extrabold tabular-nums text-ink">{staffCount}</span>
          </div>

          <div className="flex items-center justify-between rounded-md bg-surface p-2.5 border border-hairline shadow-2xs">
            <div className="flex items-center gap-2">
              <span className="h-3 w-3 rounded-full bg-purple-600" />
              <span className="text-xs font-semibold text-ink">System Admins</span>
            </div>
            <span className="text-xs font-extrabold tabular-nums text-ink">{adminCount}</span>
          </div>
        </div>
      </div>
    </div>
  );
}
