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
import { formatPosture } from "../../lib/posture.ts";
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
            <Th>Posture</Th>
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
                <Td>
                  {row.latestReading?.posture ? (
                    <span
                      className={cn(
                        "inline-flex items-center rounded-md px-2 py-0.5 text-[11px] font-semibold border",
                        formatPosture(row.latestReading.posture).badge,
                      )}
                    >
                      {formatPosture(row.latestReading.posture).label}
                    </span>
                  ) : (
                    <span className="text-ink-muted text-xs">—</span>
                  )}
                </Td>
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
    <div className="flex flex-col gap-5 w-full">
      {/* Top Header Row */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <div className="flex items-center gap-2.5">
            <h1 className="m-0 text-2xl font-black text-ink tracking-tight">Monitoring Board</h1>
            <span className="flex h-2.5 w-2.5 relative">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-calm-fg opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-calm-fg"></span>
            </span>
            <Badge variant="neutral" className="text-xs font-semibold">
              {visible.length} of {rows.length} live
            </Badge>
          </div>
          <p className="text-xs text-ink-muted mt-1 m-0">
            Real-time canine biometric telemetry & autonomic stress surveillance.
          </p>
        </div>

        {/* View Switcher & Reset */}
        <div className="flex items-center gap-2.5">
          {(search.trim() !== "" || filter !== "all" || sortBy !== "stress" || groupBy !== "none") && (
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setSearch("");
                switchFilter("all");
                switchSort("stress");
                switchGroup("none");
              }}
              className="text-xs font-semibold text-ink-muted hover:text-brand flex items-center gap-1.5 h-9"
            >
              <RotateCcw size={13} />
              <span>Reset Filters</span>
            </Button>
          )}

          <div className="flex items-center rounded-xl bg-surface-alt p-1 border border-hairline shadow-xs">
            <Button
              variant={view === "grid" ? "secondary" : "ghost"}
              size="sm"
              className="h-7 text-xs font-bold gap-1 px-3"
              aria-pressed={view === "grid"}
              onClick={() => switchView("grid")}
            >
              <LayoutGrid size={13} />
              <span>Cards</span>
            </Button>
            <Button
              variant={view === "table" ? "secondary" : "ghost"}
              size="sm"
              className="h-7 text-xs font-bold gap-1 px-3"
              aria-pressed={view === "table"}
              onClick={() => switchView("table")}
            >
              <Rows3 size={13} />
              <span>Table</span>
            </Button>
          </div>
        </div>
      </div>

      {/* Top Search & Sorting Control Bar */}
      <Card className="border-hairline shadow-xs p-3.5 bg-surface">
        <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-3">
          {/* Top Search Bar (Left & Center) */}
          <div className="relative flex-1">
            <Search
              size={15}
              className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-muted"
            />
            <Input
              id="board-search"
              className="h-10 w-full pl-10 text-xs bg-surface-alt/40 border-hairline font-medium focus:bg-surface"
              placeholder="Search patient dog, breed, owner, ward, clinic…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              aria-label="Search dogs"
            />
          </div>

          {/* Top Sorting & Grouping Section (Right) */}
          <div className="flex flex-wrap sm:flex-nowrap items-center gap-2.5">
            <div className="flex items-center gap-1.5 w-full sm:w-auto">
              <span className="text-xs font-bold text-ink-muted shrink-0">Sort:</span>
              <Select
                id="board-sort"
                aria-label="Sort board by"
                className="h-10 text-xs font-bold bg-surface-alt/40 border-hairline min-w-[180px]"
                value={sortBy}
                onChange={(e) => switchSort(e.target.value as BoardSortKey)}
              >
                <option value="stress">Stress Level (Worst first)</option>
                <option value="name">Patient Name (A-Z)</option>
                <option value="owner">Owner Name (A-Z)</option>
                <option value="clinic">Clinic Name (A-Z)</option>
              </Select>
            </div>

            <div className="flex items-center gap-1.5 w-full sm:w-auto">
              <span className="text-xs font-bold text-ink-muted shrink-0">Group:</span>
              <Select
                id="board-group"
                aria-label="Group board by"
                className="h-10 text-xs font-bold bg-surface-alt/40 border-hairline min-w-[150px]"
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
          </div>
        </div>

        {/* Filter Status Chips Row */}
        <div className="flex flex-wrap items-center gap-1.5 pt-3 mt-3 border-t border-hairline/70">
          <span className="text-[11px] font-bold text-ink-muted uppercase tracking-wider mr-1">Status:</span>
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
                  "inline-flex items-center gap-1.5 rounded-lg px-2.5 py-1 text-xs font-semibold transition-all",
                  active
                    ? "bg-brand text-white shadow-xs font-bold"
                    : "bg-surface-alt/60 text-ink-muted hover:text-ink hover:bg-surface-alt border border-hairline",
                )}
              >
                <span>{f.label}</span>
                <span
                  className={cn(
                    "rounded-full px-1.5 py-0.2 text-[10px] font-black",
                    active ? "bg-white/20 text-white" : "bg-surface text-ink-muted",
                  )}
                >
                  {count}
                </span>
              </button>
            );
          })}
        </div>
      </Card>

      {/* Main Board Content (Full Width) */}
      <div className="w-full min-w-0 flex flex-col gap-4">
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
          /* Grouped View */
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
                  <div className="ff-enter-list grid gap-4 grid-cols-1 md:grid-cols-2 xl:grid-cols-3">
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
          /* Ungrouped Cards View: Full Width 1 / 2 / 3 Column Grid */
          <div className="ff-enter-list grid gap-4 grid-cols-1 md:grid-cols-2 xl:grid-cols-3">
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
