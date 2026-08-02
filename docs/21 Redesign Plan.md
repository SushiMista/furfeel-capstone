---
title: "FurFeel Redesign Plan"
type: plan
project: FurFeel
created: 2026-08-01
updated: 2026-08-01
tags: [furfeel, design, redesign, mobile, plan]
---

# FurFeel Redesign Plan

> Execution plan for the owner-app redesign driven by the Furfeel Dream Board (Figma, 2026-07-29). Mobile first, then dashboard. Colour direction stays **palette A — the existing blue + white brand** — extended rather than replaced. Where this plan and `19 Design System` disagree, the tokens in `packages/shared/design_tokens.json` win and `19` is to be corrected.

## 0. What the board actually asked for

Four reference images were supplied. Read as a set, they are consistent about **structure** and inconsistent with our brand on **colour**:

| Board signal | Present in | Our response |
|---|---|---|
| Real pet photography on tinted grounds | all four | **Adopt.** New `tint` token set. |
| Arch / rounded-top photo frame | onboarding | **Adopt.** Signature shape. |
| Big number + unit + descriptor + 7-day sparkline | metric cards, dashboard | **Adopt.** Best pattern on the board. |
| Pill nav with filled active item | 2 of 4 | **Already shipped** (`floating_nav_bar.dart`, ADR-018). |
| Pill buttons with offset circular icon | onboarding, clinics | **Adopt.** |
| Horizontal pet selector with photo avatars | "My Pets" | **Adopt** (multi-dog homes). |
| Warm cream base, amber/terracotta accent | all four | **Reject.** See §1. |
| Composite "94% health score" ring | 2 of 4 | **Reject.** See §2. |
| Feeding tasks, journal, clinic finder, AI assistant | 2 of 4 | **Out of scope.** Different product. |

**The finding that matters:** almost everything that makes the board feel human is *structural* — corner radii, the arch, photography, generous card padding, the sparkline pattern. Very little of it is chromatic. Dropping those structures onto the existing palette captures most of the warmth at none of the brand cost.

## 1. Why the palette stays blue

The board is overwhelmingly warm; blue appears in it exactly twice, both times as a data colour, never as brand. Following it literally would mean abandoning blue.

We are not doing that, for three reasons:

1. **The manuscript already argues for blue.** Chapter 3's interface trade-off study selected Design 1 on the grounds of "healthcare, calm, and technological reliability." Re-theming to terracotta contradicts a documented, defended decision for an aesthetic preference.
2. **Blue is the only cool hue in the system.** That makes it unambiguously *interface*, which frees every warm hue to mean *status* and nothing else. A warm-branded app has to fight its own accent colour every time it renders a `moderate` chip — the action colour and the warning colour become the same family.
3. **Nothing is blocked by it.** Every structural pattern above is colour-agnostic.

What we take from the board's warmth instead: photography does the emotional work. Warm subjects (dog fur is overwhelmingly brown, gold, cream) sit on cool tinted grounds, which is a deliberate complementary contrast rather than an accident.

**Amendment to `19 Design System` §2:** warm brown (`warm` / `warmSoft`) is demoted to encouragement copy only — streaks, praise, milestone moments. It is no longer available for frames, avatars, chips, or decoration. The `tint` set and the teal accent family cover those.

## 2. Two board patterns we deliberately refuse

**The composite health score.** Two board images centre a single blended number ("94% SCORE"). A one-number verdict on an animal's wellbeing is a diagnostic claim in everything but name, and it is the exact line `02 Architecture Decisions` ADR-002 draws. We ship the *per-metric* version instead — each vital owns its own card, its own number, and its own descriptor, and no screen ever blends them into one figure. This is not a styling compromise; it is the difference between decision support and diagnosis.

**The AI assistant card.** The board renders algorithmic output as a chat message from a robot character. ADR-018 already rejected this shape for `care_guidance` on the grounds that presenting a rule engine as a person misrepresents it. Care Insights keeps its plain, labelled, non-personified treatment.

## 3. Starting position (audited 2026-08-01)

Better than the build-order checklist implies. Before planning any work:

