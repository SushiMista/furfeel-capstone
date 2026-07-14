// Device ingest-key hashing/verification, shared by telemetry-intake and (later) the
// devices/register endpoint that first issues an ingest_key.
//
// ingest_key is a high-entropy, server-generated token (docs/10: "returns { ingest_key }
// shown once, stored hashed") rather than a user-chosen password, so a plain SHA-256 digest
// is appropriate here -- slow KDFs (bcrypt/argon2/scrypt) exist to resist brute-forcing weak,
// guessable secrets, which doesn't apply to a random token. Uses only Deno's built-in Web
// Crypto so this file (and its tests) never need a network fetch to run.

export async function hashDeviceKey(plainKey: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(plainKey));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Constant-time comparison of two equal-length-in-the-common-case hex strings. */
export function timingSafeEqualHex(a: string, b: string): boolean {
  const len = Math.max(a.length, b.length);
  let diff = a.length === b.length ? 0 : 1;
  for (let i = 0; i < len; i++) {
    diff |= (i < a.length ? a.charCodeAt(i) : 0) ^ (i < b.length ? b.charCodeAt(i) : 0);
  }
  return diff === 0;
}

export async function verifyDeviceKey(
  plainKey: string,
  storedHash: string | null,
): Promise<boolean> {
  if (!storedHash) return false;
  const computed = await hashDeviceKey(plainKey);
  return timingSafeEqualHex(computed, storedHash);
}
