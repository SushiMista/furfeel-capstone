import { friendlyError } from "../../lib/errors.ts";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import {
  Activity,
  BellRing,
  Building2,
  Cpu,
  Dog as DogIcon,
  HeartHandshake,
  MapPin,
  Users as UsersIcon,
  WifiOff,
} from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import {
  acknowledgeAlert,
  fetchAlertsQueue,
  fetchClinicBoardSummary,
  fetchClinicStressDailySummary,
  fetchClinicsReadOnly,
  fetchDevicesReadOnly,
  fetchDogs,
  sortBoardRows,
  type ClinicBoardRow,
  type DailyStressSummaryRow,
} from "../../lib/queries.ts";
import { fetchAllUsers } from "../../lib/adminQueries.ts";
import { useAuth } from "../../lib/useAuth.ts";
import { useCurrentRole } from "../../lib/useCurrentRole.ts";
import { useAccount } from "../../lib/userSettings.ts";
import { useRealtimeInsert } from "../../lib/useRealtimeInsert.ts";
import { StressLevelBadge } from "../../components/StressLevelBadge.tsx";
import { StressMixChart } from "../../components/StressMixChart.tsx";
import { UserRoleChart } from "../../components/UserRoleChart.tsx";
import { ClinicFleetChart } from "../../components/ClinicFleetChart.tsx";
import { AlertCard } from "../../components/AlertCard.tsx";
import { Card, CardContent, CardHeader, CardTitle } from "../../components/ui/card.tsx";
import { Select } from "../../components/ui/input.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import type { Alert, Clinic, Device, Dog, User } from "../../../../../packages/shared/types/index.ts";

