---
title: "Security and Privacy"
type: security-design
project: FurFeel
created: 2026-07-09
tags: [furfeel, security, privacy]
---

# Security and Privacy

## Protected Data
- User account information.
- Dog profiles.
- Clinic records.
- Telemetry history.
- Stress classifications.
- Vet notes and reports.
- Owner-submitted media/videos for supplementary assessment and communication.

## Baseline Controls
- Password hashing.
- Role-based access.
- Authenticated API requests.
- HTTPS for data transfer.
- Input validation.
- Audit trail for clinical notes and alert acknowledgements.
- Least-privilege access per clinic and owner.

## Data-Collection Consent (as built)
- `consents` table: one append-only row per (user, `policy_version`), own-row RLS (select/insert only — an acceptance is a record, not an editable preference).
- The owner app gates ALL monitoring data (telemetry views, realtime subscription, media features) behind acceptance of the **current policy version** (`kConsentPolicyVersion` in `apps/mobile/lib/pages/consent_page.dart`, currently `2026-07-17.v1`). Data loading does not even start until consent is confirmed.
- Bumping the version forces re-consent on next launch while keeping earlier acceptances on record.
- The consent screen lists, in plain language: harness readings collected continuously; owner media shared with the clinic (never a classifier input); clinic visibility when a clinic is linked; decision-support-not-diagnosis framing.
- Note: device telemetry ingest itself is not consent-gated server-side (the wearer's owner consented at app setup; the harness has no user identity). If the thesis needs server-side enforcement, add a consent check to `telemetry-intake` — open question below.

## Privacy Decisions Needed
- [x] Will owner-submitted photos/videos be included in MVP? Decision: supplementary assessment/communication only, not classifier input.
- [x] Does the thesis require formal consent wording for test participants? Decision: in-app data-collection consent implemented (see above); formal thesis-participant wording still needs adviser/vet review.
- [ ] How long should telemetry be retained?
- [x] Can the owner download their data? **Yes — "Download everything (JSON)"** (Detailed Log, 2026-07-19): the complete per-dog archive of every record the owner can read under RLS, paged past the row cap; media as metadata (paths), not bytes. Research export remains a separate decision.
- [ ] Should telemetry ingest be blocked server-side for un-consented owners?

## Security test evidence (2026-07-19)
- **Static RLS audit** (`services/edge/rls_audit/policy_audit.test.ts`, runs in plain CI): RLS enabled on all 16 tables, every table has policies (readable policy matrix in the output), no policy targets `anon`, storage buckets private, `ingest_key_hash` never client-granted.
- **Live cross-tenant proof** (`rls_live.test.ts`, opt-in with `RLS_LIVE=1` + keys): throwaway users/clinics/dogs verify owner/clinic/anon isolation, owners can't write `vet_notes`/`stress_labels`, consents are own-row append-only, and media storage follows owner-or-clinic access. Cleans up after itself.
- **Devices column-grant CI guard** (`apps/dashboard/tests/devicesGrant.test.ts`): client column lists must be covered by the migrations' column-level grants; `select('*')` on devices is banned.
- **Offline consent cache:** the app caches only a **server-confirmed** acceptance of the current policy version so an offline cold start can show cached data; unconfirmed users still hit the gate offline.

## Related
- [[03 User Roles and Permissions]]
- [[09 Database Schema]]
- [[13 Testing Strategy]]
