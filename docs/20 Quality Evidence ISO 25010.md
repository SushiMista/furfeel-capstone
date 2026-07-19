---
title: "Quality Evidence (ISO/IEC 25010)"
type: quality-evidence
project: FurFeel
created: 2026-07-19
tags: [furfeel, quality, iso25010, defense]
---

# Quality Evidence (ISO/IEC 25010)

Maps FurFeel's features and tests to ISO/IEC 25010 product-quality characteristics, and documents how the response-time numbers are collected. For the Capstone defense: every claim below points at something runnable.

## Response-time instrumentation (performance efficiency)

Three flows are instrumented with p50/p95 percentiles (nearest-rank):

| Flow | Where measured | How to read it |
|---|---|---|
| Telemetry intake (server) | `services/edge/telemetry-intake` logs one `{"metric":"telemetry_intake_ms","ms":N,"status":S}` JSON line per request | Supabase → Edge Functions → telemetry-intake → Logs; compute p50/p95 over `ms` |
| Telemetry intake (client-observed round trip) | `firmware/simulator` times every POST | run `npm start -- --max-ticks=30`; the run ends with `telemetry-intake round-trip: n=… p50=… p95=… max=…` |
| Dashboard board load | `apps/dashboard/src/lib/perf.ts` (`timed("board_load", …)`) | browser devtools console: `[perf] board_load …ms (session n=… p50=… p95=…)` |
| Mobile home load | `apps/mobile/lib/util/perf.dart` (`timed('home_load', …)`) | `flutter run` debug log: `[perf] home_load …ms (session n=… p50=… p95=…)` |

Numbers stay in-session/in-log only — no third-party telemetry (docs/12 privacy stance).

## Characteristic → evidence map

| ISO/IEC 25010 characteristic | FurFeel evidence |
|---|---|
| **Functional suitability** | Vertical slice end-to-end: simulator → intake validation → rule-v1 classification → alert → both clients (edge tests cover validation/classifier/alerts; widget + component tests cover every module screen). Checklists in docs/01–07 (sprints). |
| **Performance efficiency** | Instrumentation above; high-volume `telemetry_readings` indexed `(dog_id, captured_at desc)`; board/board-row refresh fetches only the affected dog on Realtime events. |
| **Compatibility** | Same Supabase contract shared by Flutter (iOS/Android/web), React dashboard, and the device simulator; shared types in `packages/shared/types`. |
| **Usability** | docs/19 design system (word + color, never color alone; ≥44px touch targets; empty/loading/error states audited 2026-07-19 with true-cause error copy — `apps/mobile/lib/util/errors.dart`); accessibility pass (semantic labels, dynamic text scaling, contrast test in CI). |
| **Reliability** | Offline resilience: mobile caches the last-known status and labels it "showing last known reading"; device-offline alerts + auto-recovery; low-battery alerts auto-resolve on recharge; error states never masquerade as empty data (state audit). |
| **Security** | RLS on all 16 tables + private storage buckets, proven by `services/edge/rls_audit/policy_audit.test.ts` (static, in CI) and `rls_live.test.ts` (live cross-tenant proof, opt-in with keys); devices column-grant CI guard (`apps/dashboard/tests/devicesGrant.test.ts`); service-role key never in a client; consent gate (docs/12). |
| **Maintainability** | Tokens + biometric bands code-generated from single sources (`design_tokens.json`, `classifier_config.json`) with staleness tests; thresholds vet-tunable in config; ADRs in docs/02. |
| **Portability** | Flutter targets mobile + web from one codebase; dashboard is a static Vite build; Edge Functions are portable Deno. |

## Related
- [[12 Security and Privacy]]
- [[13 Testing Strategy]]
- [[10 Defense Evidence Checklist]]
