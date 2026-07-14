# Morning Summary — FurFeel full-app build (phases 7 → 9 + owner-first polish), 2026-07-12

All three build-order phases are **finished and committed on `main`**: the blue+white design-guide re-theme (7), the dashboard Vet Review + Admin modules (8), and all six mobile modules incl. multi-dog + pairing + push registration (9) — plus an **owner-first polish round** that replaces the raw-history UX with trends and computed insights. Every suite is green at HEAD: **dashboard tsc + 30 tests + vite build · mobile `flutter analyze` clean + 46 tests · edge 67 deno tests**. Nothing was deployed — **two** new migrations and the seed delta need your hands (below).

## Commits (oldest first)

| Commit | What |
|---|---|
| `dc9505e` | Phase 7 dashboard: tokens rewritten to docs/19 blue+white, Tailwind + owned shadcn-style primitives + Tremor charts, sidebar shell, Overview page |
| `386e291` | Phase 7 mobile: Material 3 blue re-theme, Inter, fl_chart vitals trend |
| `40df340` | Phase 8/9 migration: `stress_labels`, `care_guidance` (+4 global rows), pairing RPCs, media bucket + policies, `push_tokens`, admin user-update policy, Realtime adds; seed gets Mochi + an unassigned device |
| `f05da8f` | Phase 8 dashboard: Vet Review (media review + confirm/override → `stress_labels`) + Admin (users/clinics/devices) |
| `306edd3` | Phase 9 mobile: tab shell + dog switcher, Pet Creation, Device Pairing, owner Vet Review, Care Insights, Observation Assessment, push-token path |
| `41095f9` | Test-fixture fix for the new `dogs.photo_path` |
| `(latest)` | Owner-first polish: mobile Trends tab (calm-week stat hero, 14-day stress-mix chart, computed insight cards), Home simplified, raw log demoted, dashboard stress-mix chart, `stress_daily_summary`/`stress_hourly_pattern` RPCs |

## Owner-first polish round (after phase 9)

Product problem addressed: owners weren't reading raw history — they want **actionable graphs and "what's helping"**.

- **New migration `20260712100000_stress_summaries.sql`** (needs push): `stress_daily_summary` + `stress_hourly_pattern` SQL functions — SECURITY INVOKER so the caller's RLS applies unchanged; tz-offset-aware; aggregate server-side so 14 days of trends never ship raw rows to a phone.
- **Mobile History tab → Trends tab**: "Calm time this week" stat hero with week-over-week delta → 100%-stacked daily stress-mix chart (status colors + word legend, composition not volume) → **insight cards**: weekly trend, calmest/tensest time of day, activity↔calm association (median split, minimum-sample guards so nothing is claimed without data), alert trend, data-coverage caveat. Engine is pure (`lib/insights/insights.dart`), 9 unit tests including a **no-diagnosis-language test**; all copy is observational ("tends to", "worth a look").
- **Home simplified**: the 20-row raw readings list is gone; a one-line "Calm N% of today so far (+Δ vs yesterday)" strip replaced it. Raw vitals chart/timeline/readings live behind **"View detailed log"** on Trends.
- **Dashboard dog detail** gains the matching "Stress mix — last 14 days" Tremor stacked chart from the same RPC.
- Followed the dataviz skill's method: stat-tile-over-chart for headlines, composition normalized to 100%, status palette used only for statuses, legend + words so meaning never rides on color alone, no dual axes, no chartjunk.

## Phase 7 — re-theme (docs/19, blue + white)

