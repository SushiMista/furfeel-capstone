# FurFeel illustration set

One coherent flat-vector set. Style, integrity rules, and generation approach
are locked in **ADR-023**; the naming and priority below track
`docs/22 Redesign Style Prompt.md` → "AI-generated assets".

**Rendering is not wired yet.** `flutter_svg` is not a dependency and nothing in
`lib/` loads these. Adding the package + tinting `currentColor` from a token is
the *apply* step ADR-023 defers — do it when the first illustration ships on a
real screen, not before.

## Rules (see ADR-023)
- Cool palette from the design tokens; the dog is the warm element in frame.
- Transparent background; must read on both the light and the dark `#0B1220`.
- Single-colour line marks use `currentColor` so the app tints from a token —
  never bake a hex the way Dart/CSS never do.
- Never bake text into an image. Decorative → `ExcludeSemantics`; meaningful →
  a real `semanticLabel`.
- No photorealistic stand-in for a user's own dog. No harness-delivers-a-verdict
  imagery (decision support, not diagnosis — ADR-002).
- `snake_case`, content not usage (`dog_resting.svg`, not `empty_state_1.svg`).

## Planned set (priority order)
| File | Use | Status |
|---|---|---|
| `placeholder_pet.svg` | DogAvatar fallback mark | ✅ seed drawn |
| `empty_no_dogs.svg` | Home, before any dog is added | ▢ |
| `empty_no_readings.svg` | Dog detail, before first telemetry | ▢ |
| `empty_no_alerts.svg` | Alerts tab, all clear | ▢ |
| `empty_no_photo.svg` | Photoless profile (paired with the tint) | ▢ |
| `onboarding_monitoring.svg` | Onboarding 1 — real-time monitoring | ▢ |
| `onboarding_harness.svg` | Onboarding 2 — the wearable | ▢ |
| `onboarding_alerts.svg` | Onboarding 3 — alerts | ▢ |
| `milestone_calm_streak.svg` | Encouragement (the one place `warm` is allowed) | ▢ |
