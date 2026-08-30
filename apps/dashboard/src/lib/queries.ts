import type { SupabaseClient } from "@supabase/supabase-js";
import { recordAuditLog } from "./auditLogger.ts";
import type {
  Alert,
  Clinic,
  ClinicalIntervention,
  ClinicalInterventionType,
  Device,
  Dog,
  DogBaselines,
  MediaSubmission,
  StressClassification,
  StressLabel,
  StressLevel,
  TelemetryReading,
  UserRole,
  VetNote,
} from "../../../../packages/shared/types/index.ts";

export type { Dog };

const DEVICE_COLUMNS = "id, dog_id, device_code, status, last_seen_at, firmware_version, created_at";
const READING_COLUMNS =
  "id, device_id, dog_id, captured_at, received_at, heart_rate_bpm, " +
  "respiratory_rate_bpm, motion_activity, posture, ambient_temperature_c, humidity_percent, " +
  "is_valid, raw_payload";
const CLASSIFICATION_COLUMNS =
  "id, dog_id, telemetry_reading_id, stress_level, score, confidence, reasons, model_version, created_at";

export interface MonitoringBoardRow {
  dog: Dog;
  device: Device | null;
  latestReading: TelemetryReading | null;
  latestClassification: StressClassification | null;
  openAlertCount: number;
  /** ADDED: last few stress levels (oldest → newest) for the card mini trend. */
  recentLevels: StressLevel[];
  ownerName?: string;
  clinicName?: string;
}

/** All queries below rely entirely on RLS to scope results to the signed-in user's
 * owned/clinic dogs -- no client-side dog_id/clinic_id filtering is done here. */

export async function fetchDogs(client: SupabaseClient): Promise<Dog[]> {
  const { data, error } = await client.from("dogs").select("*").order("name");
  if (error) throw error;
  return (data ?? []) as unknown as Dog[];
}

export async function fetchDog(client: SupabaseClient, dogId: string): Promise<Dog | null> {
  const { data, error } = await client.from("dogs").select("*").eq("id", dogId).maybeSingle();
  if (error) throw error;
  return data as unknown as Dog | null;
}

const DOG_BASELINES_COLUMNS =
  "id, dog_id, resting_heart_rate_bpm, resting_respiratory_rate_bpm, " +
  "threshold_mild_min, threshold_moderate_min, threshold_high_min, " +
  "hr_ratio_elevated_min, hr_ratio_moderate_min, hr_ratio_high_min, " +
  "rr_ratio_elevated_min, rr_ratio_high_min, " +
  "motion_elevated_min, motion_high_min, ambient_heat_c, humidity_heat_pct, updated_at";

/** 0-or-1 row per dog (docs/08); null means every field falls back to the
 * global defaults in classifier_config.json. */
export async function fetchDogBaselines(
  client: SupabaseClient,
  dogId: string,
): Promise<DogBaselines | null> {
  const { data, error } = await client
    .from("dog_baselines")
    .select(DOG_BASELINES_COLUMNS)
    .eq("dog_id", dogId)
    .maybeSingle();
  if (error) throw error;
  return data as unknown as DogBaselines | null;
}

/** Every dog_baselines column a vet can override from the Thresholds tab —
 * the three score-level cutoffs plus the finer per-variable scoring-rule
 * tier floors. Every field is independently nullable/optional; pass null (or
 * omit) to reset a field to its global default. */
export interface DogThresholdOverrides {
  threshold_mild_min: number | null;
  threshold_moderate_min: number | null;
  threshold_high_min: number | null;
  hr_ratio_elevated_min: number | null;
  hr_ratio_moderate_min: number | null;
  hr_ratio_high_min: number | null;
  rr_ratio_elevated_min: number | null;
  rr_ratio_high_min: number | null;
  motion_elevated_min: number | null;
  motion_high_min: number | null;
  ambient_heat_c: number | null;
  humidity_heat_pct: number | null;
}

/** Per-dog threshold override (docs/08, step 2): a vet-only write in practice —
 * dog_baselines_insert/update RLS gates on is_clinic_member(dog_id), so a vet
 * outside this dog's clinic gets rejected by Postgres, not by this function.
 * Pass null for a field to reset it to the global default. Only touches the
 * threshold columns -- resting_* baseline columns set elsewhere on the
 * same row are left untouched (upsert only updates the columns given here). */
