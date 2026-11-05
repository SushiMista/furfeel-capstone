import { readFileSync } from "node:fs";
import { join } from "node:path";
import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it } from "vitest";
import { deleteDog } from "../src/lib/adminQueries.ts";

// Raw telemetry is never deleted (ADR-003, ADR-027).
describe("deleting a dog keeps its telemetry", () => {
  it("leaves telemetry_readings alone when the RPC is unavailable", async () => {
    const touched: string[] = [];
    const result = { error: null };
    const query = { update: () => query, delete: () => query, eq: () => Promise.resolve(result) };
    const client = {
      rpc: async () => ({ error: { message: "missing" } }),
      from: (table: string) => {
        touched.push(table);
        return query;
      },
    } as unknown as SupabaseClient;

    await deleteDog(client, "dog-1");

    expect(touched).toContain("dogs");
    expect(touched).not.toContain("telemetry_readings");
  });

  it("does not delete telemetry in the RPCs or keep the cascade", () => {
    const sql = readFileSync(
      join(__dirname, "..", "..", "..", "supabase", "migrations", "20261105140000_keep_telemetry_on_dog_delete.sql"),
      "utf8",
    );
    expect(sql).toContain("drop constraint telemetry_readings_dog_id_fkey");
    expect(sql).not.toMatch(/delete from public\.telemetry_readings/);
  });
});
