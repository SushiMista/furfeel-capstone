// Micro trend sparkline (docs/21 Redesign Plan §4, Phase 2 — ported from
// mobile's MicroSparkline). Bars, not a line: at this size a 1px stroke reads
// as noise. Brand blue, because the status word/badge already carries status —
// a second status-coloured element would read as a second signal. Self-hides
// below two readings, since a trend drawn from one point is not a trend.
import { cn } from "../lib/cn.ts";

export function MicroSparkline({
  series,
  className,
  track = false,
  "aria-hidden": ariaHidden = true,
}: {
  series: number[];
  className?: string;
  /** Sit each bar in a light full-height capsule (the board's chart look). */
  track?: boolean;
  "aria-hidden"?: boolean;
}) {
  if (series.length < 2) return null;
  const max = Math.max(...series);

  return (
    <div
      className={cn("flex h-6 items-end gap-px", className)}
      aria-hidden={ariaHidden}
    >
      {series.map((v, i) => {
        // A zero value still draws a floor-height bar: a missing bar reads as
        // missing data, a different claim from a low reading.
        const h = `${Math.max(0.12, max > 0 ? v / max : 0.12) * 100}%`;
        return track ? (
          <span key={i} className="flex min-w-0 flex-1 items-end rounded-sm bg-brand-soft">
            <span style={{ height: h }} className="w-full rounded-sm bg-brand" />
          </span>
        ) : (
          <span key={i} style={{ height: h }} className="min-w-0 flex-1 rounded-sm bg-brand" />
        );
      })}
    </div>
  );
}
