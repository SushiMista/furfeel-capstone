---
title: "FurFeel Design Guide"
type: design-system
project: FurFeel
created: 2026-07-11
updated: 2026-07-11
tags: [furfeel, design, ui, brand, design-guide]
---

# FurFeel Design Guide

> Single source of truth for how FurFeel looks and feels across the **owner mobile app (Flutter)** and the **veterinary dashboard (React)**. Grounded in the manuscript's own interface trade-off study (Chapter 3), which selected **Design 1** and recommended blending in Designs 2 and 3.

## 0. Design DNA (from the manuscript)
- **Design 1 — selected primary.** Minimalist, clean, lightweight; reduces visual clutter; fast. **Blue + white** primary colors chosen to signal *healthcare, calm, and technological reliability.* → This is the FurFeel brand baseline.
- **Design 2 — clinical.** Organized biometric panels, health-trend visualizations, multi-dog/kennel monitoring, alerts; gray/blue/white professional palette. → Applied to the **veterinary dashboard**.
- **Design 3 — approachable.** Interactive, modern, notification-forward, simplified visualizations for non-technical owners; warm accents. → Applied to the **owner mobile app**.

**Synthesis:** one **blue-and-white** brand. The dashboard leans clinical and dense (Design 2); the owner app leans warm and reassuring (Design 3) — but both share the same tokens, type, and status colors so they read as one product.

