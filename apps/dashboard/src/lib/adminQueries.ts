import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  Clinic,
  Device,
  DeviceStatus,
  Dog,
  DogSex,
  User,
  UserRole,
} from "../../../../packages/shared/types/index.ts";

/** Admin module data access (docs/05 §4). Every call relies on RLS:
 * users_update_admin / clinics_admin_manage / devices_admin_all only match for
 * the admin role, so a non-admin gets empty reads and rejected writes. */

const USER_COLUMNS = "id, name, email, role, clinic_id, is_active, deactivated_at, created_at";
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

export interface DeleteUserOptions {
  mode?: "auto" | "deactivate" | "hard";
  reassignOwnerId?: string;
}

/** Admin deletes or deactivates another user's account (docs/05 §4). */
export async function deleteUserAccount(
  client: SupabaseClient,
  userId: string,
  options?: DeleteUserOptions,
): Promise<{ ok: boolean; action?: string }> {
  const mode = options?.mode ?? "auto";

  // If Hard Delete is requested, use the admin_purge_user RPC function (bypasses RLS & cascades clean purge)
  if (mode === "hard") {
    const { error: rpcError } = await client.rpc("admin_purge_user", { target_user_id: userId });
    if (!rpcError) {
      return { ok: true, action: "deleted" };
    }
  }

  const { data, error } = await client.functions.invoke("admin-delete-user", {
    body: { userId, mode, reassignOwnerId: options?.reassignOwnerId },
  });

  if (error) {
    const body = await error.context?.json?.().catch(() => null);
    throw new Error(body?.error ?? error.message ?? "Failed to delete/deactivate the user");
  }
  return (data ?? { ok: true }) as { ok: boolean; action?: string };
}

/** Admin bulk deletes or deactivates multiple user accounts. */
export async function bulkDeleteUserAccounts(
  client: SupabaseClient,
  userIds: string[],
  options?: DeleteUserOptions,
): Promise<{ success: string[]; failed: { id: string; error: string }[] }> {
  const success: string[] = [];
  const failed: { id: string; error: string }[] = [];

  for (const id of userIds) {
    try {
      await deleteUserAccount(client, id, options);
      success.push(id);
    } catch (err: unknown) {
      failed.push({ id, error: (err as Error).message ?? "Operation failed" });
    }
  }

  return { success, failed };
}

