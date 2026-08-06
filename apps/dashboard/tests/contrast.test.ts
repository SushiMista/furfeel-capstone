import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

/**
 * CI contrast check against the docs/19 tokens (accessibility pass, §9):
 * every pairing that renders as TEXT in either app must hit WCAG AA 4.5:1,
 * in both the light and dark palettes. Recomputed from design_tokens.json on
 * every run, so a token tweak that breaks readability fails CI, not a user.
 */

const tokens = JSON.parse(
  readFileSync(join(__dirname, "..", "..", "..", "packages", "shared", "design_tokens.json"), "utf8"),
);

function luminance(hex: string): number {
  const c = [1, 3, 5]
    .map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
    .map((v) => (v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)));
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}

export function contrastRatio(a: string, b: string): number {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
}

type ColorSet = {
  base: Record<string, string>;
  brand: Record<string, string>;
  warm: Record<string, string>;
  tint: Record<string, string>;
  status: Record<string, { fg: string; mid?: string; bg: string }>;
  statusHighOwner: string;
};

/** "$comment" keys document provenance in the token file — filter them out
 * before treating a group's values as colors. */
const swatches = <T>(group: Record<string, T>): [string, T][] =>
  Object.entries(group ?? {}).filter(([k]) => !k.startsWith("$"));

function textPairs(c: ColorSet, dark: boolean): [string, string, string][] {
  const pairs: [string, string, string][] = [
    ["ink on bg", c.base.ink, c.base.bg],
    ["ink on surface", c.base.ink, c.base.surface],
    ["inkMuted on bg", c.base.inkMuted, c.base.bg],
    ["inkMuted on surface", c.base.inkMuted, c.base.surface],
    ["brand link text on surface", c.brand.brand, c.base.surface],
    ["button label on brand", dark ? c.base.bg : c.base.surface, c.brand.brand],
    ["warm text on warmSoft", c.warm.warm, c.warm.warmSoft],
    ["warm text on surface", c.warm.warm, c.base.surface],
    // Teal accent family. `accent` itself is a FILL (chart series, dots, rings)
    // and is deliberately not asserted as text — `accentInk` is the text stop.
    ["accentInk on accentSoft", c.brand.accentInk, c.brand.accentSoft],
    ["accentInk on surface", c.brand.accentInk, c.base.surface],
    ["accentInk on bg", c.brand.accentInk, c.base.bg],
  ];
  // Pet names and captions sit directly on the tinted photo grounds.
  for (const [name, hex] of swatches(c.tint)) {
    pairs.push([`ink on ${name}`, c.base.ink, hex]);
  }
  for (const [level, s] of swatches(c.status)) {
    pairs.push([`status ${level} word on its soft bg`, s.fg, s.bg]);
    pairs.push([`status ${level} word on surface`, s.fg, c.base.surface]);
  }
  pairs.push(["owner high (coral) on high soft bg", c.statusHighOwner, c.status.high.bg]);
  pairs.push(["owner high (coral) on surface", c.statusHighOwner, c.base.surface]);
  return pairs;
}

describe("docs/19 token contrast (WCAG AA)", () => {
  for (const [mode, dark] of [["color", false], ["colorDark", true]] as const) {
    it(`${dark ? "dark" : "light"} palette: every text pairing ≥ 4.5:1`, () => {
      const failures: string[] = [];
      for (const [name, fg, bg] of textPairs(tokens[mode], dark)) {
        const r = contrastRatio(fg, bg);
        if (r < 4.5) failures.push(`${name}: ${fg} on ${bg} = ${r.toFixed(2)}`);
      }
      expect(failures, failures.join("\n")).toEqual([]);
    });
  }

  /**
   * Status `mid` stops fill bars and sparklines rather than setting type, so
   * they answer to WCAG 1.4.11 (non-text contrast, 3:1) instead of 4.5:1.
   * Without this a "calm" bar can wash out to invisible on a white card.
   */
  for (const [mode, dark] of [["color", false], ["colorDark", true]] as const) {
    it(`${dark ? "dark" : "light"} palette: every chart mid stop ≥ 3:1 on surface`, () => {
      const set = tokens[mode] as ColorSet;
      const failures: string[] = [];
      for (const [level, s] of swatches(set.status)) {
        if (!s.mid) continue;
        const r = contrastRatio(s.mid, set.base.surface);
        if (r < 3) failures.push(`${level} mid: ${s.mid} on ${set.base.surface} = ${r.toFixed(2)}`);
      }
      expect(failures, failures.join("\n")).toEqual([]);
    });
  }
});
