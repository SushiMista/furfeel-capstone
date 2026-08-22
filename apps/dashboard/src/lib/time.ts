/** Time utility functions for Philippine Standard Time (PST / Asia/Manila, UTC+8) */

/** Formats an ISO string or Date into Philippine Standard Time (PST, UTC+8)
 * Example output: "2026-08-23 01:16 PST"
 */
export function formatPhilippineTime(dateInput: string | Date | number): string {
  const date = new Date(dateInput);
  if (isNaN(date.getTime())) return String(dateInput);

  // Format using Asia/Manila timezone
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Manila",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });

  // en-CA produces "YYYY-MM-DD, HH:mm"
  const formatted = formatter.format(date).replace(",", "");
  return `${formatted} PST`;
}

/** Formats alert message text, converting embedded UTC timestamps into Philippine Standard Time (PST).
 * Example input: "Device FURFEEL-DEV-0002 stopped sending data (last seen 2026-08-22 17:16 UTC)."
 * Example output: "Device FURFEEL-DEV-0002 stopped sending data (last seen 2026-08-23 01:16 PST)."
 */
export function formatAlertMessage(message: string): string {
  if (!message) return "";

  // Match pattern: (last seen YYYY-MM-DD HH:mm UTC)
  return message.replace(
    /\(last seen (\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}) UTC\)/g,
    (_, dateStr, timeStr) => {
      const utcIso = `${dateStr}T${timeStr}:00Z`;
      const pstStr = formatPhilippineTime(utcIso);
      return `(last seen ${pstStr})`;
    },
  );
}
