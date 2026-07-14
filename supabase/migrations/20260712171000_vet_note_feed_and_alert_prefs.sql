-- QA round (docs/04): the owner Home shows vet notes inline with the
-- clinician's name + profile photo, and the Alerts page gets per-type
-- notification preferences. Everything here only ADDS capability.

-- =========================================================================
-- Per-type alert muting (docs/04 notifications, QA: "manage notifications
-- for each [alert type] just like messenger"). Types match alerts.type
-- ('high_stress', 'moderate_stress', 'device_offline', ...).
-- user_settings RLS (own row only) already covers it.
-- =========================================================================

alter table user_settings
  add column muted_alert_types text[] not null default '{}';

-- =========================================================================
-- vet_note_feed — vet notes with the author's name + avatar path. Owners can
-- already read their dog's vet_notes, but not the author's users row (users
-- SELECT is self/clinic/admin), so the join goes through a security-definer
-- RPC that re-checks dog access explicitly. Only name + avatar_path are
-- exposed — no email, role, or clinic.
-- =========================================================================

create function public.vet_note_feed(p_dog_id uuid, p_limit int default 20)
returns table (
  id uuid,
  note text,
  created_at timestamptz,
  author_name text,
  author_avatar_path text
)
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select vn.id, vn.note, vn.created_at, u.name, u.avatar_path
  from vet_notes vn
  join users u on u.id = vn.author_user_id
  where vn.dog_id = p_dog_id
    and exists (
      select 1 from dogs d
      where d.id = p_dog_id
        and (d.owner_user_id = auth.uid() or public.is_clinic_member(d.id))
    )
  order by vn.created_at desc
  limit p_limit
$$;

revoke execute on function public.vet_note_feed(uuid, int) from public, anon;
grant execute on function public.vet_note_feed(uuid, int) to authenticated;

-- Owners may load the avatar image of clinicians who wrote notes on their
-- dogs (scoped: note authors only, and only for that owner's dogs).
create policy avatars_select_note_author_for_owner on storage.objects
  for select to authenticated
  using (
    bucket_id = 'avatars'
    and exists (
      select 1
      from public.vet_notes vn
      join public.dogs d on d.id = vn.dog_id
      where vn.author_user_id::text = (storage.foldername(objects.name))[1]
        and d.owner_user_id = auth.uid()
    )
  );