## 1. Reference systems we borrow from
Proven, open, legitimately reusable patterns — not clones:
- **React dashboard:** [shadcn/ui](https://ui.shadcn.com) (Radix primitives + Tailwind, copy-paste ownership) as the component base, **[Tremor](https://www.tremor.so)** for KPI cards, charts, and data tables (purpose-built for monitoring dashboards). Icons: [lucide](https://lucide.dev).
- **Flutter mobile:** **Material 3** (`useMaterial3: true`) with `ColorScheme.fromSeed`, `google_fonts`, and `fl_chart` for graphs.
- **Aesthetic north stars:** the clean minimalism of Linear / Vercel Geist and Apple HIG (mobile) — generous whitespace, restrained color, strong typographic hierarchy.

## 2. Color tokens
Put these in `packages/shared/design_tokens.json`; generate the dashboard CSS variables and the Flutter theme from it. **Never hardcode hex in components.**

### Brand (blue + white)
| Token | Hex | Use |
|---|---|---|
| `brand` | `#2563EB` | primary blue — buttons, active nav, links, focus |
| `brand-strong` | `#1D4ED8` | hover / pressed |
| `brand-ink` | `#1E3A8A` | headings accent, deep brand |
| `brand-soft` | `#EAF1FE` | selected rows, chips, tinted panels |
| `accent` | `#14B8A6` | teal — secondary/positive, "healthy" states |

### Neutrals (clean, cool)
| Token | Hex | Use |
|---|---|---|
| `bg` | `#F7F9FC` | app background (cool off-white) |
| `surface` | `#FFFFFF` | cards, panels |
| `surface-alt` | `#F1F5F9` | table stripes, subtle panels |
| `ink` | `#0F172A` | primary text |
| `ink-muted` | `#64748B` | secondary text, labels, axis |
| `hairline` | `#E2E8F0` | dividers, card borders (1px) |

### Owner-app warmth (Design 3 accent layer)
| Token | Hex | Use |
|---|---|---|
| `warm` | `#9A6407` | friendly highlights, streaks, encouragement (darkened 2026-07-19 so warm **text** passes 4.5:1 on `warm-soft` and white — §9) |
| `warm-soft` | `#FEF3E2` | warm tinted cards on the owner app only |

### Stress status ramp (accessible, one canonical ramp)
Pair color with **word + dot/icon** always — never color alone.

> Contrast-verified 2026-07-19: every `fg` below reads at **≥ 4.5:1** on its soft bg *and* on white/`bg` (the §9 requirement — the original brighter shades failed as text). CI enforces this: `apps/dashboard/tests/contrast.test.ts` recomputes the ratios from `design_tokens.json` on every run.

| Level | text/icon | soft bg | notes |
|---|---|---|---|
| `calm` | `#0C7C6F` teal-green | `#E6F6F3` | reassuring, "normal" |
| `mild` | `#956603` amber | `#FBF3D6` | gentle heads-up |
| `moderate` | `#A85311` orange | `#FCEBD9` | attention |
| `high` | `#CA2323` red | `#FBE4E2` | urgent (dashboard uses full red; owner app may soften to coral `#B74231` for a less alarming feel — both from tokens) |

## 3. Typography
- **Font:** **Inter** across both surfaces (clean, neutral, excellent at small sizes for dense clinical data; pairs natively with shadcn/Tremor). Flutter via `google_fonts` (Inter). Numbers use tabular figures for aligned vitals.
- **Scale:** display 30/700 · h1 24/700 · h2 20/600 · h3 16/600 · body 15/400 · label 12/600 (0.4 tracking, uppercase small labels) · caption 12/400.
- **Data emphasis:** vitals are the hero — big value (28–32/700 tabular) + small unit label + muted timestamp.
- Dashboard density can be one step tighter than mobile; mobile bumps body to 16 and touch targets to ≥44px.

## 4. Shape · spacing · elevation
- **Radius:** dashboard `sm 8 / md 12 / lg 16`; mobile `md 16 / lg 20 / pill 999`. Mobile is rounder and friendlier; dashboard is crisper.
- **Spacing scale:** 4 / 8 / 12 / 16 / 24 / 32 / 48.
- **Elevation:** soft, low. Cards: `0 1px 2px rgba(15,23,42,.06), 0 4px 12px rgba(15,23,42,.05)`. Prefer `hairline` borders + subtle shadow over heavy drop shadows. Clinical = flatter; mobile = slightly more lift.

## 5. Motion
Calm and quick. 150–250ms ease-out. Stress-level color changes **cross-fade**, never snap. New-alert entrance: gentle slide+fade, one soft pulse for `high`, never a jarring flash. Respect reduced-motion.

### 5a. Owner-app motion & polish (Flutter)
The owner app should feel alive but calm — a health app, not a game. Use `flutter_animate` for declarative motion; always honor reduced-motion (`MediaQuery.disableAnimations` → fall back to instant).
- **Entrance:** Home cards stagger fade + slide-up (≈40–60ms stagger, 250ms) on load and tab switch.
- **Stress pill:** cross-fade color + a single soft scale-pulse only when the *level changes* (not every reading).
- **Vitals:** `AnimatedSwitcher` count-up/fade when a value updates; never flicker.
- **Dog avatar:** `Hero` transition between Home and detail/profile.
- **Loading:** shimmer skeletons shaped like the real cards (not spinners).
- **Refresh:** pull-to-refresh with a gentle custom indicator.
- **Trend chart:** animate the line drawing in (fl_chart) on first paint.
- **Micro-interactions:** 0.98 press-scale on tappables; light haptic on Acknowledge + successful actions; smooth route/tab transitions.
- **Optional:** a subtle Lottie mood illustration reflecting the dog's state (calm/alert).
- **Empty states:** friendly illustration + one line — never a bare spinner or "no data".
Keep every animation short and gentle; motion should reassure, never distract.

## 6. Data visualization
- Line/area charts for vitals over time; stress timeline as a banded strip using the status colors.
- Muted grid (`hairline`), `ink-muted` axis labels, tabular value tooltips, rounded line caps.
- Dashboard: use **Tremor** `<AreaChart>`, `<LineChart>`, KPI `<Card>`/`<Metric>`. Mobile: `fl_chart` `LineChart` with the same palette.
- Keep it "simple graphical visualization" (Design 3) — one or two series per chart, clear legend, no chartjunk.

## 7. Signature components
- **Stress pill/badge:** soft-bg fill + colored text + status dot + word. The single most-used component; identical logic in both apps.
- **Vital card:** label, big tabular value, unit, tiny trend sparkline, muted "updated Xs ago."
- **Dog card (dashboard board):** name + breed + stress pill leading; calm dogs recede, above-calm dogs get a soft status tint and float to the top.
- **Alert card:** severity-colored left border, message, timestamp, one clear **Acknowledge** button; acknowledged → muted.
- **Empty states:** friendly + encouraging with a small illustration ("No alerts — Biscuit is doing great 🐾"), never a bare "No data."
- **Nav:** dashboard = left sidebar (Overview, Board, Alerts, Reports, Admin); mobile = a **floating pill bar — Home · Alerts · Trends · Profile — plus a detached Chat box** beside it (2026-07-24). The mobile bar is **icon-only**: selection is shown by swapping to the *filled* glyph plus a soft brand pill, never colour alone, and every destination keeps its name in `Semantics` (a badged tab announces as "Alerts, 3 new").

## 8. Per-module screen direction
Design intent for every manuscript module so the full build stays cohesive.

### Veterinary dashboard (React — clinical, Design 2)
- **Monitoring board:** multi-dog grid/table, stress-sorted, live via Realtime; device-online dot; quick filter (all / needs attention).
- **Dog detail:** header (dog + current stress pill), vital cards row, vitals trend chart, stress timeline, open alerts, vet-notes panel.
- **Vet review:** biometrics + stress history + **owner-submitted media** review (approve/annotate) + **confirm/override stress** control (this feeds ground-truth labels).
- **Reports (DSS):** per-dog period summary, abnormal-pattern highlights, printable/exportable.
- **Alerts queue:** triage list, severity-grouped, acknowledge + assign.
- **Admin:** manage users, clinics, devices (role-gated).

### Owner mobile app (Flutter — approachable, Design 3)
- **User dashboard (Home):** big stress hero for the selected dog, vital cards, "updated Xs ago," reassuring copy.
- **Pet creation/profiles:** add/manage multiple dogs (name, breed, age, weight, medical history, photo); dog switcher.
- **Observation assessment:** submit notes + photos + short videos (supplementary; clearly labeled "not used by the classifier").
- **Care insights:** plain-language guidance for the current stress state (vet-authored, informational only — never "diagnosis").
- **Vet review (owner side):** read vet recommendations/updates; simple threaded follow-up.
- **Device pairing & setup:** pair by code/QR, show connectivity + last-sync, low-battery/offline states.
- **Notifications:** push alert when stress crosses moderate/high or device goes offline; in-app alert list + detail.

## 9. Accessibility
- Text contrast ≥ 4.5:1 (verify muted inks on `bg`; verify status text on its soft bg).
- Never encode meaning in color alone (always word + icon).
- ≥44px touch targets (mobile); visible focus rings (`brand`); respect reduced-motion; support dynamic text scaling.

## 10. Do / Don't
- **Do:** blue+white minimalism, generous whitespace, big tabular vitals, status pills, soft shadows, encouraging owner copy, clinical clarity on the dashboard.
- **Don't:** default Material purple or default Vite look, neon/pure-`#FF0000` everywhere, hard black text, chartjunk, dense clinical grids on the owner app, "diagnosis" language, color-only status.

## 11. Implementation checklist
- [ ] `packages/shared/design_tokens.json` holds all tokens above.
- [ ] Generator emits `apps/dashboard/src/styles/tokens.css` (CSS vars) + Tailwind theme extension, `apps/mobile/lib/theme/furfeel_tokens.dart` + a Material 3 `ThemeData`, and `apps/mobile/android/.../res/values{,-night}/colors.xml` (the Android launch screen is painted by the OS before Flutter starts, so it needs real colour resources rather than Dart constants).
- [ ] Dashboard adopts shadcn/ui + Tremor themed to the tokens.
- [ ] Mobile uses `ColorScheme.fromSeed(seedColor: brand)` + Inter + `fl_chart`.
- [ ] Stress pill + vital card + alert card built once per platform from tokens; no hardcoded hex.

## Related
- [[04 Mobile App Design]]
- [[05 Veterinary Dashboard Design]]
- [[16 Interface Design Tradeoffs]]
- [[18 Repository Structure]]
