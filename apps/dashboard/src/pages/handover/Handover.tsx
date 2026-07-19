import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { Printer } from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import { fetchAlertsQueue, fetchMonitoringBoard, type MonitoringBoardRow } from "../../lib/queries.ts";
import { StressLevelBadge } from "../../components/StressLevelBadge.tsx";
import { Button } from "../../components/ui/button.tsx";
import { Card, CardContent } from "../../components/ui/card.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import type { Alert } from "../../../../../packages/shared/types/index.ts";

// ADDED (step 17): shift handover — one printable page answering "what
// happened while I was away, and who needs eyes first?". Reuses the board
// row fetch + the alerts queue; window is a UI choice, not stored state.
const WINDOWS = [
  { hours: 8, label: "Last 8 h" },
  { hours: 12, label: "Last 12 h" },
  { hours: 24, label: "Last 24 h" },
] as const;

const LEVEL_RANK: Record<string, number> = { high: 0, moderate: 1, mild: 2, calm: 3 };

function fmtTime(iso: string): string {
  const d = new Date(iso);
  return `${d.getHours().toString().padStart(2, "0")}:${d.getMinutes().toString().padStart(2, "0")}`;
}

export function Handover() {
  const [rows, setRows] = useState<MonitoringBoardRow[]>([]);
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [hours, setHours] = useState<number>(12);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    Promise.all([fetchMonitoringBoard(supabase), fetchAlertsQueue(supabase, "all", 500)])
      .then(([board, queue]) => {
        setRows(board);
        setAlerts(queue);
        setError(null);
      })
      .catch((err) => setError(err instanceof Error ? err.message : "Failed to load handover"))
      .finally(() => setLoading(false));
  }, []);

  const since = useMemo(() => new Date(Date.now() - hours * 3600_000), [hours]);

  const perDog = useMemo(() => {
    const windowAlerts = alerts.filter((a) => new Date(a.created_at) >= since);
    const byDog = new Map<string, Alert[]>();
    for (const a of windowAlerts) {
      byDog.set(a.dog_id, [...(byDog.get(a.dog_id) ?? []), a]);
    }
    // Dogs with events first (worst stress first), quiet dogs after.
    return [...rows].sort((a, b) => {
      const evDiff =
        (byDog.get(b.dog.id)?.length ?? 0) - (byDog.get(a.dog.id)?.length ?? 0);
      if (evDiff !== 0) return evDiff;
      return (
        (LEVEL_RANK[a.latestClassification?.stress_level ?? "calm"] ?? 3) -
        (LEVEL_RANK[b.latestClassification?.stress_level ?? "calm"] ?? 3)
      );
    }).map((row) => ({ row, events: byDog.get(row.dog.id) ?? [] }));
  }, [rows, alerts, since]);

  if (loading) return <CardSkeleton lines={6} />;
  if (error)
    return (
      <p role="alert" className="rounded-sm bg-high-soft px-3 py-2 text-sm text-high-fg">
        {error}
      </p>
    );

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-center justify-between gap-3 print-hidden">
        <h1 className="m-0 text-2xl font-bold text-ink">Shift handover</h1>
        <div className="flex items-center gap-2">
          {WINDOWS.map((w) => (
            <Button
              key={w.hours}
              size="sm"
              variant={hours === w.hours ? "secondary" : "ghost"}
              aria-pressed={hours === w.hours}
              onClick={() => setHours(w.hours)}
            >
              {w.label}
            </Button>
          ))}
          <Button variant="secondary" onClick={() => window.print()}>
            <Printer size={14} /> Print / save PDF
          </Button>
        </div>
      </div>

      <Card className="print-plain">
        <CardContent className="flex flex-col gap-4 p-5">
          <p className="m-0 text-sm text-ink-muted">
            Events since {since.toLocaleString()} · {rows.length} dogs monitored ·
            decision support, not a diagnosis.
          </p>
          {perDog.length === 0 ? (
            <EmptyState>No dogs on the board yet 🐾</EmptyState>
          ) : (
            perDog.map(({ row, events }) => (
              <div
                key={row.dog.id}
                className="rounded-md border border-hairline p-4 print-avoid-break"
              >
                <div className="flex flex-wrap items-center gap-3">
                  <Link
                    to={`/dogs/${row.dog.id}`}
                    className="text-sm font-semibold text-ink hover:text-brand-strong"
                  >
                    {row.dog.name}
                  </Link>
                  {row.latestClassification && (
                    <StressLevelBadge level={row.latestClassification.stress_level} />
                  )}
                  <span className="text-xs text-ink-muted">
                    harness {row.device?.status ?? "unassigned"}
                    {row.openAlertCount > 0 && ` · ${row.openAlertCount} open alert(s)`}
                  </span>
                </div>
                {events.length === 0 ? (
                  <p className="m-0 mt-2 text-xs text-ink-muted">
                    Quiet shift — no alerts in this window.
                  </p>
                ) : (
                  <ul className="m-0 mt-2 list-none p-0">
                    {events.map((a) => (
                      <li key={a.id} className="mt-1 text-xs text-ink">
                        <span className="font-semibold">{fmtTime(a.created_at)}</span>{" "}
                        {a.message}
                        {a.status !== "open" && (
                          <span className="text-ink-muted"> (handled)</span>
                        )}
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            ))
          )}
        </CardContent>
      </Card>
    </div>
  );
}
