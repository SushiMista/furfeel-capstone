// Deterministic per-dog tint (docs/21 Redesign Plan §4, Phase 1 — ported from
// mobile's dogTint). The hash matches the Flutter implementation
// (_stableHash) bit-for-bit, so a dog wears the same tint on the dashboard as
// in the owner app. Derived from the id, never list position (which reorders)
// or random (which flickers on re-render).
const TINTS = ["bg-tint-blue", "bg-tint-teal", "bg-tint-periwinkle", "bg-tint-slate"] as const;

function stableHash(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    // & 0x7FFFFFFF keeps the low 31 bits, matching Dart's masked int math.
    h = (h * 31 + s.charCodeAt(i)) & 0x7fffffff;
  }
  return h;
}

/** A Tailwind background class for the dog's ground. */
export function dogTint(dogId: string): string {
  return TINTS[stableHash(dogId) % TINTS.length];
}
