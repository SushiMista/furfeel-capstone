import { useState } from "react";
import type { Alert } from "../../../../packages/shared/types/index.ts";
import { cn } from "../lib/cn.ts";
import { Button } from "./ui/button.tsx";

/** Alert card (docs/19 §7): severity-colored left border, message, timestamp, one
 * clear Acknowledge button; acknowledged/resolved alerts stay visible but fade. */
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

  return (
    <div
      className={cn(
        "mb-3 flex items-center justify-between gap-4 rounded-md border-l-4 bg-surface-alt p-4",
        "transition-opacity duration-slow",
        critical && open ? "border-l-high bg-high-soft" : "border-l-accent",
        !open && "alert-acknowledged border-l-hairline opacity-60",
      )}
    >
      <div className="min-w-0">
        <strong className="text-sm text-ink">{alert.message}</strong>
        <p className="m-0 mt-1 text-xs text-ink-muted">
          {new Date(alert.created_at).toLocaleString()}
          {alert.status !== "open" && ` · ${alert.status}`}
        </p>
      </div>
      {open && onAcknowledge && (
        <Button variant="secondary" size="sm" disabled={busy} onClick={handleAcknowledge}>
          {busy ? "Acknowledging…" : "Acknowledge"}
        </Button>
      )}
    </div>
  );
}