- `packages/shared/design_tokens.json` rewritten verbatim to the updated docs/19: brand `#2563EB`, cool neutrals, canonical stress ramp, owner-warmth layer (`warm`/`warm-soft`), softened owner-app high (`#E5533D`), Inter, per-platform radius sets, 7-step spacing, new card shadow, 150/250ms motion.
- Generator now emits **three** files: `tokens.css` (CSS vars), **`apps/dashboard/tailwind.tokens.js`** (Tailwind theme incl. computed 50–950 shade scales so Tremor's dynamic `stroke-brand-500`-style classes stay token-driven), and `furfeel_tokens.dart`. Rerun `node packages/shared/scripts/generate_design_tokens.mjs` after editing the JSON.
- **Dashboard** now runs Tailwind 3 + owned shadcn-style primitives (`src/components/ui/`: button, card, badge, input/select/textarea, table, dialog, toast, skeleton, empty-state) + **Tremor `LineChart`** for telemetry (replacing the hand-rolled SVG). Left sidebar per docs/19 §7 (Overview · Board · Alerts · Reports · Admin-when-admin). Inter via Google Fonts. No hardcoded hex in components; Tremor's theme block in `tailwind.config.js` is wired to the generated token values.
- **Mobile** re-themed: Inter, blue seed, hairline card borders, `NavigationBar` theme; owner `high` uses the softened coral per the docs note.

## Phase 8 — dashboard modules (docs/05)

- **Vet Review** (`/dogs/:id/review`, linked from dog detail): confirm/override control preselects the model's level so confirming is one click; saving writes a `stress_labels` ground-truth row with `agreed_with_model` computed in the pure, unit-tested `buildStressLabelInsert`. Past assessments list with confirmed/override badges. Owner-media panel: signed-URL previews from the private bucket, mark-reviewed + annotation (`review_note`), and explicit "not used by the stress classifier" copy.
- **Admin** (`/admin`, shown to admins; RLS is the real gate): users role+clinic inline editing, clinic create/list, device register/assign/status, plus a dog↔clinic assignment table (docs/04 says Admin can reassign a dog's clinic).

## Phase 9 — mobile modules (docs/04)

- **Shell**: bottom tabs Home · Alerts · History · Profile, **dog switcher in the header** (multi-dog), open-alert badge on the Alerts tab, first-run onboarding for zero-dog accounts. One Realtime subscription per selected dog feeds all tabs.
- **Pet Creation** (Profile → Add/edit): name, breed, birthdate picker (→ computed age), sex, weight, notes, photo (→ `media` bucket + `dogs.photo_path`), and **clinic linkage** — picking a clinic sets `dogs.clinic_id`, which puts the dog on that clinic's live board (the board also reloads on unknown-dog Realtime events so newly linked dogs appear without refresh). Deleting a dog with monitoring history is refused with a friendly explanation (ADR-003 — telemetry is never deleted).
- **Device Pairing**: pair by `device_code` via the `pair_device` RPC (friendly errors for not-found / already-paired), connectivity + last-sync + offline guidance, unpair with confirmation.
- **Vet Review (owner)**: confirmed stress assessments (`stress_labels`) + clinic notes, read-only; threaded follow-up deferred (docs/04 marks it optional).
- **Care Insights**: warm-tinted card on Home showing `care_guidance` for the current stress level; clinic rows override globals via pure `selectCareGuidance`; "not a diagnosis" on-screen.
- **Observation Assessment**: photo / ≤30s video + note → Storage + `media_submissions`; "Supplementary — not used by the stress classifier" is rendered on the submit card; past submissions show review status + the clinic's annotation.
- **Push**: `push_tokens` table + `registerPushToken` upsert + `registerPushTokenIfAvailable()` hook called at shell startup. It's a structured no-op until FCM/APNs is wired (see "needs your hands").

## Migration `20260711170000_full_app_modules.sql` (NOT yet pushed)

`stress_labels` (+ indexes, clinic-staff insert/select, owner select), `care_guidance` (+ 4 global default rows so Care Insights works out of the box), `media_submissions.review_note`, `dogs.photo_path`, `push_tokens` (own-rows RLS), `users_update_admin` policy, `pair_device`/`unpair_device` security-definer RPCs (ingest hash never exposed), private `media` storage bucket + owner-upload/owner-update/clinic-read object policies, Realtime publication + replica identity for `dogs`/`devices`/`vet_notes`/`media_submissions`/`stress_labels`.

## Every ASSUMPTION

1. **Owners can SELECT their own dog's `stress_labels`.** docs/09 says clinic-staff-only, but docs/04 module 5 requires owners to see "confirmed stress assessments". Additive owner-read policy; staff scoping and writes unchanged. Flagged in the migration comment.
2. **Admin user management edits role/clinic of existing accounts only** — creating auth users needs the service role, which never ships in a client. New staff sign up in an app, then an admin promotes them.
3. **Device pairing via RPCs** instead of widening `devices` RLS (devices stay admin-managed per docs/03). Pairing normalizes the code to uppercase. Unpairing sets the device `inactive`.
4. **Dog deletion** is allowed only for dogs with no dependent rows (FKs enforce it); the app explains history is preserved. docs/04's "archive" alternative would need a schema column — not added.
5. **`care_guidance` global defaults' wording** is mine (plain-language, no diagnosis/treatment claims) — a vet should review the copy.
6. **Media path convention** `dogs/<dog_id>/…` in one private `media` bucket; storage policies key off that layout.
7. **Overview page content** (KPIs, needs-attention, latest alerts) is my interpretation — docs list "Overview" in the nav but never specify it.
8. **QR scanning** for pairing deferred (docs allow "entering/scanning"); code entry avoids a camera dependency.
9. **Vet Review lives per-dog** (`/dogs/:id/review`) rather than as a 6th sidebar item, because docs/19 + docs/05 both fix the sidebar at five items.
10. **Replica identity full** on dogs/devices/media_submissions so filtered UPDATE subscriptions work; slightly larger WAL, fine at this scale.

## ADDED features (beyond the docs, marked `// ADDED:` where in code)

Dashboard: Overview page; board search + needs-attention filter; toast system; loading skeletons everywhere; confirm dialog primitive; device online-dot component; board self-heals when an unknown dog's telemetry arrives (new clinic linkage appears live).
Mobile: fl_chart vitals trend on History; device connectivity chip in the status hero; quick-link tiles on Home; first-run onboarding; open-alert badge on the Alerts tab; live "Add <name>" CTA on the pet form; friendly pairing error messages.

## What needs your hands

1. **Push the migrations** (remote ops are permission-blocked for me): `supabase db push --linked` — applies `20260711150000_device_offline_alerts.sql` (if still pending), `20260711170000_full_app_modules.sql`, **and `20260712100000_stress_summaries.sql`** (the Trends tab shows its empty state until this one lands). All non-destructive.
2. **Still pending from last session** (if not done): `supabase functions deploy telemetry-intake --use-api` for offline-recovery.
3. **Seed delta** — the updated `supabase/seed/seed.sql` only runs on `db reset` (destructive on the shared project). To prove the multi-dog board + pairing without a reset, run this in the SQL editor:
   ```sql
   insert into public.dogs (id, owner_user_id, clinic_id, name, breed, birthdate, sex, weight_kg, notes)
   values ('00000000-0000-0000-0000-000000000006','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','Mochi','Shiba Inu','2023-08-02','female',9.80,'Independent; dislikes thunderstorms.');
   insert into public.devices (id, dog_id, device_code, status, firmware_version)
   values ('00000000-0000-0000-0000-000000000007', null, 'FURFEEL-DEV-0002', 'inactive', '0.1.0');
   insert into public.dog_baselines (dog_id, resting_heart_rate_bpm, resting_respiratory_rate_bpm, normal_body_temperature_c)
   values ('00000000-0000-0000-0000-000000000006', 100, 24, 38.6);
   ```
4. **FCM/APNs wiring** (the one deliberately-human piece of push): add `firebase_messaging` + platform config (google-services.json / GoogleService-Info.plist), then pass the token into `registerPushTokenIfAvailable(repository, tokenProvider: ...)` in `lib/pages/root_shell.dart`. Server-side delivery (an Edge Function reading `push_tokens` on alert insert) is also future work.
5. **Browser check**: `cd apps/dashboard && npm run dev` → `vet@example.com` / `password123`. Look at: blue+white theme everywhere, Overview, board filter/search, dog detail → **Vet review** (confirm/override + media), `/alerts`, `/reports`. For Admin, promote a user to `admin` first (SQL editor) and check `/admin`.
6. **Emulator check**: `cd apps/mobile && flutter run --dart-define-from-file=env.json` → `owner@example.com` / `password123`. Try: dog switcher (after seeding Mochi), Profile → add/edit dog with clinic linkage (watch it appear on the dashboard board live), pair `FURFEEL-DEV-0002`, share an observation (then review it on the dashboard), Care Insights card, Vet review after confirming a level on the dashboard.
7. **Uncommitted files I left alone** (yours, pre-existing): `CLAUDE.md`, four `docs/*.md`, `firmware/simulator/package.json`. Commit them when ready — the code now matches the updated docs. Note: `apps/mobile/macos|web` platform scaffolding got committed with phase 9 (needed to run on those targets); the stale `flutter create` template test was deleted.

## Exact next prompt to continue

```
Read MORNING_SUMMARY.md. I've run `supabase db push --linked` and the seed delta.
Verify end to end with the simulator + both apps: (1) confirm/override on the
dashboard writes stress_labels and shows up in the mobile Vet Review; (2) an
observation uploaded from mobile appears in the dashboard Vet Review with a
signed preview and mark-reviewed round-trips; (3) creating a dog with a clinic
on mobile appears live on the dashboard board. Fix anything that doesn't hold.
Then continue polish: FCM server-side delivery Edge Function reading
push_tokens on alert insert (leave credential wiring to me), QR scan pairing,
and dashboard code-splitting (vite chunk warning). Same rules: docs are law,
tokens/types in packages/shared, never weaken RLS, never delete raw telemetry,
ASSUMPTION notes for gaps, commit per step, rewrite MORNING_SUMMARY.md.
```
