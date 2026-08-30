import {
  Bar,
  BarChart,
  CartesianGrid,
  Legend,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { Building2, PawPrint, Users } from "lucide-react";
import type { Clinic, Device, Dog, User } from "../../../../packages/shared/types/index.ts";
import { EmptyState } from "./ui/empty-state.tsx";

export interface ClinicFleetChartProps {
  clinics: Clinic[];
  dogs: Dog[];
  devices: Device[];
  users: User[];
}

export function ClinicFleetChart({ clinics, dogs, devices, users }: ClinicFleetChartProps) {
  if (clinics.length === 0) {
    return <EmptyState>No partner clinic records registered in the system yet 🐾</EmptyState>;
  }

  const chartData = clinics.map((c) => {
    const clinicDogs = dogs.filter((d) => d.clinic_id === c.id);
    const clinicStaff = users.filter(
      (u) => u.clinic_id === c.id && (u.role === "veterinarian" || u.role === "vet_staff"),
    );
    const clinicDevices = devices.filter((dev) =>
      clinicDogs.some((d) => d.id === dev.dog_id),
    );

    return {
      clinicName: c.name.length > 18 ? `${c.name.substring(0, 16)}…` : c.name,
      fullName: c.name,
      Dogs: clinicDogs.length,
      Staff: clinicStaff.length,
      Devices: clinicDevices.length,
    };
  });

  const totalDogsAssigned = dogs.filter((d) => d.clinic_id !== null).length;
  const totalStaffAssigned = users.filter(
    (u) => u.clinic_id !== null && (u.role === "veterinarian" || u.role === "vet_staff"),
  ).length;

  return (
    <div className="flex flex-col gap-5">
      {/* Top Summary Banner */}
      <div className="flex items-center justify-between rounded-lg border border-hairline bg-surface-alt p-3.5 shadow-2xs">
        <div className="flex items-center gap-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-md bg-brand-soft text-brand">
            <Building2 size={20} />
          </div>
          <div>
            <div className="text-xs font-bold uppercase tracking-wider text-ink-muted">
              Partner Clinic Ecosystem
            </div>
            <div className="text-sm font-semibold text-ink">
              {clinics.length} active partner clinics onboarded
            </div>
          </div>
        </div>
        <div className="flex items-center gap-3 text-xs font-semibold text-ink-muted">
          <span className="flex items-center gap-1 text-ink">
            <PawPrint size={14} className="text-brand" /> {totalDogsAssigned} Dogs
          </span>
          <span>·</span>
          <span className="flex items-center gap-1 text-ink">
            <Users size={14} className="text-calm-fg" /> {totalStaffAssigned} Staff
          </span>
        </div>
      </div>

      {/* Bar Chart Container */}
      <div className="h-64 w-full pt-2">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={chartData} margin={{ top: 10, right: 20, left: -10, bottom: 5 }}>
            <CartesianGrid strokeDasharray="3 3" opacity={0.3} />
            <XAxis
              dataKey="clinicName"
              tickLine={false}
              axisLine={false}
              className="text-xs font-medium text-ink"
            />
            <YAxis allowDecimals={false} className="text-xs text-ink-muted" />
            <Tooltip
              cursor={{ fill: "var(--surface-alt, rgba(0,0,0,0.04))" }}
              content={({ active, payload }) => {
                if (!active || !payload || !payload.length) return null;
                const data = payload[0].payload;
                return (
                  <div className="rounded-md border border-hairline bg-surface p-2.5 shadow-md text-xs">
                    <div className="font-bold text-ink mb-1">{data.fullName}</div>
                    <div className="flex flex-col gap-1 text-ink-muted">
                      {payload.map((item, idx) => (
                        <div key={idx} className="flex items-center gap-2">
                          <span
                            className="h-2 w-2 rounded-full"
                            style={{ backgroundColor: item.color }}
                          />
                          <span>{item.name}:</span>
                          <span className="font-bold text-ink tabular-nums">{item.value}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                );
              }}
            />
            <Legend wrapperStyle={{ fontSize: "12px" }} />
            <Bar dataKey="Dogs" fill="var(--brand, #2563EB)" radius={[4, 4, 0, 0]} barSize={28} />
            <Bar dataKey="Staff" fill="var(--ff-status-calm-fg, #0C7C6F)" radius={[4, 4, 0, 0]} barSize={28} />
            <Bar dataKey="Devices" fill="var(--ff-status-mild-fg, #956603)" radius={[4, 4, 0, 0]} barSize={28} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
