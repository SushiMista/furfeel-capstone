import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  Alert,
  Device,
  Dog,
  MediaSubmission,
  StressClassification,
  StressLabel,
  StressLevel,
  TelemetryReading,
  VetNote,
} from "../../../../packages/shared/types/index.ts";

const DEVICE_COLUMNS = "id, dog_id, device_code, status, last_seen_at, firmware_version, created_at";
const READING_COLUMNS =
  "id, device_id, dog_id, captured_at, received_at, heart_rate_bpm, body_temperature_c, " +
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
  return Promise.all(dogs.map((dog) => fetchMonitoringBoardRowForDog(client, dog)));
}

const STRESS_SEVERITY_RANK: Record<StressLevel, number> = { calm: 0, mild: 1, moderate: 2, high: 3 };

/** docs/19 monitoring board: "Sort so anything above calm floats up." Highest stress first,
 * then unclassified/calm dogs, ties broken by dog name so ordering stays stable. */
export function sortBoardRows(rows: MonitoringBoardRow[]): MonitoringBoardRow[] {
  return [...rows].sort((a, b) => {
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
  return (data ?? []) as unknown as Alert[];
}

/** The signed-in user's role from public.users (users_select_own RLS). Used only to
 * decide what UI to offer — RLS remains the actual gate on every write. */
export async function fetchCurrentUserRole(
  client: SupabaseClient,
  userId: string,
): Promise<string | null> {
  const { data, error } = await client
    .from("users")
    .select("role")
    .eq("id", userId)
    .maybeSingle();
  if (error) throw error;
  return (data as { role: string } | null)?.role ?? null;
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
  return data as unknown as StressLabel;
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