- `apps/mobile/lib` is **~16.8k lines across 70 Dart files** — Pet Creation, Device Pairing, Vet Review, Care Insights, Observation and push are all present, not pending.
- **Zero hardcoded hex** in either `apps/mobile/lib` or `apps/dashboard/src`. Token discipline is already enforced; the re-theme does not need a colour-cleanup pass.
- `FurFeelPalette` is a proper `ThemeExtension` with `lerp`, so palette changes cross-fade for free and per-subtree theming already works.
- `StressPill` already implements word + dot + cross-fade + single pulse. **No change needed.**
- `FloatingNavBar` already implements the board's pill nav. **No change needed.**
- Light and dark palettes both exist and both pass WCAG AA in CI.

The consequence: this is a **component-layer redesign, not a re-theme**. The colour plumbing is done. What is missing is the board's *shapes*.

## 4. Phases

Ordered by cascade value — earlier phases change the most screens per line of code.

### Phase 0 — Token extension ✅ done 2026-08-01
Teal accent family (`accentStrong` / `accentInk` / `accentSoft`), status `mid` chart stops, cool `tint` set, warm demotion. Generator, Tailwind, Dart, and Android outputs all updated; contrast test extended. See **ADR-021**.

Acceptance: all text pairs ≥ 4.5:1 and all chart mids ≥ 3:1 in both modes, enforced in CI. ✅

### Phase 1 — Tinted pet photography + arch frame
`DogAvatar` gains: a deterministic per-dog tint drawn from the `tint` set, a rounded-square variant for list rows, and the board's arch frame for hero and profile contexts.

Deterministic matters: a dog's tint must be stable across sessions and devices, so it derives from the dog's `id`, never from list position (which reorders) or random (which flickers on rebuild).

Acceptance: every avatar surface reads its colour from `context.ff`; the same dog shows the same tint on Home, Profile, and the pet selector; ink on every tint ≥ 4.5:1 (already pinned in CI).

### Phase 2 — The number-plus-trend pattern ✅ built 2026-08-01
The board's strongest idea is that a number carrying a short trend beats a number alone: a resting heart rate of 92 means something different on the way up than on the way down.

Shipped as `MicroSparkline` (bars, not a line — at this size a stroke reads as noise) plus its adoption into Home's `_VitalSquare`. The trend shares the bottom line with the status word, so it costs no extra height and the grid's aspect ratio is untouched. Bars are brand blue rather than a status colour: the dot and word already carry status, and a second status-coloured element on the same line reads as a second signal.

**Update 2026-08-02 — `VitalStatCard` is now adopted on Home.** On owner request ("copy famous health dashboards, but for dogs"), Home's compact 2×2 `_VitalSquare` grid was replaced with a stack of full-width `VitalStatCard`s (icon + label + `Today`, big tabular number, plain-language descriptor, capsule-track sparkline) — the Apple-Health / Oura pattern on our palette. Gained a `timeframe` affordance and `shadowCard`; `_VitalSquare` was deleted. Sparklines still use recent readings, not true 7-day daily buckets, so no `M T W T F S` labels yet (a data-layer follow-up). The historical note below is kept for context.

**`VitalStatCard` was built and was initially unadopted.** It was written before checking where it would live, which was the wrong order. Every density tier already has a better-suited component — Home has the compact `_VitalSquare` (with activity animation and baseline-derived status words), `VitalDetailPage` has a bespoke 44px hero and a full `fl_chart` line chart, and `TrendsTab` has `CalmWeekHero`/`WellnessCard`/the stress-mix chart. Dropping it into any of them would replace a more capable widget with a less capable one. It is tested and kept for the Phase 5 dashboard port, where a full-width metric card has no equivalent yet; if that port doesn't want it either, delete it.

Acceptance: renders one metric only; never blends metrics; degrades to the number alone below 2 readings. ✅

### Phase 3 — Pill button with offset icon ⛔ reverted 2026-08-02
**Reverted on owner review.** Seen live, the stadium pill with a circular icon badge inset at the leading edge reads as a *slide-to-confirm* control, not a button — the badge looks like a draggable knob. The owner's call (gut on the running app beats the mood board, which drew it this way). All call sites returned to the theme's filled stadium `ElevatedButton`; `BadgePillButton` and its test were deleted, and the `MicroSparkline` tests that had been co-located moved to `micro_sparkline_test.dart`. History below kept for the record.


