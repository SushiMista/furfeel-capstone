// LIVE cross-tenant RLS proof (Capstone security evidence).
//
// Creates throwaway users + data against a real Supabase project, then proves
// with actual queries that: an owner reaches only their own dogs, clinic staff
// only their clinic's dogs, anon nothing, owners can't write clinical records,
// and private storage objects follow the same rules. Everything it creates is
// deleted at the end (dogs are removed before users so delete-account
// guardrails don't block cleanup).
//
// It needs credentials, so it SKIPS unless you opt in:
//
//   cd services/edge && \
//   RLS_LIVE=1 SUPABASE_URL=... SUPABASE_ANON_KEY=... SUPABASE_SERVICE_ROLE_KEY=... \
//   deno test --allow-read --allow-env --allow-net rls_audit/rls_live.test.ts
//
// Run it against the hosted project (safe: it only touches rows it creates)
// or a local `supabase start` stack. The plain CI suite runs the static
// policy_audit.test.ts instead.

import { assert, assertEquals } from "jsr:@std/assert@1";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

const canReadEnv = (await Deno.permissions.query({ name: "env" })).state === "granted";
const env = (k: string) => (canReadEnv ? Deno.env.get(k) : undefined);
const enabled = env("RLS_LIVE") === "1" &&
  !!env("SUPABASE_URL") && !!env("SUPABASE_ANON_KEY") && !!env("SUPABASE_SERVICE_ROLE_KEY");

if (!enabled) {
  console.log(
    "\n  ⏭  rls_live: SKIPPED (set RLS_LIVE=1 + SUPABASE_URL + SUPABASE_ANON_KEY + " +
      "SUPABASE_SERVICE_ROLE_KEY and add --allow-env --allow-net to run the live cross-tenant proof)\n",
  );
}

