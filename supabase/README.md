# supabase — Database, Auth, RLS

- `migrations/` — numbered SQL: schema, enums, RLS policies, indexes. One migration per change; never edit a shipped migration.
- `seed/` — local dev seed data (1 clinic, 1 owner, 1 dog, 1 device).
- `config.toml` — Supabase CLI project config (added when the CLI is initialized).

See `docs/09 Database Schema`.

_No migrations yet — scaffold only._
