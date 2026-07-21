import { describe, expect, it } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import { fetchDogBaselines, saveDogThresholds } from "../src/lib/queries.ts";

/** Minimal fake of the fluent PostgrestFilterBuilder chain used by
 * fetchDogBaselines (select/eq/maybeSingle) and saveDogThresholds
 * (upsert/select/single) — same spirit as queries.test.ts's fakeQuery, with
 * upsert support added. */
function fakeBaselinesTable(row: unknown) {
  let lastUpsertPayload: unknown;
  const chain = {
    select: () => chain,
    eq: () => chain,
    maybeSingle: async () => ({ data: row, error: null }),
    single: async () => ({ data: row, error: null }),
    upsert: (payload: unknown) => {
      lastUpsertPayload = payload;
      return chain;
    },
  };
  return { chain, getLastUpsertPayload: () => lastUpsertPayload };
}

function fakeClient(table: unknown): SupabaseClient {
  return { from: () => table } as unknown as SupabaseClient;
}

describe("fetchDogBaselines", () => {
  it("returns null when the dog has no baselines row (every field falls back to global)", async () => {
    const { chain } = fakeBaselinesTable(null);
    const result = await fetchDogBaselines(fakeClient(chain), "dog-1");
    expect(result).toBeNull();
  });

  it("returns the row, including threshold overrides, when one exists", async () => {
    const row = {
      id: "b1",
      dog_id: "dog-1",
      resting_heart_rate_bpm: 100,
      resting_respiratory_rate_bpm: null,
      normal_body_temperature_c: null,
      threshold_mild_min: 1,
      threshold_moderate_min: 3,
      threshold_high_min: 5,
      updated_at: "2026-07-20T00:00:00Z",
    };
    const { chain } = fakeBaselinesTable(row);
    const result = await fetchDogBaselines(fakeClient(chain), "dog-1");
    expect(result).toEqual(row);
  });
});

describe("saveDogThresholds", () => {
  it("upserts only dog_id + the three threshold columns, leaving resting baselines untouched", async () => {
    const saved = {
      id: "b1",
      dog_id: "dog-1",
      resting_heart_rate_bpm: 100,
      resting_respiratory_rate_bpm: null,
      normal_body_temperature_c: null,
      threshold_mild_min: 1,
      threshold_moderate_min: 3,
      threshold_high_min: 5,
      updated_at: "2026-07-21T00:00:00Z",
    };
    const { chain, getLastUpsertPayload } = fakeBaselinesTable(saved);
    const result = await saveDogThresholds(fakeClient(chain), "dog-1", {
      threshold_mild_min: 1,
      threshold_moderate_min: 3,
      threshold_high_min: 5,
    });
    expect(result).toEqual(saved);
    expect(getLastUpsertPayload()).toEqual({
      dog_id: "dog-1",
      threshold_mild_min: 1,
      threshold_moderate_min: 3,
      threshold_high_min: 5,
    });
  });

  it("passes nulls through to reset a field back to the global default", async () => {
    const saved = {
      id: "b1",
      dog_id: "dog-1",
      resting_heart_rate_bpm: null,
      resting_respiratory_rate_bpm: null,
      normal_body_temperature_c: null,
      threshold_mild_min: null,
      threshold_moderate_min: null,
      threshold_high_min: null,
      updated_at: "2026-07-21T00:00:00Z",
    };
    const { chain, getLastUpsertPayload } = fakeBaselinesTable(saved);
    await saveDogThresholds(fakeClient(chain), "dog-1", {
      threshold_mild_min: null,
      threshold_moderate_min: null,
      threshold_high_min: null,
    });
    expect(getLastUpsertPayload()).toEqual({
      dog_id: "dog-1",
      threshold_mild_min: null,
      threshold_moderate_min: null,
      threshold_high_min: null,
    });
  });
});
