import type { StressLevel } from "../../../../packages/shared/types/index.ts";
import designTokens from "../../../../packages/shared/design_tokens.json";
import { cn } from "../lib/cn.ts";

/** Canonical stress ramp from the shared design tokens (docs/19) — never hardcoded
 * in components. Used for programmatic colors (chart series, timeline dots). */
export function stressLevelColor(level: StressLevel): string {
  return designTokens.color.status[level].fg;
}

export function stressLevelSoftBg(level: StressLevel): string {
  return designTokens.color.status[level].bg;
}

const PILL_CLASSES: Record<StressLevel, string> = {
  calm: "bg-calm-soft text-calm-fg",
  mild: "bg-mild-soft text-mild-fg",
  moderate: "bg-moderate-soft text-moderate-fg",
  high: "bg-high-soft text-high-fg",
};

/** Status pill (docs/19 §7): soft-bg fill + colored text + status dot + the word,
 * so meaning never rides on color alone. Color changes cross-fade. */
export function StressLevelBadge({ level, className }: { level: StressLevel; className?: string }) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 rounded-pill px-2.5 py-0.5 text-xs font-bold capitalize",
        "transition-colors duration-slow",
        PILL_CLASSES[level],
        className,
      )}
    >
      <span className="h-2 w-2 rounded-pill bg-current" aria-hidden="true" />
      {level}
    </span>
  );
}
