#!/usr/bin/env node
// Generates platform token files from packages/shared/design_tokens.json (docs/19):
//   - apps/dashboard/src/styles/tokens.css      (CSS custom properties)
//   - apps/dashboard/tailwind.tokens.js         (Tailwind theme extension + Tremor-compatible color scales)
//   - apps/mobile/lib/theme/furfeel_tokens.dart (Flutter constants)
//   - apps/mobile/android/.../res/values{,-night}/colors.xml (Android splash)
// Run from anywhere: node packages/shared/scripts/generate_design_tokens.mjs

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, "..", "..", "..");
const tokens = JSON.parse(readFileSync(join(here, "..", "design_tokens.json"), "utf8"));

const HEADER = "GENERATED from packages/shared/design_tokens.json — do not edit by hand.\nRegenerate with: node packages/shared/scripts/generate_design_tokens.mjs";

const kebab = (s) => s.replace(/([a-z0-9])([A-Z])/g, "$1-$2").toLowerCase();

// ---------- color math (for Tremor/Tailwind shade scales) ----------
const hexToRgb = (hex) => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));
const rgbToHex = (rgb) =>
  "#" + rgb.map((c) => Math.round(Math.min(255, Math.max(0, c))).toString(16).padStart(2, "0")).join("").toUpperCase();
const mix = (hex, otherRgb, amount) => {
  const rgb = hexToRgb(hex);
  return rgbToHex(rgb.map((c, i) => c + (otherRgb[i] - c) * amount));
};
const tint = (hex, amount) => mix(hex, [255, 255, 255], amount); // toward white
const shade = (hex, amount) => mix(hex, [15, 23, 42], amount); // toward ink (cool dark)

/** Tailwind-style 50–950 scale anchored at 500 = the token value. Tremor builds
 * class names like `stroke-brand-500`, so every chart color needs a scale. */
function scaleFromBase(hex) {
  return {
    50: tint(hex, 0.94),
    100: tint(hex, 0.86),
    200: tint(hex, 0.72),
    300: tint(hex, 0.52),
    400: tint(hex, 0.28),
    500: hex,
    600: shade(hex, 0.14),
    700: shade(hex, 0.3),
    800: shade(hex, 0.46),
    900: shade(hex, 0.62),
    950: shade(hex, 0.76),
    DEFAULT: hex,
  };
}

// ---------- CSS ----------
// ADDED: dark theme — color vars are emitted twice (light in :root, dark under
// [data-theme="dark"]) so the whole dashboard re-skins by flipping one attribute.
function colorVarLines(colorSet, indent = "  ") {
  const lines = [];
  for (const [k, v] of Object.entries(colorSet.base)) lines.push(`${indent}--ff-${kebab(k)}: ${v};`);
  for (const [k, v] of Object.entries(colorSet.brand)) lines.push(`${indent}--ff-${kebab(k)}: ${v};`);
  for (const [k, v] of Object.entries(colorSet.warm)) lines.push(`${indent}--ff-${kebab(k)}: ${v};`);
  for (const [level, c] of Object.entries(colorSet.status)) {
    lines.push(`${indent}--ff-status-${level}-fg: ${c.fg};`);
    lines.push(`${indent}--ff-status-${level}-bg: ${c.bg};`);
  }
  lines.push(`${indent}--ff-status-high-owner: ${colorSet.statusHighOwner};`);
  return lines;
}

function css() {
  const lines = colorVarLines(tokens.color);
  for (const [k, v] of Object.entries(tokens.radius.dashboard)) lines.push(`  --ff-radius-${k}: ${v}px;`);
  tokens.spacing.forEach((v, i) => lines.push(`  --ff-space-${i + 1}: ${v}px;`));
  lines.push(`  --ff-shadow-card: ${tokens.shadow.card};`);
  lines.push(`  --ff-font: '${tokens.font.family}', ${tokens.font.fallback};`);
  lines.push(`  --ff-motion-fast: ${tokens.motion.fastMs}ms;`);
  lines.push(`  --ff-motion-slow: ${tokens.motion.slowMs}ms;`);
  lines.push(`  --ff-motion-easing: ${tokens.motion.easing};`);
  lines.push(`  --ff-touch-target: ${tokens.touchTargetMinPx}px;`);
  for (const [name, t] of Object.entries(tokens.type)) {
    lines.push(`  --ff-type-${kebab(name)}-size: ${t.sizePx}px;`);
    lines.push(`  --ff-type-${kebab(name)}-weight: ${t.weight};`);
  }
  const dark = colorVarLines(tokens.colorDark);
  return (
    `/* ${HEADER.replace(/\n/g, "\n   ")} */\n:root {\n${lines.join("\n")}\n}\n\n` +
    `/* Dark theme (user_settings.theme): explicit opt-in wins... */\n` +
    `:root[data-theme="dark"] {\n${dark.join("\n")}\n  color-scheme: dark;\n}\n\n` +
    `/* ...and 'system' follows the OS (index.tsx only sets data-theme for light/dark). */\n` +
    `@media (prefers-color-scheme: dark) {\n  :root:not([data-theme="light"]):not([data-theme="dark"]) {\n${dark.map((l) => "  " + l).join("\n")}\n    color-scheme: dark;\n  }\n}\n`
  );
}

