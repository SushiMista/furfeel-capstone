---
title: "Mobile App Design"
type: product-design
project: FurFeel
created: 2026-07-09
updated: 2026-07-18
tags: [furfeel, mobile, ux]
---

# Mobile App Design (Owner App — Flutter)

Full owner-app spec covering **all six manuscript modules**. Style: follow [[19 Design System]] (blue brand, warm/approachable owner layer, Material 3 + fl_chart). Anon key only; every query RLS-scoped to the signed-in owner (`owner_user_id = auth.uid()`). Media is supplementary and **never** a classifier input. No diagnosis language.

## Navigation (as built)
Floating bottom tab bar: **Home · Alerts · Trends · Profile**, plus a **detached Chat box** beside the pill (2026-07-24). Chat sits outside the pill because messaging is a different *kind* of destination than a view switch. The bar is **icon-only** — no captions. Selection still never rides on colour alone: the current item swaps to its *filled* glyph and gains a soft brand pill behind it. Every destination keeps its name in `Semantics` (a badged tab announces as “Alerts, 3 new”), so screen readers read what the bar no longer draws. A dog switcher + logo in the header (multi-dog accounts); the switcher hides on the multi-dog Home — the cards are the dog list there — and on Profile/Chat, which pick their own dog. The occasional actions live under **Profile**: Account, Settings, Pet Creation, Device Pairing, Vet Review (owner), Observation Assessment, About/How-it-works, Partner Clinics, sign out. Daily experience: open app → see how the dog is.

### Chat (2026-07-24)
The owner's messaging front door. The conversation substrate already existed — `media_messages` threads hanging off a submitted observation, RLS'd to the dog's owner + that dog's clinic staff, live over Realtime, with author-only edit/delete — but the only way in was Profile → Observation Assessment → tap a past submission.
- **Dog picker:** multi-dog accounts pick a dog first (conversations are granted per dog), each row showing the dog + latest message preview. A single-dog owner skips the picker entirely — a one-row list is pure friction.
- **Per-dog chat:** the clinic's **latest `vet_notes` entry pinned on top** as the care-team reminder (person-authored, with author name + avatar), a count of earlier notes, then every conversation thread for that dog. Each thread row shows its preview, media type, and **Reviewed / Awaiting your clinic** as a word + icon, never colour alone. Tapping opens the existing threaded `MediaThreadPage`.
- **Deliberately not in Chat:** `care_guidance` (Care Insights). It is rule-derived, not written by a clinician — rendering it as a chat bubble would make an algorithm look like a message from a named person. It stays on the dog's Care Team tab, labelled as general guidance.
- **Known limit (phase 3):** `media_submissions.storage_path` is `not null`, so a conversation can only be *started* by sharing a photo or video. The empty state says so honestly rather than offering a composer that can't work yet. Making `storage_path`/`media_type` nullable would allow text-only messages while reusing every existing policy, the realtime publication, and the thread UI.
- **No unread badge:** neither `media_messages` nor `vet_notes` stores a per-user read state, and a badge that can never clear is worse than none. Adding `last_read_at` is the prerequisite.

### Launch + splash (2026-07-24)
Two stages, deliberately made to look like one. **Stage 1** is the Android 12+ system splash, drawn by the OS before Flutter exists — it can't be a Flutter animation, so `values-v31/styles.xml` sets `windowSplashScreenBackground` to `@color/splash_background`, generated from `design_tokens.json` (the OS can't read the Dart tokens). **Stage 2** is Flutter's `SplashPage` on the *same* background with the same mark — `FurFeelLogo.auth`, the gradient paw + two-tone wordmark the auth screens use — so the handoff reads as one moment rather than two screens.

The minimum splash time is **400 ms** (was 1500 ms), with a 320 ms cross-fade into the first real screen: the floor exists only so a fast start doesn't flash the logo for a frame, not to pad the launch. A **loader appears only on the signed-in settings load**, which is a real network call that can hang — and only after 600 ms, so a quick load never flashes a bar. That delay applies under reduced motion too (avoiding a flash is not a motion preference); reduced motion only skips the fade.

