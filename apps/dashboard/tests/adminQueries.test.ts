import { describe, expect, it, vi } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  createUserAccount,
  deleteClinic,
  deleteDevice,
  deleteUserAccount,
  fetchSystemHealth,
  updateClinic,
} from "../src/lib/adminQueries.ts";

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

describe("createUserAccount", () => {
  it("invokes admin-create-user with the form fields and returns the created row", async () => {
    const invoke = vi.fn().mockResolvedValue({
      data: { id: "u1", name: "Dr. Kevin", email: "dockevin@vet.com", role: "veterinarian", clinic_id: "c1", created_at: "2026-07-18T00:00:00Z" },
      error: null,
    });
    const client = { functions: { invoke } } as unknown as SupabaseClient;

    const user = await createUserAccount(client, {
      name: "Dr. Kevin",
      email: "dockevin@vet.com",
      password: "temp-password-1",
      role: "veterinarian",
      clinicId: "c1",
    });

    expect(invoke).toHaveBeenCalledWith("admin-create-user", {
      body: {
        email: "dockevin@vet.com",
        password: "temp-password-1",
        name: "Dr. Kevin",
        role: "veterinarian",
        clinicId: "c1",
      },
    });
    expect(user.role).toBe("veterinarian");
  });

  it("surfaces the function's JSON error body (e.g. non-admin caller rejected)", async () => {
    const invoke = vi.fn().mockResolvedValue({
      data: null,
      error: {
        message: "Edge Function returned a non-2xx status code",
        context: { json: async () => ({ error: "Only admins can create accounts." }) },
      },
    });
    const client = { functions: { invoke } } as unknown as SupabaseClient;

    await expect(
      createUserAccount(client, {
        name: "x",
        email: "x@example.com",
        password: "abcdefg",
        role: "admin",
        clinicId: null,
      }),
    ).rejects.toThrow("Only admins can create accounts.");
  });
});

describe("deleteUserAccount", () => {
  it("invokes admin-delete-user with the target id", async () => {
    const invoke = vi.fn().mockResolvedValue({ data: { ok: true }, error: null });
    const client = { functions: { invoke } } as unknown as SupabaseClient;

    await deleteUserAccount(client, "u1");

    expect(invoke).toHaveBeenCalledWith("admin-delete-user", { body: { userId: "u1" } });
  });

  it("surfaces the function's JSON error body (e.g. an owner who still owns dogs)", async () => {
    const invoke = vi.fn().mockResolvedValue({
      data: null,
      error: {
        message: "Edge Function returned a non-2xx status code",
        context: { json: async () => ({ error: "Jamie still owns 2 dog profile(s) — reassign or remove those first." }) },
      },
    });
    const client = { functions: { invoke } } as unknown as SupabaseClient;

    await expect(deleteUserAccount(client, "u1")).rejects.toThrow("Jamie still owns 2 dog profile(s)");
  });
});

/** Fluent update/delete chain fake — enough for the plain RLS-backed
 * clinic/device mutations (no Edge Function involved). */
function fakeMutation(result: { data: unknown; error: unknown }) {
  const chain: Record<string, unknown> = {
    update: () => chain,
    delete: () => chain,
    eq: () => chain,
    select: () => chain,
    single: async () => result,
    then: (onFulfilled: (v: typeof result) => unknown) => Promise.resolve(result).then(onFulfilled),
  };
  return chain;
}

describe("updateClinic", () => {
  it("patches the given fields and returns the updated row", async () => {
    const client = {
      from: () => fakeMutation({ data: { id: "c1", name: "New Name", address: null, contact_number: null, created_at: "t" }, error: null }),
    } as unknown as SupabaseClient;

    const clinic = await updateClinic(client, "c1", { name: "New Name" });
    expect(clinic.name).toBe("New Name");
  });
});

describe("deleteClinic / deleteDevice (FK-guard rewording)", () => {
  it("rewords a Postgres FK violation (23503) into a friendly message", async () => {
    const client = {
      from: () => fakeMutation({ data: null, error: { code: "23503", message: "violates foreign key constraint" } }),
    } as unknown as SupabaseClient;

    await expect(deleteClinic(client, "c1")).rejects.toThrow(
      "Still linked to staff or dogs — reassign or remove those first.",
    );
  });

  it("rewords a device's FK violation with the telemetry-specific hint", async () => {
    const client = {
      from: () => fakeMutation({ data: null, error: { code: "23503", message: "violates foreign key constraint" } }),
    } as unknown as SupabaseClient;

    await expect(deleteDevice(client, "d1")).rejects.toThrow(/telemetry history/);
  });

  it("passes through a non-FK error message unchanged", async () => {
    const client = {
      from: () => fakeMutation({ data: null, error: { message: "network error" } }),
    } as unknown as SupabaseClient;

    await expect(deleteClinic(client, "c1")).rejects.toThrow("network error");
  });

  it("deletes cleanly when there is no error", async () => {
    const client = { from: () => fakeMutation({ data: null, error: null }) } as unknown as SupabaseClient;
    await expect(deleteDevice(client, "d1")).resolves.toBeUndefined();
  });
});
