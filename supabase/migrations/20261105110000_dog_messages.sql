-- Vet messaging (ADR-026): one ongoing conversation per dog, replacing
-- observation submissions as the way owners reach their clinic. A message can
-- carry text, a photo or video, and an alert with its reading.
-- Supplementary material only: NEVER a classifier input (ADR-010).

create table public.dog_messages (
  id                    uuid primary key default gen_random_uuid(),
  dog_id                uuid not null references public.dogs (id) on delete cascade,
  author_user_id        uuid references public.users (id) on delete set null,
  body                  text check (body is null or length(trim(body)) between 1 and 4000),
  media_path            text,
  media_type            media_type,
  alert_id              uuid references public.alerts (id) on delete cascade,
  telemetry_reading_id  uuid references public.telemetry_readings (id) on delete set null,
  edited_at             timestamptz,
  created_at            timestamptz not null default now(),
  constraint dog_messages_has_content
    check (body is not null or media_path is not null or alert_id is not null),
  constraint dog_messages_media_pair
    check ((media_path is null) = (media_type is null)),
  constraint dog_messages_media_in_dog_folder
    check (media_path is null or media_path like 'dogs/' || dog_id::text || '/%')
);

create index idx_dog_messages_dog_created on public.dog_messages (dog_id, created_at);

alter table public.dog_messages enable row level security;

create policy dog_messages_select on public.dog_messages
  for select to authenticated
  using (public.is_dog_owner(dog_id) or public.is_clinic_member(dog_id));

-- Attachments must belong to the same dog: never trust client-supplied ids.
create policy dog_messages_insert on public.dog_messages
  for insert to authenticated
  with check (
    author_user_id = auth.uid()
    and (public.is_dog_owner(dog_id) or public.is_clinic_member(dog_id))
    and (
      alert_id is null
      or exists (
        select 1 from public.alerts a
        where a.id = alert_id and a.dog_id = dog_messages.dog_id
      )
    )
    and (
      telemetry_reading_id is null
      or exists (
        select 1 from public.telemetry_readings r
        where r.id = telemetry_reading_id and r.dog_id = dog_messages.dog_id
      )
    )
  );

create policy dog_messages_update_author on public.dog_messages
  for update to authenticated
  using (author_user_id = auth.uid())
  with check (author_user_id = auth.uid());

create policy dog_messages_delete_author on public.dog_messages
  for delete to authenticated
  using (author_user_id = auth.uid());

-- Editing covers the words only, not who or what a message is attached to.
revoke update on public.dog_messages from authenticated;
grant update (body, edited_at) on public.dog_messages to authenticated;

create table public.dog_message_reads (
  id            uuid primary key default gen_random_uuid(),
  dog_id        uuid not null references public.dogs (id) on delete cascade,
  user_id       uuid not null references public.users (id) on delete cascade,
  last_read_at  timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  unique (dog_id, user_id)
);

alter table public.dog_message_reads enable row level security;

create policy dog_message_reads_select_own on public.dog_message_reads
  for select to authenticated
  using (user_id = auth.uid());

create policy dog_message_reads_insert_own on public.dog_message_reads
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (public.is_dog_owner(dog_id) or public.is_clinic_member(dog_id))
  );

create policy dog_message_reads_update_own on public.dog_message_reads
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- One row per dog with messages the caller can see, newest first. Runs as the
-- caller, so the policies above decide what comes back.
create function public.dog_message_threads()
returns table (
  dog_id          uuid,
  last_body       text,
  last_has_media  boolean,
  last_has_alert  boolean,
  last_author_id  uuid,
  last_at         timestamptz,
  unread_count    bigint
)
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select
    latest.dog_id,
    latest.body,
    latest.media_path is not null,
    latest.alert_id is not null,
    latest.author_user_id,
    latest.created_at,
    (
      select count(*)
      from public.dog_messages m
      where m.dog_id = latest.dog_id
        and m.author_user_id is distinct from auth.uid()
        and m.created_at > coalesce(
          (
            select r.last_read_at from public.dog_message_reads r
            where r.dog_id = latest.dog_id and r.user_id = auth.uid()
          ),
          '-infinity'::timestamptz
        )
    )
  from (
    select distinct on (m.dog_id) m.*
    from public.dog_messages m
    order by m.dog_id, m.created_at desc
  ) latest
  order by latest.created_at desc;
$$;

revoke execute on function public.dog_message_threads() from public, anon;
grant execute on function public.dog_message_threads() to authenticated;

alter publication supabase_realtime add table public.dog_messages;

-- Carry existing conversations across. The old tables stay as the record.
insert into public.dog_messages (dog_id, author_user_id, body, media_path, media_type, created_at)
select
  ms.dog_id,
  ms.submitted_by_user_id,
  nullif(trim(ms.note), ''),
  ms.storage_path,
  ms.media_type,
  ms.created_at
from public.media_submissions ms
where ms.storage_path like 'dogs/' || ms.dog_id::text || '/%';

insert into public.dog_messages (dog_id, author_user_id, body, created_at)
select ms.dog_id, ms.reviewed_by_user_id, trim(ms.review_note), ms.reviewed_at
from public.media_submissions ms
where ms.reviewed_at is not null
  and length(trim(coalesce(ms.review_note, ''))) > 0;

insert into public.dog_messages (dog_id, author_user_id, body, created_at)
select ms.dog_id, mm.author_user_id, mm.body, mm.created_at
from public.media_messages mm
join public.media_submissions ms on ms.id = mm.media_submission_id;
