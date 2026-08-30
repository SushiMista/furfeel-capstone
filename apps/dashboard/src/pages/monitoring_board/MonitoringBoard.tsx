import { useCallback, useEffect, useMemo, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Filter, LayoutGrid, RotateCcw, Rows3, Search, SlidersHorizontal } from "lucide-react";
import { friendlyError } from "../../lib/errors.ts";
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
type BoardGroupKey = "none" | "owner" | "clinic" | "ward" | "admission";

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
  const navigate = useNavigate();
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
    return saved === "owner" || saved === "clinic" || saved === "ward" || saved === "admission" ? (saved as BoardGroupKey) : "none";
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
          (r.dog.ward_location ?? "").toLowerCase().includes(q) ||
          (r.dog.admission_status ?? "").toLowerCase().includes(q) ||
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
      const key =
        groupBy === "owner"
          ? (r.ownerName ?? "Unknown Owner")
          : groupBy === "clinic"
            ? (r.clinicName ?? "Unassigned Clinic")
            : groupBy === "ward"
              ? (r.dog.ward_location ?? "General Ward / Unassigned")
              : (r.dog.admission_status ? r.dog.admission_status.replace(/_/g, " ").toUpperCase() : "OUTPATIENT");
      const list = map.get(key) ?? [];
      list.push(r);
      map.set(key, list);
    }
    return Array.from(map.entries());
  }, [visible, groupBy]);

  const filterCounts = useMemo(() => {
    return {
      all: rows.length,
      attention: rows.filter(
        (r) =>
          (r.latestClassification && r.latestClassification.stress_level !== "calm") ||
          r.device?.status === "offline" ||
          r.openAlertCount > 0,
      ).length,
      offline: rows.filter((r) => r.device?.status === "offline").length,
      moderate: rows.filter((r) => r.latestClassification?.stress_level === "moderate").length,
      high: rows.filter((r) => r.latestClassification?.stress_level === "high").length,
    };
  }, [rows]);

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
              <Tr
                key={row.dog.id}
                onClick={(e) => {
                  if ((e.target as HTMLElement).closest("button, input, a")) return;
                  navigate(`/dogs/${row.dog.id}`);
                }}
                className={cn(
                  "group relative cursor-pointer transition-all duration-200",
                  "hover:bg-brand-soft/60 hover:shadow-xs active:bg-brand-soft/80 active:scale-[0.998]",
                  level ? ROW_TINT[level] : undefined,
                )}
              >
                <Td className="relative pl-4">
                  {/* Glowing left accent border bar on row hover */}
                  <span
                    className="absolute left-0 top-1 bottom-1 w-1.5 rounded-r-md bg-brand opacity-0 transition-opacity duration-200 group-hover:opacity-100"
                    aria-hidden="true"
                  />
                  <Link
                    to={`/dogs/${row.dog.id}`}
                    className="font-bold text-ink transition-colors group-hover:text-brand-strong"
                  >
                    {row.dog.name}
                  </Link>
                  {row.dog.breed && (
                    <div className="text-xs text-ink-muted group-hover:text-ink/80">{row.dog.breed}</div>
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
    <div className="flex flex-col gap-6 lg:flex-row lg:items-start w-full">
      {/* Left Division Box: Board Controls & Filters (Sticky on scroll at top) */}
      <Card className="w-full shrink-0 p-4 lg:w-64 xl:w-72 lg:sticky lg:top-6 z-10 self-start shadow-sm">
        <div className="flex flex-col gap-4">
          <div className="flex items-center justify-between border-b border-hairline pb-3">
            <div className="flex items-center gap-2">
              <SlidersHorizontal size={18} className="text-brand" />
              <h2 className="m-0 text-sm font-bold text-ink">Board Controls</h2>
            </div>
            {(search.trim() !== "" || filter !== "all" || sortBy !== "stress" || groupBy !== "none") && (
              <button
                type="button"
                onClick={() => {
                  setSearch("");
                  switchFilter("all");
                  switchSort("stress");
                  switchGroup("none");
                }}
                className="flex items-center gap-1 text-[11px] font-semibold text-brand hover:underline"
              >
                <RotateCcw size={12} />
                Reset
              </button>
            )}
          </div>

          {/* Quick Search Input */}
          <div className="flex flex-col gap-1.5">
            <label htmlFor="board-search" className="text-xs font-semibold text-ink-muted">
              Search
            </label>
            <div className="relative">
              <Search
                size={14}
                className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-muted"
              />
              <Input
                id="board-search"
                className="h-9 w-full pl-8 text-xs bg-surface"
                placeholder="Search dogs, owners, clinics…"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                aria-label="Search dogs"
              />
            </div>
          </div>

          {/* Display View Switcher */}
          <div className="flex flex-col gap-1.5">
            <span className="text-xs font-semibold text-ink-muted">Display View</span>
            <div
              className="grid grid-cols-2 gap-1 rounded-md bg-surface-alt p-1 border border-hairline"
              role="group"
              aria-label="Board view"
            >
              <Button
                variant={view === "grid" ? "secondary" : "ghost"}
                size="sm"
                className="h-8 text-xs font-semibold"
                aria-pressed={view === "grid"}
                onClick={() => switchView("grid")}
              >
                <LayoutGrid size={14} aria-hidden="true" />
                Cards
              </Button>
              <Button
                variant={view === "table" ? "secondary" : "ghost"}
                size="sm"
                className="h-8 text-xs font-semibold"
                aria-pressed={view === "table"}
                onClick={() => switchView("table")}
              >
                <Rows3 size={14} aria-hidden="true" />
                Table
              </Button>
            </div>
          </div>

          {/* Sort Selector */}
          <div className="flex flex-col gap-1.5">
            <label htmlFor="board-sort" className="text-xs font-semibold text-ink-muted">
              Sort By
            </label>
            <Select
              id="board-sort"
              aria-label="Sort board by"
              className="h-9 w-full text-xs font-medium bg-surface"
              value={sortBy}
              onChange={(e) => switchSort(e.target.value as BoardSortKey)}
            >
              <option value="stress">Stress Level (Worst first)</option>
              <option value="name">Dog Name (A-Z)</option>
              <option value="owner">Owner Name (A-Z)</option>
              <option value="clinic">Clinic Name (A-Z)</option>
            </Select>
          </div>

          {/* Group Selector */}
          <div className="flex flex-col gap-1.5">
            <label htmlFor="board-group" className="text-xs font-semibold text-ink-muted">
              Group By
            </label>
            <Select
              id="board-group"
              aria-label="Group board by"
              className="h-9 w-full text-xs font-medium bg-surface"
              value={groupBy}
              onChange={(e) => switchGroup(e.target.value as BoardGroupKey)}
            >
              <option value="none">No Grouping</option>
              <option value="ward">Hospital Ward / Cage</option>
              <option value="admission">Admission Stage</option>
              <option value="owner">Owner</option>
              <option value="clinic">Clinic</option>
            </Select>
          </div>

          {/* Quick Filter Status Badges */}
          <div className="flex flex-col gap-1.5 pt-1">
            <div className="flex items-center justify-between text-xs font-semibold text-ink-muted">
              <span>Filter Status</span>
              <Filter size={12} />
            </div>
            <div className="flex flex-col gap-1">
              {BOARD_FILTERS.map((f) => {
                const count = filterCounts[f.id];
                const active = filter === f.id;
                return (
                  <button
                    key={f.id}
                    type="button"
                    aria-pressed={active}
                    onClick={() => switchFilter(f.id)}
                    className={cn(
                      "flex items-center justify-between rounded-md px-3 py-2 text-xs font-medium transition-colors duration-fast text-left",
                      active
                        ? "bg-brand-soft text-brand-strong font-semibold border border-brand/30"
                        : "bg-surface text-ink-muted hover:bg-surface-alt border border-hairline",
                    )}
                  >
                    <span>{f.label}</span>
                    <span
                      className={cn(
                        "rounded-full px-2 py-0.5 text-[10px] font-bold",
                        active ? "bg-brand text-white" : "bg-surface-alt text-ink-muted",
                      )}
                    >
                      {count}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      </Card>

      {/* Right Main Board Content Division */}
      <div className="flex-1 w-full min-w-0 flex flex-col gap-5">
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-hairline pb-3">
          <div>
            <h1 className="m-0 text-2xl font-bold text-ink">Monitoring board</h1>
            <p className="m-0 mt-0.5 text-xs text-ink-muted">
              Showing {visible.length} of {rows.length} dogs live
            </p>
          </div>
        </div>

        {/* Board Cards or Table Rendering */}
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
                  <div className="ff-enter-list grid gap-4 grid-cols-1 xl:grid-cols-2">
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
          <div className="ff-enter-list grid gap-4 grid-cols-1 xl:grid-cols-2">
            {visible.map((row) => (
              <DogCard key={row.dog.id} row={row} onPhotoChanged={refreshDog} />
            ))}
          </div>
        ) : (
          /* Ungrouped Table View */
          renderTableRows(visible)
        )}
      </div>
    </div>
  );
}
