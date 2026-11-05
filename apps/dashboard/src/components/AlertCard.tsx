import { useState } from "react";
import { Link } from "react-router-dom";
import { Check, ChevronDown } from "lucide-react";
import type { Alert } from "../../../../packages/shared/types/index.ts";
import { COLLAR_ALERT_TYPES, alertDetails, alertHeadline } from "../lib/alertCopy.ts";
import { cn } from "../lib/cn.ts";
import { formatPhilippineTime, timeAgo } from "../lib/time.ts";
import { Button } from "./ui/button.tsx";

interface AlertCardProps {
  alert: Alert;
  dogName?: string;
  /** Older repeats of this alert, listed when the row is expanded. */
  earlier?: Alert[];
  onAcknowledge?: (alert: Alert) => Promise<void>;
  className?: string;
}

function statusPill(alert: Alert): { label: string; className: string } {
  if (alert.status !== "open") {
    return {
      label: alert.status[0].toUpperCase() + alert.status.slice(1),
      className: "bg-surface-alt text-ink-muted",
    };
  }
  if (COLLAR_ALERT_TYPES.includes(alert.type)) return { label: "Collar", className: "bg-surface-alt text-ink-muted" };
  if (alert.severity === "critical") return { label: "High", className: "bg-high-soft text-high-fg" };
  if (alert.severity === "warning") return { label: "Moderate", className: "bg-moderate-soft text-moderate-fg" };
  return { label: "Info", className: "bg-brand-soft text-brand" };
}

/** One alert as one line of meaning, like the mobile card: a plain title, the
 * details underneath, and when. Colour always comes with a word (docs/19). */
export function AlertCard({ alert, dogName, earlier = [], onAcknowledge, className }: AlertCardProps) {
  const [busy, setBusy] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const open = alert.status === "open";
  const headline = alertHeadline(alert.type);
  const details = alertDetails(alert.message);
  const pill = statusPill(alert);

  async function handleAcknowledge() {
    if (!onAcknowledge) return;
    setBusy(true);
    try {
      await onAcknowledge(alert);
    } finally {
      setBusy(false);
    }
  }

  // Offline messages start with the device code; fall back to the dog's collar.
  const deviceCode = alert.message.match(/^Device\s+(\S+)/i)?.[1];
  const deviceUrl = deviceCode
    ? `/devices?device_code=${encodeURIComponent(deviceCode)}`
    : `/devices?dog_id=${encodeURIComponent(alert.dog_id)}`;
  const linkClass =
    "inline-flex items-center rounded-lg border border-hairline bg-surface px-2.5 py-1.5 text-xs font-semibold text-ink hover:bg-surface-alt";

  return (
    <div
      className={cn(
        "mb-2 rounded-lg border border-hairline bg-surface p-3",
        !open && "opacity-75 alert-acknowledged",
        className,
      )}
    >
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex min-w-0 flex-1 basis-72 items-start gap-3">
          <span
            className={cn(
              "mt-0.5 inline-flex w-[84px] shrink-0 items-center justify-center rounded-full px-2 py-0.5 text-xs font-semibold",
              pill.className,
            )}
          >
            {pill.label}
          </span>
          <div className="min-w-0">
            <p className="m-0 text-sm text-ink">
              {dogName && <span className="font-bold">{dogName} · </span>}
              <span className={headline ? "font-medium" : "break-words"}>{headline ?? details}</span>
              {earlier.length > 0 && (
                <span className="text-xs text-ink-muted"> · {earlier.length + 1} alerts</span>
              )}
            </p>
            <p className="m-0 break-words text-xs text-ink-muted">
              {headline && `${details} · `}
              <time dateTime={alert.created_at} title={formatPhilippineTime(alert.created_at)}>
                {timeAgo(alert.created_at)}
              </time>
            </p>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          {earlier.length > 0 && (
            <button
              type="button"
              aria-expanded={expanded}
              onClick={() => setExpanded((value) => !value)}
              className={cn(linkClass, "cursor-pointer gap-1")}
            >
              <ChevronDown
                size={13}
                aria-hidden="true"
                className={cn("transition-transform", expanded && "rotate-180")}
              />
              {expanded ? "Hide repeats" : "Show repeats"}
            </button>
          )}
          <Link to={`/dogs/${alert.dog_id}`} className={linkClass}>
            Open dog
          </Link>
          {COLLAR_ALERT_TYPES.includes(alert.type) && (
            <Link to={deviceUrl} className={linkClass}>
              Check collar
            </Link>
          )}
          {open && onAcknowledge && (
            <Button size="sm" disabled={busy} onClick={handleAcknowledge} className="gap-1.5">
              <Check size={13} strokeWidth={2.5} aria-hidden="true" />
              {busy ? "Acknowledging…" : "Acknowledge"}
            </Button>
          )}
        </div>
      </div>

      {expanded && (
        <ul className="m-0 mt-2 list-none border-t border-hairline p-0 pt-2 pl-[96px] text-xs text-ink-muted">
          {earlier.map((item) => (
            <li key={item.id} className="py-0.5">
              {formatPhilippineTime(item.created_at)} · {alertDetails(item.message)}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
