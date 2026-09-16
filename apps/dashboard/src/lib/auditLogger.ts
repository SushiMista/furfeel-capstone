import { supabase } from "./supabaseClient.ts";

export interface AuditLogRecord {
  id: string;
  created_at: string;
  actor_id: string | null;
  actor_email: string;
  actor_role: "owner" | "vet_staff" | "veterinarian" | "admin" | "system";
  surface: "dashboard" | "mobile" | "edge_function" | "system";
  action: string;
  target_resource: string;
  target_id: string | null;
  clinic_id: string | null;
  details: Record<string, unknown>;
  severity: "info" | "warning" | "critical";
}

export interface NewAuditLogEntry {
  actor_id?: string | null;
  actor_email?: string;
  actor_role: "owner" | "vet_staff" | "veterinarian" | "admin" | "system";
  surface: "dashboard" | "mobile" | "edge_function" | "system";
  action: string;
  target_resource: string;
  target_id?: string | null;
  clinic_id?: string | null;
  details?: Record<string, unknown>;
  severity?: "info" | "warning" | "critical";
}

/**
 * Persists an audit log event into public.audit_logs.
 * Dispatches asynchronously so caller performance is not impacted.
 */
export async function recordAuditLog(entry: NewAuditLogEntry): Promise<void> {
  try {
    const { data: userData } = await supabase.auth.getUser();
    const user = userData.user;

    const actorId = entry.actor_id ?? user?.id ?? null;
    const actorEmail = entry.actor_email || user?.email || "system@furfeel.local";

    await supabase.from("audit_logs").insert({
      actor_id: actorId,
      actor_email: actorEmail,
      actor_role: entry.actor_role,
      surface: entry.surface,
      action: entry.action,
      target_resource: entry.target_resource,
      target_id: entry.target_id ?? null,
      clinic_id: entry.clinic_id ?? null,
      details: entry.details ?? {},
      severity: entry.severity ?? "info",
    });
  } catch (err) {
    console.error("Failed to record audit log:", err);
  }
}

/**
 * Fetches audit logs for the Admin Audit Logs panel.
 */
export async function fetchAuditLogs(options?: {
  surface?: string;
  role?: string;
  severity?: string;
  search?: string;
  limit?: number;
}): Promise<AuditLogRecord[]> {
  let query = supabase
    .from("audit_logs")
    .select("*")
    .order("created_at", { ascending: false });

  if (options?.limit) {
    query = query.limit(options.limit);
  } else {
    query = query.limit(200);
  }

  if (options?.surface && options.surface !== "all") {
    query = query.eq("surface", options.surface);
  }

  if (options?.role && options.role !== "all") {
    query = query.eq("actor_role", options.role);
  }

  if (options?.severity && options.severity !== "all") {
    query = query.eq("severity", options.severity);
  }

  if (options?.search && options.search.trim() !== "") {
    const term = `%${options.search.trim()}%`;
    query = query.or(`actor_email.ilike.${term},action.ilike.${term},target_resource.ilike.${term}`);
  }

  const { data, error } = await query;
  if (error) {
    console.error("Error fetching audit logs:", error);
    return [];
  }

  return (data ?? []) as AuditLogRecord[];
}

/**
 * Fetches pending device deletion requests submitted by clinic staff/vets.
 */
export async function fetchPendingDeviceDeletionRequests(): Promise<
  Map<string, { reason: string; requestedAt: string; requestedBy: string }>
> {
  const { data, error } = await supabase
    .from("audit_logs")
    .select("target_id, details, created_at, actor_email")
    .eq("action", "device.deletion_requested")
    .order("created_at", { ascending: false });

  const map = new Map<string, { reason: string; requestedAt: string; requestedBy: string }>();
  if (error || !data) return map;
  for (const row of data) {
    if (row.target_id && !map.has(row.target_id)) {
      const details = (row.details ?? {}) as Record<string, unknown>;
      map.set(row.target_id, {
        reason: (details.reason as string) || "No reason specified",
        requestedAt: (details.requested_at as string) || row.created_at,
        requestedBy: (details.requested_by as string) || row.actor_email,
      });
    }
  }
  return map;
}
