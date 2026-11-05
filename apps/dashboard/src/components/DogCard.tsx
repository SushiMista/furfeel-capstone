// Monitoring board card (docs/05), matching the mobile app: full photo, a
// gradient in the stress colour, and glass chips with what staff need at a
// glance. Photos can be changed in place.
import { useEffect, useRef, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import {
  Activity,
  Bell,
  Camera,
  HeartPulse,
  MapPin,
  PawPrint,
  RefreshCw,
  Thermometer,
  Wind,
} from "lucide-react";
import { supabase } from "../lib/supabaseClient.ts";
import { getMediaSignedUrl, uploadDogPhoto, type MonitoringBoardRow } from "../lib/queries.ts";
import { formatPosture } from "../lib/posture.ts";
import { HarnessBattery } from "./HarnessBattery.tsx";
import { cn } from "../lib/cn.ts";
import { dogTint } from "../lib/dogTint.ts";
import { useToast } from "./ui/toast.tsx";
import { friendlyError } from "../lib/errors.ts";

function timeAgo(iso: string): string {
  const seconds = Math.max(0, Math.round((Date.now() - new Date(iso).getTime()) / 1000));
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.round(hours / 24)}d ago`;
}

/** Frosted chip for the card's photo, matching the mobile app. */
function GlassChip({
  icon: Icon,
  children,
  title,
}: {
  icon?: React.ElementType;
  children: React.ReactNode;
  title?: string;
}) {
  return (
    <span
      title={title}
      className="inline-flex items-center gap-1 rounded-full bg-white/20 px-2 py-1 text-[11px] font-semibold text-white backdrop-blur-md"
    >
      {Icon && <Icon size={12} aria-hidden="true" className="shrink-0" />}
      {children}
    </span>
  );
}

export function DogCard({
  row,
  onPhotoChanged,
}: {
  row: MonitoringBoardRow;
  onPhotoChanged: (dogId: string, newPhotoPath?: string) => void;
}) {
  const navigate = useNavigate();
  const toast = useToast();
  const { dog, device, latestReading, latestClassification, openAlertCount } = row;
  const level = latestClassification?.stress_level;
  const [photoUrl, setPhotoUrl] = useState<string | null>(null);
  const [photoVersion, setPhotoVersion] = useState<number>(0);
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
        if (!cancelled) {
          const separator = url.includes("?") ? "&" : "?";
          const freshUrl = photoVersion > 0 ? `${url}${separator}t=${photoVersion}` : url;
          setPhotoUrl(freshUrl);
        }
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [dog.photo_path, photoVersion]);

  // Clean up blob object URLs to prevent memory leaks
  useEffect(() => {
    return () => {
      if (photoUrl && photoUrl.startsWith("blob:")) {
        URL.revokeObjectURL(photoUrl);
      }
    };
  }, [photoUrl]);

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = ""; // Clear file input so selecting the same file triggers change
    if (!file) return;

    if (!file.type.startsWith("image/")) {
      toast("error", "Please select an image file (JPG, PNG, WebP).");
      return;
    }

    if (file.size > 10 * 1024 * 1024) {
      toast("error", "Image must be under 10MB in size.");
      return;
    }

    // Immediate optimistic preview so the user gets instant visual confirmation
    const objectUrl = URL.createObjectURL(file);
    setPhotoUrl(objectUrl);
    setUploading(true);
    setUploadError(false);

    try {
      const newPath = await uploadDogPhoto(supabase, dog.id, file);
      const timestamp = Date.now();
      setPhotoVersion(timestamp);
      toast("success", `✨ Photo updated for ${dog.name}`);
      onPhotoChanged(dog.id, newPath);
    } catch (err) {
      setUploadError(true);
      // Revert optimistic preview back to previous saved signed URL
      setPhotoVersion((v) => v + 1);
      toast("error", friendlyError(err, `update photo for ${dog.name}`));
    } finally {
      setUploading(false);
    }
  };

  const hasReading = Boolean(latestReading);
  const isMaintenance = device?.status === "maintenance";
  const online = (hasReading || device?.status === "active") && !isMaintenance;
  const offline = !hasReading && device?.status === "offline";

  // Same gradient as the mobile card: clear over the photo, rising into the
  // stress colour so urgent dogs stand out across a room.
  const tone = level ? `var(--ff-status-${level}-fg)` : "var(--ff-brand-ink)";
  const dark = `color-mix(in srgb, ${tone} 60%, black)`;
  const collarStatus = online
    ? "Collar active"
    : isMaintenance
      ? "Maintenance"
      : offline
        ? "Offline"
        : "Unassigned";
  const updated = uploadError
    ? "Upload failed"
    : latestReading
      ? timeAgo(latestReading.captured_at)
      : "Awaiting data";

  return (
    <div
      onClick={(e) => {
        // Prevent navigation if clicking interactive elements like camera button or file input
        if ((e.target as HTMLElement).closest("button, input")) return;
        navigate(`/dogs/${dog.id}`);
      }}
      className={cn(
        "group relative h-80 overflow-hidden rounded-2xl shadow-sm cursor-pointer transition-all duration-200",
        "hover:shadow-xl hover:-translate-y-1 active:scale-[0.992]",
        !photoUrl && dogTint(dog.id),
      )}
    >
      {photoUrl ? (
        <img
          src={photoUrl}
          alt={dog.name}
          loading="lazy"
          onError={() => setPhotoUrl(null)}
          className="absolute inset-0 h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
        />
      ) : (
        <div className="absolute inset-x-0 top-10 flex justify-center text-white/70">
          <PawPrint size={72} aria-hidden="true" />
        </div>
      )}

      <div
        className="absolute inset-0"
        style={{
          background: `linear-gradient(to bottom, rgba(0,0,0,.05), transparent 30%, color-mix(in srgb, ${dark} 60%, transparent) 60%, color-mix(in srgb, ${dark} 95%, transparent))`,
        }}
      />

      {uploading && (
        <div className="absolute inset-0 z-20 flex flex-col items-center justify-center bg-black/60 backdrop-blur-[2px]">
          <RefreshCw size={22} className="animate-spin text-white mb-1.5" />
          <span className="text-[11px] font-bold text-white tracking-wide drop-shadow">Saving...</span>
        </div>
      )}

      <div className="absolute inset-0 z-10 flex flex-col justify-between p-3.5">
        <div className="flex items-start justify-between gap-2">
          <HarnessBattery
            onPhoto
            percent={latestReading?.battery_percent ?? device?.battery_percent}
            reportedAt={latestReading?.captured_at}
            offline={device?.status === "offline"}
          />
          <div className="flex items-center gap-1.5">
            <button
              type="button"
              disabled={uploading}
              onClick={() => fileRef.current?.click()}
              aria-label={dog.photo_path ? `Replace ${dog.name}'s photo` : `Add photo of ${dog.name}`}
              title={dog.photo_path ? `Change photo of ${dog.name}` : `Add photo of ${dog.name}`}
              className="flex h-7 w-7 items-center justify-center rounded-full bg-white/20 text-white opacity-0 backdrop-blur-md transition-opacity group-hover:opacity-100 focus-visible:opacity-100 disabled:opacity-60"
            >
              {uploading ? (
                <RefreshCw size={13} aria-hidden="true" className="animate-spin" />
              ) : (
                <Camera size={13} aria-hidden="true" />
              )}
            </button>
            <GlassChip>
              {level && <span className="h-2 w-2 rounded-full bg-white" aria-hidden="true" />}
              {level ? level[0].toUpperCase() + level.slice(1) : "No telemetry"}
            </GlassChip>
          </div>
        </div>

        <input
          ref={fileRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={handleFileChange}
        />

        <div className="flex flex-col gap-1.5 text-white">
          <div className="min-w-0">
            <Link
              to={`/dogs/${dog.id}`}
              className="block truncate text-xl font-bold leading-tight text-white hover:underline"
            >
              {dog.name}
            </Link>
            <p className="m-0 truncate text-xs text-white/80">
              {[dog.breed, row.ownerName].filter(Boolean).join(" · ")}
            </p>
          </div>

          {(dog.ward_location || (dog.admission_status && dog.admission_status !== "outpatient")) && (
            <div className="flex flex-wrap gap-1.5">
              {dog.ward_location && <GlassChip icon={MapPin}>{dog.ward_location}</GlassChip>}
              {dog.admission_status && dog.admission_status !== "outpatient" && (
                <GlassChip>
                  <span className="capitalize">{dog.admission_status.replace(/_/g, " ")}</span>
                </GlassChip>
              )}
            </div>
          )}

          <div className="flex flex-wrap gap-1.5">
            <GlassChip icon={HeartPulse} title="Heart rate">
              {latestReading?.heart_rate_bpm ?? "—"} bpm
            </GlassChip>
            <GlassChip icon={Wind} title="Respiration">
              {latestReading?.respiratory_rate_bpm ?? "—"} bpm
            </GlassChip>
            <GlassChip icon={Thermometer} title="Ambient temperature">
              {latestReading?.ambient_temperature_c ?? "—"}°C
            </GlassChip>
            <GlassChip icon={Activity} title="Posture">
              {formatPosture(latestReading?.posture).shortLabel}
            </GlassChip>
            <GlassChip icon={Bell} title="Open alerts">
              {openAlertCount}
            </GlassChip>
          </div>

          <p className="m-0 truncate text-[11px] text-white/75" aria-live="polite">
            {collarStatus} · {updated}
          </p>
        </div>
      </div>
    </div>
  );
}
