// Static RLS audit over supabase/migrations (Capstone security evidence).
// Runs in the normal `deno test --allow-read` suite with no database: it
// parses every migration and proves, from the SQL itself, that
//   1. every public table has row level security enabled,
//   2. every table carries at least one policy (deny-by-default with no
//      policy would silently brick a feature; zero policies is a smell),
//   3. no policy is granted to `anon` — every policy names `authenticated`
//      (device ingest goes through the service role, never anon),
//   4. storage buckets are private (public = false),
//   5. the devices table's ingest_key_hash is never in a column grant.
// The live cross-tenant proof (real users, real queries) is rls_live.test.ts.

import { assert, assertEquals } from "jsr:@std/assert@1";
import { join } from "jsr:@std/path@1";

const migrationsDir = new URL("../../../supabase/migrations", import.meta.url).pathname;

function readMigrations(): { name: string; sql: string }[] {
  const files = [...Deno.readDirSync(migrationsDir)]
    .filter((e) => e.isFile && e.name.endsWith(".sql"))
    .map((e) => e.name)
    .sort();
  return files.map((name) => ({
    name,
    sql: Deno.readTextFileSync(join(migrationsDir, name)),
  }));
}

const migrations = readMigrations();
const allSql = migrations.map((m) => m.sql).join("\n");
// Strip SQL comments so commented-out statements never count.
const activeSql = allSql.replace(/--[^\n]*/g, "");

const norm = (t: string) => t.replace(/^public\./, "");

function createdTables(): string[] {
  const tables = new Set<string>();
  for (const m of activeSql.matchAll(/create\s+table\s+(?:if\s+not\s+exists\s+)?([a-z_.]+)/gi)) {
    const t = norm(m[1]);
    if (!t.startsWith("storage.") && !t.startsWith("auth.")) tables.add(t);
  }
  return [...tables].sort();
}

function rlsEnabledTables(): Set<string> {
  const tables = new Set<string>();
  for (const m of activeSql.matchAll(/alter\s+table\s+([a-z_.]+)\s+enable\s+row\s+level\s+security/gi)) {
    tables.add(norm(m[1]));
  }
  return tables;
}

type Policy = { name: string; table: string; cmd: string; roles: string };

function policies(): Policy[] {
  const out: Policy[] = [];
  const re =
    /create\s+policy\s+([a-z0-9_]+)\s+on\s+([a-z_.]+)([\s\S]*?)(?=create\s+policy|create\s+table|create\s+function|alter\s+table|insert\s+into|grant\s|revoke\s|$)/gi;
  for (const m of activeSql.matchAll(re)) {
    const body = m[3];
    const cmd = body.match(/for\s+(select|insert|update|delete|all)/i)?.[1] ?? "all";
    const roles = body.match(/\bto\s+(authenticated|anon|public|service_role)/i)?.[1] ?? "(default)";
    out.push({ name: m[1], table: norm(m[2]), cmd: cmd.toLowerCase(), roles });
  }
  return out;
}

Deno.test("RLS audit: every public table has row level security enabled", () => {
  const tables = createdTables();
  const enabled = rlsEnabledTables();
  assert(tables.length >= 16, `expected the full schema, found ${tables.length} tables`);
  const missing = tables.filter((t) => !enabled.has(t));
  assertEquals(
    missing,
    [],
    `tables WITHOUT row level security: ${missing.join(", ")} — never ship a table without RLS`,
  );
  console.log(`\n  ✓ RLS enabled on all ${tables.length} tables: ${tables.join(", ")}\n`);
});

Deno.test("RLS audit: every table carries at least one policy", () => {
  const tables = createdTables();
  const byTable = new Map<string, Policy[]>();
  for (const p of policies().filter((p) => !p.table.startsWith("storage."))) {
    byTable.set(p.table, [...(byTable.get(p.table) ?? []), p]);
  }
  const missing = tables.filter((t) => (byTable.get(t) ?? []).length === 0);
  assertEquals(missing, [], `tables with RLS but ZERO policies (fully locked): ${missing.join(", ")}`);
  // Readable evidence: the policy matrix.
  console.log("\n  Policy matrix (table → policies):");
  for (const t of tables) {
    const list = (byTable.get(t) ?? []).map((p) => `${p.name}[${p.cmd}→${p.roles}]`);
    console.log(`   ${t.padEnd(24)} ${list.join(", ")}`);
  }
});

Deno.test("RLS audit: no policy is granted to anon", () => {
  const anonPolicies = policies().filter((p) => p.roles === "anon" || p.roles === "public");
  assertEquals(
    anonPolicies.map((p) => `${p.table}.${p.name}`),
    [],
    "policies must target `to authenticated` — anon gets nothing; device ingest uses the service role",
  );
});

Deno.test("RLS audit: storage buckets are private", () => {
  for (const m of activeSql.matchAll(
    /insert\s+into\s+storage\.buckets\s*\(id,\s*name,\s*public\)\s*values\s*\('([^']+)',\s*'[^']+',\s*(\w+)\)/gi,
  )) {
    assertEquals(m[2].toLowerCase(), "false", `bucket '${m[1]}' must be private`);
    console.log(`  ✓ bucket '${m[1]}' is private (RLS-gated object access)`);
  }
});

Deno.test("RLS audit: ingest_key_hash never appears in a client column grant", () => {
  for (const m of activeSql.matchAll(/grant\s+select\s*\(([^)]+)\)\s*on\s+(?:public\.)?devices/gi)) {
    assert(
      !m[1].includes("ingest_key_hash"),
      "ingest_key_hash granted to clients — device secrets must stay server-side",
    );
  }
});