export async function saveDogThresholds(
  client: SupabaseClient,
  dogId: string,
  thresholds: DogThresholdOverrides,
): Promise<DogBaselines> {
  const { data, error } = await client
    .from("dog_baselines")
    .upsert({ dog_id: dogId, ...thresholds }, { onConflict: "dog_id" })
    .select(DOG_BASELINES_COLUMNS)
    .single();
  if (error) throw error;
  return data as unknown as DogBaselines;
}

const DEVICE_LIST_COLUMNS =
  "id, dog_id, device_code, status, last_seen_at, firmware_version, battery_percent, created_at, dog:dogs(name)";

export interface DeviceWithDog extends Device {
  dog: { name: string } | null;
}

/** Devices tab (docs/05): read-only fleet list under devices_select_owner_or_clinic
 * RLS -- the caller's own dogs, or their whole clinic. No insert/update/delete
 * here; device registration and assignment stay in Admin → Devices. */
export async function fetchDevicesReadOnly(client: SupabaseClient): Promise<DeviceWithDog[]> {
  const { data, error } = await client
    .from("devices")
    .select(DEVICE_LIST_COLUMNS)
    .order("device_code");
  if (error) throw error;
  return (data ?? []) as unknown as DeviceWithDog[];
}

async function fetchDeviceForDog(client: SupabaseClient, dogId: string): Promise<Device | null> {
  const { data, error } = await client
    .from("devices")
    .select(DEVICE_COLUMNS)
    .eq("dog_id", dogId)
    .maybeSingle();
  if (error) throw error;
  return data as unknown as Device | null;
}