`BadgePillButton`: stadium button, circular icon badge inset at the leading edge, label optically centred *against the gap beside the badge* rather than the button box — centring in the box pushes the label visually right, because the eye reads the gap, not the geometry. Hence the trailing spacer that mirrors the badge.

Built as a widget rather than an `elevatedButtonTheme` override: the badge is a structural child, and a theme can restyle a button but cannot insert an element into it.

Acceptance: ≥ 44px touch target (asserted); both filled and outline variants survive a long label. ✅ **Applied 2026-08-01** to all nine primary CTAs (welcome, sign-up, login, onboarding, dog form, consent, device pairing, guided setup, observation). A `busy` flag was added so the two spinner CTAs keep that affordance.

### Phase 4 — Horizontal pet selector ✅ built 2026-08-01
"My Pets" row for multi-dog homes: tinted squircle avatars (via `DogAvatar` + `dogTint`), name beneath, trailing add affordance. Shipped as `PetSelector` and wired into `multi_dog_home.dart`, where it also gives that screen its only add-a-dog affordance.

Acceptance: horizontal scroll, keyboard/screen-reader reachable (each tile + the add tile is a labelled `Semantics` button), add affordance labelled. ✅

### Phase 6 — Immersive status hero + per-metric waveforms ✅ built 2026-08-02 (ADR-023)
On owner direction (mood boards img 6–8), the owner Home and vital detail were rebuilt to the immersive treatment: a full-bleed status/metric-coloured top with a big value, bold description, chips, and a wide edge-to-edge curved divider (`CurvedStatusHeader`); Home's tab bar retired for a single scroll (hero → health overview → care → activity); each health-overview row a coloured `WaveSparkline` opening the detail; the vet baseline now a coloured dashed line on the detail graph. New `vital` token group for the per-metric colours (override of the monochrome rule — see ADR-023). The FurFeel-score hero shows the **classification word** (Calm), never a number (ADR-002 upheld). All 190 mobile tests green; analyze clean.

### Phase 5 — Dashboard port ✅ built 2026-08-01
Carry the vital stat card and tinted thumbnails into `apps/dashboard` (shadcn/ui + Tremor). The dashboard stays denser and flatter than mobile per `19 Design System` §4 — it takes the patterns, not the mobile radii.

Shipped: `src/lib/dogTint.ts` (the same `_stableHash` as Flutter, bit-for-bit, so a dog wears one tint across both apps — pinned in `tests/redesignPort.test.tsx`) adopted as `DogCard`'s photoless ground; `MicroSparkline.tsx` (bars, brand blue, self-hides < 2) added to the `DogDetail` vital tiles as a recent-trend ribbon. Kept the dense 4-tile hero rather than porting the full-width mobile card — a full-width card would *reduce* the dashboard's density, which §4 says to preserve. No plain-language descriptor on dashboard vitals: there is no client-side baseline to derive one from, and inventing a threshold is a guardrail break.

## 5. Risks

**Photography is a dependency, not a detail.** Every pattern above assumes real pet photos. Owner-uploaded photos already exist (`dog.photoPath`, signed URLs from the private media bucket) but coverage will be partial. Empty states need a considered placeholder treatment, not a grey box — the tinted ground plus a friendly mark is the fallback, and it must look intentional, because for some users it is the permanent state.

**AI-generated imagery for onboarding is unresolved.** Illustrations for onboarding and empty states were agreed in principle but no assets exist and no style is locked. This is the largest open item and it blocks Phase 1's polish (not its structure).

**Dark mode doubles every visual review.** Both palettes ship, so every phase needs checking twice. CI covers contrast; it does not cover whether a tinted photo ground *looks* right at night.

**Test surface.** 43 test files under `apps/mobile/test`. Widget tests that assert on colour or structure will need updating alongside each phase — expect test churn proportional to the component change, and treat a test that needed changing as a prompt to check the change was intended.

## 6. Open questions

- Do onboarding illustrations get generated, commissioned, or dropped in favour of photography alone?
- Does the arch frame apply to the vet dashboard, or is it a mobile-only brand signature?
- Multi-dog selector: does it replace the current dog switcher or sit alongside it?

## Linked notes
- [[19 Design System]]
- [[02 Architecture Decisions]] (ADR-021)
- [[04 Mobile App Design]]
- [[05 Veterinary Dashboard Design]]
