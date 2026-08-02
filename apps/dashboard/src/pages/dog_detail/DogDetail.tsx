import { friendlyError } from "../../lib/errors.ts";
import { useCallback, useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { Activity, ArrowLeft, ClipboardCheck, Heart, Thermometer, Wind, type LucideIcon } from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import {
  acknowledgeAlert,
  fetchClassificationHistory,
  fetchDailyStressSummary,
  fetchDog,
  fetchRecentAlerts,
  fetchTelemetryHistory,
  type DailyStressSummaryRow,
} from "../../lib/queries.ts";
import { useAuth } from "../../lib/useAuth.ts";
import { TelemetryChart } from "../../components/TelemetryChart.tsx";
import { StressMixChart } from "../../components/StressMixChart.tsx";
import { StressTimeline } from "../../components/StressTimeline.tsx";
import { StressLevelBadge } from "../../components/StressLevelBadge.tsx";
import { MicroSparkline } from "../../components/MicroSparkline.tsx";
import { AlertCard } from "../../components/AlertCard.tsx";
import { VetNotes } from "../../components/VetNotes.tsx";
import { ThresholdEditor } from "../../components/ThresholdEditor.tsx";
import { Card, CardContent, CardHeader, CardTitle } from "../../components/ui/card.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import { cn } from "../../lib/cn.ts";
import type {
  Alert,
  Dog,
  StressClassification,
  TelemetryReading,
} from "../../../../../packages/shared/types/index.ts";

const HISTORY_LIMIT = 50;

/** Section tabs (docs/05): same pill pattern as Admin — the per-dog page was
 * one long scroll; this groups it without changing what data shows. */
const TABS = [
  { id: "alerts", label: "Alerts" },
  { id: "telemetry", label: "Live telemetry" },
  { id: "stress", label: "Stress history" },
  { id: "notes", label: "Vet notes" },
  { id: "thresholds", label: "Thresholds" },
] as const;
type TabId = (typeof TABS)[number]["id"];

/** Vital card (docs/19 §7, docs/21 Phase 2): icon + label header, big tabular
 * value, small unit, and a recent-trend micro-sparkline — a number carrying a
 * short trend beats a number alone. Kept dense/flat per docs/19 §4; no
 * plain-language descriptor here because the dashboard has no client-side
 * baseline to derive one from, and inventing a threshold is a guardrail break. */
function Vital({
  label,
  icon: Icon,
  value,
  unit,
  series,
}: {
  label: string;
  icon: LucideIcon;
  value: number | string | null | undefined;
  unit: string;
  series: number[];
}) {
  return (
    <div className="flex min-w-28 flex-1 flex-col gap-1.5 rounded-md bg-surface-alt px-4 py-3">
      <div className="flex items-center gap-1.5 text-xs font-medium text-ink-muted">
        <Icon size={14} aria-hidden="true" className="text-brand" />
        {label}
      </div>
      <div className="text-3xl font-bold leading-tight tabular-nums text-ink">
        {value ?? "—"}
        <span className="ml-1 text-xs font-normal text-ink-muted">{unit}</span>
      </div>
      <MicroSparkline series={series} track className="mt-0.5" />
    </div>
  );
}

/** Last N non-null values of a vital, oldest → newest, for the sparkline. */
function seriesOf(
  readings: TelemetryReading[],
  pick: (r: TelemetryReading) => number | null | undefined,
  limit = 12,
): number[] {
  return readings
    .map(pick)
    .filter((v): v is number => typeof v === "number" && Number.isFinite(v))
    .slice(-limit);
}

export function DogDetail() {
  const { dogId } = useParams<{ dogId: string }>();
  const { session } = useAuth();
  const [dog, setDog] = useState<Dog | null>(null);
  const [readings, setReadings] = useState<TelemetryReading[]>([]);
  const [classifications, setClassifications] = useState<StressClassification[]>([]);
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [mixSummary, setMixSummary] = useState<DailyStressSummaryRow[]>([]);
  const [tab, setTab] = useState<TabId>("alerts");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!dogId) return;
    try {
      const [dogRow, history, classHistory, recentAlerts, mixRows] = await Promise.all([
        fetchDog(supabase, dogId),
        fetchTelemetryHistory(supabase, dogId, HISTORY_LIMIT),
        fetchClassificationHistory(supabase, dogId, HISTORY_LIMIT),
        fetchRecentAlerts(supabase, dogId),
        fetchDailyStressSummary(supabase, dogId),
      ]);
      setDog(dogRow);
      setReadings(history);
      setClassifications(classHistory);
      setAlerts(recentAlerts);
      setMixSummary(mixRows);
      setError(null);
    } catch (err) {
      setError(friendlyError(err, "load this dog"));
    } finally {
      setLoading(false);
    }
  }, [dogId]);

  useEffect(() => {
    load();
  }, [load]);

  // Single-dog page: safe to filter Realtime by dog_id directly (docs/10 Realtime).
  useEffect(() => {
    if (!dogId) return;

    const channel = supabase
      .channel(`dog-detail-${dogId}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "telemetry_readings", filter: `dog_id=eq.${dogId}` },
        (payload) =>
          setReadings((prev) => [...prev, payload.new as TelemetryReading].slice(-HISTORY_LIMIT)),
      )
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "stress_classifications",
          filter: `dog_id=eq.${dogId}`,
        },
        (payload) =>
          setClassifications((prev) =>
            [...prev, payload.new as StressClassification].slice(-HISTORY_LIMIT),
          ),
      )
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "alerts", filter: `dog_id=eq.${dogId}` },
        (payload) => setAlerts((prev) => [payload.new as Alert, ...prev]),
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [dogId]);

  if (loading)
    return (
      <div className="flex flex-col gap-4">
        <CardSkeleton lines={2} />
        <CardSkeleton lines={4} />
      </div>
    );
  if (error)
    return (
      <p role="alert" className="rounded-sm bg-high-soft px-3 py-2 text-sm text-high-fg">
        {error}
      </p>
    );
  if (!dog)
    return (
      <EmptyState>
        We couldn&apos;t find that dog (or they&apos;re not visible to your account).
      </EmptyState>
    );

  const latest = classifications[classifications.length - 1] ?? null;
  const latestReading = readings[readings.length - 1] ?? null;

  return (
    <div className="flex flex-col gap-5">
      <div className="flex items-center justify-between gap-3">
        <Link
          to="/board"
          className="inline-flex items-center gap-1 text-sm font-medium text-ink-muted hover:text-brand-strong"
        >
          <ArrowLeft size={14} /> Monitoring board
        </Link>
        <Link
          to={`/dogs/${dogId}/review`}
          className="inline-flex items-center gap-1.5 rounded-md bg-brand-soft px-3 py-2 text-sm font-semibold text-brand-strong transition-colors duration-fast hover:brightness-95"
        >
          <ClipboardCheck size={14} /> Vet review
        </Link>
      </div>

      <Card>
        <CardContent className="p-5">
          <p className="m-0 mb-1 text-xs font-semibold uppercase tracking-wide text-ink-muted">
            {dog.breed ?? "Unknown breed"}
          </p>
          <h1 className="m-0 mb-4 flex items-center gap-3 text-2xl font-bold text-ink">
            {dog.name} {latest && <StressLevelBadge level={latest.stress_level} />}
          </h1>
          <div className="flex flex-wrap gap-3">
            <Vital
              label="Heart rate"
              icon={Heart}
              value={latestReading?.heart_rate_bpm}
              unit="bpm"
              series={seriesOf(readings, (r) => r.heart_rate_bpm)}
            />
            <Vital
              label="Respiratory"
              icon={Wind}
              value={latestReading?.respiratory_rate_bpm}
              unit="bpm"
              series={seriesOf(readings, (r) => r.respiratory_rate_bpm)}
            />
            <Vital
              label="Temperature"
              icon={Thermometer}
              value={latestReading?.body_temperature_c}
              unit="°C"
              series={seriesOf(readings, (r) => r.body_temperature_c)}
            />
            <Vital
              label="Motion"
              icon={Activity}
              value={latestReading?.motion_activity}
              unit=""
              series={seriesOf(readings, (r) => r.motion_activity)}
            />
          </div>
          {latestReading && (
            <p className="m-0 mt-3 text-xs text-ink-muted">
              Last updated {new Date(latestReading.captured_at).toLocaleString()}
            </p>
          )}
        </CardContent>
      </Card>

      <div role="tablist" aria-label="Dog detail sections" className="flex flex-wrap gap-2">
        {TABS.map((t) => {
          const openCount = t.id === "alerts" ? alerts.filter((a) => a.status === "open").length : 0;
          return (
            <button
              key={t.id}
              type="button"
              role="tab"
              aria-selected={tab === t.id}
              onClick={() => setTab(t.id)}
              className={cn(
                "inline-flex items-center gap-2 rounded-md px-4 py-2 text-sm font-semibold transition-colors duration-fast",
                tab === t.id
                  ? "bg-brand-soft text-brand-strong"
                  : "text-ink-muted hover:bg-surface-alt hover:text-ink",
              )}
            >
              {t.label}
              {openCount > 0 && (
                <span className="rounded-pill bg-high-soft px-2 py-0.5 text-xs font-bold tabular-nums text-high-fg">
                  {openCount}
                </span>
              )}
            </button>
          );
        })}
      </div>

      {tab === "alerts" && (
        <Card>
          <CardHeader>
            <CardTitle>Alerts</CardTitle>
          </CardHeader>
          <CardContent>
            {alerts.length === 0 ? (
              <EmptyState>No alerts — {dog.name} is doing great 🐾</EmptyState>
            ) : (
              alerts.map((a) => (
                <AlertCard
                  key={a.id}
                  alert={a}
                  onAcknowledge={async (alert) => {
                    const userId = session?.user.id;
                    if (!userId) return;
                    const updated = await acknowledgeAlert(supabase, alert.id, userId);
                    if (updated) {
                      setAlerts((prev) => prev.map((x) => (x.id === updated.id ? updated : x)));
                    }
                  }}
                />
              ))
            )}
          </CardContent>
        </Card>
      )}

      {tab === "telemetry" && (
        <Card>
          <CardHeader>
            <CardTitle>Live telemetry</CardTitle>
          </CardHeader>
          <CardContent>
            <TelemetryChart readings={readings} />
          </CardContent>
        </Card>
      )}

      {tab === "stress" && (
        <>
          <Card>
            <CardHeader>
              <CardTitle>Stress mix — last 14 days</CardTitle>
            </CardHeader>
            <CardContent>
              <StressMixChart summary={mixSummary} />
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Stress timeline</CardTitle>
            </CardHeader>
            <CardContent>
              <StressTimeline classifications={classifications} />
            </CardContent>
          </Card>
        </>
      )}

      {tab === "notes" && <VetNotes dogId={dog.id} />}

      {tab === "thresholds" && <ThresholdEditor dogId={dog.id} />}
    </div>
  );
}
