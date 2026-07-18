import { describe, expect, it } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import { fetchSystemHealth } from "../src/lib/adminQueries.ts";

/** Same minimal fluent-chain fake as queries.test.ts, plus .gte for the
 * time-window count queries. */
function fakeQuery(result: { data: unknown; error: null; count?: number | null }) {
  const chain: Record<string, unknown> = {
    select: () => chain,
    eq: () => chain,
    gte: () => chain,
    order: () => chain,
    limit: () => chain,
    then: (onFulfilled: (v: typeof result) => unknown) => Promise.resolve(result).then(onFulfilled),
  };
  return chain;
}

describe("fetchSystemHealth", () => {
  it("assembles telemetry counts, latest reading time, and open alert count", async () => {
    const client = {
      from: (table: string) =>
        table === "telemetry_readings"
          ? fakeQuery({ data: [{ captured_at: "2026-07-14T09:40:08Z" }], error: null, count: 42 })
          : fakeQuery({ data: null, error: null, count: 3 }),
    } as unknown as SupabaseClient;

    expect(await fetchSystemHealth(client)).toEqual({
      telemetry_last_hour: 42,
      telemetry_last_24h: 42,
      last_telemetry_at: "2026-07-14T09:40:08Z",
      open_alerts: 3,
    });
  });
});
