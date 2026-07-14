import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

/**
 * Service-role client for server-side Edge Function use only (bypasses RLS by design).
 * SUPABASE_SERVICE_ROLE_KEY must never reach a mobile/dashboard client (CLAUDE.md guardrail).
 */
export function createServiceRoleClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!url || !serviceRoleKey) {
    throw new Error(
      "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in the function's environment.",
    );
  }

  return createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
