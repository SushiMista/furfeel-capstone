import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

/**
 * Guard for the devices COLUMN-level select grant (docs/09).
 *
 * Table-wide select on devices is revoked so ingest_key_hash is never
 * client-readable; clients may only name columns that appear in a
 * `grant select (...) on public.devices to authenticated` statement. A column
 * missing from the grant fails every client query naming it — this already
 * broke Home once (battery_percent, fixed in 20260718090000). This test makes
 * that a CI failure instead of a production one: it collects every granted
 * column from the migrations and checks each client's device column list
 * against it.
 */

// __dirname: vitest runs test files through a CJS-style transform under the
// jsdom environment (import.meta.url is not a file: URL there).
const repoRoot = join(__dirname, "..", "..", "..");

function grantedDeviceColumns(): Set<string> {
  const dir = join(repoRoot, "supabase", "migrations");
  const granted = new Set<string>();
  for (const file of readdirSync(dir)) {
    if (!file.endsWith(".sql")) continue;
    const sql = readFileSync(join(dir, file), "utf8");
    const re = /grant\s+select\s*\(([^)]+)\)\s*on\s+public\.devices\s+to\s+authenticated/gis;
    for (const m of sql.matchAll(re)) {
      for (const col of m[1].split(",")) granted.add(col.trim());
    }
  }
  return granted;
}

function expectColumnsGranted(list: string, source: string, granted: Set<string>) {
  const columns = list.split(",").map((c) => c.trim()).filter(Boolean);
  expect(columns.length, `${source}: empty device column list?`).toBeGreaterThan(0);
  for (const col of columns) {
    expect(
      granted.has(col),
      `${source} selects devices.${col}, which is NOT in any ` +
        "`grant select (...) on public.devices to authenticated` migration — " +
        "every client devices query would fail with a permission error. " +
        "Add the column to a grant migration (see 20260718090000) first.",
    ).toBe(true);
  }
}

describe("devices column-level select grant (docs/09)", () => {
  const granted = grantedDeviceColumns();

  it("found the grant statements in the migrations", () => {
    expect(granted.has("id")).toBe(true);
    expect(granted.has("ingest_key_hash")).toBe(false);
  });

  it("covers every dashboard DEVICE_COLUMNS list", () => {
    const dir = join(repoRoot, "apps", "dashboard", "src", "lib");
    let found = 0;
    for (const file of readdirSync(dir)) {
      const src = readFileSync(join(dir, file), "utf8");
      for (const m of src.matchAll(/DEVICE_COLUMNS\s*=\s*"([^"]+)"/g)) {
        found += 1;
        expectColumnsGranted(m[1], `dashboard ${file}`, granted);
      }
    }
    expect(found, "no DEVICE_COLUMNS constants found — did the queries move?").toBeGreaterThan(0);
  });

  it("covers the mobile repository's _deviceColumns list", () => {
    const src = readFileSync(
      join(repoRoot, "apps", "mobile", "lib", "data", "furfeel_repository.dart"),
      "utf8",
    );
    const m = src.match(/_deviceColumns\s*=\s*'([^']+)'/);
    expect(m, "mobile _deviceColumns constant not found — did the repository move?").toBeTruthy();
    expectColumnsGranted(m![1], "mobile furfeel_repository.dart", granted);
  });

  it("no client ever uses select('*') on devices (grants make * fail)", () => {
    const scan = (dir: string, exts: RegExp) => {
      for (const entry of readdirSync(dir, { withFileTypes: true })) {
        const p = join(dir, entry.name);
        if (entry.isDirectory()) scan(p, exts);
        else if (exts.test(entry.name)) {
          const src = readFileSync(p, "utf8");
          const bad = /from\(["'`]devices["'`]\)\s*(?:\n\s*)?\.select\(["'`]\*/.test(src);
          expect(bad, `${p} selects * from devices — column grants reject *`).toBe(false);
        }
      }
    };
    scan(join(repoRoot, "apps", "dashboard", "src"), /\.tsx?$/);
    scan(join(repoRoot, "apps", "mobile", "lib"), /\.dart$/);
  });
});
