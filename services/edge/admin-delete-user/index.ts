// admin-delete-user — deletes ANY user's account, called from the dashboard
// Admin > Users tab. Auth deletion needs the service role, so it lives
// server-side (mirrors delete-account, which only ever deletes the caller's
// own account); this one is scoped to admin callers deleting other accounts.
//
// Guards, checked before touching auth.users:
//  - an admin can't delete their own account through this panel. This is
//    also what keeps Admin from ever locking everyone out: the caller is
//    always a DIFFERENT admin than the target (self-delete is blocked), so
//    the caller is guaranteed to still be there after any deletion — a
//    dedicated "last admin" head-count is redundant given that invariant.
//  - a user who still owns dog profiles can't be deleted (dogs.owner_user_id
//    is NOT NULL with no cascade — and per ADR-003 raw telemetry is never
//    deleted, so cascading through an owner's monitoring history isn't an
//    option here the way it might be for a self-service, no-history account)
import { createClient } from "npm:@supabase/supabase-js@2";
import { createServiceRoleClient } from "../_shared/supabase-client.ts";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "Method not allowed." });

  const jwt = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!jwt) return json(401, { error: "Not signed in." });

  const anon = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
  );
  const { data: callerData, error: callerError } = await anon.auth.getUser(jwt);
  if (callerError || !callerData.user) return json(401, { error: "Not signed in." });

  const admin = createServiceRoleClient();

  const { data: caller, error: callerRowError } = await admin
    .from("users")
    .select("role")
    .eq("id", callerData.user.id)
    .single();
  if (callerRowError || caller?.role !== "admin") {
    return json(403, { error: "Only admins can delete accounts." });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "Request body must be valid JSON." });
  }
  const { userId } = (body ?? {}) as Record<string, unknown>;
  if (typeof userId !== "string" || userId.trim() === "") {
    return json(400, { error: "userId is required." });
  }

  if (userId === callerData.user.id) {
    return json(400, { error: "You can't delete your own account from here." });
  }

  const { data: target, error: targetError } = await admin
    .from("users")
    .select("name")
    .eq("id", userId)
    .single();
  if (targetError || !target) return json(404, { error: "That user no longer exists." });

  const { count: dogCount, error: dogCountError } = await admin
    .from("dogs")
    .select("id", { count: "exact", head: true })
    .eq("owner_user_id", userId);
  if (dogCountError) return json(500, { error: "Could not check the account's data." });
  if ((dogCount ?? 0) > 0) {
    return json(409, {
      error: `${target.name} still owns ${dogCount} dog profile(s) — reassign or remove ` +
        "those first (Admin > Devices > dog-clinic assignment doesn't change ownership; " +
        "the owner's mobile app can transfer or delete a dog).",
    });
  }

  // Cascades to public.users (FK on delete cascade) → user_settings, push_tokens, etc.
  // Any remaining FK reference (authored vet notes, acknowledged alerts, reviewed
  // media) blocks the cascade and surfaces here as a generic DB error.
  const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
  if (deleteError) {
    return json(409, {
      error: `${target.name} still has linked records (vet notes, alerts, or media ` +
        "reviews) and can't be deleted while those exist.",
    });
  }

  return json(200, { ok: true });
});