### First-run onboarding
Animated **Splash → Welcome → Onboarding → Guided Setup** (create account or Google sign-in → add your dog → pair a harness → done), warm animated steps, not blank screens.

### As-built owner screens (beyond the base modules)
- **Home (multi-dog):** accounts with 2+ dogs land on a **minimalist glance row per dog** — photo, name, breed, stress pill. No raw numbers on the glance card (owner feedback): vitals, wellness, and battery live on the dog's own page. Tapping a card opens that dog's **full detail** (the rich single-dog Home below, self-loading + live). Single-dog owners land straight on the rich detail.
- **Home (single dog / dog detail):** greeting by name/time; big stress status hero + plain-language "why" (`primary_reason`); below the hero, a **pill tab bar — Vitals · Activity** — keeps the page glanceable instead of one long scroll. (The third tab, Care Team, was retired 2026-07-24 when Chat took over the vet-note feed; see below.)
  - **Vitals:** the **Care Insights card** (rule-derived guidance for the current level — it stays here rather than moving to Chat, because it is not written by a clinician), then a **battery-health card** for the paired harness (charge, connectivity, friendly contextual notes, Manage → Device Pairing) above the **2×2 grid of tappable vital cards**, each carrying a **plain-language status word** (Low / Normal / Elevated / High, token-colored) derived from the dog's own baseline (`dog_baselines`, else the provisional global range) → each opens a **Vital Detail** page with the value, a status sentence ("Heart rate 92 bpm — Normal for Biscuit"), the typical resting range, and an owner-friendly explanation.
  - **Activity:** the animated **calm-percentage ring** ("today so far" + vs-yesterday trend) and the "today, hour by hour" banded strip.
  The hero's harness status chip still shows **battery %** with a low-battery state. Vet notes and the Vet review / Share an observation links moved to **Chat** and **Profile** respectively, so nothing has two homes.
- **Care Insights (combination-aware):** the tip is keyed off the **combination** of signals + environment when one applies (`cold_stressed`, `hot_stressed`, `panting_hot`, `restless_high_hr`, `cold_calm`, `hot_calm` — see `08`), falling back to the per-level guidance. Vet-editable via `care_guidance.context_key`.
- **Trends tab:** "calm time this week" headline with a week-over-week delta; a **daily wellness score card** (0–100 provisional engineering score + active/rest/calm balance bar, labeled "not a medical score"); a **7 / 14 / 30-day stress-mix** chart (100%-stacked bars in the status colors); computed, honesty-guarded **insight cards** with minimum-sample thresholds and strictly observational wording (no diagnosis, no causal claims).
- **Detailed Log (redesigned):** friendly **per-vital mini-dashboards** over a selectable range (24h / 7d / 30d / custom date range), with **downloadable exports** — CSV of the raw readings always, plus the shareable **PDF health record** (share sheet on mobile, plain browser download on web). Both carry the decision-support disclaimer. Charts use the **baseline technique** (2026-07-24, borrowed from trading charts): one dashed line at the period average, with the fill shaded two tones — one above, one below — instead of a bare line, so "was this reading above or below normal for this dog" reads at a glance.
- **PDF health record (transferable):** the PDF (Trends "Share weekly report" + Detailed Log export) is formatted as a document another veterinary clinic can file — blue FurFeel masthead with issue date, side-by-side **Patient / Owner / Veterinary clinic** panels (breed, sex, birthdate + age, weight; owner contact + emergency contact; clinic name + address or "home monitoring"), a vitals table with units and min/avg/max, a **stress-distribution table** with color swatches + proportional bars, an **alert history** for the period, and a per-page footer with the disclaimer and page numbers. Empty fields print as a dash so the receiving clinic sees "empty," not "omitted."
- **Observation Assessment → conversations:** every past submission opens a **threaded conversation** (media up top, the owner's note, the clinic's review, then `media_messages` replies back and forth like an email chain, with a composer).
- **Device Pairing** can pick from a **Partner Clinics** list to set the dog's clinic; shows **battery health** (% + "time for a charge" low state) alongside connectivity. Battery everywhere (Home hero chip, multi-dog cards, pairing) uses a **level-aware icon** (7 fill steps; red ≤15%, amber ≤30%, green above) instead of a binary full/alert glyph.
- **Alerts:** all/by-type view with a per-type mute switch, persisted to `user_settings.muted_alert_types` (in-app + preference; server-side push suppression is the pending FCM step). The Harness group covers `device_offline` + `low_battery`. The list is **grouped under date headers** (Today / Yesterday / full date) so "when did this happen?" reads first, and each card leads with its **timestamp**, a **severity-tinted type icon** (high stress, moderate stress, offline harness, low battery), and a **severity chip** — Critical (red) / Warning (orange) / Info (blue), word + color, never color alone. All alert copy is warm and observational, names the dog and the sensed reason (see `11`).
- **Consent gate (docs/12):** after sign-in, monitoring data and media features stay locked until the current data-collection policy version is accepted; the realtime subscription doesn't start before that. Policy bump = re-consent.
- **Theme:** new installs open in **light** mode (`user_settings.theme` default `'light'`); Light / Dark / System remain selectable, System demoted to last. Implementation: colors ride a Material `ThemeExtension` (`context.ff`, ADR-012); `MaterialApp` uses `theme`/`darkTheme`/`themeMode`.

