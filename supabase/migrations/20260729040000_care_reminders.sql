-- Care reminders (docs/04 module, P3.12): owner-created reminders per dog
-- (medication, feeding, vet appointments) that fire as *local* notifications on
-- the device. No server push involved -- FCM/APNs is still unwired, and local
-- notifications sidestep it entirely, so this is a self-contained slice.
--
-- Owner-scoped only: same RLS shape as stress_labels_select_owner / media --
-- access is gated on the dog belonging to the caller (dogs.owner_user_id).
-- Clinic staff are intentionally NOT granted access; docs/04 keeps reminders an
-- owner-side feature, and narrow policies are the guardrail.
create table care_reminders (
  id          uuid primary key default gen_random_uuid(),
  dog_id      uuid not null references dogs (id) on delete cascade,
  user_id     uuid not null references users (id),   -- creator = the dog's owner
  title       text not null,
  notes       text,
  due_at      timestamptz not null,
  -- 'none' = one-off (appointment); 'daily'/'weekly' recur from due_at.
  repeat      text not null default 'none' check (repeat in ('none', 'daily', 'weekly')),
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

alter table care_reminders enable row level security;

create policy care_reminders_own_all on care_reminders
  for all
  using (
    exists (
      select 1 from dogs d
      where d.id = care_reminders.dog_id and d.owner_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from dogs d
      where d.id = care_reminders.dog_id and d.owner_user_id = auth.uid()
    )
  );

-- Active reminders for a dog are read on every home/detail load and reschedule.
create index care_reminders_dog_active_idx on care_reminders (dog_id) where active;
