-- Fix: media-bucket RLS policies never matched, so every owner photo/video
-- upload (Observation Assessment, dog profile photo) failed with an RLS error.
--
-- Root cause: inside `exists (select 1 from public.dogs d ...)` the unqualified
-- `name` resolved to dogs.name (the dog's name!) instead of the storage
-- object's path, so the deployed predicate was
--   (d.id)::text = (storage.foldername(d.name))[2]   -- foldername('Biscuit')
-- which is never true. The avatars policies work because they have no subquery.
-- Recreate all six media policies with the object column qualified as
-- `objects.name`. Same intended scope as before — nothing is widened.

drop policy media_objects_insert_owner on storage.objects;
drop policy media_objects_update_owner on storage.objects;
drop policy media_objects_delete_owner on storage.objects;
drop policy media_objects_select_owner_or_clinic on storage.objects;
drop policy media_profile_photo_insert_clinic on storage.objects;
drop policy media_profile_photo_update_clinic on storage.objects;

-- Owners upload into their own dog's folder only.
create policy media_objects_insert_owner on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'media'
    and (storage.foldername(objects.name))[1] = 'dogs'
    and exists (
      select 1 from public.dogs d
      where d.id::text = (storage.foldername(objects.name))[2]
        and d.owner_user_id = auth.uid()
    )
  );

-- Owners can replace/remove their own dog's objects (profile photo re-upload).
create policy media_objects_update_owner on storage.objects
  for update to authenticated
  using (
    bucket_id = 'media'
    and (storage.foldername(objects.name))[1] = 'dogs'
    and exists (
      select 1 from public.dogs d
      where d.id::text = (storage.foldername(objects.name))[2]
        and d.owner_user_id = auth.uid()
    )
  );

create policy media_objects_delete_owner on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'media'
    and (storage.foldername(objects.name))[1] = 'dogs'
    and exists (
      select 1 from public.dogs d
      where d.id::text = (storage.foldername(objects.name))[2]
        and d.owner_user_id = auth.uid()
    )
  );

-- Owner + the dog's clinic staff can view media objects.
create policy media_objects_select_owner_or_clinic on storage.objects
  for select to authenticated
  using (
    bucket_id = 'media'
    and (storage.foldername(objects.name))[1] = 'dogs'
    and exists (
      select 1 from public.dogs d
      where d.id::text = (storage.foldername(objects.name))[2]
        and (d.owner_user_id = auth.uid() or public.is_clinic_member(d.id))
    )
  );

-- Clinic staff may upload/replace only the dogs/<id>/profile.* object.
create policy media_profile_photo_insert_clinic on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'media'
    and (storage.foldername(objects.name))[1] = 'dogs'
    and storage.filename(objects.name) like 'profile.%'
    and exists (
      select 1 from public.dogs d
      where d.id::text = (storage.foldername(objects.name))[2]
        and public.is_clinic_member(d.id)
    )
  );

create policy media_profile_photo_update_clinic on storage.objects
  for update to authenticated
  using (
    bucket_id = 'media'
    and (storage.foldername(objects.name))[1] = 'dogs'
    and storage.filename(objects.name) like 'profile.%'
    and exists (
      select 1 from public.dogs d
      where d.id::text = (storage.foldername(objects.name))[2]
        and public.is_clinic_member(d.id)
    )
  );
