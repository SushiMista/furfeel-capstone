import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { friendlyError } from "../src/lib/errors.ts";

describe("friendlyError", () => {
  let consoleErrorSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    consoleErrorSpy = vi.spyOn(console, "error").mockImplementation(() => {});
  });

  afterEach(() => {
    consoleErrorSpy.mockRestore();
  });

  // The actual bug this file fixes: queries.ts does `if (error) throw error`
  // on postgrest-js's parsed-JSON error object, which is a plain object, not
  // an Error instance (PostgrestBuilder.ts's non-2xx path is `JSON.parse(body)`,
  // never `new PostgrestError(...)` unless `.throwOnError()` is used, which
  // nothing here does). `instanceof Error` is false for it — reproduced here
  // with the exact shape observed live.
  it("names a known Postgres error code instead of the generic fallback", () => {
    const pgError = { code: "57014", message: "canceling statement due to statement timeout" };
    const result = friendlyError(pgError, "load the overview");
    expect(result).toContain("Couldn't load the overview");
    expect(result).toContain("too many requests are running at once");
    // Must not fall through to the old behaviour this replaces.
    expect(result).not.toBe("Failed to load overview");
  });

  it("names a permission-denied error by code, not by message text alone", () => {
    const pgError = { code: "42501", message: "permission denied for table dogs" };
    expect(friendlyError(pgError, "load dogs")).toContain("doesn't have permission");
  });

  it("falls back to the raw message for an unrecognized Postgrest-shaped error", () => {
    const pgError = { code: "PGRST999", message: "something postgrest-specific" };
    expect(friendlyError(pgError, "load dogs")).toContain(
      "the server rejected the request (something postgrest-specific)",
    );
  });

  it("uses .message directly for a real Error instance", () => {
    expect(friendlyError(new Error("boom"), "save the note")).toBe(
      "Couldn't save the note — boom.",
    );
  });

  it("names a network failure distinctly from a server-side rejection", () => {
    const fetchFailure = new TypeError("Failed to fetch");
    expect(friendlyError(fetchFailure, "load alerts")).toContain(
      "you're offline or FurFeel can't be reached",
    );
  });

  it("never returns the un-narrowed 'unexpected error' for something error-shaped", () => {
    // Guards the duck-typed check itself: anything with a string `message`
    // must be treated as error-shaped, regardless of `instanceof`.
    expect(friendlyError({ message: "weird but message-shaped" }, "load dogs")).toContain(
      "weird but message-shaped",
    );
  });

  it("logs the full raw error, not just its message, so code/details/hint stay inspectable", () => {
    const pgError = { code: "57014", message: "timeout", details: "d", hint: "h" };
    friendlyError(pgError, "load the overview");
    expect(consoleErrorSpy).toHaveBeenCalledWith(
      expect.stringContaining("Couldn't load the overview"),
      pgError,
    );
  });
});
