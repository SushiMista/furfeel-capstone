-- clinical_interventions is live and used by the dashboard, but
-- 20260830130001 drops it, so a database built from migrations would lack it.
-- Recreates it idempotently to match production; a no-op there.

create table if not exists public.clinical_interventions (
  id                  uuid primary key default gen_random_uuid(),
  dog_id              uuid not null references public.dogs (id) on delete cascade,
  clinic_id           uuid references public.clinics (id) on delete set null,
  intervention_type   text not null,
  title               text not null,
  notes               text,
  dosage              text,
  administered_by     uuid references public.users (id) on delete set null,
  created_at          timestamptz not null default now()
);

create index if not exists idx_clinical_interventions_dog_created
  on public.clinical_interventions (dog_id, created_at desc);

alter table public.clinical_interventions enable row level security;

drop policy if exists clinical_interventions_select on public.clinical_interventions;
create policy clinical_interventions_select on public.clinical_interventions
  for select to authenticated
  using (
    public.current_user_role() = 'admin'
    or exists (
      select 1 from public.dogs d
      where d.id = clinical_interventions.dog_id
        and (
          d.owner_user_id = auth.uid()
          or d.clinic_id = (select clinic_id from public.users where id = auth.uid())
        )
    )
  );

drop policy if exists clinical_interventions_insert on public.clinical_interventions;
create policy clinical_interventions_insert on public.clinical_interventions
  for insert to authenticated
  with check (public.current_user_role() in ('veterinarian', 'vet_staff', 'admin'));

drop policy if exists clinical_interventions_delete on public.clinical_interventions;
create policy clinical_interventions_delete on public.clinical_interventions
  for delete to authenticated
  using (public.current_user_role() in ('veterinarian', 'vet_staff', 'admin'));

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'clinical_interventions'
  ) then
    alter publication supabase_realtime add table public.clinical_interventions;
  end if;
end $$;
