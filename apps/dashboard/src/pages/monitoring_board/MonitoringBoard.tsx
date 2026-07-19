import { useCallback, useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { LayoutGrid, Rows3, Search } from "lucide-react";
import { timed } from "../../lib/perf.ts";
import { supabase } from "../../lib/supabaseClient.ts";
import {
  fetchMonitoringBoard,
  fetchMonitoringBoardRowForDog,
  sortBoardRows,
  type MonitoringBoardRow,
} from "../../lib/queries.ts";
import { useRealtimeInsert } from "../../lib/useRealtimeInsert.ts";
import { DogCard } from "../../components/DogCard.tsx";
import { StressLevelBadge } from "../../components/StressLevelBadge.tsx";
import { Card } from "../../components/ui/card.tsx";
import { Button } from "../../components/ui/button.tsx";
import { Input } from "../../components/ui/input.tsx";
import { Table, TBody, Td, Th, THead, Tr } from "../../components/ui/table.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import { cn } from "../../lib/cn.ts";
import type {
  Alert,
  StressClassification,
  StressLevel,
  TelemetryReading,
} from "../../../../../packages/shared/types/index.ts";

const ROW_TINT: Record<StressLevel, string> = {
  calm: "",
  mild: "bg-mild-soft",
  moderate: "bg-moderate-soft",
  high: "bg-high-soft",
};

/** Device connectivity dot (docs/05 board: "device status (online dot)"). */
function DeviceStatus({ status }: { status: string | undefined }) {
  const online = status === "active";
  const offline = status === "offline";
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 text-xs font-medium",
        online ? "text-calm-fg" : offline ? "text-high-fg" : "text-ink-muted",
      )}
    >
      <span
        className={cn(
          "h-2 w-2 rounded-pill",
          online ? "bg-calm-fg" : offline ? "bg-high-fg" : "bg-hairline",
        )}
        aria-hidden="true"
      />
      {status ?? "unassigned"}
    </span>
  );
}

// ADDED (docs/05): card grid is the default board view; the compact table
// stays one click away and the choice sticks per browser.
type BoardView = "grid" | "table";
const VIEW_KEY = "furfeel:board-view";

