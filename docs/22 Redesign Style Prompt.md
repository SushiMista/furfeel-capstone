---
title: "FurFeel Redesign Style Prompt"
type: working-prompt
project: FurFeel
created: 2026-08-01
tags: [furfeel, design, prompt, mobile]
---

# FurFeel Redesign Style Prompt

> Paste the block below into Claude Code (or any agent working in this repo) when applying the redesign to a screen. It is deliberately self-contained. Keep it in sync with `19 Design System`, `21 Redesign Plan`, and ADR-022.

---

You are restyling the FurFeel Flutter owner app (`apps/mobile`) to a redesign driven by a mood board. Read `docs/21 Redesign Plan.md` and `docs/19 Design System.md` before making changes.

## Brand

Blue and white. The existing palette stays — this is an extension, not a re-theme. The mood board is warm (cream, amber, terracotta); we deliberately rejected that direction because blue is the only cool hue in the system, which makes it read unambiguously as *interface* and frees every warm hue to mean *status* alone. See ADR-022 for the full reasoning; do not re-litigate it.

Warmth comes from **photography and structure**, not from the palette.

## Non-negotiables

- **Never hardcode a hex.** Flutter reads colors from `context.ff.*` (a `ThemeExtension`); the dashboard reads CSS vars / Tailwind tokens. The repo currently has zero hardcoded hex in both apps — keep it that way.
- **Both light and dark.** Every token has a dark counterpart. Check both.
- **Status never rides on color alone.** Always word + dot/icon (`StressPill` is the reference implementation).
- **Text pairings need 4.5:1. Chart fills need 3:1.** These are different rules for different things. `fg` stops are for type; `mid` stops are for bars and sparklines; never use `mid` for text or `accent` for text (`accentInk` is the teal text stop). CI enforces both in `apps/dashboard/tests/contrast.test.ts`.
- **No composite health score.** No single blended number summarising a dog's wellbeing — it is a diagnostic claim in all but name and violates ADR-002. One metric per card, always.
- **No personified AI.** Rule-engine output is never rendered as a chat message from a character (ADR-018).
- **No "diagnosis" language** anywhere in copy. This is decision support.

## Visual language

**Shape.** Mobile radii are generous: `radiusMd 16`, `radiusLg 20`, pill `999`. Cards are surface-colored with a hairline border and the soft `shadowCard`, never heavy drop shadows. Buttons are stadium-shaped.

**Photography.** Real dog photos on cool tinted grounds (`tintBlue` / `tintTeal` / `tintPeriwinkle` / `tintSlate`). Dog fur is warm, so a cool ground is deliberate complementary contrast. Tints are assigned deterministically from `dog.id` via `dogTint()` — never from list position or random. Photoless states get the same tinted treatment plus a mark, never a grey box; for some owners the placeholder is permanent and must look intentional.

**Avatar shapes** (`DogAvatarShape`): `circle` inline and in compact rows, `squircle` in lists and selectors, `arch` for hero and profile moments only — it's a brand signature, so overusing it spends it.

**Numbers.** Vitals are the hero: large tabular figures (`FontFeature.tabularFigures()` — without it the number jitters as digits change), small muted unit, and a one-line plain-language descriptor. A number the owner cannot interpret is not decision support.

**Trends.** A number plus a short trend beats a number alone. Use `MicroSparkline` — bars, not lines (a 1px stroke reads as noise at this size). It self-hides below 2 readings. Zero values still draw a floor-height bar, because a missing bar reads as *missing data*, which is a different claim.

**Primary actions.** `BadgePillButton` — stadium pill with a circular icon badge inset at the leading edge. The label centres against the gap beside the badge, not the button box. One filled button per screen; everything else is the outline variant.

## Metric card anatomy — the target pattern

This is the reference layout for any card showing a vital. It comes from the mood board's health-metric screen, **adapted to run monochrome**.

**Structure**, top to bottom:

- **Header row.** Small icon (18px) + bold metric label on the left; a muted timeframe affordance on the right (`Today ›`, `7 days ›`).
- **Body row**, two columns:
  - *Left:* the number, large and bold with tabular figures, its unit small and muted beside it on the baseline; directly beneath, a one-line plain-language descriptor in muted caption (`Mostly calm`, `Resting`, `On track`, `Stable range`). The descriptor is the point — it is what turns a reading into something the owner can act on.
  - *Right:* a compact 7-column micro chart with day initials (`M T W T F S S`) beneath in muted caption.
