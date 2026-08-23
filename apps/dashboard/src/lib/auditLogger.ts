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
