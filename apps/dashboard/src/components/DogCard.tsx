// ADDED: photo dog-card (docs/05 monitoring board): profile photo in a
// status-color ring, vitals, a mini stress-trend ribbon, and in-place photo
// upload — monitored dogs recognizable at a glance, not just rows.
import { useEffect, useRef, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import {
  Activity,
  Bell,
  Building2,
  Camera,
  Heart,
  Thermometer,
  User,
  Wind,
} from "lucide-react";
import { supabase } from "../lib/supabaseClient.ts";
import { getMediaSignedUrl, uploadDogPhoto, type MonitoringBoardRow } from "../lib/queries.ts";
import { StressLevelBadge } from "./StressLevelBadge.tsx";
import { cn } from "../lib/cn.ts";
import { dogTint } from "../lib/dogTint.ts";
import type { StressLevel } from "../../../../packages/shared/types/index.ts";

function timeAgo(iso: string): string {
  const seconds = Math.max(0, Math.round((Date.now() - new Date(iso).getTime()) / 1000));
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.round(hours / 24)}d ago`;
}

function MetricItem({
  icon: Icon,
  value,
  unit,
  label,
}: {
  icon: React.ElementType;
  value: string;
  unit?: string;
  label: string;
}) {
  return (
    <div className="flex items-center gap-1.5 min-w-0" title={`${label}: ${value} ${unit ?? ""}`}>
      <Icon size={14} className="text-brand shrink-0 opacity-80" aria-hidden="true" />
      <div className="flex items-baseline gap-0.5 truncate">
        <span className="text-xs font-bold tabular-nums text-ink">{value}</span>
        {unit && <span className="text-[10px] text-ink-muted">{unit}</span>}
      </div>
    </div>
  );
}

export function DogCard({
  row,
  onPhotoChanged,
}: {
  row: MonitoringBoardRow;
  onPhotoChanged: (dogId: string) => void;
}) {
  const navigate = useNavigate();
  const { dog, device, latestReading, latestClassification, openAlertCount } = row;
  const level = latestClassification?.stress_level;
  const [photoUrl, setPhotoUrl] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!dog.photo_path) {
      setPhotoUrl(null);
      return;
    }
    let cancelled = false;
    getMediaSignedUrl(supabase, dog.photo_path)
      .then((url) => {
        if (!cancelled) setPhotoUrl(url);
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [dog.photo_path]);

  const online = device?.status === "active";
  const offline = device?.status === "offline";

  return (
    <div
      onClick={(e) => {
        // Prevent navigation if clicking interactive elements like camera button or file input
        if ((e.target as HTMLElement).closest("button, input")) return;
        navigate(`/dogs/${dog.id}`);
      }}
      className={cn(
        "group relative flex flex-col sm:flex-row items-stretch gap-4 rounded-2xl border border-hairline bg-surface p-3.5",
        "shadow-sm cursor-pointer transition-all duration-200",
        "hover:shadow-xl hover:-translate-y-1 hover:border-brand/40 hover:ring-2 hover:ring-brand/20 active:scale-[0.992]",
        level === "mild" && "bg-mild-soft/40 border-mild-fg/20 hover:bg-mild-soft/70",
        level === "moderate" && "bg-moderate-soft/40 border-moderate-fg/20 hover:bg-moderate-soft/70",
        level === "high" && "bg-high-soft/40 border-high-fg/20 hover:bg-high-soft/70",
      )}
    >
      {/* Left Column: Photo Container with Floating Action Badge */}
      <div className="relative shrink-0 w-full sm:w-32 h-32 sm:h-auto rounded-xl overflow-hidden bg-surface-alt border border-hairline/60">
        {photoUrl ? (
          <img
            src={photoUrl}
            alt={dog.name}
            loading="lazy"
            className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
          />
        ) : (
          <div
            className={cn(
              "flex h-full w-full items-center justify-center text-4xl select-none",
              dogTint(dog.id),
            )}
          >
            🐶
          </div>
        )}

        {/* Top-Right Floating Action Badge (Overlay on Image like reference design) */}
        <div className="absolute top-2 right-2 flex items-center gap-1">
          {openAlertCount > 0 && (
            <span
              className="inline-flex items-center gap-0.5 rounded-full bg-high-fg text-white px-2 py-0.5 text-[10px] font-bold shadow-md"
              title={`${openAlertCount} open alert(s)`}
            >
              <Bell size={10} aria-hidden="true" />
              {openAlertCount}
            </span>
          )}

          <button
            type="button"
            disabled={uploading}
            onClick={() => fileRef.current?.click()}
            aria-label={dog.photo_path ? `Replace ${dog.name}'s photo` : `Add a photo of ${dog.name}`}
            title={dog.photo_path ? "Replace photo" : "Add photo"}
            className={cn(
              "flex h-7 w-7 items-center justify-center rounded-full bg-surface/90 backdrop-blur-md text-ink shadow-sm",
              "transition-all duration-150 hover:bg-white hover:scale-110 active:scale-95 disabled:opacity-50",
            )}
          >
            <Camera size={13} aria-hidden="true" className={uploading ? "animate-pulse text-brand" : undefined} />
          </button>
        </div>

        <input
          ref={fileRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={async (e) => {
            const file = e.target.files?.[0];
            e.target.value = "";
            if (!file) return;
            setUploading(true);
            setUploadError(false);
            try {
              await uploadDogPhoto(supabase, dog.id, file);
              onPhotoChanged(dog.id);
            } catch {
              setUploadError(true);
            } finally {
              setUploading(false);
            }
          }}
        />
      </div>

      {/* Right Column: Dog Information, Vitals, and Status */}
      <div className="flex flex-1 flex-col justify-between min-w-0 gap-2.5 py-0.5">
        {/* Top Row: Name, Breed, and Stress Badge */}
        <div className="flex items-start justify-between gap-2">
          <div className="min-w-0">
            <Link
              to={`/dogs/${dog.id}`}
              className="block truncate text-base font-bold text-ink hover:text-brand transition-colors"
            >
              {dog.name}
            </Link>
            {dog.breed && <p className="truncate text-xs font-medium text-ink-muted">{dog.breed}</p>}
          </div>

          <div className="shrink-0">
            {level ? (
              <StressLevelBadge level={level} className="text-[11px] px-2 py-0.5 shadow-2xs" />
            ) : (
              <span className="rounded-full bg-surface-alt px-2 py-0.5 text-[10px] font-medium text-ink-muted">
                No telemetry
              </span>
            )}
          </div>
        </div>

        {/* Location & Owner Meta Row */}
        <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-ink-muted">
          {row.ownerName && (
            <div className="flex items-center gap-1 truncate" title={`Owner: ${row.ownerName}`}>
              <User size={12} className="shrink-0 text-ink-muted/70" />
              <span className="truncate">{row.ownerName}</span>
            </div>
          )}
          {row.clinicName && (
            <div className="flex items-center gap-1 truncate" title={`Clinic: ${row.clinicName}`}>
              <Building2 size={12} className="shrink-0 text-ink-muted/70" />
              <span className="truncate">{row.clinicName}</span>
            </div>
          )}
        </div>

        {/* Horizontal Vitals Metrics Bar (matching icon metric row in reference card) */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 rounded-xl bg-surface-alt/70 border border-hairline/50 p-2">
          <MetricItem
            icon={Heart}
            value={latestReading?.heart_rate_bpm?.toString() ?? "—"}
            unit="bpm"
            label="Heart Rate"
          />
          <MetricItem
            icon={Wind}
            value={latestReading?.respiratory_rate_bpm?.toString() ?? "—"}
            unit="bpm"
            label="Respiration"
          />
          <MetricItem
            icon={Activity}
            value={latestReading?.motion_activity?.toString() ?? "—"}
            label="Motion"
          />
          <MetricItem
            icon={Thermometer}
            value={latestReading?.ambient_temperature_c?.toString() ?? "—"}
            unit="°C"
            label="Ambient Temp"
          />
        </div>

        {/* Footer Row: Device Status & Last Updated Timestamp */}
        <div className="flex items-center justify-between gap-2 border-t border-hairline/60 pt-2 text-[11px] text-ink-muted">
          <div className="flex items-center gap-1.5 font-medium truncate">
            <span
              className={cn(
                "h-2 w-2 rounded-full shrink-0",
                online ? "bg-calm-fg animate-pulse" : offline ? "bg-high-fg" : "bg-hairline",
              )}
              aria-hidden="true"
            />
            <span className={cn(online ? "text-calm-fg" : offline ? "text-high-fg" : "text-ink-muted")}>
              {online ? `Collar Active ${device?.device_code ? `(${device.device_code})` : ""}` : offline ? `Offline (${device?.device_code ?? ""})` : "Unassigned"}
            </span>
          </div>

          <div className="truncate text-[10px] text-ink-muted/80" aria-live="polite">
            {uploadError
              ? "Upload failed"
              : latestReading
                ? timeAgo(latestReading.captured_at)
                : "Awaiting data"}
          </div>
        </div>
      </div>
    </div>
  );
}

