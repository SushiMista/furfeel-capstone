import { friendlyError } from "../../lib/errors.ts";
import { useCallback, useEffect, useMemo, useState } from "react";
import { AlertCircle, AlertTriangle, CheckCheck, Radio } from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import { acknowledgeAlert, acknowledgeAlerts, fetchAlertsQueue, fetchDogs } from "../../lib/queries.ts";
import { useAuth } from "../../lib/useAuth.ts";
import { useRealtimeInsert } from "../../lib/useRealtimeInsert.ts";
import { AlertCard } from "../../components/AlertCard.tsx";
import { Button } from "../../components/ui/button.tsx";
import { Card, CardContent } from "../../components/ui/card.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import { cn } from "../../lib/cn.ts";
import type { Alert, Dog } from "../../../../../packages/shared/types/index.ts";

const SEVERITY_RANK: Record<string, number> = { critical: 0, warning: 1, info: 2 };

type TypeFilter = "all" | "critical" | "device_offline" | "stress";

/** Alerts queue (docs/05): every RLS-visible alert across the clinic's dogs, open
 * first for fast triage, live via Realtime. */
export function AlertsQueue() {
  const { session } = useAuth();
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [dogs, setDogs] = useState<Dog[]>([]);
  const [showAll, setShowAll] = useState(false);
  const [typeFilter, setTypeFilter] = useState<TypeFilter>("all");
  const [loading, setLoading] = useState(true);
  const [acking, setAcking] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const [queue, dogRows] = await Promise.all([
        fetchAlertsQueue(supabase, showAll ? "all" : "open"),
        fetchDogs(supabase),
      ]);
      setAlerts(queue);
      setDogs(dogRows);
      setError(null);
    } catch (err) {
      setError(friendlyError(err, "load alerts"));
    } finally {
      setLoading(false);
    }
  }, [showAll]);

  useEffect(() => {
    load();
  }, [load]);

  useRealtimeInsert<Alert>("alerts", (row) => {
    setAlerts((prev) => (prev.some((a) => a.id === row.id) ? prev : [row, ...prev]));
  });

  const dogNames = useMemo(() => new Map(dogs.map((d) => [d.id, d.name])), [dogs]);

  // Counts for filter pills
  const counts = useMemo(() => {
    const critical = alerts.filter((a) => a.status === "open" && a.severity === "critical").length;
    const offline = alerts.filter((a) => a.status === "open" && a.type === "device_offline").length;
    const stress = alerts.filter((a) => a.status === "open" && a.type !== "device_offline").length;
    const totalOpen = alerts.filter((a) => a.status === "open").length;
    return { critical, offline, stress, totalOpen, total: alerts.length };
  }, [alerts]);

  const filtered = useMemo(() => {
    if (typeFilter === "critical") {
      return alerts.filter((a) => a.severity === "critical");
    }
    if (typeFilter === "device_offline") {
      return alerts.filter((a) => a.type === "device_offline");
    }
    if (typeFilter === "stress") {
      return alerts.filter((a) => a.type !== "device_offline");
    }
    return alerts;
  }, [alerts, typeFilter]);

  const sorted = useMemo(
    () =>
      [...filtered].sort((a, b) => {
        const openDiff = Number(b.status === "open") - Number(a.status === "open");
        if (openDiff !== 0) return openDiff;
        const sevDiff = (SEVERITY_RANK[a.severity] ?? 9) - (SEVERITY_RANK[b.severity] ?? 9);
        if (sevDiff !== 0) return sevDiff;
        return b.created_at.localeCompare(a.created_at);
      }),
    [filtered],
  );

  const openIds = useMemo(
    () => sorted.filter((a) => a.status === "open").map((a) => a.id),
    [sorted],
  );

  const acknowledgeAllOpen = async () => {
    const userId = session?.user.id;
    if (!userId || openIds.length === 0) return;
    setAcking(true);
    try {
      const updated = await acknowledgeAlerts(supabase, openIds, userId);
      const byId = new Map(updated.map((a) => [a.id, a]));
      setAlerts((prev) => prev.map((a) => byId.get(a.id) ?? a));
    } catch (err) {
      setError(friendlyError(err, "acknowledge alerts"));
    } finally {
      setAcking(false);
    }
  };

  if (loading) return <CardSkeleton lines={5} />;
  if (error)
    return (
      <p role="alert" className="rounded-md bg-[#DC2626] px-4 py-3 text-sm font-semibold text-white shadow-sm">
        {error}
      </p>
    );

  return (
    <div className="flex flex-col gap-6">
      {/* Header Section */}
      <div className="flex flex-wrap items-center justify-between gap-4 border-b border-hairline pb-4">
        <div>
          <div className="flex items-center gap-2.5">
            <h1 className="m-0 text-2xl font-extrabold text-ink tracking-tight">Alerts Queue</h1>
            {counts.totalOpen > 0 && (
              <span className="inline-flex items-center rounded-full bg-[#DC2626] px-2.5 py-0.5 text-xs font-bold text-white shadow-xs">
                {counts.totalOpen} Active
              </span>
            )}
          </div>
          <p className="m-0 mt-1 text-xs text-ink-muted">
            Live clinical telemetry triage &amp; hardware monitoring
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          {openIds.length > 1 && (
            <Button
              size="sm"
              variant="secondary"
              disabled={acking}
              onClick={acknowledgeAllOpen}
              className="font-bold shadow-xs"
            >
              <CheckCheck size={14} className="text-emerald-600" />
              <span>{acking ? "Acknowledging…" : `Acknowledge All (${openIds.length})`}</span>
            </Button>
          )}

          <label className="inline-flex items-center gap-2 text-xs font-semibold text-ink-muted cursor-pointer select-none bg-surface-alt px-3 py-1.5 rounded-lg border border-hairline">
            <input
              type="checkbox"
              className="accent-[#0088D6] rounded"
              checked={showAll}
              onChange={(e) => setShowAll(e.target.checked)}
            />
            <span>Include history</span>
          </label>
        </div>
      </div>

      {/* Filter Tabs matching Alert 27 color categories */}
      <div className="flex flex-wrap items-center gap-2">
        <button
          type="button"
          onClick={() => setTypeFilter("all")}
          className={cn(
            "inline-flex items-center gap-1.5 rounded-lg px-3.5 py-2 text-xs font-bold transition-all border cursor-pointer",
            typeFilter === "all"
              ? "bg-ink text-white border-ink shadow-xs"
              : "bg-surface text-ink-muted border-hairline hover:bg-surface-alt hover:text-ink",
          )}
        >
          <span>All Alerts</span>
          <span className={cn("rounded-full px-1.5 py-0.2 text-[10px] font-extrabold", typeFilter === "all" ? "bg-white/20 text-white" : "bg-surface-alt text-ink-muted")}>
            {showAll ? counts.total : counts.totalOpen}
          </span>
        </button>

        <button
          type="button"
          onClick={() => setTypeFilter("critical")}
          className={cn(
            "inline-flex items-center gap-1.5 rounded-lg px-3.5 py-2 text-xs font-bold transition-all border cursor-pointer",
            typeFilter === "critical"
              ? "bg-[#DC2626] text-white border-[#DC2626] shadow-xs"
              : "bg-surface text-ink-muted border-hairline hover:bg-red-50 hover:text-[#DC2626]",
          )}
        >
          <AlertTriangle size={13} className={typeFilter === "critical" ? "text-white" : "text-[#DC2626]"} />
          <span>Critical</span>
          {counts.critical > 0 && (
            <span className="rounded-full bg-white/20 px-1.5 py-0.2 text-[10px] font-extrabold text-white">
              {counts.critical}
            </span>
          )}
        </button>

        <button
          type="button"
          onClick={() => setTypeFilter("stress")}
          className={cn(
            "inline-flex items-center gap-1.5 rounded-lg px-3.5 py-2 text-xs font-bold transition-all border cursor-pointer",
            typeFilter === "stress"
              ? "bg-[#E65100] text-white border-[#E65100] shadow-xs"
              : "bg-surface text-ink-muted border-hairline hover:bg-orange-50 hover:text-[#E65100]",
          )}
        >
          <AlertCircle size={13} className={typeFilter === "stress" ? "text-white" : "text-[#E65100]"} />
          <span>Stress Alerts</span>
          {counts.stress > 0 && (
            <span className="rounded-full bg-white/20 px-1.5 py-0.2 text-[10px] font-extrabold text-white">
              {counts.stress}
            </span>
          )}
        </button>

        <button
          type="button"
          onClick={() => setTypeFilter("device_offline")}
          className={cn(
            "inline-flex items-center gap-1.5 rounded-lg px-3.5 py-2 text-xs font-bold transition-all border cursor-pointer",
            typeFilter === "device_offline"
              ? "bg-[#0088D6] text-white border-[#0088D6] shadow-xs"
              : "bg-surface text-ink-muted border-hairline hover:bg-sky-50 hover:text-[#0088D6]",
          )}
        >
          <Radio size={13} className={typeFilter === "device_offline" ? "text-white" : "text-[#0088D6]"} />
          <span>Device Offline</span>
          {counts.offline > 0 && (
            <span className="rounded-full bg-white/20 px-1.5 py-0.2 text-[10px] font-extrabold text-white">
              {counts.offline}
            </span>
          )}
        </button>
      </div>

      {/* Main Alert List Container */}
      <div className="ff-enter-list flex flex-col gap-3">
        {sorted.length === 0 ? (
          <Card className="border-dashed border-2 border-hairline">
            <CardContent className="p-8">
              <EmptyState>
                No {showAll ? "" : "open "}alerts — all patient vitals and devices are operating normally 🐾
              </EmptyState>
            </CardContent>
          </Card>
        ) : (
          sorted.map((a) => (
            <AlertCard
              key={a.id}
              alert={a}
              dogName={dogNames.get(a.dog_id)}
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
      </div>
    </div>
  );
}
