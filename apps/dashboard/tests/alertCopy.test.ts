import { describe, expect, it } from "vitest";
import { alertDetails, alertHeadline, groupAlerts } from "../src/lib/alertCopy.ts";
import type { Alert } from "../../../packages/shared/types/index.ts";

const alert = (id: string, overrides: Partial<Alert> = {}) =>
  ({ id, dog_id: "dog-1", type: "high_stress", status: "open", ...overrides }) as Alert;

describe("alert wording", () => {
  it("uses a plain title, and none for unknown types", () => {
    expect(alertHeadline("device_offline")).toBe("Device stopped sending data");
    expect(alertHeadline("something_new")).toBeNull();
  });

  it("moves the device code and last seen time into the details", () => {
    expect(
      alertDetails("Device COLLAR-BOCHI stopped sending data (last seen 2026-09-17 05:39 PST)."),
    ).toBe("COLLAR-BOCHI · Last seen 2026-09-17 05:39 PST");
    expect(alertDetails("Bochi seems a bit stressed.")).toBe("Bochi seems a bit stressed.");
  });
});

describe("groupAlerts", () => {
  it("collapses repeats for one dog and keeps other dogs, types and statuses apart", () => {
    const groups = groupAlerts([
      alert("a"),
      alert("b", { dog_id: "dog-2" }),
      alert("c"),
      alert("d", { type: "device_offline" }),
      alert("e", { status: "resolved" }),
    ]);

    expect(groups.map((g) => g.latest.id)).toEqual(["a", "b", "d", "e"]);
    expect(groups[0].earlier.map((a) => a.id)).toEqual(["c"]);
  });
});
