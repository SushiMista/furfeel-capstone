import { SupabaseClient } from "npm:@supabase/supabase-js@2";

export interface AuditEventInput {
  actorId?: string | null;
  actorEmail: string;
  actorRole: "owner" | "vet_staff" | "veterinarian" | "admin" | "system";
  surface: "dashboard" | "mobile" | "edge_function" | "system";
  action: string;
  targetResource: string;
  targetId?: string | null;
  clinicId?: string | null;
  details?: Record<string, unknown>;
  severity?: "info" | "warning" | "critical";
}

/**
 * Writes an audit event entry to public.audit_logs.
 * Errors are caught and logged to console to prevent blocking main edge function execution.
 */
export async function logAuditEvent(client: SupabaseClient, event: AuditEventInput): Promise<void> {
  try {
    await client.from("audit_logs").insert({
      actor_id: event.actorId ?? null,
      actor_email: event.actorEmail,
      actor_role: event.actorRole,
      surface: event.surface,
      action: event.action,
      target_resource: event.targetResource,
      target_id: event.targetId ?? null,
      clinic_id: event.clinicId ?? null,
      details: event.details ?? {},
      severity: event.severity ?? "info",
    });
  } catch (err) {
    console.error("Failed to record audit log:", err);
  }
}
