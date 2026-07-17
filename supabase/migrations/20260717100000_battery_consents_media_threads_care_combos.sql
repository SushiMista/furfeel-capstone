-- FurFeel QA/enhancement pass (Phase 2). Everything here only ADDS capability;
-- no existing policy is weakened. Sources: docs/07 (battery in the payload),
-- docs/11 (low-battery alert trigger), docs/12 (consent), docs/04 module 5
-- (threaded vet review), docs/09.

-- =========================================================================
-- Battery telemetry (docs/07, docs/11 "Battery is low, if battery telemetry
-- is available"). The harness reports battery_percent 0-100; the intake
-- function validates and mirrors the latest value onto the device row.
-- =========================================================================

alter table telemetry_readings
  add column battery_percent int check (battery_percent between 0 and 100);

alter table devices
  add column battery_percent int check (battery_percent between 0 and 100);

-- =========================================================================
-- consents — data-collection consent (docs/12). Append-only: one row per
-- (user, policy version); re-consent after a policy bump inserts a new row.
-- The app blocks telemetry/media views until the current version is accepted.
-- =========================================================================

create table consents (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references users (id) on delete cascade,
  policy_version  text not null,
  accepted_at     timestamptz not null default now(),
  unique (user_id, policy_version)
);

alter table consents enable row level security;

-- Own rows only; no update/delete policies — an accepted consent is a record,
-- not an editable preference.
create policy consents_select_own on consents
  for select using (user_id = auth.uid());

create policy consents_insert_own on consents
  for insert with check (user_id = auth.uid());

-- =========================================================================
-- media_messages — threaded conversation on an owner media submission
-- (docs/04 module 5 "simple threaded follow-up"). Turns submission + vet
-- review into an email-style chain. Access = the dog's owner + clinic staff
-- of that dog, exactly like the parent submission.
-- =========================================================================

create table media_messages (
  id                   uuid primary key default gen_random_uuid(),
  media_submission_id  uuid not null references media_submissions (id) on delete cascade,
  author_user_id       uuid not null references users (id),
  body                 text not null check (length(trim(body)) > 0),
  created_at           timestamptz not null default now()
);

create index idx_media_messages_submission_created
  on media_messages (media_submission_id, created_at);

alter table media_messages enable row level security;

create policy media_messages_select_owner_or_clinic on media_messages
  for select using (
    exists (
      select 1
      from media_submissions ms
      join dogs d on d.id = ms.dog_id
      where ms.id = media_messages.media_submission_id
        and (d.owner_user_id = auth.uid() or public.is_clinic_member(d.id))
    )
  );

create policy media_messages_insert_owner_or_clinic on media_messages
  for insert with check (
    author_user_id = auth.uid()
    and exists (
      select 1
      from media_submissions ms
      join dogs d on d.id = ms.dog_id
      where ms.id = media_messages.media_submission_id
        and (d.owner_user_id = auth.uid() or public.is_clinic_member(d.id))
    )
  );

-- Replies should appear live on both sides of the conversation.
alter publication supabase_realtime add table public.media_messages;

-- =========================================================================
-- care_guidance combinations — guidance keyed to a COMBINATION of signals
-- (cold+stressed, hot+stressed, restless+high HR, ...) via context_key.
-- stress_level becomes nullable: a combination row applies across levels;
-- plain per-level rows keep working unchanged. Selection: the app prefers a
-- context_key match, then falls back to the stress_level row.
-- =========================================================================

alter table care_guidance add column context_key text;

alter table care_guidance alter column stress_level drop not null;

-- Every row must be keyed by at least one of the two.
alter table care_guidance
  add constraint care_guidance_keyed check (stress_level is not null or context_key is not null);

create index idx_care_guidance_context on care_guidance (context_key, clinic_id);

-- Vet-authored global defaults for combinations. PROVISIONAL wording —
-- observational and comfort-focused only, never diagnosis; clinics can
-- override per-clinic and vets should review the copy (docs/08 guardrail).
insert into care_guidance (stress_level, context_key, clinic_id, title, body) values
  (null, 'cold_stressed', null, 'Warm and settle',
   'It''s chilly and your dog seems tense. Offer a warm bed, a blanket, or a spot away from drafts, and stay close for a while — warmth and company usually help a dog settle.'),
  (null, 'hot_stressed', null, 'Cool and calm',
   'It''s warm and your dog seems stressed. Move them to a cool, shaded spot with fresh water, and skip play or walks until things settle. A damp towel to lie on can help too.'),
  (null, 'restless_high_hr', null, 'Time to wind down',
   'Your dog is restless and their heart is working harder than usual. Try a quiet space with less noise and activity, dim the lights if you can, and let them rest without fuss.'),
  (null, 'panting_hot', null, 'Water and shade',
   'Fast breathing in warm weather is your dog''s way of cooling off. Offer fresh water and a shaded, airy spot, and hold off on exercise until they''re breathing easy again.'),
  (null, 'cold_calm', null, 'Cozy is good',
   'It''s on the cold side, but your dog seems comfortable. A warm bed nearby keeps it that way — just keep an eye out for shivering on longer stays outdoors.'),
  (null, 'hot_calm', null, 'Keep the water coming',
   'Warm day, relaxed dog. Keep fresh water within reach and shade available, and prefer cooler hours for walks.');

-- =========================================================================
-- dog_wellness_score — optional daily 0-100 score. SECURITY INVOKER: RLS on
-- telemetry_readings / stress_classifications / alerts decides what the
-- caller may aggregate, so this leaks nothing an owner or clinic couldn't
-- already read row-by-row.
--
-- PROVISIONAL ENGINEERING FORMULA (not clinical; document in docs/08):
--   calm_component  = 60 * (calm classifications / all classifications)
--   balance_component = 40 * (1 - |active_share - 0.30|), where active_share
--     is the share of readings with motion_activity >= 0.4 and 0.30 is a
--     provisional "healthy activity share" a vet can tune here.
--   alert_penalty   = 10 per alert raised that day, capped at 30.
--   score = clamp(round(calm + balance - penalty), 0, 100)
-- Returns no row when the day has no classifications (no data ≠ score 0).
-- =========================================================================

create function public.dog_wellness_score(p_dog_id uuid, p_day date)
returns table (
  score int,
  calm_percent numeric,
  active_percent numeric,
  rest_percent numeric,
  alert_count int,
  sample_count int
)
language sql
security invoker
stable
as $$
  with day_bounds as (
    select p_day::timestamptz as day_start, (p_day + 1)::timestamptz as day_end
  ),
  cls as (
    select count(*) as total,
           count(*) filter (where stress_level = 'calm') as calm
    from stress_classifications, day_bounds
    where dog_id = p_dog_id
      and created_at >= day_start and created_at < day_end
  ),
  motion as (
    select count(*) filter (where motion_activity is not null) as total,
           count(*) filter (where motion_activity >= 0.4) as active,
           count(*) filter (where motion_activity < 0.15) as rest
    from telemetry_readings, day_bounds
    where dog_id = p_dog_id
      and captured_at >= day_start and captured_at < day_end
  ),
  al as (
    select count(*) as alerts
    from alerts, day_bounds
    where dog_id = p_dog_id
      and created_at >= day_start and created_at < day_end
  )
  select
    least(100, greatest(0, round(
      60.0 * cls.calm / cls.total
      + 40.0 * (1 - abs(
          coalesce(motion.active::numeric / nullif(motion.total, 0), 0.30) - 0.30))
      - least(al.alerts * 10, 30)
    )))::int as score,
    round(100.0 * cls.calm / cls.total, 1) as calm_percent,
    round(100.0 * coalesce(motion.active::numeric / nullif(motion.total, 0), 0), 1) as active_percent,
    round(100.0 * coalesce(motion.rest::numeric / nullif(motion.total, 0), 0), 1) as rest_percent,
    al.alerts::int as alert_count,
    cls.total::int as sample_count
  from cls, motion, al
  where cls.total > 0;
$$;

revoke execute on function public.dog_wellness_score(uuid, date) from public, anon;
grant execute on function public.dog_wellness_score(uuid, date) to authenticated;
