---
title: "Definition of Done"
type: quality-standard
project: FurFeel
created: 2026-07-09
updated: 2026-10-04
tags: [furfeel, done, quality]
---

# Definition of Done

A FurFeel feature is done only when it passes these checks.

## Feature Done
- [ ] The feature works in the intended app or service.
- [ ] It uses the confirmed stack: Flutter, React, Supabase, ESP32/simulator as relevant.
- [ ] It handles loading, empty, and error states.
- [ ] It stores or reads data from the correct Supabase table when applicable.
- [ ] It follows the agreed naming rules.
- [ ] It has at least one manual test case.
- [ ] It is documented in the brain if it affects architecture, scope, or defense.
- [ ] It does not weaken RLS, expose service-role secrets, or blur the owner app/dashboard boundary.

## Data Feature Done
- [ ] Schema is defined.
- [ ] Migration exists for the schema change; shipped migrations are not edited in place.
- [ ] Example data exists.
- [ ] Security policy is considered.
- [ ] RLS is tested or manually verified for owner, clinic staff/vet, admin, and unrelated user where relevant.
- [ ] Invalid data behavior is known.
- [ ] Evidence screenshot or sample record is saved for defense if needed.
- [ ] Raw telemetry retention is preserved unless an ADR explicitly overrides it.

## Classifier Feature Done
- [ ] Rule inputs are documented.
- [ ] Rule outputs are documented.
- [ ] Edge cases are listed.
- [ ] Limitations are stated clearly.
- [ ] Media, owner notes, and photos/videos are not classifier inputs.
- [ ] Output copy uses decision-support language, not diagnosis/treatment language.
- [ ] Future Random Forest path is not contradicted.

## UI Feature Done
- [ ] User can understand what happened.
- [ ] Important status has clear wording.
- [ ] No screen depends on fake data unless labeled as demo/simulation.
- [ ] Mobile and dashboard behavior match their role.
- [ ] Loading, empty, permission-denied, offline, and server-error states are visible.
- [ ] Icon-only controls have accessible labels; color is never the only status signal.

## Auth Feature Done
- [ ] Mobile owner/staff auth redirects back to the app-local callback (`localhost` in web dev, custom scheme for APK/native).
- [ ] Dashboard auth redirects only to dashboard origins.
- [ ] Google OAuth and email/password use the same user mirror path (`auth.users` → `public.users` + `user_settings`).
- [ ] Owners cannot land in the dashboard after sign-in; dashboard guards non-clinic/admin roles.

## Manager Rule
If a feature cannot pass this note, mark it as “in progress,” not done.
