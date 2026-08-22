import { describe, expect, it } from "vitest";
import { formatAlertMessage, formatPhilippineTime } from "../src/lib/time.ts";

describe("time utility (Philippine Standard Time)", () => {
  it("formats ISO timestamps into Philippine Standard Time (PST, UTC+8)", () => {
    // 2026-08-22 17:16 UTC -> +8 hours -> 2026-08-23 01:16 PST
    const utcIso = "2026-08-22T17:16:00Z";
    const formatted = formatPhilippineTime(utcIso);
    expect(formatted).toContain("2026-08-23");
    expect(formatted).toContain("01:16");
    expect(formatted).toContain("PST");
  });

  it("replaces embedded UTC last-seen strings in alert messages with PST", () => {
    const rawMessage = "Device FURFEEL-DEV-0002 stopped sending data (last seen 2026-08-22 17:16 UTC).";
    const converted = formatAlertMessage(rawMessage);
    expect(converted).toBe("Device FURFEEL-DEV-0002 stopped sending data (last seen 2026-08-23 01:16 PST).");
  });
});
