import { createClient, type SupabaseClient } from "@supabase/supabase-js";
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

/** Admin "add user" (docs/05 §4): a throwaway anon-key client signs the account
 * up — the handle_new_user trigger mirrors it into public.users as 'owner' —
 * then the admin's own client sets role/clinic via users_update_admin. The
 * admin's session is untouched and no service key ever reaches the browser.
 * If email confirmations are on, the new user must confirm before first login. */
export async function createUserAccount(
  adminClient: SupabaseClient,
  input: { email: string; password: string; name: string; role: UserRole; clinicId: string | null },
): Promise<User> {
  const signupClient = createClient(
    import.meta.env.VITE_SUPABASE_URL,
    import.meta.env.VITE_SUPABASE_ANON_KEY,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  const { data, error } = await signupClient.auth.signUp({
    email: input.email,
    password: input.password,
    options: { data: { name: input.name } },
  });
  if (error) throw error;
  // GoTrue obfuscates duplicate signups as a user with no identities.
  if (!data.user || data.user.identities?.length === 0) {
    throw new Error("That email is already registered.");
  }
  return updateUserRoleClinic(adminClient, data.user.id, input.role, input.clinicId);
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
