// Tailwind theme is assembled from the GENERATED token file (tailwind.tokens.js),
// which comes from packages/shared/design_tokens.json (docs/19). No hex here.
import ff from "./tailwind.tokens.js";

const c = ff.colors;

/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{ts,tsx}",
    "./node_modules/@tremor/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      fontFamily: ff.fontFamily,
      borderRadius: {
        ...ff.borderRadius,
        "tremor-small": ff.borderRadius.sm,
        "tremor-default": ff.borderRadius.md,
        "tremor-full": ff.borderRadius.pill,
      },
      boxShadow: {
        ...ff.boxShadow,
        "tremor-input": ff.boxShadow.card,
        "tremor-card": ff.boxShadow.card,
        "tremor-dropdown": ff.boxShadow.card,
      },
      transitionDuration: ff.transitionDuration,
      colors: {
        ...c,
        // Tremor component theme (light), mapped onto FurFeel tokens.
        tremor: {
          brand: {
            faint: c.brand[50],
            muted: c.brand[200],
            subtle: c.brand[400],
            DEFAULT: c.brand[500],
            emphasis: c.brand[700],
            inverted: c.surface,
          },
          background: {
            muted: c.bg,
            subtle: c["surface-alt"],
            DEFAULT: c.surface,
            emphasis: c.ink,
          },
          border: { DEFAULT: c.hairline },
          ring: { DEFAULT: c.hairline },
          content: {
            subtle: c["ink-muted"],
            DEFAULT: c["ink-muted"],
            emphasis: c.ink,
            strong: c.ink,
            inverted: c.surface,
          },
        },
      },
      fontSize: {
        "tremor-label": ["0.75rem", { lineHeight: "1rem" }],
        "tremor-default": ["0.875rem", { lineHeight: "1.25rem" }],
        "tremor-title": ["1.125rem", { lineHeight: "1.75rem" }],
        "tremor-metric": ["1.875rem", { lineHeight: "2.25rem" }],
      },
    },
  },
  // Tremor builds chart class names dynamically (e.g. stroke-brand-500), so the
  // token color scales must be safelisted for the JIT compiler.
  safelist: [
    {
      pattern:
        /^(bg|stroke|fill|text|border|ring)-(brand|accent|calm|mild|moderate|high|warm)-(50|100|200|300|400|500|600|700|800|900|950)$/,
      variants: ["hover", "ui-selected"],
    },
  ],
  plugins: [],
};