### Improvement pass (2026-07-19)
- **Demo mode (ADR-014):** "Explore the demo (sample data)" on Welcome opens the real app shell over a fully local `DemoRepository` — a deterministic generated week (calm nights, lively mornings, one warm afternoon that reaches `moderate` and leaves an open alert). Persistent "Demo mode — sample data, not a real dog" banner; writes refused with friendly copy; nothing touches Supabase.
- **Offline resilience:** after every successful load the app caches the dogs list + selected dog's latest reading/classification (`StatusCache`). A dead network shows that snapshot behind a warm "Showing last known reading from … — pull to refresh" banner instead of an error. Only a **server-confirmed** consent for the exact current policy version is cached, so the consent gate still wins when acceptance was never confirmed. Cache clears on sign-out.
- **True-cause error copy:** every failure names its actual cause (offline / session expired / permission denied / server rejection / timeout) via `util/errors.dart`; shared `RetryMessage` view for load failures. No blanket "something went wrong" where the cause is known.
- **Full data export (docs/12):** Detailed Log → "Download everything (JSON)" — the complete per-dog archive (profile, dog, baseline, device, ALL readings + classifications paged past the row cap, alerts, vet notes, stress labels, media metadata) with the decision-support disclaimer.
- **Accessibility:** status/warm text tokens darkened to pass 4.5:1 (docs/19, CI-checked); Semantics labels on icon-only controls; dynamic type verified at 2× (nav-bar labels cap at 1.3× per Material guidance).

### Owner-delight layer (2026-07-18 pass)
- **Guided setup checklist** on Home until the harness is paired and the first reading lands (clinic step optional, never blocks); steps deep-link to pairing / the dog form.
- **"Today, hour by hour"** banded stress strip (docs/19 §6) with a word legend; dominant level per hour, ties break toward the more elevated level.
- **Calm-streak card** on Trends (≥2 mostly-calm days; 70% share threshold — provisional, product-tunable) and a **birthday moment** on Home from `dogs.birthdate`. Celebration copy is observational only.
- **One-tap "Share weekly report"** on Trends (last 7 days → the PDF exporter).
- **Alert action tips:** every open alert carries a practical "what you can do" line per type; gone once acknowledged.
- **Ambient context** on the status hero (ambient temp in the preferred unit + humidity) — the environment is often the classifier's story.
- **"Last 3 hours" sparkline** on each vital detail screen.
- **Live in-app alert banner** while the app is open (floating snackbar with the friendly message + View → Alerts); honors the master notification toggle and per-type mutes — the same rules push will follow.
- **Care tips library** under Profile: all vet-editable guidance browsable by stress level and by situation.

## Modules (manuscript)

