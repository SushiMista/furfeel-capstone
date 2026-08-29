-- Migration: 20260829210000_user_soft_delete_and_status.sql
-- Description: Add soft delete / account deactivation support to public.users

ALTER TABLE users 
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS deactivated_at TIMESTAMPTZ NULL;

COMMENT ON COLUMN users.is_active IS 'False when the user account is soft-deleted/deactivated by an admin or self-action';
COMMENT ON COLUMN users.deactivated_at IS 'Timestamp when the account was soft-deleted/deactivated';
