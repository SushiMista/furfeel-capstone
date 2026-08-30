-- =========================================================================
-- ROLLBACK SCRIPT: Revert Ward Locations & Clinical Interventions
-- Run this in Supabase SQL Editor if you ever wish to undo the migration.
-- =========================================================================

-- 1. Remove clinical_interventions from realtime publication if it exists
do $$
begin
  if exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'clinical_interventions'
  ) then
    alter publication supabase_realtime drop table public.clinical_interventions;
  end if;
end $$;

-- 2. Drop the clinical_interventions table (and all its RLS policies & indexes)
drop table if exists public.clinical_interventions cascade;

-- 3. Drop the added columns from dogs
alter table public.dogs
  drop column if exists ward_location,
  drop column if exists admission_status;
