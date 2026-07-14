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

## Navigation (simplified for owners)
Bottom tab bar: **Home · History · More** (3 tabs only — keep it glanceable). A dog switcher in the header for multi-dog accounts. Alerts surface as a **banner on Home + a bell icon**, not a primary tab. **More** holds the occasional actions: add/switch pets (Pet Creation), Device Pairing, Vet Review (owner), Observation Assessment, notification settings, sign out. The daily experience is: open app → see how the dog is.

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
- Simple threaded follow-up message back to the clinic (optional MVP: read-only first).

### 6. Device Pairing & Setup
- Pair a device by entering/scanning its `device_code`; show connectivity, `last_seen_at`, offline and low-battery states.
- Calls the device register/status endpoints; reflects `devices.status`.

## Account, Settings & Personalization (make it feel like a real app)
The app should feel personal and complete, not a demo.
- **Personalized greeting:** Home greets the owner by name + time of day ("Good morning, Joshua 👋") with the dog front and center.
- **Onboarding / sign-up:** a real first-run flow — welcome, create account (Supabase Auth), then a friendly guided setup (add your dog → pair a device → done). Warm empty states, not blank screens.
- **Profile / Account:** name, email, profile photo (`users.avatar_path` → Storage), change password, sign out, delete account.
- **Settings** (backed by `user_settings`): theme (system/light/dark), temperature unit (°C/°F), notification toggles + quiet hours, plus About, Privacy, and "How FurFeel works" (reinforce decision-support-not-diagnosis).
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
