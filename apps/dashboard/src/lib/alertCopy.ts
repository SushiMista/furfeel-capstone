// Plain alert wording, matching the mobile alert card (alert_card.dart).
import type { Alert } from "../../../../packages/shared/types/index.ts";

export const COLLAR_ALERT_TYPES = ["device_offline", "low_battery"];

/** Short title per alert type. Null for unknown types, where the stored
 * message has to stand alone. */
export function alertHeadline(type: string): string | null {
  switch (type) {
    case "high_stress":
      return "Stress level is high";
    case "moderate_stress":
      return "Stress level is up";
    case "device_offline":
      return "Device stopped sending data";
    case "low_battery":
      return "Battery is low";
    default:
      return null;
  }
}

/** Small print under the headline. Offline messages keep their stored form
 * because the device code is parsed out of them. */
export function alertDetails(message: string): string {
  const offline = message.match(/^Device (\S+) stopped sending data \(last seen ([^)]+)\)/i);
  return offline ? `${offline[1]} · Last seen ${offline[2]}` : message;
}

export interface AlertGroup {
  latest: Alert;
  earlier: Alert[];
}

/** Collapses repeats of one alert for one dog into a single row, keeping the
 * order of the first alert in each group. */
export function groupAlerts(alerts: Alert[]): AlertGroup[] {
  const groups = new Map<string, AlertGroup>();
  for (const alert of alerts) {
    const key = `${alert.dog_id}|${alert.type}|${alert.status}`;
    const group = groups.get(key);
    if (group) group.earlier.push(alert);
    else groups.set(key, { latest: alert, earlier: [] });
  }
  return [...groups.values()];
}
