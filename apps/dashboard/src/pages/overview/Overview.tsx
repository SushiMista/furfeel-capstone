// ADDED: Overview page — docs/05 nav lists "Overview" but never specified it, so this
// is a clinic-at-a-glance screen: greeting, KPI cards, a clinic-wide 14-day
// stress-mix chart, needs-attention dogs, and latest open alerts.
import { friendlyError } from "../../lib/errors.ts";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { Activity, Bell, Dog as DogIcon, HeartHandshake, WifiOff } from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import {
  acknowledgeAlert,
  fetchAlertsQueue,
  fetchClinicBoardSummary,
  fetchClinicStressDailySummary,
  sortBoardRows,
  type ClinicBoardRow,
  type DailyStressSummaryRow,
} from "../../lib/queries.ts";
import { useAuth } from "../../lib/useAuth.ts";
import { useAccount } from "../../lib/userSettings.ts";
import { useRealtimeInsert } from "../../lib/useRealtimeInsert.ts";
import { StressLevelBadge } from "../../components/StressLevelBadge.tsx";
import { StressMixChart } from "../../components/StressMixChart.tsx";
import { AlertCard } from "../../components/AlertCard.tsx";
import { Card, CardContent, CardHeader, CardTitle } from "../../components/ui/card.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import type { Alert } from "../../../../../packages/shared/types/index.ts";

/** Clinic mix window (matches the "last 14 days" header below). */
const MIX_DAYS = 14;

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
  const [rows, setRows] = useState<ClinicBoardRow[]>([]);
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [mix, setMix] = useState<DailyStressSummaryRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // 3 queries total, regardless of clinic size — was ~25 for a 4-dog clinic
  // (fetchMonitoringBoard's 5-per-dog fan-out + one stress_daily_summary RPC
  // per dog), which is what produced the 57014 statement-timeout under
  // concurrent load from the firmware simulator + mobile app + dashboard all
  // hitting the same free-tier project at once (ADR-021). The mix chart is
  // aggregated server-side by clinic_stress_daily_summary — an earlier,
  // client-side-bucketing version of this fix silently truncated the chart
  // to ~8% of the period, since this project's PostgREST config caps a plain
  // row fetch at 1000 and a real 14-day window is 11,000+ rows.
  const load = useCallback(async () => {
    try {
      const [board, openAlerts, mix] = await Promise.all([
        fetchClinicBoardSummary(supabase),
        fetchAlertsQueue(supabase, "open", 20),
        fetchClinicStressDailySummary(supabase, MIX_DAYS),
      ]);
      setRows(board);
      setAlerts(openAlerts);
      setMix(mix);
      setError(null);
    } catch (err) {
      setError(friendlyError(err, "load the overview"));
    } finally {
      setLoading(false);
    }
  }, []);

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

  // Clinic calm share today: the reassuring headline number.
  const calmToday = useMemo(() => {
    const today = mix[mix.length - 1];
    if (!today) return null;
    const total = today.calm + today.mild + today.moderate + today.high;
    if (total === 0) return null;
    return Math.round((today.calm / total) * 100);
  }, [mix]);

  if (loading)
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

  return (
    <div className="flex flex-col gap-5">
      {/* ADDED: greeting by name + date — the dashboard knows who's working. */}
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

      <div className="ff-enter-list flex flex-wrap gap-4">
        <Kpi label="Dogs monitored" value={String(rows.length)} icon={<DogIcon size={20} />} />
        {calmToday !== null && (
          <Kpi
            label="Calm today"
            value={`${calmToday}%`}
            icon={<HeartHandshake size={20} />}
            tone="positive"
          />
        )}
        <Kpi
          label="Needs attention"
          value={String(needsAttention.length)}
          icon={<Activity size={20} />}
          tone="attention"
          attention={needsAttention.length > 0}
        />
        <Kpi
          label="Open alerts"
          value={String(alerts.length)}
          icon={<Bell size={20} />}
          tone="attention"
          attention={alerts.length > 0}
        />
        <Kpi
          label="Devices offline"
          value={String(offlineDevices)}
          icon={<WifiOff size={20} />}
          tone="attention"
          attention={offlineDevices > 0}
        />
      </div>

      {/* ADDED: clinic-wide stress mix — composition per day on the canonical
          status ramp; the word legend keeps identity off color alone. */}
      <Card className="ff-enter">
        <CardHeader>
          <CardTitle className="text-lg">Clinic stress mix — last 14 days</CardTitle>
        </CardHeader>
        <CardContent>
          <StressMixChart summary={mix} />
        </CardContent>
      </Card>

      <div className="ff-enter-list grid gap-5 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Needs attention</CardTitle>
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
            <CardTitle className="text-lg">Latest open alerts</CardTitle>
          </CardHeader>
          <CardContent>
            {alerts.length === 0 ? (
              <EmptyState>No open alerts — everyone&apos;s doing great 🐾</EmptyState>
            ) : (
              alerts.slice(0, 5).map((a) => (
                <div key={a.id}>
                  <Link
                    to={`/dogs/${a.dog_id}`}
                    className="mb-1 inline-block text-sm font-semibold text-ink hover:text-brand-strong"
                  >
                    {dogNames.get(a.dog_id) ?? "Unknown dog"}
                  </Link>
                  <AlertCard
                    alert={a}
                    onAcknowledge={async (alert) => {
                      const userId = session?.user.id;
                      if (!userId) return;
                      const updated = await acknowledgeAlert(supabase, alert.id, userId);
                      if (updated) setAlerts((prev) => prev.filter((x) => x.id !== updated.id));
                    }}
                  />
                </div>
              ))
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
