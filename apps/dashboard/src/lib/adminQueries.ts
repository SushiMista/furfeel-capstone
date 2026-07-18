import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  Clinic,
  Device,
  DeviceStatus,
  Dog,
  User,
  UserRole,
} from "../../../../packages/shared/types/index.ts";

/** Admin module data access (docs/05 §4). Every call relies on RLS:
 * users_update_admin / clinics_admin_manage / devices_admin_all only match for
 * the admin role, so a non-admin gets empty reads and rejected writes. */

const USER_COLUMNS = "id, name, email, role, clinic_id, created_at";
const DEVICE_COLUMNS = "id, dog_id, device_code, status, last_seen_at, firmware_version, created_at";

export async function fetchAllUsers(client: SupabaseClient): Promise<User[]> {
  const { data, error } = await client.from("users").select(USER_COLUMNS).order("name");
  if (error) throw error;
  return (data ?? []) as unknown as User[];
}

export async function updateUserRoleClinic(
  client: SupabaseClient,
  userId: string,
  role: UserRole,
  clinicId: string | null,
): Promise<User> {
  const { data, error } = await client
    .from("users")
    .update({ role, clinic_id: clinicId })
    .eq("id", userId)
    .select(USER_COLUMNS)
    .single();
  if (error) throw error;
  return data as unknown as User;
}

/** Admin "add user" (docs/05 §4): calls the admin-create-user Edge Function,
 * which creates the account pre-confirmed (service-role only; no service key
 * in this client) and sets role + clinic in one step. Auto-confirming is
 * safe here specifically because an admin — not the account owner — is
 * picking the email; self-signup in the mobile/dashboard apps still requires
 * email confirmation. The function re-checks the caller is an admin
 * server-side, so this call is only ever a UI convenience, not the gate. */
export async function createUserAccount(
  adminClient: SupabaseClient,
  input: { email: string; password: string; name: string; role: UserRole; clinicId: string | null },
): Promise<User> {
  const { data, error } = await adminClient.functions.invoke("admin-create-user", {
    body: {
      email: input.email,
      password: input.password,
      name: input.name,
      role: input.role,
      clinicId: input.clinicId,
    },
  });
  if (error) {
    // FunctionsHttpError carries the function's JSON error body on .context.
    const body = await error.context?.json?.().catch(() => null);
    throw new Error(body?.error ?? error.message ?? "Failed to create the user");
  }
  return data as User;
}

/** Admin deletes another user's account (docs/05 §4). Auth deletion needs the
 * service role, so this goes through the admin-delete-user Edge Function —
 * same reasoning as createUserAccount. The function itself refuses self-delete,
 * deleting the last admin, and deleting a user who still owns dogs, so those
 * checks don't need duplicating here. */
export async function deleteUserAccount(client: SupabaseClient, userId: string): Promise<void> {
  const { error } = await client.functions.invoke("admin-delete-user", { body: { userId } });
  if (error) {
    const body = await error.context?.json?.().catch(() => null);
    throw new Error(body?.error ?? error.message ?? "Failed to delete the user");
  }
}

export async function fetchClinics(client: SupabaseClient): Promise<Clinic[]> {
  const { data, error } = await client.from("clinics").select("*").order("name");
  if (error) throw error;
  return (data ?? []) as unknown as Clinic[];
}

export async function createClinic(
  client: SupabaseClient,
  clinic: Pick<Clinic, "name" | "address" | "contact_number">,
): Promise<Clinic> {
  const { data, error } = await client.from("clinics").insert(clinic).select("*").single();
  if (error) throw error;
  return data as unknown as Clinic;
}

export async function updateClinic(
  client: SupabaseClient,
  clinicId: string,
  patch: Partial<Pick<Clinic, "name" | "address" | "contact_number">>,
): Promise<Clinic> {
  const { data, error } = await client
    .from("clinics")
    .update(patch)
    .eq("id", clinicId)
    .select("*")
    .single();
  if (error) throw error;
  return data as unknown as Clinic;
}

/** Postgres foreign-key violation (clinics/devices still referenced by other
 * rows) surfaces as error code 23503 — reworded here since the raw message
 * names a constraint, not something a clinic admin should have to parse. */
