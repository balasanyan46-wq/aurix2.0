-- Lock down sensitive profile fields (plan/billing_period/role/account_status)
-- Regular users can edit profile info, but cannot change subscription/role/status.
-- Service role and admins are allowed.

BEGIN;

CREATE OR REPLACE FUNCTION public.block_profile_sensitive_updates()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  is_admin boolean := false;
BEGIN
  -- Allow backend / service role updates (webhooks, edge functions)
  IF COALESCE(auth.role(), '') = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- Allow SQL editor / maintenance (no JWT context)
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid() AND p.role = 'admin'
  ) INTO is_admin;

  IF is_admin THEN
    RETURN NEW;
  END IF;

  IF NEW.plan IS DISTINCT FROM OLD.plan THEN
    RAISE EXCEPTION 'Not allowed: plan is managed by billing';
  END IF;

  IF NEW.billing_period IS DISTINCT FROM OLD.billing_period THEN
    RAISE EXCEPTION 'Not allowed: billing period is managed by billing';
  END IF;

  IF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'Not allowed: role is admin-only';
  END IF;

  IF NEW.account_status IS DISTINCT FROM OLD.account_status THEN
    RAISE EXCEPTION 'Not allowed: account status is admin-only';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_block_profile_sensitive_updates ON public.profiles;
CREATE TRIGGER trg_block_profile_sensitive_updates
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.block_profile_sensitive_updates();

COMMIT;

