import { describe, expect, it } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import { acknowledgeAlert, fetchDogs, fetchMonitoringBoardRowForDog, sortBoardRows } from "../src/lib/queries.ts";
import type { Dog } from "../../../packages/shared/types/index.ts";

/** Minimal fake of the fluent PostgrestFilterBuilder chain: chainable + thenable, and
 * supports .maybeSingle() for the single-row queries. Good enough to unit-test how
 * queries.ts assembles results without hitting a real Supabase project. */
function fakeQuery(result: { data: unknown; error: null; count?: number | null }) {
  const chain: Record<string, unknown> = {
    select: () => chain,
    eq: () => chain,
    order: () => chain,
    limit: () => chain,
    maybeSingle: async () => ({ data: result.data, error: null }),
    // Awaiting the chain itself = a list query; wrap single-row fixture data.
    then: (onFulfilled: (v: typeof result) => unknown) =>
      Promise.resolve({
        ...result,
        data:
          result.data == null || Array.isArray(result.data) ? result.data : [result.data],
      }).then(onFulfilled),
  };
  return chain;
}

function fakeClient(tables: Record<string, unknown>): SupabaseClient {
  return { from: (table: string) => tables[table] } as unknown as SupabaseClient;
}

const DOG: Dog = {
  id: "dog-1",
  owner_user_id: "user-1",
  clinic_id: "clinic-1",
  name: "Biscuit",
  breed: "Golden Retriever",
  birthdate: "2022-03-15",
  sex: "male",
  weight_kg: 28.5,
  notes: null,
  photo_path: null,
  created_at: "2026-01-01T00:00:00Z",
};

describe("fetchDogs", () => {
  it("returns the dogs array from a resolved query", async () => {
    const client = fakeClient({ dogs: fakeQuery({ data: [DOG], error: null }) });
    const dogs = await fetchDogs(client);
    expect(dogs).toEqual([DOG]);
  });

  it("returns an empty array when data is null", async () => {
    const client = fakeClient({ dogs: fakeQuery({ data: null, error: null }) });
    expect(await fetchDogs(client)).toEqual([]);
  });
});

describe("fetchMonitoringBoardRowForDog", () => {
  it("assembles device, latest reading, latest classification, and open alert count", async () => {
    const client = fakeClient({
      devices: fakeQuery({
        data: {
          id: "device-1",
          dog_id: "dog-1",
          device_code: "FURFEEL-DEV-0001",
          status: "active",
          last_seen_at: "2026-07-10T17:00:00Z",
          firmware_version: "0.1.0",
          created_at: "2026-01-01T00:00:00Z",
        },
        error: null,
      }),
      telemetry_readings: fakeQuery({
        data: {
          id: "reading-1",
          device_id: "device-1",
          dog_id: "dog-1",
          captured_at: "2026-07-10T17:00:00Z",
          received_at: "2026-07-10T17:00:01Z",
          heart_rate_bpm: 95,
          body_temperature_c: 38.6,
          respiratory_rate_bpm: 22,
          motion_activity: 0.3,
          posture: "standing",
          ambient_temperature_c: 24,
          humidity_percent: 55,
          is_valid: true,
          raw_payload: {},
        },
        error: null,
      }),
      stress_classifications: fakeQuery({
        data: {
          id: "class-1",
          dog_id: "dog-1",
          telemetry_reading_id: "reading-1",
          stress_level: "calm",
          score: 0,
          confidence: null,
          reasons: [],
          model_version: "rule-v1",
          created_at: "2026-07-10T17:00:02Z",
        },
        error: null,
      }),
      alerts: fakeQuery({ data: null, error: null, count: 2 }),
    });

    const row = await fetchMonitoringBoardRowForDog(client, DOG);

    expect(row.dog).toBe(DOG);
    expect(row.device?.status).toBe("active");
    expect(row.latestReading?.heart_rate_bpm).toBe(95);
    expect(row.latestClassification?.stress_level).toBe("calm");
    expect(row.openAlertCount).toBe(2);
    expect(row.recentLevels).toEqual(["calm"]); // mini-trend feed
  });

  it("handles a dog with no device, no readings, and no alerts", async () => {
    const client = fakeClient({
      devices: fakeQuery({ data: null, error: null }),
      telemetry_readings: fakeQuery({ data: null, error: null }),
      stress_classifications: fakeQuery({ data: null, error: null }),
      alerts: fakeQuery({ data: null, error: null, count: 0 }),
    });

    const row = await fetchMonitoringBoardRowForDog(client, DOG);

    expect(row.device).toBeNull();
    expect(row.latestReading).toBeNull();
    expect(row.latestClassification).toBeNull();
    expect(row.openAlertCount).toBe(0);
  });
});