/** Admin reactivates a soft-deleted / deactivated user account. */
export async function reactivateUserAccount(client: SupabaseClient, userId: string): Promise<void> {
  const { error } = await client.functions.invoke("admin-delete-user", {
    body: { userId, reactivate: true },
  });
  if (error) {
    const body = await error.context?.json?.().catch(() => null);
    throw new Error(body?.error ?? error.message ?? "Failed to reactivate the user");
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

export async function bulkDeleteClinics(
  client: SupabaseClient,
  clinicIds: string[],
): Promise<{ success: string[]; failed: { id: string; error: string }[] }> {
  const success: string[] = [];
  const failed: { id: string; error: string }[] = [];

  for (const id of clinicIds) {
    try {
      await deleteClinic(client, id);
      success.push(id);
    } catch (err: unknown) {
      failed.push({ id, error: (err as Error).message ?? "Delete failed" });
    }
  }

  return { success, failed };
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

export async function bulkDeleteDevices(
  client: SupabaseClient,
  deviceIds: string[],
  fallbackToInactive = true,
): Promise<{ deleted: string[]; deactivated: string[]; failed: { id: string; error: string }[] }> {
  const deleted: string[] = [];
  const deactivated: string[] = [];
  const failed: { id: string; error: string }[] = [];

  for (const id of deviceIds) {
    try {
      await deleteDevice(client, id);
      deleted.push(id);
    } catch (err: unknown) {
      if (fallbackToInactive) {
        try {
          await updateDevice(client, id, { status: "inactive", dog_id: null });
          deactivated.push(id);
        } catch (innerErr: unknown) {
          failed.push({ id, error: (innerErr as Error).message ?? "Failed to deactivate" });
        }
      } else {
        failed.push({ id, error: (err as Error).message ?? "Delete failed" });
      }
    }
  }

  return { deleted, deactivated, failed };
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

export interface CreateDogInput {
  name: string;
  breed?: string | null;
  sex?: DogSex | null;
  birthdate?: string | null;
  weight_kg?: number | null;
  notes?: string | null;
  owner_user_id: string;
  clinic_id?: string | null;
  photo_path?: string | null;
}

export async function createDog(
  client: SupabaseClient,
  input: CreateDogInput,
): Promise<Dog> {
  const { data, error } = await client
    .from("dogs")
    .insert({
      name: input.name.trim(),
      breed: input.breed?.trim() || null,
      sex: input.sex || null,
      birthdate: input.birthdate || null,
      weight_kg: input.weight_kg != null && !isNaN(Number(input.weight_kg)) ? Number(input.weight_kg) : null,
      notes: input.notes?.trim() || null,
      owner_user_id: input.owner_user_id,
      clinic_id: input.clinic_id || null,
      photo_path: input.photo_path || null,
    })
    .select("*")
    .single();
  if (error) throw error;
  return data as unknown as Dog;
}

export async function updateDog(
  client: SupabaseClient,
  dogId: string,
  patch: Partial<CreateDogInput>,
): Promise<Dog> {
  const payload: Record<string, unknown> = {};
  if (patch.name !== undefined) payload.name = patch.name.trim();
  if (patch.breed !== undefined) payload.breed = patch.breed?.trim() || null;
  if (patch.sex !== undefined) payload.sex = patch.sex || null;
  if (patch.birthdate !== undefined) payload.birthdate = patch.birthdate || null;
  if (patch.weight_kg !== undefined) {
    payload.weight_kg = patch.weight_kg != null && !isNaN(Number(patch.weight_kg)) ? Number(patch.weight_kg) : null;
  }
  if (patch.notes !== undefined) payload.notes = patch.notes?.trim() || null;
  if (patch.owner_user_id !== undefined) payload.owner_user_id = patch.owner_user_id;
  if (patch.clinic_id !== undefined) payload.clinic_id = patch.clinic_id || null;
  if (patch.photo_path !== undefined) payload.photo_path = patch.photo_path || null;

  const { data, error } = await client
    .from("dogs")
    .update(payload)
    .eq("id", dogId)
    .select("*")
    .single();
  if (error) throw error;
  return data as unknown as Dog;
}

export async function deleteDog(client: SupabaseClient, dogId: string): Promise<void> {
  // 1. Try server-side RPC first (security definer atomic cascade delete)
  const { error: rpcError } = await client.rpc("admin_delete_dog", { p_dog_id: dogId });
  if (!rpcError) return;

  // 2. Fallback: Unlink device and delete dog
  await client.from("devices").update({ dog_id: null }).eq("dog_id", dogId);

  await Promise.allSettled([
    client.from("alerts").delete().eq("dog_id", dogId),
    client.from("vet_notes").delete().eq("dog_id", dogId),
    client.from("handover_notes").delete().eq("dog_id", dogId),
    client.from("media_submissions").delete().eq("dog_id", dogId),
    client.from("dog_baselines").delete().eq("dog_id", dogId),
    client.from("stress_classifications").delete().eq("dog_id", dogId),
    client.from("telemetry_readings").delete().eq("dog_id", dogId),
  ]);

  const { error } = await client.from("dogs").delete().eq("id", dogId);
  if (error) throw friendlyDeleteError(error, "telemetry history or media submissions");
}

export async function bulkDeleteDogs(
  client: SupabaseClient,
  dogIds: string[],
): Promise<{ success: string[]; failed: { id: string; error: string }[] }> {
  // Try atomic bulk RPC first
  const { error: rpcError } = await client.rpc("admin_bulk_delete_dogs", { p_dog_ids: dogIds });
  if (!rpcError) {
    return { success: dogIds, failed: [] };
  }

  // Fallback sequential
  const success: string[] = [];
  const failed: { id: string; error: string }[] = [];

  for (const id of dogIds) {
    try {
      await deleteDog(client, id);
      success.push(id);
    } catch (err: unknown) {
      failed.push({ id, error: (err as Error).message ?? "Delete failed" });
    }
  }

  return { success, failed };
}

/** Admin can also (re)assign a dog's clinic (docs/04 clinic linkage note). */
export async function updateDogClinic(
  client: SupabaseClient,
  dogId: string,
  clinicId: string | null,
): Promise<Dog> {
  return updateDog(client, dogId, { clinic_id: clinicId });
}

export interface AdminInefficiencies {
  unassignedActiveDevices: Device[];
  unassignedDogs: Dog[];
  staleDevices: Device[];
  inactiveUsers: User[];
}

export function calculateAdminInefficiencies(
  devices: Device[],
  dogs: Dog[],
  users: User[],
): AdminInefficiencies {
  const fourteenDaysAgo = Date.now() - 14 * 24 * 60 * 60 * 1000;

  const unassignedActiveDevices = devices.filter((d) => d.status === "active" && !d.dog_id);
  const unassignedDogs = dogs.filter((d) => !d.clinic_id);
  const staleDevices = devices.filter((d) => {
    if (d.status === "offline") return true;
    if (!d.last_seen_at) return true;
    return new Date(d.last_seen_at).getTime() < fourteenDaysAgo;
  });
  const inactiveUsers = users.filter((u) => u.is_active === false);

  return {
    unassignedActiveDevices,
    unassignedDogs,
    staleDevices,
    inactiveUsers,
  };
}