- Card is `surface` with `radiusLg`, a hairline border and `shadowCard`, sitting on the `bg` ground. Generous internal padding; the cards breathe.

**Chart type follows the data shape.** Do not repeat one chart for everything — this is what makes the board's screen readable at a glance:

| Data shape | Chart |
|---|---|
| Continuous magnitude (stress, activity) | Rounded capsule bars — `MicroSparkline` |
| Continuous fine-grained (heart rate, breathing) | Thin line, optional soft fill beneath |
| Range or two-part value (blood pressure) | Two-tone stacked capsule: light track + solid value segment |
| Binary / adherence (harness worn, medication) | Row of dots with check or cross above |
| Categorical state (mood, posture) | Row of small glyphs, the active one emphasised |

All bars and dots are **rounded capsules**, generously spaced. Empty or unreported days show the light track, never a gap — a gap reads as *no data*, which is a different claim from *a low reading*.

**Monochrome rule — the important adaptation.** The board gives every metric its own hue (orange stress, red heart rate, purple blood pressure, blue hydration). **Do not do this.** In FurFeel, hue is reserved for status: warm means elevated, teal means calm. If each metric owned a hue, a purple blood-pressure chart would compete with the status ramp and an owner would have to learn which colours mean *what a thing is* versus *how bad it is*.

So: **charts render in brand blue**, with the light track in `brandSoft`. The single exception is a chart whose subject *is* the stress level — that one uses the matching status `mid` stop, because there the hue genuinely encodes severity.

Metrics are told apart by **icon, label, and chart type** — never by colour. This is the stricter constraint, and it produces a calmer screen than the board's: run the whole set in one blue and the numbers become the thing you read, rather than the palette.

**Motion.** Calm and quick: 150–250ms ease-out. Stress-level changes cross-fade, never snap. One soft pulse on level *change* only, never per reading. Always respect `context.reduceMotion`.

## Copy

Sentence case. Warm and plain, never clinical or cute. Address the owner directly and name the dog. Empty states are invitations, not apologies.

## AI-generated assets

Generate the app's illustration set rather than sourcing stock. The app currently has no imagery, and that is the single biggest reason it still reads clinical.

**What to produce, in priority order:**

1. **Empty states** — no dogs yet, no readings yet, no alerts, no photo on file. Highest value: these are the screens a new user sees first and they are currently bare.
2. **Onboarding** — 3–4 screens introducing monitoring, the harness, and alerts.
3. **Placeholder pet mark** — a friendlier replacement for the `Icons.pets` fallback, sitting on the dog's derived tint.
4. **Milestone / encouragement moments** — calm streaks, first week complete. This is the one place `warm` is still allowed.

**Style.** One coherent set, not four. Flat vector illustration with clean geometry and generous whitespace — no gradients, no drop shadows, no 3D render, no glossy mascot. Cool palette drawn from the tokens (`brand` blue, `accent` teal, the `tint` set) with the dog as the warm element in frame. Dogs should be friendly and mixed-breed-ambiguous rather than a specific recognisable breed, so owners of any dog see theirs. Match the app's line weight to the Material outline icons already in use.

**Technical requirements:**

- SVG where the asset is geometric; PNG at `@1x`/`@2x`/`@3x` otherwise. Flutter needs the multiplier variants in sibling `2.0x/` and `3.0x/` folders.
- Store under `apps/mobile/assets/illustrations/`, register in `pubspec.yaml`, name in `snake_case` describing content not usage (`dog_resting.svg`, not `empty_state_1.svg`).
- **Transparent backgrounds.** Every illustration must sit on both the light ground and the dark `#0B1220` one. Test on both — an illustration with dark linework vanishes in dark mode. Provide a dark variant only where transparency genuinely cannot solve it.
- **Never bake text into an image.** It can't be localised, can't be read by a screen reader, and won't scale with the user's text size.
- Decorative illustrations get `ExcludeSemantics`; anything carrying meaning gets a real `semanticLabel`.

**Two integrity rules, which matter more than the aesthetics:**

- **Do not generate photorealistic dogs to stand in for a user's own pet.** A generated photo in a profile slot invites an owner to think they are looking at their dog. Placeholders are illustrations and must be visibly illustrations. Photorealistic generation is acceptable only for onboarding and marketing frames that clearly depict *a* dog, never *their* dog.
- **Do not depict the harness reporting a diagnosis**, a vet delivering a verdict, or any imagery implying the device decides what is wrong with an animal. The product is decision support (ADR-002), and illustration is exactly where that line gets crossed accidentally.

