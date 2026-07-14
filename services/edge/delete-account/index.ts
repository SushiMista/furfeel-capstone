// delete-account — deletes the CALLER's account (docs/04 Profile/Account).
// Auth deletion needs the service role, so it lives server-side; the caller is
// identified strictly from their own JWT — no user id is accepted as input.
//
// Raw telemetry is never deleted (ADR-003): if any of the account's dogs have
// monitoring history, deletion is refused with a friendly explanation instead
// of cascading through clinic records.
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

  // Validate the JWT with the anon client; the service role never trusts input.
  const anon = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
  );
  const { data: userData, error: userError } = await anon.auth.getUser(jwt);
  if (userError || !userData.user) return json(401, { error: "Not signed in." });
  const userId = userData.user.id;

  const admin = createServiceRoleClient();

  const { data: dogs, error: dogsError } = await admin
    .from("dogs")
    .select("id")
    .eq("owner_user_id", userId);
  if (dogsError) return json(500, { error: "Could not check the account's data." });

  const dogIds = (dogs ?? []).map((d) => d.id);
  if (dogIds.length > 0) {
    const { count, error: telemetryError } = await admin
      .from("telemetry_readings")
      .select("id", { count: "exact", head: true })
      .in("dog_id", dogIds);
    if (telemetryError) return json(500, { error: "Could not check the account's data." });
    if ((count ?? 0) > 0) {
      return json(409, {
        error:
          "This account's dogs already have monitoring history, which FurFeel keeps " +
          "for the clinic record — the account can't be deleted automatically. " +
          "Please contact your clinic to close the account.",
      });
    }

    // No history: release paired devices, then remove the profiles.
    await admin.from("devices").update({ dog_id: null, status: "inactive" }).in("dog_id", dogIds);
    await admin.from("dog_baselines").delete().in("dog_id", dogIds);
    const { error: dogDeleteError } = await admin.from("dogs").delete().in("id", dogIds);
    if (dogDeleteError) return json(500, { error: "Could not delete the account's dogs." });
  }

  // Cascades to public.users (FK on delete cascade) → user_settings, push_tokens.
  const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
  if (deleteError) return json(500, { error: "Could not delete the account — please try again." });

  return json(200, { ok: true });
});
