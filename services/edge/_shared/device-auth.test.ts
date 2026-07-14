import { hashDeviceKey, timingSafeEqualHex, verifyDeviceKey } from "./device-auth.ts";

function assertEqual<T>(actual: T, expected: T, msg?: string) {
  if (actual !== expected) {
    throw new Error(msg ?? `expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

Deno.test("hashDeviceKey matches the known SHA-256 vector for 'abc'", async () => {
  const hash = await hashDeviceKey("abc");
  assertEqual(hash, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
});

Deno.test("hashDeviceKey is deterministic and case-sensitive to input", async () => {
  const a = await hashDeviceKey("device-secret-123");
  const b = await hashDeviceKey("device-secret-123");
  const c = await hashDeviceKey("device-secret-124");
  assertEqual(a, b);
  assertEqual(a === c, false);
});

Deno.test("timingSafeEqualHex: equal strings -> true", () => {
  assertEqual(timingSafeEqualHex("abcd1234", "abcd1234"), true);
});

Deno.test("timingSafeEqualHex: differing strings -> false", () => {
  assertEqual(timingSafeEqualHex("abcd1234", "abcd1235"), false);
});

Deno.test("timingSafeEqualHex: different lengths -> false", () => {
  assertEqual(timingSafeEqualHex("abcd1234", "abcd123"), false);
  assertEqual(timingSafeEqualHex("abcd123", "abcd1234"), false);
});

Deno.test("verifyDeviceKey: matching key/hash -> true", async () => {
  const hash = await hashDeviceKey("my-plain-key");
  assertEqual(await verifyDeviceKey("my-plain-key", hash), true);
});

Deno.test("verifyDeviceKey: wrong key -> false", async () => {
  const hash = await hashDeviceKey("my-plain-key");
  assertEqual(await verifyDeviceKey("wrong-key", hash), false);
});

Deno.test("verifyDeviceKey: null stored hash (unprovisioned device) -> false", async () => {
  assertEqual(await verifyDeviceKey("any-key", null), false);
});
