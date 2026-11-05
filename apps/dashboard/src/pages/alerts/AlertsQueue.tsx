import { friendlyError } from "../../lib/errors.ts";
import { useCallback, useEffect, useMemo, useState } from "react";
import { CheckCheck, Volume2, VolumeX } from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import { acknowledgeAlerts, fetchAlertsQueue, fetchDogs } from "../../lib/queries.ts";
import { COLLAR_ALERT_TYPES, groupAlerts } from "../../lib/alertCopy.ts";
import { useAuth } from "../../lib/useAuth.ts";
import { playAlertChime } from "../../lib/sound.ts";
import { AlertCard } from "../../components/AlertCard.tsx";
import { Button } from "../../components/ui/button.tsx";
import { Card, CardContent } from "../../components/ui/card.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import { cn } from "../../lib/cn.ts";
import type { Alert, Dog } from "../../../../../packages/shared/types/index.ts";

const SEVERITY_RANK: Record<string, number> = { critical: 0, warning: 1, info: 2 };

type TypeFilter = "all" | "stress" | "collar";

/** Alerts queue (docs/05): every RLS-visible alert across the clinic's dogs, open
 * first for fast triage, live via Realtime with audio chime and multi-vet synchronization. */
export function AlertsQueue() {
  const { session } = useAuth();
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [dogs, setDogs] = useState<Dog[]>([]);
  const [showAll, setShowAll] = useState(false);
  const [soundEnabled, setSoundEnabled] = useState<boolean>(() => {
    return localStorage.getItem("furfeel:alert-sound") !== "false";
  });
  const [typeFilter, setTypeFilter] = useState<TypeFilter>("all");
  const [loading, setLoading] = useState(true);
  const [acking, setAcking] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const toggleSound = () => {
    setSoundEnabled((prev) => {
      const next = !prev;
      localStorage.setItem("furfeel:alert-sound", String(next));
      if (next) playAlertChime();
      return next;
    });
  };

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

  // Full bi-directional Realtime Sync (INSERT, UPDATE, DELETE)
  useEffect(() => {
    const channel = supabase
      .channel("alerts-queue-live-channel")
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "alerts" },
        (payload) => {
          const row = payload.new as Alert;
          setAlerts((prev) => (prev.some((a) => a.id === row.id) ? prev : [row, ...prev]));
          if (soundEnabled && row.severity === "critical" && row.status === "open") {
            playAlertChime();
          }
        },
      )
      .on(
        "postgres_changes",
        { event: "UPDATE", schema: "public", table: "alerts" },
        (payload) => {
          const row = payload.new as Alert;
          setAlerts((prev) => prev.map((a) => (a.id === row.id ? row : a)));
        },
      )
      .on(
        "postgres_changes",
        { event: "DELETE", schema: "public", table: "alerts" },
        (payload) => {
          const old = payload.old as { id?: string };
          if (old?.id) {
            setAlerts((prev) => prev.filter((a) => a.id !== old.id));
          }
        },
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [soundEnabled]);

  const dogNames = useMemo(() => new Map(dogs.map((d) => [d.id, d.name])), [dogs]);

  const isCollar = (a: Alert) => COLLAR_ALERT_TYPES.includes(a.type);

  // Counts for filter pills
  const counts = useMemo(() => {
    const open = alerts.filter((a) => a.status === "open");
    return {
      all: open.length,
      stress: open.filter((a) => !isCollar(a)).length,
      collar: open.filter(isCollar).length,
    };
  }, [alerts]);

  const filtered = useMemo(() => {
    if (typeFilter === "stress") return alerts.filter((a) => !isCollar(a));
    if (typeFilter === "collar") return alerts.filter(isCollar);
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

  const groups = useMemo(() => groupAlerts(sorted), [sorted]);

  const openIds = useMemo(
    () => sorted.filter((a) => a.status === "open").map((a) => a.id),
    [sorted],
  );

  const acknowledge = async (ids: string[]) => {
    const userId = session?.user.id;
    if (!userId || ids.length === 0) return;
    const updated = await acknowledgeAlerts(supabase, ids, userId);
    const byId = new Map(updated.map((a) => [a.id, a]));
    setAlerts((prev) => prev.map((a) => byId.get(a.id) ?? a));
  };

  const acknowledgeAllOpen = async () => {
    setAcking(true);
    try {
      await acknowledge(openIds);
    } catch (err) {
      setError(friendlyError(err, "acknowledge alerts"));
    } finally {
      setAcking(false);
    }
  };

  const chipClass = (active: boolean) =>
    cn(
      "inline-flex cursor-pointer items-center gap-1.5 rounded-full border px-3 py-1.5 text-xs font-semibold transition-colors",
      active
        ? "border-brand bg-brand text-white"
        : "border-hairline bg-surface text-ink-muted hover:bg-surface-alt hover:text-ink",
    );

  if (loading) return <CardSkeleton lines={5} />;
  if (error)
    return (
      <p role="alert" className="rounded-md bg-high-soft px-4 py-3 text-sm font-semibold text-high-fg">
        {error}
      </p>
    );

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="m-0 text-2xl font-bold text-ink">Alerts Queue</h1>

        <div className="flex flex-wrap items-center gap-2">
          <Button
            size="sm"
            variant="ghost"
            onClick={toggleSound}
            title={soundEnabled ? "Mute the alert sound" : "Turn on the alert sound"}
            className="gap-1.5"
          >
            {soundEnabled ? <Volume2 size={14} /> : <VolumeX size={14} />}
            {soundEnabled ? "Sound on" : "Sound off"}
          </Button>

          {openIds.length > 1 && (
            <Button
              size="sm"
              variant="secondary"
              disabled={acking}
              onClick={acknowledgeAllOpen}
              className="gap-1.5"
            >
              <CheckCheck size={14} />
              {acking ? "Acknowledging…" : `Acknowledge all (${openIds.length})`}
            </Button>
          )}
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        {(
          [
            ["all", "Open", counts.all],
            ["stress", "Stress", counts.stress],
            ["collar", "Collar", counts.collar],
          ] as const
        ).map(([id, label, count]) => (
          <button
            key={id}
            type="button"
            aria-pressed={typeFilter === id}
            onClick={() => setTypeFilter(id)}
            className={chipClass(typeFilter === id)}
          >
            {label} {count}
          </button>
        ))}
        <button
          type="button"
          aria-pressed={showAll}
          onClick={() => setShowAll((value) => !value)}
          className={chipClass(showAll)}
        >
          History
        </button>
      </div>

      <div className="ff-enter-list flex flex-col">
        {groups.length === 0 ? (
          <Card className="border-dashed border-2 border-hairline">
            <CardContent className="p-8">
              <EmptyState>
                No {showAll ? "" : "open "}alerts — all patient vitals and devices are operating normally 🐾
              </EmptyState>
            </CardContent>
          </Card>
        ) : (
          groups.map(({ latest, earlier }) => (
            <AlertCard
              key={latest.id}
              alert={latest}
              earlier={earlier}
              dogName={dogNames.get(latest.dog_id)}
              onAcknowledge={() =>
                acknowledge([latest, ...earlier].filter((a) => a.status === "open").map((a) => a.id))
              }
            />
          ))
        )}
      </div>
    </div>
  );
}