Record the generation approach and any prompt seeds in an ADR so the set can be extended consistently later — an illustration set that can't be added to in six months is a set that will be replaced in six months.

## Working rules

- Prefer enhancing an existing widget over introducing a parallel one. This codebase already has good components (`StressPill`, `FloatingNavBar`, `_VitalSquare`, `VitalDetailPage`) — check whether the pattern already has a home before building a new widget. A new widget that duplicates a better existing one is a regression.
- Every change needs `flutter analyze` clean and the relevant test passing. Widget tests that needed updating are a prompt to check the change was intended, not a chore.
- Log any architectural choice as an ADR in `docs/02 Architecture Decisions.md`, matching the existing voice: Decision, Reason, what was deliberately *not* done, and linked notes.
- Don't weaken RLS, don't feed media to the classifier, don't rename the rule-based classifier.

## Working unsupervised

You are running autonomously with permissions skipped. Nobody is watching, nobody will catch a bad call before it lands, and there is no one to ask. That changes what "done" means.

**The app must be working when you stop.** Not "working apart from", not "working once someone fixes". `flutter analyze` clean and `flutter test` green is the bar, and it is the bar at *every* checkpoint — not just at the end. Verify after each unit of work; never stack three unverified changes and hope. If you cannot get back to green, revert to the last green state rather than leaving a half-migration in the tree. A smaller finished change beats a larger broken one, every time.

**Commit per working increment**, message referencing the spec doc. Every commit should be a state someone could ship. A broken commit is worse than no commit, because it looks like progress.

**Never make a test pass by weakening it.** This is the failure mode that matters most when unsupervised, and it is always tempting. No deleting assertions, no `skip:`, no loosening a matcher until it accepts what you produced, no `// ignore:` on a lint, no lowering a contrast threshold, no `--no-fatal-warnings`. A failing test means the code and the intent disagree — your job is to work out which one is wrong, fix that, and say so in the commit message. A suite that passes because it stopped asking anything is worse than a red one, because it is silent.

**When you hit a real decision, stop and write it down — do not guess.** `docs/15 Open Technical Questions` exists for this, and `CLAUDE.md` says to stop and ask. With no one to ask, the equivalent is: leave the code in a working state, skip that thread, and record the question in `docs/15` or as an ADR with the options and trade-offs you saw. An unanswered question you recorded is worth far more than an invented answer you shipped, because the invented one will be discovered much later and by then it will have dependents.

**You cannot see the screen.** Nobody will tell you a card overflowed or a colour looks wrong. So: prefer changes that cannot break layout (adding a token, swapping a colour source, extracting a widget) over ones that can (changing density, aspect ratio, or the number of elements per row). Where a layout-sensitive change is genuinely required, write a golden test — that is the closest thing to eyes you have. Anything you could not verify goes in the handoff note as needing review, explicitly.

**Do not touch:** `.env` or any secret, applied migrations in `supabase/migrations`, raw telemetry (ADR-003 — it is never deleted), or RLS policies. Never weaken a policy to make a feature work; fix the policy properly or record why you couldn't. Do not rewrite git history, force push, or `git reset --hard` over work you did not create.

**Stay in scope.** Do the redesign task in front of you. A refactor you noticed on the way is a note in the handoff, not a change in the diff — unreviewed opportunistic refactoring is how an unsupervised session turns into an unreviewable one.

**Finish with a handoff note**: what changed, what is verified green, what you could not verify, what you deliberately did not do and why, and any question you recorded. Write it as if the person reading it has not seen any of your reasoning — because they haven't.

## Current state

Phases 0–3 are built (tokens, tinted avatars + shapes, `MicroSparkline` adopted into Home's vital grid, `BadgePillButton`). Not yet done: applying `BadgePillButton` to call sites, the horizontal pet selector (Phase 4), the dashboard port (Phase 5), and the whole illustration set. `VitalStatCard` exists, is tested, and is unadopted — see `21 Redesign Plan` §4 Phase 2 before using or deleting it.

`apps/mobile/assets/` exists but holds no illustrations. Generating them is the highest-value remaining work: the structural redesign is largely in place and imagery is now the thing standing between the app and the mood board.