function friendlyDeleteError(error: { code?: string; message?: string }, linkedTo: string): Error {
  if (error.code === "23503") {
    return new Error(`Still linked to ${linkedTo} — reassign or remove those first.`);
  }
  return new Error(error.message ?? "Delete failed");
}

export async function deleteClinic(client: SupabaseClient, clinicId: string): Promise<void> {
  const { error } = await client.from("clinics").delete().eq("id", clinicId);
  if (error) throw friendlyDeleteError(error, "staff or dogs");
}

export async function fetchAllDevices(client: SupabaseClient): Promise<Device[]> {
  const { data, error } = await client.from("devices").select(DEVICE_COLUMNS).order("device_code");
  if (error) throw error;
  return (data ?? []) as unknown as Device[];
}

export async function registerDevice(
  client: SupabaseClient,
  deviceCode: string,
  firmwareVersion: string | null,
): Promise<Device> {
  const { data, error } = await client
    .from("devices")
    .insert({ device_code: deviceCode.trim().toUpperCase(), firmware_version: firmwareVersion })
    .select(DEVICE_COLUMNS)
    .single();
  if (error) throw error;
  return data as unknown as Device;
}

export async function updateDevice(
  client: SupabaseClient,
  deviceId: string,
  patch: { dog_id?: string | null; status?: DeviceStatus },
): Promise<Device> {
  const { data, error } = await client
    .from("devices")
    .update(patch)
    .eq("id", deviceId)
    .select(DEVICE_COLUMNS)
    .single();
  if (error) throw error;
  return data as unknown as Device;
}

/** Devices with telemetry history can't be deleted (ADR-003: raw telemetry is
 * never deleted, and telemetry_readings.device_id is a NOT NULL FK with no
 * cascade) — set status to inactive/maintenance instead. Freshly registered,
 * never-used devices delete cleanly. */
export async function deleteDevice(client: SupabaseClient, deviceId: string): Promise<void> {
  const { error } = await client.from("devices").delete().eq("id", deviceId);
  if (error) throw friendlyDeleteError(error, "telemetry history — set it to inactive instead");
}

export interface SystemHealth {
  telemetry_last_hour: number;
  telemetry_last_24h: number;
  last_telemetry_at: string | null;
  open_alerts: number;
}

/** System Health tab (docs/03 "view system health"). Read-only aggregates; the
 * admin role sees all rows via is_clinic_member/devices_admin_all, so plain
 * head-count queries are enough. */
export async function fetchSystemHealth(client: SupabaseClient): Promise<SystemHealth> {
  const hourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const dayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const [hour, day, latest, alerts] = await Promise.all([
    client.from("telemetry_readings").select("id", { count: "exact", head: true }).gte("captured_at", hourAgo),
    client.from("telemetry_readings").select("id", { count: "exact", head: true }).gte("captured_at", dayAgo),
    client.from("telemetry_readings").select("captured_at").order("captured_at", { ascending: false }).limit(1),
    client.from("alerts").select("id", { count: "exact", head: true }).eq("status", "open"),
  ]);
  const failed = [hour, day, latest, alerts].find((r) => r.error);
  if (failed?.error) throw failed.error;
  return {
    telemetry_last_hour: hour.count ?? 0,
    telemetry_last_24h: day.count ?? 0,
    last_telemetry_at: (latest.data?.[0] as { captured_at: string } | undefined)?.captured_at ?? null,
    open_alerts: alerts.count ?? 0,
  };
}

export async function fetchAllDogs(client: SupabaseClient): Promise<Dog[]> {
  const { data, error } = await client.from("dogs").select("*").order("name");
  if (error) throw error;
  return (data ?? []) as unknown as Dog[];
}

/** Admin can also (re)assign a dog's clinic (docs/04 clinic linkage note). */
export async function updateDogClinic(
  client: SupabaseClient,
  dogId: string,
  clinicId: string | null,
): Promise<Dog> {
  const { data, error } = await client
    .from("dogs")
    .update({ clinic_id: clinicId })
    .eq("id", dogId)
    .select("*")
    .single();
  if (error) throw error;
  return data as unknown as Dog;
}
