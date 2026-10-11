-- Linked owners need private media read access, matching dog record access.
-- Retains private storage and existing upload/update/delete permissions.
create policy media_objects_select_linked_owner on storage.objects
for select to authenticated
using (
  bucket_id = 'media'
  and (storage.foldername(name))[1] = 'dogs'
  and exists (
    select 1 from public.dog_owners o
    where o.dog_id::text = (storage.foldername(objects.name))[2]
      and o.user_id = auth.uid()
  )
);
