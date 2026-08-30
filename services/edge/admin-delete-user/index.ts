// admin-delete-user — deletes or deactivates ANY user's account, called from dashboard
// Admin > Users tab. Scoped to admin callers managing other accounts.
import { createClient } from "npm:@supabase/supabase-js@2";
import { createServiceRoleClient } from "../_shared/supabase-client.ts";
import { corsHeaders, handleCors } from "../_shared/cors.ts";
import { logAuditEvent } from "../_shared/audit.ts";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

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
    return json(403, { error: "Only admins can manage account status." });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "Request body must be valid JSON." });
  }

  const { userId, mode = "auto", reassignOwnerId, reactivate } = (body ?? {}) as {
    userId?: string;
    mode?: "auto" | "deactivate" | "hard";
    reassignOwnerId?: string;
    reactivate?: boolean;
  };

  if (typeof userId !== "string" || userId.trim() === "") {
    return json(400, { error: "userId is required." });
  }

  if (userId === callerData.user.id) {
    return json(400, { error: "You can't modify your own account status from here." });
  }

  const { data: target, error: targetError } = await admin
    .from("users")
    .select("name, is_active")
    .eq("id", userId)
    .single();
  if (targetError || !target) return json(404, { error: "That user no longer exists." });

  // Handle account Reactivation
  if (reactivate === true) {
    await admin.from("users").update({ is_active: true, deactivated_at: null }).eq("id", userId);
    await admin.auth.admin.updateUserById(userId, { ban_duration: "none" });

    await logAuditEvent(admin, {
      actorId: callerData.user.id,
      actorEmail: callerData.user.email ?? "admin@furfeel.local",
      actorRole: "admin",
      surface: "edge_function",
      action: "user.reactivate",
      targetResource: "users",
      targetId: userId,
      details: { reactivated_user_id: userId, target_name: target.name },
      severity: "info",
    });

    return json(200, { ok: true, action: "reactivated" });
  }

  // Handle Dog Reassignment if specified
  if (typeof reassignOwnerId === "string" && reassignOwnerId.trim() !== "") {
    const { data: newOwner, error: newOwnerError } = await admin
      .from("users")
      .select("id, name")
      .eq("id", reassignOwnerId)
      .single();
    if (newOwnerError || !newOwner) {
      return json(404, { error: "The target new owner for dog reassignment does not exist." });
    }

    const { error: reassignError } = await admin
      .from("dogs")
      .update({ owner_user_id: reassignOwnerId })
      .eq("owner_user_id", userId);

    if (reassignError) {
      return json(500, { error: `Failed to reassign dog profiles to ${newOwner.name}.` });
    }
  }

  // Execute Complete Hard Cascade Purge if explicitly requested
  if (mode === "hard") {
    // 1. Get all dog IDs owned by this user
    const { data: userDogs } = await admin
      .from("dogs")
      .select("id")
      .eq("owner_user_id", userId);

    const dogIds = (userDogs ?? []).map((d) => d.id);

    if (dogIds.length > 0) {
      // Unassign devices from these dogs
      await admin.from("devices").update({ dog_id: null }).in("dog_id", dogIds);

      // Delete telemetry readings, classifications, alerts, notes, media for these dogs
      const { data: readings } = await admin
        .from("telemetry_readings")
        .select("id")
        .in("dog_id", dogIds);
      const readingIds = (readings ?? []).map((r) => r.id);
      if (readingIds.length > 0) {
        await admin.from("stress_classifications").delete().in("telemetry_reading_id", readingIds);
      }

      await admin.from("stress_classifications").delete().in("dog_id", dogIds);
      await admin.from("telemetry_readings").delete().in("dog_id", dogIds);
      await admin.from("alerts").delete().in("dog_id", dogIds);
      await admin.from("vet_notes").delete().in("dog_id", dogIds);
      await admin.from("media_submissions").delete().in("dog_id", dogIds);
      await admin.from("dog_baselines").delete().in("dog_id", dogIds);

      // Delete the dogs themselves
      await admin.from("dogs").delete().eq("owner_user_id", userId);
    }

    // 2. Delete user-authored or acknowledged records across the system
    await admin.from("vet_notes").delete().eq("author_user_id", userId);
    await admin.from("media_submissions").delete().eq("submitted_by_user_id", userId);
    await admin.from("media_submissions").update({ reviewed_by_user_id: null }).eq("reviewed_by_user_id", userId);
    await admin.from("alerts").update({ acknowledged_by: null }).eq("acknowledged_by", userId);

    // 3. Delete auth user (cascades to public.users -> user_settings, push_tokens)
    const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
    if (deleteError) {
      // If auth delete returns error, purge public.users directly using service role
      const { error: dbDeleteError } = await admin.from("users").delete().eq("id", userId);
      if (dbDeleteError) {
        return json(500, { error: `Failed to purge user ${target.name}: ${dbDeleteError.message}` });
      }
      await admin.auth.admin.deleteUser(userId).catch(() => null);
    }

    await logAuditEvent(admin, {
      actorId: callerData.user.id,
      actorEmail: callerData.user.email ?? "admin@furfeel.local",
      actorRole: "admin",
      surface: "edge_function",
      action: "user.delete",
      targetResource: "users",
      targetId: userId,
      details: { deleted_user_id: userId, target_name: target.name, mode: "hard_cascade" },
      severity: "warning",
    });

    return json(200, { ok: true, action: "deleted" });
  }

  // Check remaining dog ownership for auto / deactivate modes
  const { count: dogCount, error: dogCountError } = await admin
    .from("dogs")
    .select("id", { count: "exact", head: true })
    .eq("owner_user_id", userId);
  if (dogCountError) return json(500, { error: "Could not check the account's data." });

  if ((dogCount ?? 0) > 0 && (!reassignOwnerId || reassignOwnerId.trim() === "")) {
    return json(409, {
      error: `${target.name} still owns ${dogCount} dog profile(s) — reassign or remove ` +
        "those first, or select a new owner in the deletion dialog.",
    });
  }

  // Default: Soft Delete / Deactivate Account
  await admin.auth.admin.updateUserById(userId, { ban_duration: "876000h" });

  const { error: deactivateError } = await admin
    .from("users")
    .update({
      is_active: false,
      deactivated_at: new Date().toISOString(),
      clinic_id: null,
    })
    .eq("id", userId);

  if (deactivateError) {
    return json(500, { error: "Failed to deactivate user row in database." });
  }

  await logAuditEvent(admin, {
    actorId: callerData.user.id,
    actorEmail: callerData.user.email ?? "admin@furfeel.local",
    actorRole: "admin",
    surface: "edge_function",
    action: "user.deactivate",
    targetResource: "users",
    targetId: userId,
    details: { deactivated_user_id: userId, target_name: target.name, mode: "deactivate" },
    severity: "warning",
  });

  return json(200, { ok: true, action: "deactivated" });
});