async function fetchLatestReading(
  client: SupabaseClient,
  dogId: string,
): Promise<TelemetryReading | null> {
  const { data, error } = await client
    .from("telemetry_readings")
    .select(READING_COLUMNS)
    .eq("dog_id", dogId)
    .order("captured_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  return data as unknown as TelemetryReading | null;
}

async function fetchLatestClassification(
  client: SupabaseClient,
  dogId: string,
): Promise<StressClassification | null> {
  const { data, error } = await client
    .from("stress_classifications")
    .select(CLASSIFICATION_COLUMNS)
    .eq("dog_id", dogId)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  return data as unknown as StressClassification | null;
}

async function fetchOpenAlertCount(client: SupabaseClient, dogId: string): Promise<number> {
  const { count, error } = await client
    .from("alerts")
    .select("id", { count: "exact", head: true })
    .eq("dog_id", dogId)
    .eq("status", "open");
  if (error) throw error;
  return count ?? 0;
}

export async function fetchMonitoringBoardRowForDog(
  client: SupabaseClient,
  dog: Dog,
  ownerName?: string,
  clinicName?: string,
): Promise<MonitoringBoardRow> {
  const [device, latestReading, latestClassification, openAlertCount, recent] =
    await Promise.all([
      fetchDeviceForDog(client, dog.id),
      fetchLatestReading(client, dog.id),
      fetchLatestClassification(client, dog.id),
      fetchOpenAlertCount(client, dog.id),
      fetchClassificationHistory(client, dog.id, 24),
    ]);
  return {
    dog,
    device,
    latestReading,
    latestClassification,
    openAlertCount,
    recentLevels: recent.map((c) => c.stress_level),
    ownerName,
    clinicName,
  };
}

/** ADDED (docs/05): clinic uploads/replaces a dog's profile photo. Storage RLS
 * limits clinic staff to dogs/<id>/profile.*; dogs.photo_path is set through
 * the set_dog_photo RPC because dogs UPDATE stays owner/admin-only. */
export async function uploadDogPhoto(
  client: SupabaseClient,
  dogId: string,
  file: File,
): Promise<string> {
  const extension = file.name.includes(".") ? file.name.split(".").pop() : "jpg";
  const path = `dogs/${dogId}/profile.${extension}`;
  const { error: uploadError } = await client.storage
    .from("media")
    .upload(path, file, { upsert: true });
  if (uploadError) throw uploadError;
  const { error } = await client.rpc("set_dog_photo", {
    p_dog_id: dogId,
    p_photo_path: path,
  });
  if (error) throw error;
  return path;
}

export async function fetchMonitoringBoard(client: SupabaseClient): Promise<MonitoringBoardRow[]> {
  const dogs = await fetchDogs(client);
  const ownerIds = Array.from(new Set(dogs.map((d) => d.owner_user_id)));
  const clinicIds = Array.from(new Set(dogs.map((d) => d.clinic_id).filter((id): id is string => Boolean(id))));

  const [usersRes, clinicsRes] = await Promise.all([
    ownerIds.length > 0 ? client.from("users").select("id, name").in("id", ownerIds) : Promise.resolve({ data: [] }),
    clinicIds.length > 0 ? client.from("clinics").select("id, name").in("id", clinicIds) : Promise.resolve({ data: [] }),
  ]);

  const ownerMap = new Map((usersRes.data ?? []).map((u: any) => [u.id, u.name]));
  const clinicMap = new Map((clinicsRes.data ?? []).map((c: any) => [c.id, c.name]));

  return Promise.all(
    dogs.map((dog) =>
      fetchMonitoringBoardRowForDog(
        client,
        dog,
        ownerMap.get(dog.owner_user_id) ?? "Unknown Owner",
        dog.clinic_id ? (clinicMap.get(dog.clinic_id) ?? "Unassigned Clinic") : "Unassigned Clinic",
      ),
    ),
  );
}

/** Just what the Overview KPI/needs-attention view actually reads — never
 * the reading, open-alert count, or 24-row history `MonitoringBoardRow`
 * carries for the richer Monitoring Board cards. */
export interface ClinicBoardRow {
  dog: Dog;
  device: Pick<Device, "status"> | null;
  latestClassification: Pick<StressClassification, "stress_level" | "created_at"> | null;
}

const BOARD_SUMMARY_SELECT = "*, devices(status), stress_classifications(stress_level, created_at)";

/**
 * Overview's board data in ONE query, instead of `fetchMonitoringBoard`'s
 * 5-queries-per-dog fan-out (device, latest reading, latest classification,
 * open-alert count, 24-row history) that Overview doesn't need most of. For
 * a 4-dog clinic that fan-out plus Overview's old per-dog daily-summary RPC
 * loop meant ~25 concurrent round trips from one page load — the exact
 * amplification that produced a `57014` (statement timeout) under
 * concurrent load (ADR-021).
 *
 * PostgREST's per-relation `order`/`limit` (via `referencedTable`) does the
 * "latest child row per parent dog" join Postgres-side, in one round trip,
 * using the existing `idx_stress_classifications_dog_created` index —
 * equivalent to a `DISTINCT ON` but through the embedded-resource query
 * PostgREST already supports, so no new SQL function/migration is needed.
 * `devices` has no unique constraint on `dog_id`, so it always comes back as
 * an array even though it's 0-or-1 in practice; handled defensively.
 */
export async function fetchClinicBoardSummary(client: SupabaseClient): Promise<ClinicBoardRow[]> {
  const { data, error } = await client
    .from("dogs")
    .select(BOARD_SUMMARY_SELECT)
    .order("name")
    .order("created_at", { referencedTable: "stress_classifications", ascending: false })
    .limit(1, { referencedTable: "stress_classifications" });
  if (error) throw error;

  type RawRow = Record<string, unknown> & {
    devices: Pick<Device, "status">[] | Pick<Device, "status"> | null;
    stress_classifications:
      | Pick<StressClassification, "stress_level" | "created_at">[]
      | Pick<StressClassification, "stress_level" | "created_at">
      | null;
  };

  return ((data ?? []) as unknown as RawRow[]).map((row) => {
    const { devices, stress_classifications, ...dog } = row;
    const device = Array.isArray(devices) ? (devices[0] ?? null) : devices;
    const latestClassification = Array.isArray(stress_classifications)
      ? (stress_classifications[0] ?? null)
      : stress_classifications;
    return { dog: dog as unknown as Dog, device, latestClassification };
  });
}

/**
 * Overview's clinic-wide "stress mix — last 14 days" chart, aggregated
 * server-side in ONE RPC call — replaces both the old N-per-dog
 * `stress_daily_summary` loop (the query that hit `57014` in production)
 * *and* a first-attempt fix that fetched raw classifications client-side.
 * That attempt was wrong, not just slow: this project's PostgREST config
 * caps responses at 1000 rows, and a 14-day window for one active dog alone
 * was already 11,893 rows — the client-side version silently charted only
 * the first ~8% of the period. `clinic_stress_daily_summary`
 * (20260729020000_clinic_stress_daily_summary.sql) does the grouping in SQL
 * and ships back only the resulting day rows. No `dog_id` list is passed —
 * RLS scopes which classifications count, the same convention `fetchDogs`
 * relies on.
 */
export async function fetchClinicStressDailySummary(
  client: SupabaseClient,
  days = 14,
): Promise<DailyStressSummaryRow[]> {
  const { data, error } = await client.rpc("clinic_stress_daily_summary", {
    p_days: days,
    p_tz_offset_minutes: -new Date().getTimezoneOffset(),
  });
  if (error) throw error;
  // The RPC has no per-dog motion to average across a whole clinic, so it
  // doesn't return the column at all — filled in here rather than lying
  // about the shape via a bare cast. StressMixChart never reads it anyway.
  return ((data ?? []) as Omit<DailyStressSummaryRow, "avg_motion">[]).map((row) => ({
    ...row,
    avg_motion: null,
  }));
}

const STRESS_SEVERITY_RANK: Record<StressLevel, number> = { calm: 0, mild: 1, moderate: 2, high: 3 };

export type BoardSortKey = "stress" | "name" | "owner" | "clinic";

/** docs/19 monitoring board: Sort by stress severity, dog name, owner name, or clinic.
 * Generic over fields so both MonitoringBoardRow and ClinicBoardRow can share. */
export function sortBoardRows<
  T extends {
    dog: { name: string };
    latestClassification: { stress_level: StressLevel } | null;
    ownerName?: string;
    clinicName?: string;
  },
>(rows: T[], sortBy: BoardSortKey = "stress"): T[] {
  return [...rows].sort((a, b) => {
    if (sortBy === "name") {
      return a.dog.name.localeCompare(b.dog.name);
    }
    if (sortBy === "owner") {
      const ownerA = a.ownerName ?? "";
      const ownerB = b.ownerName ?? "";
      const ownerCmp = ownerA.localeCompare(ownerB);
      if (ownerCmp !== 0) return ownerCmp;
      return a.dog.name.localeCompare(b.dog.name);
    }
    if (sortBy === "clinic") {
      const clinicA = a.clinicName ?? "";
      const clinicB = b.clinicName ?? "";
      const clinicCmp = clinicA.localeCompare(clinicB);
      if (clinicCmp !== 0) return clinicCmp;
      return a.dog.name.localeCompare(b.dog.name);
    }
    // Default: Highest stress first, then ties broken by dog name
    const rankA = a.latestClassification ? STRESS_SEVERITY_RANK[a.latestClassification.stress_level] : -1;
    const rankB = b.latestClassification ? STRESS_SEVERITY_RANK[b.latestClassification.stress_level] : -1;
    if (rankA !== rankB) return rankB - rankA;
    return a.dog.name.localeCompare(b.dog.name);
  });
}

export async function fetchTelemetryHistory(
  client: SupabaseClient,
  dogId: string,
  limit = 50,
): Promise<TelemetryReading[]> {
  const { data, error } = await client
    .from("telemetry_readings")
    .select(READING_COLUMNS)
    .eq("dog_id", dogId)
    .order("captured_at", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return ((data ?? []) as unknown as TelemetryReading[]).reverse(); // oldest -> newest, for charting
}

export async function fetchClassificationHistory(
  client: SupabaseClient,
  dogId: string,
  limit = 50,
): Promise<StressClassification[]> {
  const { data, error } = await client
    .from("stress_classifications")
    .select(CLASSIFICATION_COLUMNS)
    .eq("dog_id", dogId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return ((data ?? []) as unknown as StressClassification[]).reverse(); // oldest -> newest
}

const ALERT_COLUMNS =
  "id, dog_id, classification_id, severity, type, message, status, acknowledged_by, acknowledged_at, created_at";

export async function fetchOpenAlerts(client: SupabaseClient, dogId: string): Promise<Alert[]> {
  const { data, error } = await client
    .from("alerts")
    .select(ALERT_COLUMNS)
    .eq("dog_id", dogId)
    .eq("status", "open")
    .order("created_at", { ascending: false });
  if (error) throw error;
  return (data ?? []) as unknown as Alert[];
}

/** Recent alerts of every status (open + acknowledged + resolved) so acknowledged
 * ones stay visible, faded, per docs/19. */
export async function fetchRecentAlerts(
  client: SupabaseClient,
  dogId: string,
  limit = 20,
): Promise<Alert[]> {
  const { data, error } = await client
    .from("alerts")
    .select(ALERT_COLUMNS)
    .eq("dog_id", dogId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return (data ?? []) as unknown as Alert[];
}

/** Acknowledge flow (docs/11 lifecycle step 4). The .eq("status", "open") guard makes
 * this a no-op (null) if someone else acknowledged first; RLS enforces that
 * acknowledged_by is the caller's own auth.uid(). */
export async function acknowledgeAlert(
  client: SupabaseClient,
  alertId: string,
  userId: string,
): Promise<Alert | null> {
  const { data, error } = await client
    .from("alerts")
    .update({
      status: "acknowledged",
      acknowledged_by: userId,
      acknowledged_at: new Date().toISOString(),
    })
    .eq("id", alertId)
    .eq("status", "open")
    .select(ALERT_COLUMNS)
    .maybeSingle();
  if (error) throw error;
  if (data) {
    recordAuditLog({
      actor_id: userId,
      actor_role: "veterinarian",
      surface: "dashboard",
      action: "alert.acknowledge",
      target_resource: "alerts",
      target_id: alertId,
      details: { alert_id: alertId },
      severity: "info",
    });
  }
  return data as unknown as Alert | null;
}

/** ADDED (step 16): bulk-acknowledge for triage. Same open-status guard and
 * RLS as the single ack, one round trip; returns the rows actually flipped so
 * races (someone else acked first) reconcile in the UI. */
export async function acknowledgeAlerts(
  client: SupabaseClient,
  alertIds: string[],
  userId: string,
): Promise<Alert[]> {
  if (alertIds.length === 0) return [];
  const { data, error } = await client
    .from("alerts")
    .update({
      status: "acknowledged",
      acknowledged_by: userId,
      acknowledged_at: new Date().toISOString(),
    })
    .in("id", alertIds)
    .eq("status", "open")
    .select(ALERT_COLUMNS);
  if (error) throw error;
  const result = (data ?? []) as unknown as Alert[];
  if (result.length > 0) {
    recordAuditLog({
      actor_id: userId,
      actor_role: "veterinarian",
      surface: "dashboard",
      action: "alert.bulk_acknowledge",
      target_resource: "alerts",
      details: { count: result.length, alert_ids: result.map((a) => a.id) },
      severity: "info",
    });
  }
  return result;
}

export interface CurrentUserProfile {
  role: string | null;
  clinicId: string | null;
  name: string | null;
  email: string | null;
}

/** Fetches full current user profile for role gating and clinic isolation. */
export async function fetchCurrentUserProfile(
  client: SupabaseClient,
  userId: string,
): Promise<CurrentUserProfile | null> {
  const { data, error } = await client
    .from("users")
    .select("role, clinic_id, name, email")
    .eq("id", userId)
    .maybeSingle();
  if (error) throw error;
  if (!data) return null;
  return {
    role: data.role ?? null,
    clinicId: data.clinic_id ?? null,
    name: data.name ?? null,
    email: data.email ?? null,
  };
}

/** The signed-in user's role from public.users (users_select_own RLS). Used only to
 * decide what UI to offer — RLS remains the actual gate on every write. */
export async function fetchCurrentUserRole(
  client: SupabaseClient,
  userId: string,
): Promise<string | null> {
  const profile = await fetchCurrentUserProfile(client, userId);
  return profile?.role ?? null;
}

/** Alerts queue (docs/05): every RLS-visible alert across dogs, newest first. */
export async function fetchAlertsQueue(
  client: SupabaseClient,
  status: "open" | "all" = "open",
  limit = 100,
): Promise<Alert[]> {
  let query = client.from("alerts").select(ALERT_COLUMNS);
  if (status === "open") query = query.eq("status", "open");
  const { data, error } = await query.order("created_at", { ascending: false }).limit(limit);
  if (error) throw error;
  return (data ?? []) as unknown as Alert[];
}

export interface VetNoteWithAuthor extends VetNote {
  author: { name: string } | null;
}

export async function fetchVetNotes(
  client: SupabaseClient,
  dogId: string,
  limit = 50,
): Promise<VetNoteWithAuthor[]> {
  const { data, error } = await client
    .from("vet_notes")
    .select("id, dog_id, author_user_id, note, created_at, author:users(name)")
    .eq("dog_id", dogId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return (data ?? []) as unknown as VetNoteWithAuthor[];
}

/** RLS allows only clinic staff/vets/admins to insert, and only as themselves. */
export async function addVetNote(
  client: SupabaseClient,
  dogId: string,
  authorUserId: string,
  note: string,
): Promise<VetNote> {
  const { data, error } = await client
    .from("vet_notes")
    .insert({ dog_id: dogId, author_user_id: authorUserId, note })
    .select("id, dog_id, author_user_id, note, created_at")
    .single();
  if (error) throw error;
  return data as unknown as VetNote;
}

export async function fetchTelemetrySince(
  client: SupabaseClient,
  dogId: string,
  sinceIso: string,
): Promise<TelemetryReading[]> {
  const { data, error } = await client
    .from("telemetry_readings")
    .select(READING_COLUMNS)
    .eq("dog_id", dogId)
    .gte("captured_at", sinceIso)
    .order("captured_at", { ascending: true });
  if (error) throw error;
  return (data ?? []) as unknown as TelemetryReading[];
}

export async function fetchClassificationsSince(
  client: SupabaseClient,
  dogId: string,
  sinceIso: string,
): Promise<StressClassification[]> {
  const { data, error } = await client
    .from("stress_classifications")
    .select(CLASSIFICATION_COLUMNS)
    .eq("dog_id", dogId)
    .gte("created_at", sinceIso)
    .order("created_at", { ascending: true });
  if (error) throw error;
  return (data ?? []) as unknown as StressClassification[];
}

export async function fetchAlertsSince(
  client: SupabaseClient,
  dogId: string,
  sinceIso: string,
): Promise<Alert[]> {
  const { data, error } = await client
    .from("alerts")
    .select(ALERT_COLUMNS)
    .eq("dog_id", dogId)
    .gte("created_at", sinceIso)
    .order("created_at", { ascending: true });
  if (error) throw error;
  return (data ?? []) as unknown as Alert[];
}

// =========================================================================
// Vet Review (docs/05 module 2): owner media review + confirm/override stress.
// =========================================================================

const MEDIA_COLUMNS =
  "id, dog_id, submitted_by_user_id, storage_path, media_type, note, " +
  "reviewed_by_user_id, reviewed_at, review_note, created_at";
const STRESS_LABEL_COLUMNS =
  "id, dog_id, classification_id, telemetry_reading_id, vet_user_id, " +
  "confirmed_level, agreed_with_model, note, created_at";

export async function fetchMediaSubmissions(
  client: SupabaseClient,
  dogId: string,
  limit = 50,
): Promise<MediaSubmission[]> {
  const { data, error } = await client
    .from("media_submissions")
    .select(MEDIA_COLUMNS)
    .eq("dog_id", dogId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return (data ?? []) as unknown as MediaSubmission[];
}

/** Mark a media submission reviewed (with optional annotation). Column-level grants
 * restrict staff updates to exactly the review fields; RLS scopes to the clinic. */
export async function reviewMediaSubmission(
  client: SupabaseClient,
  mediaId: string,
  reviewerUserId: string,
  reviewNote: string | null,
): Promise<MediaSubmission> {
  const { data, error } = await client
    .from("media_submissions")
    .update({
      reviewed_by_user_id: reviewerUserId,
      reviewed_at: new Date().toISOString(),
      review_note: reviewNote,
    })
    .eq("id", mediaId)
    .select(MEDIA_COLUMNS)
    .single();
  if (error) throw error;
  return data as unknown as MediaSubmission;
}

/** Media lives in the private `media` bucket; viewing needs a short-lived signed URL.
 * RLS on storage.objects limits this to the dog's owner and clinic staff. */
export async function getMediaSignedUrl(
  client: SupabaseClient,
  storagePath: string,
  expiresInSeconds = 3600,
): Promise<string> {
  const { data, error } = await client.storage
    .from("media")
    .createSignedUrl(storagePath, expiresInSeconds);
  if (error) throw error;
  return data.signedUrl;
}

export interface StressLabelWithVet extends StressLabel {
  vet: { name: string } | null;
}

export async function fetchStressLabels(
  client: SupabaseClient,
  dogId: string,
  limit = 50,
): Promise<StressLabelWithVet[]> {
  const { data, error } = await client
    .from("stress_labels")
    .select(`${STRESS_LABEL_COLUMNS}, vet:users!stress_labels_vet_user_id_fkey(name)`)
    .eq("dog_id", dogId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return (data ?? []) as unknown as StressLabelWithVet[];
}

/** Pure builder so the ground-truth semantics (agreed_with_model) stay unit-testable:
 * confirming the model's level records agreement; picking another level records an
 * override. A label with no underlying classification leaves agreed_with_model null. */
export function buildStressLabelInsert(
  dogId: string,
  vetUserId: string,
  confirmedLevel: StressLevel,
  classification: StressClassification | null,
  note: string,
): Omit<StressLabel, "id" | "created_at"> {
  return {
    dog_id: dogId,
    classification_id: classification?.id ?? null,
    telemetry_reading_id: classification?.telemetry_reading_id ?? null,
    vet_user_id: vetUserId,
    confirmed_level: confirmedLevel,
    agreed_with_model: classification ? classification.stress_level === confirmedLevel : null,
    note: note.trim() === "" ? null : note.trim(),
  };
}

/** Confirm/override stress (docs/05): writes a vet-confirmed ground-truth label —
 * the data that will train the future Random Forest. RLS restricts inserts to
 * clinic staff, and vet_user_id must be the caller. */
export async function addStressLabel(
  client: SupabaseClient,
  insert: Omit<StressLabel, "id" | "created_at">,
): Promise<StressLabel> {
  const { data, error } = await client
    .from("stress_labels")
    .insert(insert)
    .select(STRESS_LABEL_COLUMNS)
    .single();
  if (error) throw error;
  const result = data as unknown as StressLabel;
  if (result) {
    recordAuditLog({
      actor_id: insert.vet_user_id,
      actor_role: "veterinarian",
      surface: "dashboard",
      action: insert.agreed_with_model === false ? "stress_label.override" : "stress_label.confirm",
      target_resource: "stress_labels",
      target_id: result.id,
      details: {
        dog_id: insert.dog_id,
        confirmed_level: insert.confirmed_level,
        agreed_with_model: insert.agreed_with_model,
        note: insert.note,
      },
      severity: insert.agreed_with_model === false ? "warning" : "info",
    });
  }
  return result;
}

// =========================================================================
// Stress summaries (stress_daily_summary RPC): server-side aggregation so a
// 14-day mix chart doesn't ship raw classifications. SECURITY INVOKER — the
// caller's RLS decides row visibility.
// =========================================================================

export interface DailyStressSummaryRow {
  day: string; // date
  calm: number;
  mild: number;
  moderate: number;
  high: number;
  avg_motion: number | null;
}

export async function fetchDailyStressSummary(
  client: SupabaseClient,
  dogId: string,
  days = 14,
): Promise<DailyStressSummaryRow[]> {
  const { data, error } = await client.rpc("stress_daily_summary", {
    p_dog_id: dogId,
    p_days: days,
    p_tz_offset_minutes: -new Date().getTimezoneOffset(),
  });
  if (error) throw error;
  return (data ?? []) as DailyStressSummaryRow[];
}

export interface ClinicTeamMember {
  id: string;
  name: string;
  email: string;
  role: UserRole;
  clinic_id: string | null;
  avatar_path: string | null;
  phone: string | null;
  created_at: string;
}

export interface ClinicTeam {
  clinic: Clinic;
  members: ClinicTeamMember[];
  dogCount: number;
  veterinarianCount: number;
  vetStaffCount: number;
}

export async function fetchClinicTeams(
  client: SupabaseClient,
  scopedClinicId?: string | null,
): Promise<ClinicTeam[]> {
  let clinicQuery = client.from("clinics").select("*").order("name");
  if (scopedClinicId) {
    clinicQuery = clinicQuery.eq("id", scopedClinicId);
  }

  let usersQuery = client
    .from("users")
    .select("id, name, email, role, clinic_id, avatar_path, phone, created_at")
    .in("role", ["veterinarian", "vet_staff", "admin"])
    .order("name");
  if (scopedClinicId) {
    usersQuery = usersQuery.eq("clinic_id", scopedClinicId);
  }

  let dogsQuery = client.from("dogs").select("id, clinic_id");
  if (scopedClinicId) {
    dogsQuery = dogsQuery.eq("clinic_id", scopedClinicId);
  }

  const [clinicsRes, usersRes, dogsRes] = await Promise.all([
    clinicQuery,
    usersQuery,
    dogsQuery,
  ]);

  if (clinicsRes.error) throw clinicsRes.error;

  const clinics = (clinicsRes.data ?? []) as unknown as Clinic[];
  const users = (usersRes.data ?? []) as unknown as ClinicTeamMember[];
  const dogs = (dogsRes.data ?? []) as unknown as { id: string; clinic_id: string | null }[];

  const dogsByClinic = new Map<string, number>();
  for (const dog of dogs) {
    if (dog.clinic_id) {
      dogsByClinic.set(dog.clinic_id, (dogsByClinic.get(dog.clinic_id) ?? 0) + 1);
    }
  }

  const membersByClinic = new Map<string, ClinicTeamMember[]>();
  for (const user of users) {
    if (user.clinic_id && user.role !== "owner") {
      const list = membersByClinic.get(user.clinic_id) ?? [];
      list.push(user);
      membersByClinic.set(user.clinic_id, list);
    }
  }

  return clinics.map((clinic) => {
    const members = membersByClinic.get(clinic.id) ?? [];
    const veterinarianCount = members.filter((m) => m.role === "veterinarian").length;
    const vetStaffCount = members.filter((m) => m.role === "vet_staff").length;
    const dogCount = dogsByClinic.get(clinic.id) ?? 0;

    return {
      clinic,
      members,
      dogCount,
      veterinarianCount,
      vetStaffCount,
    };
  });
}

export async function fetchClinicsReadOnly(client: SupabaseClient): Promise<Clinic[]> {
  const { data, error } = await client.from("clinics").select("*").order("name");
  if (error) throw error;
  return (data ?? []) as unknown as Clinic[];
}

export async function fetchClinicalInterventions(
  client: SupabaseClient,
  dogId: string,
): Promise<ClinicalIntervention[]> {
  const { data, error } = await client
    .from("clinical_interventions")
    .select(`
      id, dog_id, clinic_id, intervention_type, title, notes, dosage, administered_by, created_at,
      users:administered_by ( name )
    `)
    .eq("dog_id", dogId)
    .order("created_at", { ascending: false });
  if (error) throw error;
  return (data ?? []).map((row: any) => ({
    ...row,
    administered_by_name: row.users?.name ?? null,
  })) as ClinicalIntervention[];
}

export async function recordClinicalIntervention(
  client: SupabaseClient,
  payload: {
    dog_id: string;
    clinic_id?: string | null;
    intervention_type: ClinicalInterventionType;
    title: string;
    notes?: string | null;
    dosage?: string | null;
    administered_by?: string | null;
  },
): Promise<ClinicalIntervention> {
  const { data, error } = await client
    .from("clinical_interventions")
    .insert(payload)
    .select("id, dog_id, clinic_id, intervention_type, title, notes, dosage, administered_by, created_at")
    .single();
  if (error) throw error;
  return data as unknown as ClinicalIntervention;
}

export async function updateDogWardAndAdmission(
  client: SupabaseClient,
  dogId: string,
  wardLocation: string | null,
  admissionStatus: string,
): Promise<void> {
  const { error } = await client
    .from("dogs")
    .update({ ward_location: wardLocation, admission_status: admissionStatus })
    .eq("id", dogId);
  if (error) throw error;
}

