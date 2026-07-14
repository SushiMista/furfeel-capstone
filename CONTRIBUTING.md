# Contributing to FurFeel

Thanks for helping build FurFeel. Please read this and `CLAUDE.md` before opening a PR.

## Getting set up
Full Windows + macOS setup (tools, env files, running each app, and the AI toolchain) is in **[`docs/Developer Setup Guide.md`](docs/Developer%20Setup%20Guide.md)**.

## Ground rules (non-negotiable)
- **Never commit secrets.** No real keys, `.env` files, or device ingest keys. Only `.example` files.
- **Never weaken Row Level Security** to make something work — fix the policy instead. RLS covers every table and storage bucket.
- **Never delete raw telemetry** (ADR-003). Store the raw payload before classification.
- **No "diagnosis" language** anywhere. FurFeel is decision support; owner-facing copy stays observational (there are tests asserting this).
- **Don't call the classifier "Random Forest"** — it's `rule-v1` until a trained model exists.
- **Colors come from tokens** (`docs/19 Design System` → `packages/shared/design_tokens.json`). No hardcoded hex in components.
- **Media is supplementary** and never a classifier input.

## Workflow
1. Branch from `main`; keep changes small and scoped (one feature per PR).
2. When touching data, write the **migration first**, then backend, then client.
3. Reference the relevant spec in `docs/` in your PR description.
4. Make sure tests pass locally:
   - Dashboard: `cd apps/dashboard && npm test`
   - Mobile: `cd apps/mobile && flutter analyze && flutter test`
   - Edge: `cd services/edge && deno test`
5. Record any architectural decision as an ADR in `docs/02 Architecture Decisions`.

## Commit style
Small, scoped commits with clear messages (e.g. `feat(dashboard): photo dog-cards`, `fix(rls): qualify objects.name in media policy`).

## Coding conventions
Tables plural `snake_case`; every table `id uuid default gen_random_uuid()` + `created_at timestamptz default now()`; validate every input server-side; anon key only in clients (service-role key only in Edge Function env). See `CLAUDE.md` for the full list.
