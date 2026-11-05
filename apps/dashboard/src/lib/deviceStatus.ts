// Plain status for a collar, and which collars need someone's attention.
import type { Device } from "../../../../packages/shared/types/index.ts";

/** Same cutoff as the harness battery pill. */
const LOW_BATTERY_PERCENT = 15;

type CollarState = Pick<Device, "status" | "battery_percent" | "dog_id">;

export function needsAttention(device: CollarState): boolean {
  return (
    device.status === "offline" ||
    (device.battery_percent != null && device.battery_percent <= LOW_BATTERY_PERCENT)
  );
}

export function collarState(device: CollarState): string {
  if (device.status === "offline") return "Stopped sending data";
  if (needsAttention(device)) return "Low battery";
  if (device.status === "maintenance") return "Maintenance";
  if (device.status === "inactive") return "Inactive";
  return device.dog_id ? "Active" : "Not assigned to a dog";
}

/** Problems first, then unassigned collars, then everything else. */
export function collarRank(device: CollarState): number {
  if (needsAttention(device)) return 0;
  return device.dog_id ? 2 : 1;
}