Deno.test({
  name: "LIVE RLS: cross-tenant isolation, role boundaries, storage",
  ignore: !enabled,
  fn: async (t) => {
    const url = env("SUPABASE_URL")!;
    const anonKey = env("SUPABASE_ANON_KEY")!;
    const admin = createClient(url, env("SUPABASE_SERVICE_ROLE_KEY")!, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const stamp = Date.now();
    const password = `rls-test-${stamp}-Aa1!`;
    const mail = (who: string) => `rls-${who}-${stamp}@example.com`;

    const createdUserIds: string[] = [];
    async function makeUser(who: string, role: string, clinicId: string | null) {
      const { data, error } = await admin.auth.admin.createUser({
        email: mail(who),
        password,
        email_confirm: true,
        user_metadata: { name: `RLS ${who}` },
      });
      if (error) throw new Error(`createUser ${who}: ${error.message}`);
      const id = data.user!.id;
      createdUserIds.push(id);
      const { error: uerr } = await admin.from("users")
        .update({ role, clinic_id: clinicId }).eq("id", id);
      if (uerr) throw new Error(`set role ${who}: ${uerr.message}`);
      return id;
    }

    async function signIn(who: string): Promise<SupabaseClient> {
      const c = createClient(url, anonKey, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
      const { error } = await c.auth.signInWithPassword({ email: mail(who), password });
      if (error) throw new Error(`signIn ${who}: ${error.message}`);
      return c;
    }

    // ---- fixture: two clinics, two owners, staff on each clinic, one dog each
    const ins = async (table: string, row: Record<string, unknown>) => {
      const { data, error } = await admin.from(table).insert(row).select("id").single();
      if (error) throw new Error(`insert ${table}: ${error.message}`);
      return (data as { id: string }).id;
    };

    const clinic1 = await ins("clinics", { name: `RLS Clinic One ${stamp}` });
    const clinic2 = await ins("clinics", { name: `RLS Clinic Two ${stamp}` });
    const ownerA = await makeUser("ownerA", "owner", null);
    const ownerB = await makeUser("ownerB", "owner", null);
    await makeUser("staff1", "vet_staff", clinic1);
    await makeUser("staff2", "vet_staff", clinic2);

    const dogA = await ins("dogs", { owner_user_id: ownerA, clinic_id: clinic1, name: "RLS DogA" });
    const dogB = await ins("dogs", { owner_user_id: ownerB, clinic_id: clinic2, name: "RLS DogB" });
    const deviceA = await ins("devices", { dog_id: dogA, device_code: `RLS-DEV-${stamp}` });
    const readingA = await ins("telemetry_readings", {
      device_id: deviceA,
      dog_id: dogA,
      captured_at: new Date().toISOString(),
      heart_rate_bpm: 95,
      raw_payload: { rls: "test" },
    });
    await ins("alerts", {
      dog_id: dogA,
      severity: "warning",
      type: "moderate_stress",
      message: "RLS test alert",
    });
    const mediaPath = `dogs/${dogA}/rls-${stamp}.jpg`;
    {
      const { error } = await admin.storage.from("media")
        .upload(mediaPath, new Blob([new Uint8Array([0xff, 0xd8, 0xff])]), {
          contentType: "image/jpeg",
        });
      if (error) throw new Error(`storage seed: ${error.message}`);
    }

    const a = await signIn("ownerA");
    const b = await signIn("ownerB");
    const s1 = await signIn("staff1");
    const s2 = await signIn("staff2");
    const anon = createClient(url, anonKey, { auth: { persistSession: false } });

    const rows = async (c: SupabaseClient, table: string, col: string, id: string) => {
      const { data, error } = await c.from(table).select("id").eq(col, id);
      if (error) return `ERROR:${error.code ?? error.message}`;
      return (data ?? []).length;
    };

    try {
      await t.step("anon sees no dogs, telemetry, alerts, or users", async () => {
        for (const [table, col] of [["dogs", "id"], ["telemetry_readings", "dog_id"], ["alerts", "dog_id"]]) {
          const r = await rows(anon, table, col, table === "dogs" ? dogA : dogA);
          assert(r === 0 || String(r).startsWith("ERROR"), `anon reached ${table}: ${r}`);
        }
        const u = await rows(anon, "users", "id", ownerA);
        assert(u === 0 || String(u).startsWith("ERROR"), `anon reached users: ${u}`);
      });

      await t.step("owner A sees own dog + telemetry; owner B sees neither", async () => {
        assertEquals(await rows(a, "dogs", "id", dogA), 1, "ownerA should see dogA");
        assertEquals(await rows(a, "telemetry_readings", "id", readingA), 1);
        assertEquals(await rows(b, "dogs", "id", dogA), 0, "ownerB must NOT see dogA");
        assertEquals(await rows(b, "telemetry_readings", "id", readingA), 0);
        assertEquals(await rows(a, "dogs", "id", dogB), 0, "ownerA must NOT see dogB");
      });

      await t.step("clinic staff see only their clinic's dogs", async () => {
        assertEquals(await rows(s1, "dogs", "id", dogA), 1, "staff1 should see clinic1's dogA");
        assertEquals(await rows(s1, "dogs", "id", dogB), 0, "staff1 must NOT see clinic2's dogB");
        assertEquals(await rows(s2, "dogs", "id", dogA), 0, "staff2 must NOT see clinic1's dogA");
        assertEquals(await rows(s1, "telemetry_readings", "id", readingA), 1);
        assertEquals(await rows(s2, "telemetry_readings", "id", readingA), 0);
      });

      await t.step("owners cannot write clinical records (vet_notes, stress_labels)", async () => {
        const { error: vn } = await a.from("vet_notes")
          .insert({ dog_id: dogA, author_user_id: ownerA, note: "owner should not write this" });
        assert(vn !== null, "owner inserted a vet note — vet_notes_insert_clinic_staff failed");
        const { error: sl } = await a.from("stress_labels")
          .insert({ dog_id: dogA, vet_user_id: ownerA, confirmed_level: "calm" });
        assert(sl !== null, "owner inserted a stress label — clinic-staff-only policy failed");
      });

      await t.step("staff of the right clinic CAN write a vet note; wrong clinic cannot", async () => {
        const staff1Id = (await s1.auth.getUser()).data.user!.id;
        const { error: ok } = await s1.from("vet_notes")
          .insert({ dog_id: dogA, author_user_id: staff1Id, note: "RLS test note" });
        assertEquals(ok, null, `staff1 blocked from own-clinic vet note: ${ok?.message}`);
        const staff2Id = (await s2.auth.getUser()).data.user!.id;
        const { error: no } = await s2.from("vet_notes")
          .insert({ dog_id: dogA, author_user_id: staff2Id, note: "cross-clinic note" });
        assert(no !== null, "staff2 wrote a vet note on another clinic's dog");
      });

      await t.step("consents are own-row only and append-only", async () => {
        const { error: ins1 } = await a.from("consents")
          .insert({ user_id: ownerA, policy_version: `rls-${stamp}` });
        assertEquals(ins1, null, `ownerA could not record own consent: ${ins1?.message}`);
        const { data: peek } = await b.from("consents").select("id").eq("user_id", ownerA);
        assertEquals((peek ?? []).length, 0, "ownerB read ownerA's consents");
        const { error: forged } = await b.from("consents")
          .insert({ user_id: ownerA, policy_version: `rls-forged-${stamp}` });
        assert(forged !== null, "ownerB inserted a consent for ownerA");
        const { data: afterDel } = await a.from("consents").delete()
          .eq("user_id", ownerA).eq("policy_version", `rls-${stamp}`).select("id");
        assertEquals((afterDel ?? []).length, 0, "consent rows must not be deletable (append-only)");
      });

      await t.step("storage: owner + right-clinic staff read the media object; others cannot", async () => {
        const dl = (c: SupabaseClient) => c.storage.from("media").download(mediaPath);
        assertEquals((await dl(a)).error, null, "ownerA blocked from own dog's media");
        assertEquals((await dl(s1)).error, null, "staff1 blocked from clinic dog's media");
        assert((await dl(b)).error !== null, "ownerB downloaded another owner's media");
        assert((await dl(s2)).error !== null, "staff2 downloaded another clinic's media");
        assert((await anon.storage.from("media").download(mediaPath)).error !== null,
          "anon downloaded private media");
      });

      console.log("\n  ✓ LIVE RLS proof complete: tenant isolation, role boundaries, and storage all held.\n");
    } finally {
      // ---- cleanup (children first; ADR-003 only protects real telemetry,
      // these are our own throwaway rows, removed via service role)
      await admin.storage.from("media").remove([mediaPath]);
      await admin.from("telemetry_readings").delete().eq("dog_id", dogA);
      await admin.from("alerts").delete().eq("dog_id", dogA);
      await admin.from("vet_notes").delete().eq("dog_id", dogA);
      await admin.from("devices").delete().eq("id", deviceA);
      await admin.from("consents").delete().eq("user_id", ownerA);
      await admin.from("dogs").delete().in("id", [dogA, dogB]);
      for (const id of createdUserIds) await admin.auth.admin.deleteUser(id);
      await admin.from("clinics").delete().in("id", [clinic1, clinic2]);
      await a.auth.signOut();
      await b.auth.signOut();
      await s1.auth.signOut();
      await s2.auth.signOut();
    }
  },
});
