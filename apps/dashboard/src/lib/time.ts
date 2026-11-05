/** Time utility functions for Philippine Standard Time (PHT / Asia/Manila, UTC+8) */

/** Formats an ISO string or Date into Philippine Standard Time (UTC+8)
 * Example output: "September 29, 2026 at 7:53 PM"
 */
export function formatPhilippineTime(dateInput: string | Date | number): string {
  const date = new Date(dateInput);
  if (isNaN(date.getTime())) return String(dateInput);

  // Format using Asia/Manila timezone
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Manila",
    month: "long",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  });

  const parts = formatter.formatToParts(date);
  const month = parts.find((p) => p.type === "month")?.value;
  const day = parts.find((p) => p.type === "day")?.value;
  const year = parts.find((p) => p.type === "year")?.value;
  const hour = parts.find((p) => p.type === "hour")?.value;
  const minute = parts.find((p) => p.type === "minute")?.value;
  const dayPeriod = parts.find((p) => p.type === "dayPeriod")?.value;

  if (month && day && year && hour && minute && dayPeriod) {
    return `${month} ${day}, ${year} at ${hour}:${minute} ${dayPeriod}`;
  }

  return formatter.format(date);
}

export function timeAgo(iso: string): string {
  const seconds = Math.max(0, Math.round((Date.now() - new Date(iso).getTime()) / 1000));
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.round(hours / 24)}d ago`;
}
