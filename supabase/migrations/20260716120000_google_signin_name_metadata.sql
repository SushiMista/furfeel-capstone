-- =========================================================================
-- Google sign-in support (ADR-011): OAuth signups arrive with the display
-- name under `full_name` (Google), not the `name` key our email signup sends.
-- Fall through name -> full_name -> email prefix so no provider path lands
-- a user with a missing display name. Everything else is unchanged from
-- 20260712150000 (users mirror + user_settings defaults row).
-- =========================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.users (id, name, email, role)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'name',
      new.raw_user_meta_data ->> 'full_name',
      split_part(new.email, '@', 1)
    ),
    new.email,
    'owner'
  );
  insert into public.user_settings (user_id) values (new.id);
  return new;
end;
$$;
