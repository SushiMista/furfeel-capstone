# apps/mobile — Flutter Owner + Staff App

Flutter app for dog owners and clinic staff. Displays real-time stress status, alerts, and history via Supabase Realtime, styled per `docs/19 Design System` (tokens generated into `lib/theme/furfeel_tokens.dart` from `packages/shared/design_tokens.json`).

See `docs/04 Mobile App Design` and `docs/05 Sprint 4 - Mobile App Checklist`.

## Running

Supabase client config comes in via `--dart-define-from-file`. Create `env.json` in this directory (gitignored):

```json
{
  "SUPABASE_URL": "https://<project-ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<anon key>"
}
```

Then:

```sh
flutter run --dart-define-from-file=env.json
```

Sign in as the seeded owner: `owner@example.com` / `password123`. Only the anon key is used — every query is scoped by RLS to the signed-in owner's dogs.

## Checks

```sh
flutter analyze
flutter test
```

## Structure

- `lib/theme/` — generated design tokens + `buildFurFeelTheme()` (Nunito via `google_fonts`).
- `lib/models/` — Dart mirrors of the canonical row shapes in `packages/shared/types/`.
- `lib/data/furfeel_repository.dart` — all Supabase access (queries + Realtime subscription), behind an interface so widget tests use a fake.
- `lib/pages/` — login, owner home (status hero, alerts, recent readings).
- `lib/widgets/` — status pill, big vital numbers, alert card.
