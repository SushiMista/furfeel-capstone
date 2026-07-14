import { alertTypeForStressLevel, decideAlert } from "./rules.ts";

function assertEqual<T>(actual: T, expected: T, msg?: string) {
  if (actual !== expected) {
    throw new Error(msg ?? `expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

Deno.test("alertTypeForStressLevel: calm/mild -> null, moderate/high -> their type", () => {
  assertEqual(alertTypeForStressLevel("calm"), null);
  assertEqual(alertTypeForStressLevel("mild"), null);
  assertEqual(alertTypeForStressLevel("moderate"), "moderate_stress");
  assertEqual(alertTypeForStressLevel("high"), "high_stress");
});

Deno.test("decideAlert: calm -> no alert regardless of open-alert state", () => {
  assertEqual(decideAlert("calm", false), null);
  assertEqual(decideAlert("calm", true), null);
});

Deno.test("decideAlert: mild -> no alert regardless of open-alert state", () => {
  assertEqual(decideAlert("mild", false), null);
  assertEqual(decideAlert("mild", true), null);
});

Deno.test("decideAlert: moderate with no open alert -> creates a warning alert", () => {
  const result = decideAlert("moderate", false);
  assertEqual(result?.type, "moderate_stress");
  assertEqual(result?.severity, "warning");
});

Deno.test("decideAlert: moderate with an existing open moderate_stress alert -> deduped", () => {
  assertEqual(decideAlert("moderate", true), null);
});

Deno.test("decideAlert: high with no open alert -> creates a critical alert", () => {
  const result = decideAlert("high", false);
  assertEqual(result?.type, "high_stress");
  assertEqual(result?.severity, "critical");
});

Deno.test("decideAlert: high with an existing open high_stress alert -> deduped", () => {
  assertEqual(decideAlert("high", true), null);
});

Deno.test("decideAlert: dedup is per-type — caller must check the type-specific open state, not a blanket 'any open alert' flag", () => {
  // A dog with an open moderate_stress alert that then escalates to 'high' should still
  // get a new high_stress alert, since hasOpenAlertOfSameType here refers to high_stress
  // specifically (the caller is responsible for querying by the mapped type).
  const result = decideAlert("high", false);
  assertEqual(result?.type, "high_stress");
});
