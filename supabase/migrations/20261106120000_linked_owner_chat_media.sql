-- Linked owners can chat about a dog (ADR-026), but the media insert policy only
-- covered the primary owner, so their photos and videos failed to upload.
-- Limited to chat files, so profile photos and other paths stay as they were.
create policy media_chat_insert_linked_owner on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'dogs'
    and storage.filename(name) like 'chat-%'
    and exists (
      select 1
      from public.dog_owners o
      where o.dog_id::text = (storage.foldername(name))[2]
        and o.user_id = auth.uid()
    )
  );
