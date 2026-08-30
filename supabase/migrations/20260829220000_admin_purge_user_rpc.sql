-- Migration: 20260829220000_admin_purge_user_rpc.sql
-- Description: SECURITY DEFINER Postgres RPC function to allow admins to hard-delete user accounts and cascade purge owned dogs and clinical records.

CREATE OR REPLACE FUNCTION admin_purge_user(target_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  dog_ids UUID[];
  target_name TEXT;
BEGIN
  -- 1. Verify caller is an active admin
  IF NOT EXISTS (
    SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can purge accounts.';
  END IF;

  -- 2. Prevent self-deletion
  IF target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'You cannot delete your own account.';
  END IF;

  SELECT name INTO target_name FROM public.users WHERE id = target_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found.';
  END IF;

  -- 3. Get all dog IDs owned by target user
  SELECT ARRAY_AGG(id) INTO dog_ids FROM public.dogs WHERE owner_user_id = target_user_id;

  IF dog_ids IS NOT NULL AND array_length(dog_ids, 1) > 0 THEN
    -- Unassign active devices from these dogs
    UPDATE public.devices SET dog_id = NULL WHERE dog_id = ANY(dog_ids);

    -- Delete media messages linked to submissions of these dogs
    PERFORM 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'media_messages';
    IF FOUND THEN
      EXECUTE 'DELETE FROM public.media_messages WHERE media_submission_id IN (
        SELECT id FROM public.media_submissions WHERE dog_id = ANY($1)
      )' USING dog_ids;
    END IF;

    -- Delete media submissions and vet notes for these dogs
    DELETE FROM public.media_submissions WHERE dog_id = ANY(dog_ids);
    DELETE FROM public.vet_notes WHERE dog_id = ANY(dog_ids);

    -- Delete stress labels (vet reviews) linked to these dogs
    PERFORM 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'stress_labels';
    IF FOUND THEN
      EXECUTE 'DELETE FROM public.stress_labels WHERE dog_id = ANY($1)' USING dog_ids;
    END IF;

    -- Delete alerts linked to these dogs (must be deleted BEFORE stress_classifications due to classification_id FK)
    DELETE FROM public.alerts WHERE dog_id = ANY(dog_ids);

    -- Delete stress classifications linked to readings of these dogs
    DELETE FROM public.stress_classifications 
    WHERE telemetry_reading_id IN (
      SELECT id FROM public.telemetry_readings WHERE dog_id = ANY(dog_ids)
    );
    DELETE FROM public.stress_classifications WHERE dog_id = ANY(dog_ids);

    -- Delete telemetry readings & dog baselines
    DELETE FROM public.telemetry_readings WHERE dog_id = ANY(dog_ids);
    DELETE FROM public.dog_baselines WHERE dog_id = ANY(dog_ids);

    -- Delete owned dog profiles
    DELETE FROM public.dogs WHERE owner_user_id = target_user_id;
  END IF;

  -- 4. Purge user-authored or reviewed records across the system
  DELETE FROM public.vet_notes WHERE author_user_id = target_user_id;

  PERFORM 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'media_messages';
  IF FOUND THEN
    EXECUTE 'DELETE FROM public.media_messages WHERE author_user_id = $1' USING target_user_id;
  END IF;

  -- Delete stress labels authored by the target user (if veterinarian)
  PERFORM 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'stress_labels';
  IF FOUND THEN
    EXECUTE 'DELETE FROM public.stress_labels WHERE vet_user_id = $1' USING target_user_id;
  END IF;

  -- Nullify updated_by in care_guidance if target user edited any guidance
  PERFORM 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'care_guidance';
  IF FOUND THEN
    EXECUTE 'UPDATE public.care_guidance SET updated_by = NULL WHERE updated_by = $1' USING target_user_id;
  END IF;

  DELETE FROM public.media_submissions WHERE submitted_by_user_id = target_user_id;
  UPDATE public.media_submissions SET reviewed_by_user_id = NULL WHERE reviewed_by_user_id = target_user_id;
  UPDATE public.alerts SET acknowledged_by = NULL WHERE acknowledged_by = target_user_id;

  PERFORM 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'bug_reports';
  IF FOUND THEN
    EXECUTE 'UPDATE public.bug_reports SET user_id = NULL WHERE user_id = $1' USING target_user_id;
  END IF;

  -- 5. Delete public.users row and auth.users entry
  DELETE FROM public.users WHERE id = target_user_id;
  DELETE FROM auth.users WHERE id = target_user_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION admin_purge_user(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION admin_purge_user(UUID) TO authenticated;

