// A month of a dog's days, matching the mobile Trends calendar. Colour marks
// only days with readings, so a collar left off never looks like a good day.
// Each day also has a text label, and a dot marks alerts (docs/19).
import { useEffect, useMemo, useState } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { supabase } from "../lib/supabaseClient.ts";
import {
  fetchAlertsSince,
  fetchDailyStressSummary,
  type DailyStressSummaryRow,
} from "../lib/queries.ts";
import { dayLevel, dayWord } from "../lib/stressDay.ts";
import { cn } from "../lib/cn.ts";
import type { Alert, StressLevel } from "../../../../packages/shared/types/index.ts";

const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const DAY_MS = 24 * 60 * 60 * 1000;
const LEVEL_CLASS: Record<StressLevel, string> = {
  calm: "bg-calm-soft text-calm-fg",
  mild: "bg-mild-soft text-mild-fg",
  moderate: "bg-moderate-soft text-moderate-fg",
  high: "bg-high-soft text-high-fg",
};

const dayKey = (date: Date) =>
  `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;

export function StressCalendar({ dogId }: { dogId: string }) {
  const today = new Date();
  const [month, setMonth] = useState(new Date(today.getFullYear(), today.getMonth(), 1));
  const [days, setDays] = useState<DailyStressSummaryRow[]>([]);
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [failed, setFailed] = useState(false);
  const [selected, setSelected] = useState(dayKey(today));

  useEffect(() => {
    let cancelled = false;
    // The summary counts back from today, so reach the start of the month shown.
    const daysBack = Math.ceil((Date.now() - month.getTime()) / DAY_MS) + 1;
    Promise.all([
      fetchDailyStressSummary(supabase, dogId, daysBack),
      fetchAlertsSince(supabase, dogId, month.toISOString()),
    ])
      .then(([summary, monthAlerts]) => {
        if (cancelled) return;
        setDays(summary);
        setAlerts(monthAlerts);
        setFailed(false);
      })
      .catch(() => {
        if (!cancelled) setFailed(true);
      });
    return () => {
      cancelled = true;
    };
  }, [dogId, month]);

  const byDay = useMemo(() => new Map(days.map((d) => [d.day.slice(0, 10), d])), [days]);
  const alertCounts = useMemo(() => {
    const counts = new Map<string, number>();
    for (const alert of alerts) {
      const key = dayKey(new Date(alert.created_at));
      counts.set(key, (counts.get(key) ?? 0) + 1);
    }
    return counts;
  }, [alerts]);

  const daysInMonth = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
  const isCurrentMonth =
    month.getFullYear() === today.getFullYear() && month.getMonth() === today.getMonth();
  const describe = (key: string) => {
    const count = alertCounts.get(key) ?? 0;
    return [dayWord(dayLevel(byDay.get(key))), count > 0 && `${count} ${count === 1 ? "alert" : "alerts"}`]
      .filter(Boolean)
      .join(" · ");
  };
  const changeMonth = (delta: number) =>
    setMonth(new Date(month.getFullYear(), month.getMonth() + delta, 1));

  return (
    <div>
      <div className="mb-2 flex items-center justify-between">
        <h3 className="m-0 text-base font-semibold text-ink">
          {month.toLocaleDateString(undefined, { month: "long", year: "numeric" })}
        </h3>
        <div className="flex gap-1">
          <button
            type="button"
            aria-label="Previous month"
            onClick={() => changeMonth(-1)}
            className="rounded-md p-1 text-ink-muted hover:bg-surface-alt"
          >
            <ChevronLeft size={18} aria-hidden="true" />
          </button>
          <button
            type="button"
            aria-label="Next month"
            disabled={isCurrentMonth}
            onClick={() => changeMonth(1)}
            className="rounded-md p-1 text-ink-muted hover:bg-surface-alt disabled:opacity-30"
          >
            <ChevronRight size={18} aria-hidden="true" />
          </button>
        </div>
      </div>

      {failed ? (
        <p className="m-0 text-sm text-ink-muted">Couldn&apos;t load this month. Try again later.</p>
      ) : (
        <>
          <div className="grid grid-cols-7 gap-1 text-center">
            {WEEKDAYS.map((name) => (
              <span key={name} className="text-[11px] text-ink-muted">
                {name}
              </span>
            ))}
            {Array.from({ length: month.getDay() }, (_, i) => (
              <span key={`lead-${i}`} />
            ))}
            {Array.from({ length: daysInMonth }, (_, i) => {
              const date = new Date(month.getFullYear(), month.getMonth(), i + 1);
              const key = dayKey(date);
              const level = dayLevel(byDay.get(key));
              const future = date > today;
              return (
                <button
                  key={key}
                  type="button"
                  disabled={future}
                  aria-pressed={selected === key}
                  aria-label={`${date.toLocaleDateString(undefined, { month: "long", day: "numeric" })}: ${describe(key)}`}
                  onClick={() => setSelected(key)}
                  className={cn(
                    "relative h-8 rounded-md text-xs font-medium disabled:text-ink-muted/40",
                    level ? LEVEL_CLASS[level] : "text-ink-muted hover:bg-surface-alt",
                    key === dayKey(today) && "ring-1 ring-ink",
                    selected === key && "ring-2 ring-brand",
                  )}
                >
                  {i + 1}
                  {alertCounts.has(key) && (
                    <span
                      aria-hidden="true"
                      className="absolute right-1 top-1 h-1.5 w-1.5 rounded-full bg-current"
                    />
                  )}
                </button>
              );
            })}
          </div>
          <p className="m-0 mt-2 text-sm text-ink-muted" aria-live="polite">
            {new Date(`${selected}T00:00:00`).toLocaleDateString(undefined, {
              weekday: "long",
              month: "short",
              day: "numeric",
            })}
            : {describe(selected)}
          </p>
        </>
      )}
    </div>
  );
}
