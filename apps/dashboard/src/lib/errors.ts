/**
 * Turns a caught error into copy naming the true cause, instead of a blanket
 * "Failed to load X" — mirrors apps/mobile/lib/util/errors.dart.
 *
 * Why this exists: every load in this app does
 *   const { data, error } = await query;
 *   if (error) throw error;
 * and postgrest-js's response path (PostgrestBuilder.ts) builds that `error`
 * with `JSON.parse(body)` on the non-2xx branch — a PLAIN OBJECT, not a
 * `new PostgrestError(...)` instance (that class is only used on the
 * `.throwOnError()` opt-in path, which nothing here uses). So `error
 * instanceof Error` is false for the exact errors this app throws, and the
 * previous `err instanceof Error ? err.message : "Failed to load X"` in
 * every page silently discarded the real Postgrest code/message/hint every
 * time — confirmed live: a genuine `{code: '57014', message: 'canceling
 * statement due to statement timeout'}` rendered only as "Failed to load
 * overview" on screen. Detection below duck-types the shape instead of
 * relying on `instanceof`.
 */

interface PostgrestErrorShape {
  code?: string;
  message: string;
  details?: string | null;
  hint?: string | null;
}

function isPostgrestErrorShape(error: unknown): error is PostgrestErrorShape {
  return (
    typeof error === "object" &&
    error !== null &&
    // Real Error/TypeError instances also carry a string .message — without
    // this exclusion they'd match here first and never reach the instanceof
    // checks below, which is exactly backwards: this branch exists for the
    // PLAIN-OBJECT errors postgrest-js hands back (see file header), not for
    // genuine Error instances.
    !(error instanceof Error) &&
    typeof (error as { message?: unknown }).message === "string"
  );
}

/** Postgres/PostgREST codes worth naming specifically. Extend as new ones
 * turn up in `console.error` output rather than guessing ahead of time. */
const KNOWN_CODES: Record<string, string> = {
  "57014":
    "the database took too long to respond — this usually means too many requests are running at once (e.g. the firmware simulator, mobile app, and dashboard all hitting it together); try again in a moment",
  "42501": "this account doesn't have permission for that",
  PGRST301: "your session has expired — sign out and back in",
};

function errorCause(error: unknown): string {
  if (isPostgrestErrorShape(error)) {
    const code = error.code ?? "";
    if (KNOWN_CODES[code]) return KNOWN_CODES[code];
    if (error.message.includes("row-level security") || error.message.includes("permission denied")) {
      return "this account doesn't have permission for that";
    }
    return `the server rejected the request (${error.message})`;
  }
  if (error instanceof TypeError && /fetch/i.test(error.message)) {
    return "you're offline or FurFeel can't be reached";
  }
  if (error instanceof Error) return error.message;
  return "an unexpected error occurred";
}

/**
 * Logs the full raw error (code/details/hint live there, not just `message`
 * — see PostgrestError.ts's own doc comment) tagged with what failed, then
 * returns friendly copy: "Couldn't {what} — {cause}."
 *
 * This is the "debugs" half of the fix: open DevTools console on any future
 * failure and the exact code/details/hint are right there, instead of
 * needing to reproduce the failure from a live session to find them.
 */
export function friendlyError(error: unknown, what: string): string {
  console.error(`[FurFeel] Couldn't ${what}:`, error);
  return `Couldn't ${what} — ${errorCause(error)}.`;
}
