# FurFeel brand photos (curated stock — replaceable)

Real dog photography for **generic** slots only — welcome, onboarding, marketing.
Rendered through `BrandPhotoFrame`. These are placeholders you swap for your own
shoot later; nothing here represents a *specific* user's dog.

**Hard rule (ADR-023):** never put a stock or generated photo in an identity slot
(dog profile, avatar, monitoring cards). Those use the owner's upload or the
tinted illustration placeholder. A stock dog in a profile slot reads as *their*
dog and misleads.

## How to add one
1. Source from a permissive-license library (Unsplash / Pexels — both allow app
   use; keep a note of the source URL + photographer for attribution).
2. Prefer a **single visual set** (similar lighting/crop) so the app stays
   coherent — mixed stock is what looks generic.
3. Name it exactly per the slot table, drop it in this folder. It appears
   immediately; until then the frame shows the tinted fallback mark, so nothing
   looks broken.
4. Optional: add `2.0x/<name>` and `3.0x/<name>` for crisper rendering on dense
   screens (Flutter picks the variant). A single high-res base also works —
   Flutter downscales.

## Slots
| File | Slot | Frame | Suggested source crop |
|---|---|---|---|
| `welcome_hero.jpg` | Welcome screen hero | arch (portrait) | ~800 × 1040, dog head/shoulders, calm |
| `onboarding_monitoring.jpg` | Onboarding 1 · "Feel what they feel" | arch | portrait, dog wearing/near a harness |
| `onboarding_stress.jpg` | Onboarding 2 · "Stress, made simple" | arch | portrait, calm/resting dog |
| `onboarding_care.jpg` | Onboarding 3 · "Care as a team" | arch | portrait, dog with a person/vet |

Keep each file reasonably small (< ~250 KB) so the bundle stays light. Prefer
`.jpg` for photos; the frame clips them, so no rounded corners needed in-file.
