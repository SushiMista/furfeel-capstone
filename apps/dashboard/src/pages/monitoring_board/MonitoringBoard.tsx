import { friendlyError } from "../../lib/errors.ts";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { LayoutGrid, Rows3, Search } from "lucide-react";
import { timed } from "../../lib/perf.ts";
import { supabase } from "../../lib/supabaseClient.ts";
import {
  fetchMonitoringBoard,
  fetchMonitoringBoardRowForDog,
  sortBoardRows,
  type BoardSortKey,
  type MonitoringBoardRow,
} from "../../lib/queries.ts";
import { useRealtimeInsert } from "../../lib/useRealtimeInsert.ts";
import { DogCard } from "../../components/DogCard.tsx";
import { StressLevelBadge } from "../../components/StressLevelBadge.tsx";
import { Card } from "../../components/ui/card.tsx";
import { Button } from "../../components/ui/button.tsx";
import { Input, Select } from "../../components/ui/input.tsx";
import { Badge } from "../../components/ui/badge.tsx";
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

type BoardView = "grid" | "table";
type BoardGroupKey = "none" | "owner" | "clinic";

const VIEW_KEY = "furfeel:board-view";
const FILTER_KEY = "furfeel:board-filter";
const SORT_KEY = "furfeel:board-sort";
const GROUP_KEY = "furfeel:board-group";

const BOARD_FILTERS = [
  { id: "all", label: "All" },
  { id: "attention", label: "Needs attention" },
  { id: "offline", label: "Offline devices" },
  { id: "moderate", label: "Moderate" },
  { id: "high", label: "High" },
] as const;
type BoardFilter = (typeof BOARD_FILTERS)[number]["id"];

