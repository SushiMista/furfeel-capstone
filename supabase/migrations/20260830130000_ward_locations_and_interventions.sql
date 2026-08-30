-- =========================================================================
-- Veterinary Hospital Operations: Ward / Cage Locations & Clinical Interventions
-- Adds:
-- 1. Ward / Cage Location & Admission Status on dogs table
-- 2. Clinical Interventions & Medication Treatment Logging table
-- 3. RLS Policies and Realtime Publication inclusion
-- =========================================================================

-- 1. Add ward location and admission status to dogs
alter table public.dogs
  add column if not exists ward_location text default null,
  add column if not exists admission_status text not null default 'outpatient';

comment on column public.dogs.ward_location is 'Physical hospital location e.g. ICU - Cage 1, Ward A - 4, Post-Op Recovery, Boarding';
comment on column public.dogs.admission_status is 'Hospitalization stage: admitted, in_surgery, recovery, ready_for_discharge, outpatient';

-- 2. Clinical Interventions & Medication Logging Table
create table if not exists public.clinical_interventions (
  id                  uuid primary key default gen_random_uuid(),
  dog_id              uuid not null references public.dogs (id) on delete cascade,
  clinic_id           uuid references public.clinics (id) on delete set null,
  intervention_type   text not null, -- 'medication', 'feeding', 'walk', 'procedure', 'vet_exam', 'other'
  title               text not null,
  notes               text,
  dosage              text,
  administered_by     uuid references public.users (id) on delete set null,
  created_at          timestamptz not null default now()
);

create index if not exists idx_clinical_interventions_dog_created
  on public.clinical_interventions (dog_id, created_at desc);

-- 3. RLS Security Policies
alter table public.clinical_interventions enable row level security;

create policy "clinical_interventions_select"
  on public.clinical_interventions
  for select
  using (
    public.current_user_role() = 'admin'
    or exists (
      select 1 from public.dogs d
      where d.id = clinical_interventions.dog_id
      and (
        d.owner_user_id = auth.uid()
        or (d.clinic_id = (select clinic_id from public.users where id = auth.uid()))
      )
    )
  );

create policy "clinical_interventions_insert"
  on public.clinical_interventions
  for insert
  with check (
    public.current_user_role() in ('veterinarian', 'vet_staff', 'admin')
  );

create policy "clinical_interventions_delete"
  on public.clinical_interventions
  for delete
  using (
    public.current_user_role() in ('veterinarian', 'vet_staff', 'admin')
  );

-- 4. Enable Supabase Realtime for clinical_interventions
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'clinical_interventions'
  ) then
    alter publication supabase_realtime add table public.clinical_interventions;
  end if;
end $$;