describe("sortBoardRows", () => {
  function boardRow(name: string, level: "calm" | "mild" | "moderate" | "high" | null) {
    return {
      dog: { ...DOG, id: `dog-${name}`, name },
      device: null,
      latestReading: null,
      latestClassification: level
        ? {
            id: `c-${name}`,
            dog_id: `dog-${name}`,
            telemetry_reading_id: "r-1",
            stress_level: level,
            score: 1,
            confidence: null,
            reasons: [],
            model_version: "rule-v1",
            created_at: "2026-07-11T00:00:00Z",
          }
        : null,
      openAlertCount: 0,
      recentLevels: [],
    };
  }

  it("floats anything above calm to the top, highest stress first", () => {
    const rows = [
      boardRow("Calm Carl", "calm"),
      boardRow("High Hank", "high"),
      boardRow("Mild Millie", "mild"),
      boardRow("Moderate Moe", "moderate"),
    ];
    const sorted = sortBoardRows(rows);
    expect(sorted.map((r) => r.dog.name)).toEqual([
      "High Hank",
      "Moderate Moe",
      "Mild Millie",
      "Calm Carl",
    ]);
  });

  it("puts unclassified dogs after calm ones and does not mutate the input", () => {
    const rows = [boardRow("Newbie", null), boardRow("Calm Carl", "calm")];
    const sorted = sortBoardRows(rows);
    expect(sorted.map((r) => r.dog.name)).toEqual(["Calm Carl", "Newbie"]);
    expect(rows.map((r) => r.dog.name)).toEqual(["Newbie", "Calm Carl"]);
  });

  it("breaks ties by dog name for a stable board", () => {
    const rows = [boardRow("Ziggy", "calm"), boardRow("Apollo", "calm")];
    expect(sortBoardRows(rows).map((r) => r.dog.name)).toEqual(["Apollo", "Ziggy"]);
  });
});

describe("acknowledgeAlert", () => {
  it("returns the updated row and sends acknowledged fields", async () => {
    const captured: Record<string, unknown>[] = [];
    const updatedRow = { id: "a1", status: "acknowledged", acknowledged_by: "user-1" };
    const chain: Record<string, unknown> = {
      update: (values: Record<string, unknown>) => {
        captured.push(values);
        return chain;
      },
      eq: () => chain,
      select: () => chain,
      maybeSingle: async () => ({ data: updatedRow, error: null }),
    };
    const client = fakeClient({ alerts: chain });

    const result = await acknowledgeAlert(client, "a1", "user-1");
    expect(result).toEqual(updatedRow);
    expect(captured).toHaveLength(1);
    expect(captured[0].status).toBe("acknowledged");
    expect(captured[0].acknowledged_by).toBe("user-1");
    expect(captured[0].acknowledged_at).toEqual(expect.any(String));
  });

  it("returns null when the alert was no longer open (raced another acknowledger)", async () => {
    const chain: Record<string, unknown> = {
      update: () => chain,
      eq: () => chain,
      select: () => chain,
      maybeSingle: async () => ({ data: null, error: null }),
    };
    const client = fakeClient({ alerts: chain });
    expect(await acknowledgeAlert(client, "a1", "user-1")).toBeNull();
  });
});
