import { describe, expect, it } from "vitest";
import { render } from "@testing-library/react";
import { dogTint } from "../src/lib/dogTint.ts";
import { MicroSparkline } from "../src/components/MicroSparkline.tsx";

describe("dogTint", () => {
  it("is deterministic for a given id and picks from the four tints", () => {
    expect(dogTint("dog-1")).toBe(dogTint("dog-1"));
    const seen = new Set(
      ["a", "b", "c", "d", "e", "f", "g", "h"].map(dogTint),
    );
    for (const c of seen) {
      expect(["bg-tint-blue", "bg-tint-teal", "bg-tint-periwinkle", "bg-tint-slate"]).toContain(c);
    }
  });

  it("matches the Flutter _stableHash for a known id", () => {
    // stableHash("dog-1") = 95759328 → % 4 = 0 → blue. Pinned so the
    // cross-platform contract with Flutter's _stableHash can't drift.
    expect(dogTint("dog-1")).toBe("bg-tint-blue");
  });
});

describe("MicroSparkline", () => {
  it("renders nothing below two readings", () => {
    const { container } = render(<MicroSparkline series={[5]} />);
    expect(container.firstChild).toBeNull();
  });

  it("draws one bar per reading once there are two", () => {
    const { container } = render(<MicroSparkline series={[1, 2, 3, 0]} />);
    expect(container.querySelectorAll("span")).toHaveLength(4);
  });
});
