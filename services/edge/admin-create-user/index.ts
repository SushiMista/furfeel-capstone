// admin-create-user — creates a staff/owner account with role + clinic already
// set, called from the dashboard Admin > Users "Add user" form.
//
// Why this exists (not a plain client signUp): the hosted project requires
// email confirmation (no custom SMTP configured, so confirmation mail is
// unreliable) and a plain signUp can't set email_confirm. An admin picking
// the email and vouching for the account is a different trust boundary than
// a stranger self-registering, so admin-created accounts are auto-confirmed
// here; self-signup in the mobile/dashboard apps still requires confirmation.
import { createClient } from "npm:@supabase/supabase-js@2";
import { createServiceRoleClient } from "../_shared/supabase-client.ts";

const ROLES = new Set(["owner", "vet_staff", "veterinarian", "admin"]);

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

  // Caller must be an admin — never trust the client's own claim of role.
  const { data: caller, error: callerRowError } = await admin
    .from("users")
    .select("role")
    .eq("id", callerData.user.id)
    .single();
  if (callerRowError || caller?.role !== "admin") {
    return json(403, { error: "Only admins can create accounts." });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "Request body must be valid JSON." });
  }
  const { name, email, password, role, clinicId } = (body ?? {}) as Record<string, unknown>;

  if (typeof name !== "string" || name.trim() === "") {
    return json(400, { error: "Name is required." });
  }
  if (typeof email !== "string" || email.trim() === "") {
    return json(400, { error: "Email is required." });
  }
  if (typeof password !== "string" || password.length < 6) {
    return json(400, { error: "Password must be at least 6 characters." });
  }
  if (typeof role !== "string" || !ROLES.has(role)) {
    return json(400, { error: "Invalid role." });
  }
  if (clinicId !== null && typeof clinicId !== "string") {
    return json(400, { error: "Invalid clinic." });
  }

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email: email.trim(),
    password,
    email_confirm: true, // admin vouches for the address — see file header
    user_metadata: { name: name.trim() },
  });
  if (createError || !created.user) {
    const message = createError?.message ?? "Could not create the account.";
    const status = /already.*registered|already exists/i.test(message) ? 409 : 400;
    return json(status, { error: message });
  }

  // handle_new_user already inserted the owner-role row; set role + clinic now.
  const { data: updated, error: updateError } = await admin
    .from("users")
    .update({ role, clinic_id: clinicId })
    .eq("id", created.user.id)
    .select("id, name, email, role, clinic_id, created_at")
    .single();
  if (updateError) {
    return json(500, { error: "Account created but role assignment failed — try Admin > Users." });
  }

  return json(200, updated);
});