/** Multi-dog live board (docs/05 module 1): stress-sorted, Realtime, filterable. */
export function MonitoringBoard() {
  const [rows, setRows] = useState<MonitoringBoardRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<"all" | "attention">("all");
  const [search, setSearch] = useState("");
  const [view, setView] = useState<BoardView>(() =>
    localStorage.getItem(VIEW_KEY) === "table" ? "table" : "grid",
  );

  const switchView = (next: BoardView) => {
    setView(next);
    localStorage.setItem(VIEW_KEY, next);
  };

  const load = useCallback(async () => {
    try {
      const board = await timed("board_load", () => fetchMonitoringBoard(supabase));
      setRows(board);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load dogs");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const refreshDog = useCallback((dogId: string) => {
    setRows((prev) => {
      const dog = prev.find((r) => r.dog.id === dogId)?.dog;
      if (dog) {
        fetchMonitoringBoardRowForDog(supabase, dog).then((updated) => {
          setRows((current) => current.map((r) => (r.dog.id === dogId ? updated : r)));
        });
      } else {
        // ADDED: a dog newly linked to this clinic (Pet Creation / Device Pairing on
        // mobile) won't be in `prev` — reload the whole board so it appears live.
        load();
      }
      return prev;
    });
  }, [load]);

  useRealtimeInsert<TelemetryReading>("telemetry_readings", (row) => refreshDog(row.dog_id));
  useRealtimeInsert<StressClassification>("stress_classifications", (row) => refreshDog(row.dog_id));
  useRealtimeInsert<Alert>("alerts", (row) => refreshDog(row.dog_id));

  const visible = useMemo(() => {
    let filtered = sortBoardRows(rows);
    if (filter === "attention") {
      filtered = filtered.filter(
        (r) =>
          (r.latestClassification && r.latestClassification.stress_level !== "calm") ||
          r.device?.status === "offline" ||
          r.openAlertCount > 0,
      );
    }
    const q = search.trim().toLowerCase();
    if (q) {
      filtered = filtered.filter(
        (r) => r.dog.name.toLowerCase().includes(q) || (r.dog.breed ?? "").toLowerCase().includes(q),
      );
    }
    return filtered;
  }, [rows, filter, search]);

  if (loading) return <CardSkeleton lines={6} />;
  if (error)
    return (
      <p role="alert" className="rounded-sm bg-high-soft px-3 py-2 text-sm text-high-fg">
        {error}
      </p>
    );

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="m-0 text-2xl font-bold text-ink">Monitoring board</h1>
        <div className="flex items-center gap-2">
          {/* ADDED: quick search across name/breed */}
          <div className="relative">
            <Search
              size={14}
              className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-muted"
            />
            <Input
              className="h-9 w-48 pl-8"
              placeholder="Search dogs…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              aria-label="Search dogs"
            />
          </div>
          <Button
            variant={filter === "all" ? "secondary" : "ghost"}
            size="sm"
            onClick={() => setFilter("all")}
          >
            All
          </Button>
          <Button
            variant={filter === "attention" ? "secondary" : "ghost"}
            size="sm"
            onClick={() => setFilter("attention")}
          >
            Needs attention
          </Button>
          {/* ADDED: grid ↔ compact table toggle (docs/05). */}
          <div
            className="ml-1 flex rounded-md border border-hairline"
            role="group"
            aria-label="Board view"
          >
            <Button
              variant={view === "grid" ? "secondary" : "ghost"}
              size="sm"
              className="rounded-r-none"
              aria-pressed={view === "grid"}
              onClick={() => switchView("grid")}
            >
              <LayoutGrid size={14} aria-hidden="true" />
              Cards
            </Button>
            <Button
              variant={view === "table" ? "secondary" : "ghost"}
              size="sm"
              className="rounded-l-none"
              aria-pressed={view === "table"}
              onClick={() => switchView("table")}
            >
              <Rows3 size={14} aria-hidden="true" />
              Table
            </Button>
          </div>
        </div>
      </div>

      {rows.length === 0 ? (
        <Card>
          <EmptyState>
            No dogs here yet — once a pup joins your clinic, they&apos;ll show up right here 🐾
          </EmptyState>
        </Card>
      ) : visible.length === 0 ? (
        <Card>
          <EmptyState>No dogs match — try clearing the search or filter 🐾</EmptyState>
        </Card>
      ) : view === "grid" ? (
        <div className="ff-enter-list grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {visible.map((row) => (
            <DogCard key={row.dog.id} row={row} onPhotoChanged={refreshDog} />
          ))}
        </div>
      ) : (
        <Card>
          <Table>
            <THead>
              <Tr className="border-t-0">
                <Th>Dog</Th>
                <Th>Device</Th>
                <Th>Stress level</Th>
                <Th className="text-right">HR (bpm)</Th>
                <Th className="text-right">Temp (°C)</Th>
                <Th className="text-right">RR (bpm)</Th>
                <Th className="text-right">Motion</Th>
                <Th>Last reading</Th>
                <Th className="text-right">Open alerts</Th>
              </Tr>
            </THead>
            <TBody>
              {visible.map((row) => {
                const level = row.latestClassification?.stress_level;
                return (
                  <Tr key={row.dog.id} className={level ? ROW_TINT[level] : undefined}>
                    <Td>
                      <Link
                        to={`/dogs/${row.dog.id}`}
                        className="font-semibold text-ink hover:text-brand-strong"
                      >
                        {row.dog.name}
                      </Link>
                      {row.dog.breed && (
                        <div className="text-xs text-ink-muted">{row.dog.breed}</div>
                      )}
                    </Td>
                    <Td>
                      <DeviceStatus status={row.device?.status} />
                    </Td>
                    <Td>
                      {level ? (
                        <StressLevelBadge level={level} className={level !== "calm" ? "bg-surface" : undefined} />
                      ) : (
                        <span className="text-ink-muted">—</span>
                      )}
                    </Td>
                    <Td className="text-right tabular-nums">{row.latestReading?.heart_rate_bpm ?? "—"}</Td>
                    <Td className="text-right tabular-nums">{row.latestReading?.body_temperature_c ?? "—"}</Td>
                    <Td className="text-right tabular-nums">{row.latestReading?.respiratory_rate_bpm ?? "—"}</Td>
                    <Td className="text-right tabular-nums">{row.latestReading?.motion_activity ?? "—"}</Td>
                    <Td className="text-xs text-ink-muted">
                      {row.latestReading
                        ? new Date(row.latestReading.captured_at).toLocaleString()
                        : "—"}
                    </Td>
                    <Td className="text-right">
                      {row.openAlertCount > 0 ? (
                        <span className="inline-flex h-6 min-w-6 items-center justify-center rounded-pill bg-high-soft px-2 text-xs font-bold text-high-fg">
                          {row.openAlertCount}
                        </span>
                      ) : (
                        <span className="text-ink-muted">0</span>
                      )}
                    </Td>
                  </Tr>
                );
              })}
            </TBody>
          </Table>
        </Card>
      )}
    </div>
  );
}
