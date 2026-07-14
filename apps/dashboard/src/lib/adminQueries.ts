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
