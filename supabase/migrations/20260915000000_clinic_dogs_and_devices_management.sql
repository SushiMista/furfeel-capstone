-- =========================================================================
-- Migration: Clinic Dogs Update Policy & Clinic Device Management
-- 1. Allows clinic staff (veterinarian, vet_staff) and admins to update dogs
--    (admission_status, ward_location, etc.) belonging to their clinic.
-- 2. Allows clinic staff to register and update devices for their clinic.
-- =========================================================================

-- 1. Dogs Update Policy for Clinic Members
do $$
begin
  if not exists (
    select 1 from pg_policies where tablename = 'dogs' and policyname = 'dogs_update_clinic_staff'
  ) then
    create policy dogs_update_clinic_staff on public.dogs
      for update
      using (
        public.is_clinic_member(dogs.id)
        or public.current_user_role() = 'admin'
        or owner_user_id = auth.uid()
      )
      with check (
        public.is_clinic_member(dogs.id)
        or public.current_user_role() = 'admin'
        or owner_user_id = auth.uid()
      );
  end if;
end $$;

-- 2. Devices Insert & Update Policy for Clinic Members
do $$
begin
  if not exists (
    select 1 from pg_policies where tablename = 'devices' and policyname = 'devices_insert_clinic_staff'
  ) then
    create policy devices_insert_clinic_staff on public.devices
      for insert
      with check (
        public.current_user_role() in ('veterinarian', 'vet_staff', 'admin')
      );
  end if;

  if not exists (
    select 1 from pg_policies where tablename = 'devices' and policyname = 'devices_update_clinic_staff'
  ) then
    create policy devices_update_clinic_staff on public.devices
      for update
      using (
        public.current_user_role() in ('veterinarian', 'vet_staff', 'admin')
      )
      with check (
        public.current_user_role() in ('veterinarian', 'vet_staff', 'admin')
      );
  end if;
end $$;
