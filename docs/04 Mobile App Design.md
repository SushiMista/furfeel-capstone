---
title: "Mobile App Design"
type: product-design
project: FurFeel
created: 2026-07-09
updated: 2026-07-11
tags: [furfeel, mobile, ux]
---

# Mobile App Design (Owner App — Flutter)

Full owner-app spec covering **all six manuscript modules**. Style: follow [[19 Design System]] (blue brand, warm/approachable owner layer, Material 3 + fl_chart). Anon key only; every query RLS-scoped to the signed-in owner (`owner_user_id = auth.uid()`). Media is supplementary and **never** a classifier input. No diagnosis language.

## Navigation (as built)
Floating bottom tab bar: **Home · Alerts · Trends · Profile**. A dog switcher + logo in the header (multi-dog accounts). The occasional actions live under **Profile**: Account, Settings, Pet Creation, Device Pairing, Vet Review (owner), Observation Assessment, About/How-it-works, Partner Clinics, sign out. Daily experience: open app → see how the dog is.

### First-run onboarding
Animated **Splash → Welcome → Onboarding → Guided Setup** (create account or Google sign-in → add your dog → pair a harness → done), warm animated steps, not blank screens.

### As-built owner screens (beyond the base modules)
- **Home (multi-dog):** accounts with 2+ dogs land on a **glanceable card per dog** — photo, name, stress pill, wellness score, one key vital, harness battery, last-updated. Tapping a card opens that dog's **full detail** (the rich single-dog Home below, self-loading + live). Single-dog owners land straight on the rich detail.
- **Home (single dog / dog detail):** greeting by name/time; big stress status + plain-language "why" (`primary_reason`); a **2×2 grid of tappable vital cards**, each carrying a **plain-language status word** (Low / Normal / Elevated / High, token-colored) derived from the dog's own baseline (`dog_baselines`, else the provisional global range) → each opens a **Vital Detail** page with the value, a status sentence ("Heart rate 92 bpm — Normal for Biscuit"), the typical resting range, and an owner-friendly explanation; an animated **calm-percentage ring**; the latest vet note inline (live via Realtime); harness status chip includes **battery %** with a low-battery state.
- **Care Insights (combination-aware):** the tip is keyed off the **combination** of signals + environment when one applies (`cold_stressed`, `hot_stressed`, `panting_hot`, `restless_high_hr`, `cold_calm`, `hot_calm` — see `08`), falling back to the per-level guidance. Vet-editable via `care_guidance.context_key`.
- **Trends tab:** "calm time this week" headline with a week-over-week delta; a **daily wellness score card** (0–100 provisional engineering score + active/rest/calm balance bar, labeled "not a medical score"); a **7 / 14 / 30-day stress-mix** chart (100%-stacked bars in the status colors); computed, honesty-guarded **insight cards** with minimum-sample thresholds and strictly observational wording (no diagnosis, no causal claims).
- **Detailed Log (redesigned):** friendly **per-vital mini-dashboards** (fl_chart line + min/avg/max chips) over a selectable range (24h / 7d / 30d / custom date range), with **downloadable exports** — CSV of the raw readings always, plus a shareable **PDF health report** (share sheet on mobile, plain browser download on web). Both carry the decision-support disclaimer.
- **Observation Assessment → conversations:** every past submission opens a **threaded conversation** (media up top, the owner's note, the clinic's review, then `media_messages` replies back and forth like an email chain, with a composer).
- **Device Pairing** can pick from a **Partner Clinics** list to set the dog's clinic; shows **battery health** (% + "time for a charge" low state) alongside connectivity.
- **Alerts:** all/by-type view with a per-type mute switch, persisted to `user_settings.muted_alert_types` (in-app + preference; server-side push suppression is the pending FCM step). The Harness group covers `device_offline` + `low_battery`. All alert copy is warm and observational, names the dog and the sensed reason (see `11`).
- **Consent gate (docs/12):** after sign-in, monitoring data and media features stay locked until the current data-collection policy version is accepted; the realtime subscription doesn't start before that. Policy bump = re-consent.
- **Theme:** new installs open in **light** mode (`user_settings.theme` default `'light'`); Light / Dark / System remain selectable, System demoted to last.

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
