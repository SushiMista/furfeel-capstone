-- Migration: 20260917040000_allow_clinic_staff_intake_patient_dogs.sql
-- Description: Grants veterinarians and clinic staff permissions to intake patients
-- (insert/update dogs in their clinic) and register/bind devices on the fly.

-- =========================================================================
-- 1. Table-level GRANTs for authenticated users
-- =========================================================================
GRANT ALL ON public.dogs TO authenticated;
GRANT ALL ON public.dog_baselines TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.devices TO authenticated;

-- =========================================================================
-- 2. Allow clinic staff / vets to view pet owners for intake owner selection
-- =========================================================================
DROP POLICY IF EXISTS users_select_clinic_staff ON public.users;
CREATE POLICY users_select_clinic_staff ON public.users
  FOR SELECT USING (
    public.current_user_role() IN ('vet_staff', 'veterinarian')
    AND (
      role = 'owner'
      OR role IS NULL
      OR clinic_id = public.current_clinic_id()
      OR id = auth.uid()
    )
  );

-- =========================================================================
-- 3. Dogs RLS: Allow clinic staff / vets to SELECT, INSERT, and UPDATE dogs
-- =========================================================================
DROP POLICY IF EXISTS dogs_select_clinic_staff ON public.dogs;
CREATE POLICY dogs_select_clinic_staff ON public.dogs
  FOR SELECT USING (
    public.current_user_role() IN ('vet_staff', 'veterinarian')
    OR public.is_clinic_member(dogs.id)
  );

DROP POLICY IF EXISTS dogs_clinic_staff_insert ON public.dogs;
CREATE POLICY dogs_clinic_staff_insert ON public.dogs
  FOR INSERT WITH CHECK (
    public.current_user_role() IN ('vet_staff', 'veterinarian')
  );

DROP POLICY IF EXISTS dogs_clinic_staff_update ON public.dogs;
CREATE POLICY dogs_clinic_staff_update ON public.dogs
  FOR UPDATE USING (
    public.current_user_role() IN ('vet_staff', 'veterinarian')
  );

-- =========================================================================
-- 4. Devices RLS: Allow clinic staff / vets to register/insert & update devices
-- =========================================================================
DROP POLICY IF EXISTS devices_clinic_staff_insert ON public.devices;
CREATE POLICY devices_clinic_staff_insert ON public.devices
  FOR INSERT WITH CHECK (
    public.current_user_role() IN ('vet_staff', 'veterinarian')
  );

DROP POLICY IF EXISTS devices_clinic_staff_update ON public.devices;
CREATE POLICY devices_clinic_staff_update ON public.devices
  FOR UPDATE USING (
    public.current_user_role() IN ('vet_staff', 'veterinarian')
  );

-- =========================================================================
-- 5. Baselines RLS: Allow clinic staff / vets to insert/update dog baselines
-- =========================================================================
DROP POLICY IF EXISTS dog_baselines_clinic_staff_insert ON public.dog_baselines;
CREATE POLICY dog_baselines_clinic_staff_insert ON public.dog_baselines
  FOR INSERT WITH CHECK (
    public.current_user_role() IN ('vet_staff', 'veterinarian')
  );

DROP POLICY IF EXISTS dog_baselines_clinic_staff_update ON public.dog_baselines;
CREATE POLICY dog_baselines_clinic_staff_update ON public.dog_baselines
  FOR UPDATE USING (
    public.current_user_role() IN ('vet_staff', 'veterinarian')
  );

