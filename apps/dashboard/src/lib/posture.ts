import type { Posture } from "../../../../packages/shared/types/index.ts";

export interface PostureDisplayInfo {
  label: string;
  shortLabel: string;
  badge: string;
  description: string;
}

export function formatPosture(posture: Posture | string | null | undefined): PostureDisplayInfo {
  switch (posture?.toLowerCase()) {
    case "lying":
      return {
        label: "Lying Down",
        shortLabel: "Lying",
        badge: "bg-indigo-50 text-indigo-700 border-indigo-200",
        description: "Resting flat on belly or side",
      };
    case "sitting":
      return {
        label: "Sitting",
        shortLabel: "Sitting",
        badge: "bg-sky-50 text-sky-700 border-sky-200",
        description: "Sitting upright on hind legs",
      };
    case "standing":
      return {
        label: "Standing",
        shortLabel: "Standing",
        badge: "bg-emerald-50 text-emerald-700 border-emerald-200",
        description: "Upright on all four paws",
      };
    case "moving":
      return {
        label: "Moving / Active",
        shortLabel: "Moving",
        badge: "bg-amber-50 text-amber-700 border-amber-200",
        description: "Walking, pacing, or active movement",
      };
    default:
      return {
        label: "Unknown",
        shortLabel: "—",
        badge: "bg-surface-alt text-ink-muted border-hairline",
        description: "No posture data",
      };
  }
}