### 1. User Dashboard (Home)
Primary status screen for the selected dog. Always shows valuable info at a glance — never a bare/empty screen.
- Stress hero: large stress pill (cross-fading color) + reassuring copy.
- **The "why" (important):** a plain-language reason under the pill, derived from the classification's `reasons` (stress_classifications.reasons). Surface the **top driver** in owner-friendly words, e.g. high ambient temp/humidity → "Feeling the heat — it's warm and humid today"; elevated HR → "Heart rate is higher than usual"; high motion → "Restless and moving a lot"; calm → "Relaxed and comfortable." Mapping lives in a small reason→phrase table (see `08 AI Classification Pipeline`). This turns a label into something an owner understands and can act on.
- Vital cards: heart rate, respiratory rate, body temperature, motion — big tabular values + units + "updated Xs ago". Include ambient temp/humidity when they're the driver (so "it's hot" is visible).
- 24h trend sparkline + a "what you can do" care tip (Care Insights) tied to the current driver.
- Live via Supabase Realtime. Pull-to-refresh. Loading/offline/error states visible.

### 2. Pet Creation / Profiles
Create and manage **multiple** dog profiles in one account.
- Add/edit dog: name, breed, birthdate (→ age), sex, weight, medical history/notes, photo (Storage).
- Dog list + switcher; delete/archive.
- Writes to `dogs` (owner_user_id = auth.uid()) and optional `dog_baselines`.
- **Clinic linkage (important):** during creation (or Device Pairing) the owner may select an associated clinic → sets `dogs.clinic_id`. Setting it makes the dog appear **live on that clinic's monitoring board** (Realtime). `clinic_id = null` = home-only monitoring, not on any clinic board. Admin can also assign/reassign a dog's clinic. (Boarding "visits" over time are future work — one `clinic_id` for MVP.)

### 3. Observation Assessment
Owner-submitted supplementary context.
- Submit notes, photos, and short videos (upload to Supabase Storage → `media_submissions`).
- Every media view labeled "Supplementary — not used by the stress classifier."
- List of past submissions with review status.

### 4. Care Insights
Automated, plain-language guidance for the current stress state.
- Shows vet-authored guidance mapped to the current stress level (informational only; never "diagnosis"/"treatment").
- Content source: a `care_guidance` lookup (stress_level → guidance text), editable by vets.

### 5. Vet Review (owner side)
Owner reads clinician output and follows up.
- Displays vet recommendations/notes for the dog (`vet_notes`) and any confirmed stress assessments.
- Threaded follow-up: **built** for media submissions (`media_messages` — see Observation conversations above); vet notes remain read-only.

### 6. Device Pairing & Setup
- Pair a device by entering/scanning its `device_code`; show connectivity, `last_seen_at`, offline and low-battery states.
- Calls the device register/status endpoints; reflects `devices.status`.

## Account, Settings & Personalization (make it feel like a real app)
The app should feel personal and complete, not a demo.
- **Personalized greeting:** Home greets the owner by name + time of day ("Good morning, Joshua 👋") with the dog front and center.
- **Onboarding / sign-up:** a real first-run flow — welcome, create account (Supabase Auth), then a friendly guided setup (add your dog → pair a device → done). Warm empty states, not blank screens.
- **Profile / Account:** name, email, profile photo (`users.avatar_path` → Storage), change password, sign out, delete account.
- **Settings** (backed by `user_settings`): theme (light default; light/dark/system), temperature unit (°C/°F), notification toggles + quiet hours, plus About, Privacy, and "How FurFeel works" (reinforce decision-support-not-diagnosis).
- Live under the **More** tab (Profile, Settings, plus the occasional modules).

## Notifications
Push alert when stress crosses **moderate/high** or the device goes **offline**; deep-link into the alert detail. In-app alert list + detail with **Acknowledge**. (FCM/APNs wiring may be finished by a human — build the in-app + token-registration side.)

## MVP priority order
1. User Dashboard (done) → 2. Alerts + acknowledge (done) → 3. History (done) → 4. Pet Creation → 5. Device Pairing → 6. Vet Review (owner) → 7. Care Insights → 8. Observation Assessment → 9. Push notifications.

## Related
- [[19 Design System]]
- [[03 User Roles and Permissions]]
- [[11 Alerts and Notifications]]
- [[10 API and Backend Services]]
- [[09 Database Schema]]