export function Kpi({
  label,
  value,
  icon,
  tone = "default",
  attention = false,
}: {
  label: string;
  value: string;
  icon: React.ReactNode;
  tone?: "default" | "attention" | "positive";
  attention?: boolean;
}) {
  return (
    <Card className="flex-1">
      <CardContent className="flex items-center gap-4 p-5">
        <span
          className={
            tone === "attention" && attention
              ? "rounded-md bg-high-soft p-2 text-high-fg"
              : tone === "positive"
                ? "rounded-md bg-calm-soft p-2 text-calm-fg"
                : "rounded-md bg-brand-soft p-2 text-brand"
          }
        >
          {icon}
        </span>
        <div>
          <div className="text-3xl font-bold tabular-nums text-ink">{value}</div>
          <div className="text-xs font-semibold uppercase tracking-wide text-ink-muted">
            {label}
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

function greetingWord(hour: number): string {
  if (hour >= 5 && hour < 12) return "Good morning";
  if (hour >= 12 && hour < 17) return "Good afternoon";
  return "Good evening";
}

export function Overview() {
  const { session } = useAuth();
  const { profile } = useAccount();
  const { role, loading: roleLoading } = useCurrentRole();

  const [rows, setRows] = useState<ClinicBoardRow[]>([]);
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [mix, setMix] = useState<DailyStressSummaryRow[]>([]);
  const [clinics, setClinics] = useState<Clinic[]>([]);
  const [devices, setDevices] = useState<Device[]>([]);
  const [dogs, setDogs] = useState<Dog[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  const [timeRange, setTimeRange] = useState<number>(14);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const [board, openAlerts, mixData, deviceList, dogList, clinicList, userList] = await Promise.all([
        fetchClinicBoardSummary(supabase),
        fetchAlertsQueue(supabase, "open", 20),
        fetchClinicStressDailySummary(supabase, timeRange).catch(() => []),
        fetchDevicesReadOnly(supabase).catch(() => []),
        fetchDogs(supabase).catch(() => []),
        fetchClinicsReadOnly(supabase).catch(() => []),
        fetchAllUsers(supabase).catch(() => []),
      ]);
      setRows(board);
      setAlerts(openAlerts);
      setMix(mixData);
      setDevices(deviceList);
      setDogs(dogList);
      setClinics(clinicList);
      setUsers(userList);
      setError(null);
    } catch (err) {
      setError(friendlyError(err, "load the overview"));
    } finally {
      setLoading(false);
    }
  }, [timeRange]);

  useEffect(() => {
    load();
  }, [load]);

  useRealtimeInsert<Alert>("alerts", (row) =>
    setAlerts((prev) => (prev.some((a) => a.id === row.id) ? prev : [row, ...prev])),
  );

  const dogNames = useMemo(() => new Map(rows.map((r) => [r.dog.id, r.dog.name])), [rows]);
  const needsAttention = rows.filter(
    (r) => r.latestClassification && r.latestClassification.stress_level !== "calm",
  );
  const offlineDevices = rows.filter((r) => r.device?.status === "offline").length;
  const admittedCount = rows.filter(
    (r) =>
      r.dog.admission_status &&
      r.dog.admission_status !== "outpatient" &&
      r.dog.admission_status !== "ready_for_discharge",
  ).length;

  const calmToday = useMemo(() => {
    const today = mix[mix.length - 1];
    if (!today) return null;
    const total = today.calm + today.mild + today.moderate + today.high;
    if (total === 0) return null;
    return Math.round((today.calm / total) * 100);
  }, [mix]);

  if (roleLoading || loading)
    return (
      <div className="flex flex-col gap-4">
        <CardSkeleton lines={1} />
        <CardSkeleton lines={4} />
      </div>
    );

  if (error)
    return (
      <p role="alert" className="rounded-sm bg-high-soft px-3 py-2 text-sm text-high-fg">
        {error}
      </p>
    );

  const name = profile?.name ?? session?.user.email ?? "";

  // ---------------------------------------------------------------------------
  // SYSTEM ADMINISTRATOR PLATFORM OVERVIEW (Role: admin)
  // ---------------------------------------------------------------------------
  if (role === "admin") {
    return (
      <div className="flex flex-col gap-5">
        {/* Header Greeting */}
        <div className="ff-enter">
          <h1 className="m-0 text-2xl font-bold text-ink">
            {greetingWord(new Date().getHours())}
            {name ? `, ${name}` : ""}
          </h1>
          <p className="m-0 mt-1 text-sm text-ink-muted">
            FurFeel System Administrator Overview · Ecosystem Health &amp; Platform Status
          </p>
        </div>

        {/* Layer 1: 5 Platform Administrator KPI Cards */}
        <div className="ff-enter-list grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-4">
          <Kpi label="Total Users" value={String(users.length || 0)} icon={<UsersIcon size={20} strokeWidth={1.75} />} />
          <Kpi label="Partner Clinics" value={String(clinics.length)} icon={<Building2 size={20} strokeWidth={1.75} />} tone="positive" />
          <Kpi label="Dogs Monitored" value={String(dogs.length || rows.length)} icon={<DogIcon size={20} strokeWidth={1.75} />} />
          <Kpi label="Active Devices" value={String(devices.length)} icon={<Cpu size={20} strokeWidth={1.75} />} />
          <Kpi
            label="System Alerts"
            value={String(alerts.length)}
            icon={<BellRing size={20} strokeWidth={1.75} />}
            tone="attention"
            attention={alerts.length > 0}
          />
        </div>

        {/* Layer 2: 2 Platform Executive Charts Side-by-Side */}
        <div className="ff-enter grid grid-cols-1 xl:grid-cols-2 gap-5">
          {/* Chart 1: User Account & Role Distribution */}
          <Card>
            <CardHeader className="py-4">
              <CardTitle className="text-lg">User Account &amp; Role Distribution</CardTitle>
            </CardHeader>
            <CardContent>
              <UserRoleChart users={users} />
            </CardContent>
          </Card>

          {/* Chart 2: Partner Clinic Deployment & Fleet Allocation */}
          <Card>
            <CardHeader className="py-4">
              <CardTitle className="text-lg">Partner Clinic Deployment &amp; Fleet Allocation</CardTitle>
            </CardHeader>
            <CardContent>
              <ClinicFleetChart clinics={clinics} dogs={dogs} devices={devices} users={users} />
            </CardContent>
          </Card>
        </div>

        {/* Layer 3: 2 Operational Divisions (Partner Clinics Directory & System Alerts Triage) */}
        <div className="ff-enter-list grid gap-5 lg:grid-cols-2">
          {/* Division 1: Partner Clinics Overview */}
          <Card>
            <CardHeader className="flex flex-row items-center justify-between">
              <CardTitle className="text-lg">Partner Clinics Directory</CardTitle>
              <Link to="/admin/clinics" className="text-xs font-semibold text-brand hover:underline">
                Manage Clinics &rarr;
              </Link>
            </CardHeader>
            <CardContent>
              {clinics.length === 0 ? (
                <EmptyState>No partner clinics registered yet 🐾</EmptyState>
              ) : (
                <div className="flex flex-col gap-2.5">
                  {clinics.map((c) => {
                    const clinicDogs = dogs.filter((d) => d.clinic_id === c.id).length;
                    const clinicStaff = users.filter(
                      (u) => u.clinic_id === c.id && (u.role === "veterinarian" || u.role === "vet_staff"),
                    ).length;

                    return (
                      <div
                        key={c.id}
                        className="flex items-center justify-between rounded-lg bg-surface-alt p-3 border border-hairline"
                      >
                        <div className="flex flex-col gap-0.5">
                          <span className="font-bold text-sm text-ink">{c.name}</span>
                          <span className="text-xs text-ink-muted">{c.address || "No address listed"}</span>
                        </div>
                        <div className="flex items-center gap-3 text-xs font-medium">
                          <span className="rounded-full bg-brand-soft px-2.5 py-0.5 text-brand-strong font-semibold">
                            {clinicStaff} Staff
                          </span>
                          <span className="rounded-full bg-calm-soft px-2.5 py-0.5 text-calm-fg font-semibold">
                            {clinicDogs} Dogs
                          </span>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </CardContent>
          </Card>

          {/* Division 2: System & Hardware Alerts Triage */}
          <Card>
            <CardHeader className="flex flex-row items-center justify-between">
              <CardTitle className="text-lg">System &amp; Hardware Alerts</CardTitle>
              <Link to="/alerts" className="text-xs font-semibold text-brand hover:underline">
                Alerts Queue &rarr;
              </Link>
            </CardHeader>
            <CardContent>
              {alerts.length === 0 ? (
                <EmptyState>No open system alerts — all hardware operating normally 🐾</EmptyState>
              ) : (
                alerts.slice(0, 5).map((a) => (
                  <AlertCard
                    key={a.id}
                    alert={a}
                    dogName={dogNames.get(a.dog_id)}
                    onAcknowledge={async (alert) => {
                      const userId = session?.user.id;
                      if (!userId) return;
                      const updated = await acknowledgeAlert(supabase, alert.id, userId);
                      if (updated) setAlerts((prev) => prev.filter((x) => x.id !== updated.id));
                    }}
                  />
                ))
              )}
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  // ---------------------------------------------------------------------------
  // VETERINARY CLINIC OVERVIEW (Role: veterinarian / vet_staff / owner)
  // ---------------------------------------------------------------------------
  return (
    <div className="flex flex-col gap-5">
      {/* Header Greeting */}
      <div className="ff-enter">
        <h1 className="m-0 text-2xl font-bold text-ink">
          {greetingWord(new Date().getHours())}
          {name ? `, ${name}` : ""}
        </h1>
        <p className="m-0 mt-1 text-sm text-ink-muted">
          {new Date().toLocaleDateString(undefined, {
            weekday: "long",
            month: "long",
            day: "numeric",
          })}
          {rows.length > 0 &&
            ` · ${rows.length} ${rows.length === 1 ? "dog" : "dogs"} on the board`}
        </p>
      </div>

      {/* Layer 1: Clinical KPI Cards */}
      <div className="ff-enter-list grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3.5">
        <Kpi label="Monitored" value={String(rows.length)} icon={<DogIcon size={18} strokeWidth={1.75} />} />
        <Kpi label="Inpatients" value={String(admittedCount)} icon={<MapPin size={18} strokeWidth={1.75} />} tone="positive" />
        {calmToday !== null && (
          <Kpi
            label="Calm Today"
            value={`${calmToday}%`}
            icon={<HeartHandshake size={18} strokeWidth={1.75} />}
            tone="positive"
          />
        )}
        <Kpi
          label="Attention"
          value={String(needsAttention.length)}
          icon={<Activity size={18} strokeWidth={1.75} />}
          tone="attention"
          attention={needsAttention.length > 0}
        />
        <Kpi
          label="Open Alerts"
          value={String(alerts.length)}
          icon={<BellRing size={18} strokeWidth={1.75} />}
          tone="attention"
          attention={alerts.length > 0}
        />
        <Kpi
          label="Offline"
          value={String(offlineDevices)}
          icon={<WifiOff size={18} strokeWidth={1.75} />}
          tone="attention"
          attention={offlineDevices > 0}
        />
      </div>

      {/* Layer 2: Clinical Stress Mix Area Chart */}
      <Card className="ff-enter">
        <CardHeader className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between py-4">
          <div>
            <CardTitle className="text-lg">
              Clinic Stress Mix — {timeRange === 7 ? "last 7 days" : timeRange === 14 ? "last 14 days" : timeRange === 30 ? "last 30 days" : "last 3 months"}
            </CardTitle>
          </div>
          <Select
            value={String(timeRange)}
            onChange={(e) => setTimeRange(Number(e.target.value))}
            className="h-9 w-44 text-xs font-medium"
            aria-label="Select time range"
          >
            <option value="7">Last 7 days</option>
            <option value="14">Last 14 days</option>
            <option value="30">Last 30 days</option>
            <option value="90">Last 3 months</option>
          </Select>
        </CardHeader>
        <CardContent>
          <StressMixChart summary={mix} />
        </CardContent>
      </Card>

      {/* Layer 3: Needs Attention & Latest Open Alerts */}
      <div className="ff-enter-list grid gap-5 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Needs Attention</CardTitle>
          </CardHeader>
          <CardContent>
            {needsAttention.length === 0 ? (
              <EmptyState>Everyone&apos;s calm right now — great news 🐾</EmptyState>
            ) : (
              <ul className="m-0 flex list-none flex-col gap-2 p-0">
                {sortBoardRows(needsAttention).map((r) => (
                  <li
                    key={r.dog.id}
                    className="flex items-center justify-between rounded-md bg-surface-alt px-3 py-2"
                  >
                    <Link
                      to={`/dogs/${r.dog.id}`}
                      className="font-semibold text-ink hover:text-brand-strong"
                    >
                      {r.dog.name}
                    </Link>
                    {r.latestClassification && (
                      <StressLevelBadge level={r.latestClassification.stress_level} />
                    )}
                  </li>
                ))}
              </ul>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Latest Open Alerts</CardTitle>
          </CardHeader>
          <CardContent>
            {alerts.length === 0 ? (
              <EmptyState>No open alerts — everyone&apos;s doing great 🐾</EmptyState>
            ) : (
              alerts.slice(0, 5).map((a) => (
                <AlertCard
                  key={a.id}
                  alert={a}
                  dogName={dogNames.get(a.dog_id)}
                  onAcknowledge={async (alert) => {
                    const userId = session?.user.id;
                    if (!userId) return;
                    const updated = await acknowledgeAlert(supabase, alert.id, userId);
                    if (updated) setAlerts((prev) => prev.filter((x) => x.id !== updated.id));
                  }}
                />
              ))
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}


