import { describe, expect, it } from "vitest";
import { formatAlertMessage, formatPhilippineTime } from "../src/lib/time.ts";

describe("time utility (Philippine Standard Time)", () => {
  it("formats ISO timestamps into Philippine Standard Time (PHT, UTC+8)", () => {
    // 2026-08-22 17:16 UTC -> +8 hours -> August 23, 2026 at 1:16 AM
    const utcIso = "2026-08-22T17:16:00Z";
    const formatted = formatPhilippineTime(utcIso);
    expect(formatted).toBe("August 23, 2026 at 1:16 AM");
  });

  it("removes redundant embedded UTC last-seen strings in alert messages", () => {
    const rawMessage = "Device FURFEEL-DEV-0002 stopped sending data (last seen 2026-08-22 17:16 UTC).";
    const converted = formatAlertMessage(rawMessage);
    expect(converted).toBe("Device FURFEEL-DEV-0002 stopped sending data");
  });
});
