-- Migration: 20260916000000_account_activation_gate.sql
-- Description: Pre-activation gate for self-registered mobile accounts.
--
-- Newly self-registered users (those whose raw_user_meta_data does NOT carry
-- the admin_created=true flag set by the admin-create-user Edge Function) are
-- created with is_active = false and must be explicitly activated by a
-- veterinarian or admin before the mobile app grants full access.
--
-- Admin-created accounts and any account marked admin_created skip the gate
-- and are inserted as active immediately.

-- 1. Recreate handle_new_user to conditionally set is_active
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_is_admin_created BOOLEAN;
BEGIN
  -- The admin-create-user Edge Function injects admin_created=true into
  -- raw_user_meta_data so those accounts skip the activation queue.
  v_is_admin_created := (new.raw_user_meta_data->>'admin_created')::boolean IS TRUE;

  INSERT INTO public.users (id, name, email, role, is_active)
  VALUES (
    new.id,
    COALESCE(
      new.raw_user_meta_data->>'name',
      new.raw_user_meta_data->>'full_name',
      split_part(new.email, '@', 1)
    ),
    new.email,
    'owner',
    v_is_admin_created   -- false for self-registered, true for admin-created
  );

  INSERT INTO public.user_settings (user_id) VALUES (new.id);

  RETURN new;
END;
$$;

-- 2. Index for fast pending-activation queries (is_active = false filter)
CREATE INDEX IF NOT EXISTS users_pending_activation_idx
  ON public.users (is_active, created_at DESC)
  WHERE is_active = false AND role = 'owner';

-- 3. Helpful comment
COMMENT ON INDEX users_pending_activation_idx IS
  'Speeds up vet/admin queries for pending (unactivated) owner accounts.';
