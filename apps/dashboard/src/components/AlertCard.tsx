import { useState } from "react";
import { Link } from "react-router-dom";
import {
  AlertCircle,
  AlertTriangle,
  Check,
  CheckCheck,
  Cpu,
  Dog as DogIcon,
  Info,
} from "lucide-react";
import type { Alert } from "../../../../packages/shared/types/index.ts";
import { cn } from "../lib/cn.ts";
import { formatAlertMessage, formatPhilippineTime } from "../lib/time.ts";
import { Button } from "./ui/button.tsx";

interface AlertCardProps {
  alert: Alert;
  dogName?: string;
  onAcknowledge?: (alert: Alert) => Promise<void>;
  className?: string;
}

/**
 * Outline & Left-Stripe Alert Card:
 * - Red Outline: Critical / High Stress / Malfunction
 * - Orange Outline: Warning / Moderate Stress / Offline Warning
 * - Blue Outline: Info / Telemetry Notice / Advisory
 * - Green Outline: Resolved / Acknowledged / Normal
 */
export function AlertCard({
  alert,
  dogName,
  onAcknowledge,
  className,
}: AlertCardProps) {
  const [busy, setBusy] = useState(false);
  const open = alert.status === "open";
  const isDeviceOffline = alert.type === "device_offline";

  async function handleAcknowledge() {
    if (!onAcknowledge) return;
    setBusy(true);
    try {
      await onAcknowledge(alert);
    } finally {
      setBusy(false);
    }
  }

  const isAcknowledged = !open;

  // Determine border outlines, icon badges, and color themes
  let theme = {
    cardBorder: "border-l-4 border-l-[#DC2626] border-red-200 bg-red-50/40",
    iconBg: "bg-red-100 text-[#DC2626]",
    badgeBg: "bg-red-100 text-red-800 border-red-200",
    title: alert.type === "device_offline" ? "Critical: Device Offline" : "Critical: High Stress Alert",
    Icon: AlertTriangle,
  };

  if (isAcknowledged) {
    theme = {
      cardBorder: "border-l-4 border-l-[#009B4D] border-emerald-200 bg-emerald-50/30",
      iconBg: "bg-emerald-100 text-[#009B4D]",
      badgeBg: "bg-emerald-100 text-emerald-800 border-emerald-200",
      title: "Alert Acknowledged & Monitored",
      Icon: CheckCheck,
    };
  } else if (alert.severity === "critical") {
    theme = {
      cardBorder: "border-l-4 border-l-[#DC2626] border-red-200 bg-red-50/40",
      iconBg: "bg-red-100 text-[#DC2626]",
      badgeBg: "bg-red-100 text-red-800 border-red-200",
      title: alert.type === "device_offline" ? "Critical: Device Offline" : "Critical: High Stress Alert",
      Icon: AlertTriangle,
    };
  } else if (alert.severity === "warning" || isDeviceOffline) {
    theme = {
      cardBorder: "border-l-4 border-l-[#E65100] border-orange-200 bg-orange-50/40",
      iconBg: "bg-orange-100 text-[#E65100]",
      badgeBg: "bg-orange-100 text-orange-800 border-orange-200",
      title: isDeviceOffline ? "Warning: Device Connection Lost" : "Warning: Moderate Stress Elevated",
      Icon: AlertCircle,
    };
  } else {
    theme = {
      cardBorder: "border-l-4 border-l-[#0088D6] border-sky-200 bg-sky-50/40",
      iconBg: "bg-sky-100 text-[#0088D6]",
      badgeBg: "bg-sky-100 text-sky-800 border-sky-200",
      title: "System Advisory",
      Icon: Info,
    };
  }

  const { cardBorder, iconBg, badgeBg, title, Icon } = theme;

  // Extract device code if device_offline alert
  const matchCode =
    alert.message.match(/Device\s+([A-Za-z0-9_-]+)/i) ??
    alert.message.match(/([A-Za-z0-9_-]+-DEV-[A-Za-z0-9_-]+)/i);
  const deviceCode = matchCode ? matchCode[1] : null;

  const targetDeviceUrl = deviceCode
    ? `/admin/devices?device_code=${encodeURIComponent(deviceCode)}`
    : alert.dog_id
      ? `/admin/devices?dog_id=${encodeURIComponent(alert.dog_id)}`
      : `/admin/devices?status=offline`;

  return (
    <div
      className={cn(
        "relative mb-3 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 rounded-xl border p-4 shadow-xs transition-all duration-200",
        cardBorder,
        isAcknowledged && "opacity-75 shadow-none",
        className,
      )}
    >
      {/* Left section: Themed Icon + Message text */}
      <div className="flex items-start gap-3.5 min-w-0 flex-1">
        <div
          className={cn(
            "mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-lg shadow-xs",
            iconBg,
          )}
        >
          <Icon className="h-4 w-4" strokeWidth={2.5} aria-hidden="true" />
        </div>

        <div className="flex flex-col min-w-0 flex-1">
          <div className="flex items-center gap-2 flex-wrap">
            <h4 className="text-sm font-bold text-ink tracking-tight m-0 leading-tight">
              {title}
            </h4>
            {dogName && (
              <span
                className={cn(
                  "inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-semibold border",
                  badgeBg,
                )}
              >
                🐶 {dogName}
              </span>
            )}
          </div>

          <p className="mt-1 text-xs text-ink/90 leading-relaxed font-medium m-0">
            {formatAlertMessage(alert.message)}
          </p>

          <div className="mt-2 flex items-center gap-2 text-[11px] text-ink-muted">
            <span>{formatPhilippineTime(alert.created_at)}</span>
            {alert.status !== "open" && (
              <>
                <span>•</span>
                <span className="uppercase tracking-wide font-bold">{alert.status}</span>
              </>
            )}
          </div>
        </div>
      </div>

      {/* Right section: Action Buttons */}
      <div className="flex items-center gap-2 shrink-0 self-end sm:self-center flex-wrap">
        {/* Investigate Dog Link */}
        {alert.dog_id && (
          <Link
            to={`/dogs/${alert.dog_id}`}
            className="inline-flex items-center gap-1.5 rounded-lg border border-hairline bg-surface px-2.5 py-1.5 text-xs font-semibold text-ink hover:bg-surface-alt hover:text-brand-strong transition-colors shadow-xs"
            title="Investigate dog profile & vitals history"
          >
            <DogIcon size={13} className="text-brand" aria-hidden="true" />
            <span>Investigate</span>
          </Link>
        )}

        {/* Check Device Link */}
        {isDeviceOffline && (
          <Link
            to={targetDeviceUrl}
            className="inline-flex items-center gap-1.5 rounded-lg border border-hairline bg-surface px-2.5 py-1.5 text-xs font-semibold text-ink hover:bg-surface-alt transition-colors shadow-xs"
            title="Check device status in management console"
          >
            <Cpu size={13} className="text-ink-muted" aria-hidden="true" />
            <span>Check Device</span>
          </Link>
        )}

        {/* Fast Triage Acknowledge Button */}
        {open && onAcknowledge && (
          <Button
            variant="secondary"
            size="sm"
            disabled={busy}
            onClick={handleAcknowledge}
            className="font-bold shadow-xs flex items-center gap-1.5"
            title="Acknowledge this alert"
          >
            <Check size={13} strokeWidth={2.5} aria-hidden="true" />
            <span>{busy ? "Acknowledging…" : "Acknowledge"}</span>
          </Button>
        )}
      </div>
    </div>
  );
}
