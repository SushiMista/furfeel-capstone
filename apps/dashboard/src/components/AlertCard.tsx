import { useState } from "react";
import { Link } from "react-router-dom";
import { ExternalLink, Cpu, Dog as DogIcon } from "lucide-react";
import type { Alert } from "../../../../packages/shared/types/index.ts";
import { cn } from "../lib/cn.ts";
import { formatAlertMessage, formatPhilippineTime } from "../lib/time.ts";
import { Button } from "./ui/button.tsx";

/** Alert card (docs/19 §7): severity-colored left border, message, PST timestamp,
 * investigation redirection links, and one clear Acknowledge button. */
export function AlertCard({
  alert,
  onAcknowledge,
}: {
  alert: Alert;
  onAcknowledge?: (alert: Alert) => Promise<void>;
}) {
  const [busy, setBusy] = useState(false);
  const open = alert.status === "open";
  const critical = alert.severity === "critical";

  async function handleAcknowledge() {
    if (!onAcknowledge) return;
    setBusy(true);
    try {
      await onAcknowledge(alert);
    } finally {
      setBusy(false);
    }
  }

  const isDeviceOffline = alert.type === "device_offline";

  return (
    <div
      className={cn(
        "mb-3 flex flex-wrap items-center justify-between gap-4 rounded-md border-l-4 bg-surface-alt p-4",
        "transition-opacity duration-slow shadow-xs",
        critical && open ? "border-l-high bg-high-soft" : "border-l-accent",
        !open && "alert-acknowledged border-l-hairline opacity-60",
      )}
    >
      <div className="min-w-0 flex-1">
        <strong className="text-sm text-ink">{formatAlertMessage(alert.message)}</strong>
        <p className="m-0 mt-1 flex flex-wrap items-center gap-2 text-xs text-ink-muted">
          <span>{formatPhilippineTime(alert.created_at)}</span>
          {alert.status !== "open" && <span>· {alert.status}</span>}
        </p>
      </div>

      <div className="flex items-center gap-2 flex-shrink-0">
        {/* Redirection / Investigation links */}
        {alert.dog_id && (
          <Link
            to={`/dogs/${alert.dog_id}`}
            className="inline-flex items-center gap-1 rounded-md border border-hairline bg-surface px-2.5 py-1 text-xs font-semibold text-brand hover:bg-brand-soft hover:text-brand-strong transition-colors duration-fast"
            title="Redirect to dog profile & vitals history"
          >
            <DogIcon size={13} />
            <span>Investigate Dog</span>
          </Link>
        )}

        {isDeviceOffline && (
          <Link
            to="/admin/devices?status=offline"
            className="inline-flex items-center gap-1 rounded-md border border-hairline bg-surface px-2.5 py-1 text-xs font-semibold text-ink-muted hover:bg-surface-alt hover:text-ink transition-colors duration-fast"
            title="Open Admin Device Fleet panel"
          >
            <Cpu size={13} />
            <span>Check Device</span>
          </Link>
        )}

        {open && onAcknowledge && (
          <Button variant="secondary" size="sm" disabled={busy} onClick={handleAcknowledge}>
            {busy ? "Acknowledging…" : "Acknowledge"}
          </Button>
        )}
      </div>
    </div>
  );
}
