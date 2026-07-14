import { useCallback, useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { supabase } from "../../lib/supabaseClient.ts";
import { acknowledgeAlert, fetchAlertsQueue, fetchDogs } from "../../lib/queries.ts";
import { useAuth } from "../../lib/useAuth.ts";
import { useRealtimeInsert } from "../../lib/useRealtimeInsert.ts";
import { AlertCard } from "../../components/AlertCard.tsx";
import { Card, CardContent } from "../../components/ui/card.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import type { Alert, Dog } from "../../../../../packages/shared/types/index.ts";

const SEVERITY_RANK: Record<string, number> = { critical: 0, warning: 1, info: 2 };

/** Alerts queue (docs/05): every RLS-visible alert across the clinic's dogs, open
 * first for fast triage, live via Realtime. */
export function AlertsQueue() {
  const { session } = useAuth();
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [dogs, setDogs] = useState<Dog[]>([]);
  const [showAll, setShowAll] = useState(false);
  const [loading, setLoading] = useState(true);
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
      setError(err instanceof Error ? err.message : "Failed to load alerts");
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

  const sorted = useMemo(
    () =>
      [...alerts].sort((a, b) => {
        const openDiff = Number(b.status === "open") - Number(a.status === "open");
        if (openDiff !== 0) return openDiff;
        const sevDiff = (SEVERITY_RANK[a.severity] ?? 9) - (SEVERITY_RANK[b.severity] ?? 9);
        if (sevDiff !== 0) return sevDiff;
        return b.created_at.localeCompare(a.created_at);
      }),
    [alerts],
  );

  if (loading) return <CardSkeleton lines={5} />;
  if (error)
    return (
      <p role="alert" className="rounded-sm bg-high-soft px-3 py-2 text-sm text-high-fg">
        {error}
      </p>
    );

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="m-0 text-2xl font-bold text-ink">Alerts queue</h1>
        <label className="inline-flex items-center gap-2 text-xs font-medium text-ink-muted">
          <input
            type="checkbox"
            className="accent-[--ff-brand]"
            checked={showAll}
            onChange={(e) => setShowAll(e.target.checked)}
          />
          Include acknowledged &amp; resolved
        </label>
      </div>
      <Card>
        <CardContent className="p-5">
          {sorted.length === 0 ? (
            <EmptyState>
              No {showAll ? "" : "open "}alerts — everyone&apos;s doing great 🐾
            </EmptyState>
          ) : (
            sorted.map((a) => (
              <div key={a.id} className="mb-4 last:mb-0">
                <Link
                  className="mb-1 inline-block text-sm font-semibold text-ink hover:text-brand-strong"
                  to={`/dogs/${a.dog_id}`}
                >
                  {dogNames.get(a.dog_id) ?? "Unknown dog"}
                </Link>
                <AlertCard
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
              </div>
            ))
          )}
        </CardContent>
      </Card>
    </div>
  );
}
