// ADDED: photo dog-card (docs/05 monitoring board): profile photo in a
// status-color ring, vitals, a mini stress-trend ribbon, and in-place photo
// upload — monitored dogs recognizable at a glance, not just rows.
import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { Bell, Camera } from "lucide-react";
import { supabase } from "../lib/supabaseClient.ts";
import { getMediaSignedUrl, uploadDogPhoto, type MonitoringBoardRow } from "../lib/queries.ts";
import { StressLevelBadge, stressLevelColor } from "./StressLevelBadge.tsx";
import { cn } from "../lib/cn.ts";
import type { StressLevel } from "../../../../packages/shared/types/index.ts";

const RING_CLASS: Record<StressLevel, string> = {
  calm: "ring-calm-fg",
  mild: "ring-mild-fg",
  moderate: "ring-moderate-fg",
  high: "ring-high-fg",
};

function timeAgo(iso: string): string {
  const seconds = Math.max(0, Math.round((Date.now() - new Date(iso).getTime()) / 1000));
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.round(hours / 24)}d ago`;
}

/** Mini stress trend: one colored segment per recent classification (oldest →
 * newest). Supplementary to the badge, which carries the word — so meaning
 * never rides on color alone (docs/19 §9). */
function StressRibbon({ levels }: { levels: StressLevel[] }) {
  if (levels.length < 2) return null;
  const latest = levels[levels.length - 1];
  return (
    <div
      className="flex h-1.5 gap-px overflow-hidden rounded-pill"
      role="img"
      aria-label={`Recent stress trend, latest ${latest}`}
      title={`Recent stress trend (oldest to newest), latest: ${latest}`}
    >
      {levels.map((level, i) => (
        <span
          key={i}
          className="min-w-0 flex-1"
          style={{ backgroundColor: stressLevelColor(level) }}
        />
      ))}
    </div>
  );
}

function Vital({ label, value, unit }: { label: string; value: string; unit?: string }) {
  return (
    <div className="min-w-0">
      <div className="truncate text-lg font-bold tabular-nums text-ink">
        {value}
        {unit && <span className="ml-0.5 text-xs font-normal text-ink-muted">{unit}</span>}
      </div>
      <div className="truncate text-[11px] text-ink-muted">{label}</div>
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
  const { dog, device, latestReading, latestClassification, openAlertCount, recentLevels } = row;
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
      className={cn(
        "group relative flex flex-col gap-3 rounded-lg border border-hairline bg-surface p-4",
        "shadow-card transition-shadow duration-fast hover:shadow-lg",
        // Above-calm dogs get a soft status tint so they stand out (docs/19 §7).
        level === "mild" && "bg-mild-soft",
        level === "moderate" && "bg-moderate-soft",
        level === "high" && "bg-high-soft",
      )}
    >
      <div className="flex items-start gap-3">
        <div className="relative flex-shrink-0">
          <span
            className={cn(
              "block h-14 w-14 overflow-hidden rounded-pill bg-brand-soft ring-2 ring-offset-2",
              "ring-offset-surface transition-colors duration-slow",
              level ? RING_CLASS[level] : "ring-hairline",
            )}
          >
            {photoUrl ? (
              <img
                src={photoUrl}
                alt=""
                width={56}
                height={56}
                loading="lazy"
                className="h-full w-full object-cover"
              />
            ) : (
              <span
                className="flex h-full w-full items-center justify-center text-2xl"
                aria-hidden="true"
              >
                🐶
              </span>
            )}
          </span>
          {/* Upload/replace photo, revealed on hover/focus (docs/05). */}
          <button
            type="button"
            disabled={uploading}
            onClick={() => fileRef.current?.click()}
            aria-label={dog.photo_path ? `Replace ${dog.name}'s photo` : `Add a photo of ${dog.name}`}
            title={dog.photo_path ? "Replace photo" : "Add photo"}
            className={cn(
              "absolute -bottom-1 -right-1 rounded-pill bg-brand p-1.5 text-surface shadow-card",
              "opacity-0 transition-opacity duration-fast focus-visible:opacity-100",
              "group-hover:opacity-100 disabled:opacity-100",
            )}
          >
            <Camera size={12} aria-hidden="true" className={uploading ? "animate-pulse" : undefined} />
          </button>
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

        <div className="min-w-0 flex-1">
          <Link
            to={`/dogs/${dog.id}`}
            className="block truncate text-base font-bold text-ink hover:text-brand-strong"
          >
            {dog.name}
          </Link>
          {dog.breed && <div className="truncate text-xs text-ink-muted">{dog.breed}</div>}
          <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
            {level ? (
              <StressLevelBadge level={level} className={level !== "calm" ? "bg-surface" : undefined} />
            ) : (
              <span className="text-xs text-ink-muted">No reading yet</span>
            )}
            {openAlertCount > 0 && (
              <span className="inline-flex items-center gap-1 rounded-pill bg-surface px-2 py-0.5 text-xs font-bold text-high-fg">
                <Bell size={11} aria-hidden="true" />
                {openAlertCount}
              </span>
            )}
          </div>
        </div>

        <span
          className={cn(
            "mt-1 inline-flex items-center gap-1.5 text-[11px] font-medium",
            online ? "text-calm-fg" : offline ? "text-high-fg" : "text-ink-muted",
          )}
        >
          <span
            className={cn(
              "h-2 w-2 rounded-pill",
              online ? "bg-calm-fg" : offline ? "bg-high-fg" : "bg-hairline",
            )}
            aria-hidden="true"
          />
          {device?.status ?? "unassigned"}
        </span>
      </div>

      <div className="grid grid-cols-4 gap-2">
        <Vital label="Heart" value={latestReading?.heart_rate_bpm?.toString() ?? "—"} unit="bpm" />
        <Vital label="Temp" value={latestReading?.body_temperature_c?.toString() ?? "—"} unit="°C" />
        <Vital label="Resp" value={latestReading?.respiratory_rate_bpm?.toString() ?? "—"} unit="bpm" />
        <Vital label="Motion" value={latestReading?.motion_activity?.toString() ?? "—"} />
      </div>

      <StressRibbon levels={recentLevels} />

      <div className="text-[11px] text-ink-muted" aria-live="polite">
        {uploadError
          ? "Photo upload failed — check the file and try again."
          : latestReading
            ? `Updated ${timeAgo(latestReading.captured_at)}`
            : "Waiting for first reading"}
      </div>
    </div>
  );
}
