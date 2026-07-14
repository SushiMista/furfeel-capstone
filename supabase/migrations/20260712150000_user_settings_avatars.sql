-- User settings + avatars (docs/09 user_settings, users.avatar_path;
-- docs/04 Account/Settings/Personalization; docs/05 vet account menu).
-- Everything here only ADDS capability; no existing policy is weakened.

-- =========================================================================
-- users.avatar_path — profile photo in the private `avatars` bucket
-- (<user_id>/avatar.*); clients resolve it with a signed URL. Additive
-- column; users_update_own already permits the owner to set it.
-- =========================================================================

alter table users add column avatar_path text;

-- =========================================================================
-- user_settings — per-user preferences (docs/09). One row per user.
-- =========================================================================

create table user_settings (
  user_id                uuid primary key references users (id) on delete cascade,
  theme                  text not null default 'system' check (theme in ('system', 'light', 'dark')),
  temperature_unit       text not null default 'c' check (temperature_unit in ('c', 'f')),
  notifications_enabled  boolean not null default true,
  quiet_hours_start      time,
  quiet_hours_end        time,
  updated_at             timestamptz not null default now()
);

alter table user_settings enable row level security;

-- docs/09: a user reads/writes only their own row.
create policy user_settings_own_all on user_settings
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Backfill a defaults row for every existing user (incl. seed users).
insert into user_settings (user_id)
select id from users
on conflict (user_id) do nothing;

-- New signups get a defaults row alongside their public.users mirror.
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
    coalesce(new.raw_user_meta_data ->> 'name', split_part(new.email, '@', 1)),
    new.email,
    'owner'
  );
  insert into public.user_settings (user_id) values (new.id);
  return new;
end;
$$;

-- =========================================================================
-- Storage: private `avatars` bucket, path convention <user_id>/avatar.*.
-- Owner-scoped: each user manages only their own folder.
-- =========================================================================

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false)
on conflict (id) do nothing;

create policy avatars_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy avatars_update_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy avatars_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy avatars_select_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- =========================================================================
-- Dashboard dog photos (docs/05): clinic staff may upload/replace a
-- monitored dog's profile photo. Scoped to the dogs/<dog_id>/profile.*
-- object only — observation media stays owner-write (ADR-010 unaffected).
-- Setting dogs.photo_path goes through a security-definer RPC because dogs
-- UPDATE is owner/admin-only and we won't widen it (same pattern as
-- pair_device in 20260711170000).
-- =========================================================================

create policy media_profile_photo_insert_clinic on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'dogs'
    and storage.filename(name) like 'profile.%'
    and exists (
      select 1 from public.dogs d
      where d.id::text = (storage.foldername(name))[2]
        and public.is_clinic_member(d.id)
    )
  );

create policy media_profile_photo_update_clinic on storage.objects
  for update to authenticated
  using (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'dogs'
    and storage.filename(name) like 'profile.%'
    and exists (
      select 1 from public.dogs d
      where d.id::text = (storage.foldername(name))[2]
        and public.is_clinic_member(d.id)
    )
  );

create function public.set_dog_photo(p_dog_id uuid, p_photo_path text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1 from dogs d
    where d.id = p_dog_id
      and (d.owner_user_id = auth.uid() or public.is_clinic_member(d.id))
  ) then
    raise exception 'DOG_NOT_ACCESSIBLE';
  end if;

  -- Only accept paths inside this dog's own media folder.
  if p_photo_path is not null
     and p_photo_path not like ('dogs/' || p_dog_id || '/profile.%') then
    raise exception 'INVALID_PHOTO_PATH';
  end if;

  update dogs set photo_path = p_photo_path where id = p_dog_id;
end;
$$;

revoke execute on function public.set_dog_photo(uuid, text) from public, anon;
grant execute on function public.set_dog_photo(uuid, text) to authenticated;
