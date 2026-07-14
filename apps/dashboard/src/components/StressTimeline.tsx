import type { StressClassification } from "../../../../packages/shared/types/index.ts";
import { StressLevelBadge, stressLevelColor } from "./StressLevelBadge.tsx";
import { EmptyState } from "./ui/empty-state.tsx";

/** docs/05: "Stress classification timeline". Oldest-first list; caller controls how much
 * history to pass in (see fetchClassificationHistory's `limit`). */
export function StressTimeline({ classifications }: { classifications: StressClassification[] }) {
  if (classifications.length === 0) {
    return <EmptyState>No stress readings yet — we&apos;ll chart them as they arrive 🐾</EmptyState>;
  }

  return (
    <ol className="m-0 flex list-none flex-col gap-2 p-0">
      {classifications.map((c) => (
        <li key={c.id} className="flex items-center gap-3">
          <span
            className="inline-block h-2.5 w-2.5 flex-shrink-0 rounded-pill"
            style={{ backgroundColor: stressLevelColor(c.stress_level) }}
            title={`${c.stress_level} (score ${c.score ?? "n/a"})`}
          />
          <span className="min-w-[84px] text-xs text-ink-muted">
            {new Date(c.created_at).toLocaleTimeString()}
          </span>
          <StressLevelBadge level={c.stress_level} />
          <span className="text-xs text-ink-muted">score {c.score ?? "n/a"}</span>
        </li>
      ))}
    </ol>
  );
}