// ---------- Tailwind theme extension ----------
function tailwind() {
  const br = tokens.color.brand;
  const w = tokens.color.warm;
  // ADDED: semantic colors point at the CSS vars so utilities like bg-surface /
  // text-ink flip with [data-theme="dark"]. Numbered scales stay literal hex —
  // Tremor charts safelist them and chart hues are theme-stable by design.
  const colors = {
    bg: "var(--ff-bg)",
    surface: "var(--ff-surface)",
    "surface-alt": "var(--ff-surface-alt)",
    ink: "var(--ff-ink)",
    "ink-muted": "var(--ff-ink-muted)",
    hairline: "var(--ff-hairline)",
    brand: {
      ...scaleFromBase(br.brand),
      DEFAULT: "var(--ff-brand)",
      soft: "var(--ff-brand-soft)",
      strong: "var(--ff-brand-strong)",
      ink: "var(--ff-brand-ink)",
    },
    accent: { ...scaleFromBase(br.accent), DEFAULT: "var(--ff-accent)" },
    warm: { ...scaleFromBase(w.warm), DEFAULT: "var(--ff-warm)", soft: "var(--ff-warm-soft)" },
  };
  for (const [level, c] of Object.entries(tokens.color.status)) {
    colors[level] = {
      ...scaleFromBase(c.fg),
      DEFAULT: `var(--ff-status-${level}-fg)`,
      fg: `var(--ff-status-${level}-fg)`,
      soft: `var(--ff-status-${level}-bg)`,
    };
  }
  colors.high.owner = "var(--ff-status-high-owner)";

  const theme = {
    colors,
    fontFamily: { sans: [tokens.font.family, ...tokens.font.fallback.split(",").map((s) => s.trim())] },
    borderRadius: Object.fromEntries(
      Object.entries(tokens.radius.dashboard).map(([k, v]) => [k, `${v}px`]),
    ),
    boxShadow: { card: tokens.shadow.card },
    transitionDuration: { fast: `${tokens.motion.fastMs}ms`, slow: `${tokens.motion.slowMs}ms` },
  };
  return `/* eslint-disable */\n// ${HEADER.replace(/\n/g, "\n// ")}\nexport default ${JSON.stringify(theme, null, 2)};\n`;
}

// ---------- Dart ----------
const dartColor = (hex) => `Color(0xFF${hex.slice(1).toUpperCase()})`;

// Flatten a color set ({base, brand, warm, status, statusHighOwner}) into
// [name, hex] pairs using the Dart naming convention.
function dartColorEntries(colorSet) {
  const entries = [];
  for (const [k, v] of Object.entries(colorSet.base)) entries.push([k, v]);
  for (const [k, v] of Object.entries(colorSet.brand)) entries.push([k, v]);
  for (const [k, v] of Object.entries(colorSet.warm)) entries.push([k, v]);
  for (const [level, c] of Object.entries(colorSet.status)) {
    const cap = level[0].toUpperCase() + level.slice(1);
    entries.push([`status${cap}Fg`, c.fg]);
    entries.push([`status${cap}Bg`, c.bg]);
  }
  entries.push(["statusHighOwner", colorSet.statusHighOwner]);
  return entries;
}

