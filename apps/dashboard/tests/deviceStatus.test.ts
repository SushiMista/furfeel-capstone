import { describe, expect, it } from "vitest";
import { collarRank, collarState, needsAttention } from "../src/lib/deviceStatus.ts";

const collar = (status: "active" | "offline" | "maintenance", battery_percent: number | null, dog_id: string | null) => ({
  status,
  battery_percent,
  dog_id,
});

describe("collar status", () => {
  it("flags offline and low-battery collars", () => {
    expect(needsAttention(collar("offline", 54, "d"))).toBe(true);
    expect(needsAttention(collar("active", 15, "d"))).toBe(true);
    expect(needsAttention(collar("active", 16, "d"))).toBe(false);
    expect(needsAttention(collar("active", null, "d"))).toBe(false);
  });

  it("gives the reason in plain words", () => {
    expect(collarState(collar("offline", 54, "d"))).toBe("Stopped sending data");
    expect(collarState(collar("active", 10, "d"))).toBe("Low battery");
    expect(collarState(collar("maintenance", 90, "d"))).toBe("Maintenance");
    expect(collarState(collar("active", 90, null))).toBe("Not assigned to a dog");
    expect(collarState(collar("active", 90, "d"))).toBe("Active");
  });

  it("ranks problems, then unassigned, then the rest", () => {
    const ranks = [collar("active", 90, "d"), collar("active", 90, null), collar("offline", 90, "d")].map(collarRank);
    expect(ranks).toEqual([2, 1, 0]);
  });
});
