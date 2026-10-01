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

/** Formats alert message text, converting embedded UTC timestamps into Philippine Standard Time.
 * Example input: "Device FURFEEL-DEV-0002 stopped sending data (last seen 2026-08-22 17:16 UTC)."
 * Example output: "Device FURFEEL-DEV-0002 stopped sending data (last seen August 23, 2026 at 1:16 AM)."
 */
export function formatAlertMessage(message: string): string {
  if (!message) return "";

  // Match pattern: (last seen YYYY-MM-DD HH:mm UTC)
  return message.replace(
    /\(last seen (\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}) UTC\)/g,
    (_, dateStr, timeStr) => {
      const utcIso = `${dateStr}T${timeStr}:00Z`;
      const phtStr = formatPhilippineTime(utcIso);
      return `(last seen ${phtStr})`;
    },
  );
}