function dart() {
  const lines = [];
  lines.push(`// ${HEADER.replace(/\n/g, "\n// ")}`);
  lines.push("");
  lines.push("import 'package:flutter/material.dart';");
  lines.push("");
  const light = dartColorEntries(tokens.color);
  const dark = dartColorEntries(tokens.colorDark);
  // ADDED: colors are a proper ThemeExtension now — theme flows through
  // context (context.ff.*), per-subtree theming works, and lerp gives free
  // cross-fades on theme change. The old FurFeelTokens.isDark static is gone.
  lines.push("/// FurFeel colors as a Material [ThemeExtension] (docs/19 Design Guide).");
  lines.push("/// Registered on [ThemeData.extensions] by buildFurFeelTheme; read it with");
  lines.push("/// `context.ff` (word + dot always, never color alone).");
  lines.push("class FurFeelPalette extends ThemeExtension<FurFeelPalette> {");
  lines.push("  const FurFeelPalette({");
  for (const [k] of light) lines.push(`    required this.${k},`);
  lines.push("  });");
  lines.push("");
  for (const [k] of light) lines.push(`  final Color ${k};`);
  lines.push("");
  const paletteLiteral = (entries) =>
    ["FurFeelPalette(", ...entries.map(([k, v]) => `    ${k}: ${dartColor(v)},`), "  )"].join("\n");
  lines.push(`  static const light = ${paletteLiteral(light)};`);
  lines.push("");
  lines.push(`  static const dark = ${paletteLiteral(dark)};`);
  lines.push("");
  lines.push("  @override");
  lines.push("  FurFeelPalette copyWith({");
  for (const [k] of light) lines.push(`    Color? ${k},`);
  lines.push("  }) =>");
  lines.push("      FurFeelPalette(");
  for (const [k] of light) lines.push(`        ${k}: ${k} ?? this.${k},`);
  lines.push("      );");
  lines.push("");
  lines.push("  @override");
  lines.push("  FurFeelPalette lerp(FurFeelPalette? other, double t) {");
  lines.push("    if (other == null) return this;");
  lines.push("    return FurFeelPalette(");
  for (const [k] of light) lines.push(`      ${k}: Color.lerp(${k}, other.${k}, t)!,`);
  lines.push("    );");
  lines.push("  }");
  lines.push("}");
  lines.push("");
  lines.push("/// `context.ff.brand` — the palette for the ambient theme. Falls back to");
  lines.push("/// light when no FurFeel theme is installed (e.g. bare-widget tests).");
  lines.push("extension FurFeelPaletteContext on BuildContext {");
  lines.push("  FurFeelPalette get ff =>");
  lines.push("      Theme.of(this).extension<FurFeelPalette>() ?? FurFeelPalette.light;");
  lines.push("}");
  lines.push("");
  lines.push("/// FurFeel non-color design tokens (docs/19 Design Guide).");
  lines.push("abstract final class FurFeelTokens {");
  lines.push("  // Radius (mobile set — rounder and friendlier than the dashboard)");
  for (const [k, v] of Object.entries(tokens.radius.mobile)) {
    lines.push(`  static const double radius${k[0].toUpperCase() + k.slice(1)} = ${v};`);
  }
  lines.push("");
  lines.push(`  // Spacing scale (${tokens.spacing.join(" / ")})`);
  lines.push(`  static const List<double> spacing = [${tokens.spacing.join(", ")}];`);
  tokens.spacing.forEach((v, i) => lines.push(`  static const double space${i + 1} = ${v};`));
  lines.push("");
  lines.push("  // Elevation: soft and low — hairline borders + subtle shadow");
  lines.push("  static const List<BoxShadow> shadowCard = [");
  lines.push("    BoxShadow(color: Color(0x0F0F172A), offset: Offset(0, 1), blurRadius: 2),");
  lines.push("    BoxShadow(color: Color(0x0D0F172A), offset: Offset(0, 4), blurRadius: 12),");
  lines.push("  ];");
  lines.push("");
  lines.push("  // Typography scale");
  for (const [name, t] of Object.entries(tokens.type)) {
    const cap = name[0].toUpperCase() + name.slice(1);
    lines.push(`  static const double type${cap}Size = ${t.sizePx};`);
    lines.push(`  static const FontWeight type${cap}Weight = FontWeight.w${t.weight};`);
  }
  lines.push(`  static const double labelLetterSpacing = ${tokens.type.label.letterSpacingPx};`);
  lines.push("");
  lines.push("  // Motion: calm and quick, ease-out");
  lines.push(`  static const Duration motionFast = Duration(milliseconds: ${tokens.motion.fastMs});`);
  lines.push(`  static const Duration motionSlow = Duration(milliseconds: ${tokens.motion.slowMs});`);
  lines.push("");
  lines.push(`  static const double touchTargetMin = ${tokens.touchTargetMinPx};`);
  lines.push("}");
  lines.push("");
  return lines.join("\n");
}

/** Android's launch screen is drawn by the OS before Flutter starts, so it
 * can't read the Dart tokens — it needs real color resources. Only the two
 * values the splash theme uses are emitted; everything else stays in Dart. */
function androidColors(palette) {
  return [
    '<?xml version="1.0" encoding="utf-8"?>',
    ...HEADER.split("\n").map((line) => `<!-- ${line} -->`),
    "<resources>",
    `    <color name="splash_background">${palette.base.bg}</color>`,
    `    <color name="brand">${palette.brand.brand}</color>`,
    "</resources>",
    "",
  ].join("\n");
}

const cssPath = join(repoRoot, "apps", "dashboard", "src", "styles", "tokens.css");
const twPath = join(repoRoot, "apps", "dashboard", "tailwind.tokens.js");
const dartPath = join(repoRoot, "apps", "mobile", "lib", "theme", "furfeel_tokens.dart");
mkdirSync(dirname(cssPath), { recursive: true });
mkdirSync(dirname(dartPath), { recursive: true });
writeFileSync(cssPath, css());
writeFileSync(twPath, tailwind());
writeFileSync(dartPath, dart());

const androidRes = join(repoRoot, "apps", "mobile", "android", "app", "src", "main", "res");
for (const [dir, palette] of [["values", tokens.color], ["values-night", tokens.colorDark]]) {
  const p = join(androidRes, dir, "colors.xml");
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, androidColors(palette));
  console.log(`wrote ${p}`);
}
console.log(`wrote ${cssPath}`);
console.log(`wrote ${twPath}`);
console.log(`wrote ${dartPath}`);