/** Multi-dog live board (docs/05 module 1): stress-sorted, Realtime, filterable, sortable, groupable. */
export function MonitoringBoard() {
  const [rows, setRows] = useState<MonitoringBoardRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [filter, setFilter] = useState<BoardFilter>(() => {
    const saved = localStorage.getItem(FILTER_KEY);
    return BOARD_FILTERS.some((f) => f.id === saved) ? (saved as BoardFilter) : "all";
  });
  const switchFilter = (next: BoardFilter) => {
    setFilter(next);
    localStorage.setItem(FILTER_KEY, next);
  };

  const [sortBy, setSortBy] = useState<BoardSortKey>(() => {
    const saved = localStorage.getItem(SORT_KEY);
    return saved === "name" || saved === "owner" || saved === "clinic" ? (saved as BoardSortKey) : "stress";
  });
  const switchSort = (next: BoardSortKey) => {
    setSortBy(next);
    localStorage.setItem(SORT_KEY, next);
  };

  const [groupBy, setGroupBy] = useState<BoardGroupKey>(() => {
    const saved = localStorage.getItem(GROUP_KEY);
    return saved === "owner" || saved === "clinic" ? (saved as BoardGroupKey) : "none";
  });
  const switchGroup = (next: BoardGroupKey) => {
    setGroupBy(next);
    localStorage.setItem(GROUP_KEY, next);
  };

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
      setError(friendlyError(err, "load dogs"));
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
        load();
      }
      return prev;
    });
  }, [load]);

  useRealtimeInsert<TelemetryReading>("telemetry_readings", (row) => refreshDog(row.dog_id));
  useRealtimeInsert<StressClassification>("stress_classifications", (row) => refreshDog(row.dog_id));
  useRealtimeInsert<Alert>("alerts", (row) => refreshDog(row.dog_id));

  const visible = useMemo(() => {
    let filtered = sortBoardRows(rows, sortBy);
    if (filter === "attention") {
      filtered = filtered.filter(
        (r) =>
          (r.latestClassification && r.latestClassification.stress_level !== "calm") ||
          r.device?.status === "offline" ||
          r.openAlertCount > 0,
      );
    } else if (filter === "offline") {
      filtered = filtered.filter((r) => r.device?.status === "offline");
    } else if (filter === "moderate" || filter === "high") {
      filtered = filtered.filter(
        (r) => r.latestClassification?.stress_level === filter,
      );
    }
    const q = search.trim().toLowerCase();
    if (q) {
      filtered = filtered.filter(
        (r) =>
          r.dog.name.toLowerCase().includes(q) ||
          (r.dog.breed ?? "").toLowerCase().includes(q) ||
          (r.ownerName ?? "").toLowerCase().includes(q) ||
          (r.clinicName ?? "").toLowerCase().includes(q),
      );
    }
    return filtered;
  }, [rows, filter, search, sortBy]);

  const groupedSections = useMemo(() => {
    if (groupBy === "none") return null;
    const map = new Map<string, MonitoringBoardRow[]>();
    for (const r of visible) {
      const key = groupBy === "owner" ? (r.ownerName ?? "Unknown Owner") : (r.clinicName ?? "Unassigned Clinic");
      const list = map.get(key) ?? [];
      list.push(r);
      map.set(key, list);
    }
    return Array.from(map.entries());
  }, [visible, groupBy]);

  if (loading) return <CardSkeleton lines={6} />;
  if (error)
    return (
      <p role="alert" className="rounded-sm bg-high-soft px-3 py-2 text-sm text-high-fg">
        {error}
      </p>
    );

  const renderTableRows = (sectionRows: MonitoringBoardRow[]) => (
    <Card>
      <Table>
        <THead>
          <Tr className="border-t-0">
            <Th>Dog</Th>
            <Th>Owner / Clinic</Th>
            <Th>Device</Th>
            <Th>Stress level</Th>
            <Th className="text-right">HR (bpm)</Th>
            <Th className="text-right">RR (bpm)</Th>
            <Th className="text-right">Motion</Th>
            <Th>Last reading</Th>
            <Th className="text-right">Open alerts</Th>
          </Tr>
        </THead>
        <TBody>
          {sectionRows.map((row) => {
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
                <Td className="text-xs text-ink-muted">
                  <div>{row.ownerName ?? "—"}</div>
                  <div className="text-[10px] text-ink-muted/80">{row.clinicName ?? "—"}</div>
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
  );

  return (
    <div className="flex flex-col gap-5">
      {/* Top Toolbar */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="m-0 text-2xl font-bold text-ink">Monitoring board</h1>
        <div className="flex flex-wrap items-center gap-2">
          {/* Quick Search */}
          <div className="relative">
            <Search
              size={14}
              className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-muted"
            />
            <Input
              className="h-9 w-44 pl-8 text-xs"
              placeholder="Search dogs, owners, clinics…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              aria-label="Search dogs"
            />
          </div>

          {/* Minimal Sort Dropdown */}
          <div className="flex items-center gap-1">
            <span className="text-xs font-semibold text-ink-muted">Sort:</span>
            <Select
              aria-label="Sort board by"
              className="h-9 w-32 text-xs font-medium"
              value={sortBy}
              onChange={(e) => switchSort(e.target.value as BoardSortKey)}
            >
              <option value="stress">Stress Level</option>
              <option value="name">Dog Name</option>
              <option value="owner">Owner Name</option>
              <option value="clinic">Clinic</option>
            </Select>
          </div>

          {/* Minimal Group Dropdown */}
          <div className="flex items-center gap-1">
            <span className="text-xs font-semibold text-ink-muted">Group:</span>
            <Select
              aria-label="Group board by"
              className="h-9 w-32 text-xs font-medium"
              value={groupBy}
              onChange={(e) => switchGroup(e.target.value as BoardGroupKey)}
            >
              <option value="none">No Grouping</option>
              <option value="owner">Owner</option>
              <option value="clinic">Clinic</option>
            </Select>
          </div>

          {/* Quick Filters */}
          <div className="flex items-center gap-1">
            {BOARD_FILTERS.map((f) => (
              <Button
                key={f.id}
                variant={filter === f.id ? "secondary" : "ghost"}
                size="sm"
                className="text-xs"
                aria-pressed={filter === f.id}
                onClick={() => switchFilter(f.id)}
              >
                {f.label}
              </Button>
            ))}
          </div>

          {/* Grid / Table Toggle */}
          <div
            className="ml-1 flex rounded-md border border-hairline"
            role="group"
            aria-label="Board view"
          >
            <Button
              variant={view === "grid" ? "secondary" : "ghost"}
              size="sm"
              className="rounded-r-none text-xs"
              aria-pressed={view === "grid"}
              onClick={() => switchView("grid")}
            >
              <LayoutGrid size={14} aria-hidden="true" />
              Cards
            </Button>
            <Button
              variant={view === "table" ? "secondary" : "ghost"}
              size="sm"
              className="rounded-l-none text-xs"
              aria-pressed={view === "table"}
              onClick={() => switchView("table")}
            >
              <Rows3 size={14} aria-hidden="true" />
              Table
            </Button>
          </div>
        </div>
      </div>

      {/* Main Board Content */}
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
      ) : groupedSections ? (
        /* Grouped View (by Owner or Clinic) */
        <div className="flex flex-col gap-6">
          {groupedSections.map(([groupName, sectionRows]) => (
            <div key={groupName} className="flex flex-col gap-3">
              <div className="flex items-center gap-2 border-b border-hairline pb-2 pt-1">
                <span className="text-sm font-bold text-ink">
                  {groupBy === "owner" ? "Owner:" : "Clinic:"} {groupName}
                </span>
                <Badge variant="neutral" className="text-[11px] font-medium">
                  {sectionRows.length} {sectionRows.length === 1 ? "dog" : "dogs"}
                </Badge>
              </div>

              {view === "grid" ? (
                <div className="ff-enter-list grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
                  {sectionRows.map((row) => (
                    <DogCard key={row.dog.id} row={row} onPhotoChanged={refreshDog} />
                  ))}
                </div>
              ) : (
                renderTableRows(sectionRows)
              )}
            </div>
          ))}
        </div>
      ) : view === "grid" ? (
        /* Ungrouped Cards View */
        <div className="ff-enter-list grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {visible.map((row) => (
            <DogCard key={row.dog.id} row={row} onPhotoChanged={refreshDog} />
          ))}
        </div>
      ) : (
        /* Ungrouped Table View */
        renderTableRows(visible)
      )}
    </div>
  );
}
