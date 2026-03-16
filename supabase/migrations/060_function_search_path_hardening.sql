-- ============================================================
-- 060 · Security Advisor hardening: Function Search Path Mutable
-- ============================================================
-- Purpose:
--   Set explicit search_path for public functions flagged by advisor
--   (and analogous project functions) without changing logic/signatures.

begin;

do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as regproc
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = any (array[
        -- Explicitly reported / requested
        'set_updated_at_profiles',
        'sync_release_owner_user',
        'set_updated_at_support_tickets',
        'set_updated_at',
        'support_apply_status_timestamps',
        'report_rows_fill_scope',
        'set_promo_requests_updated_at',
        'crm_set_updated_at',
        'crm_map_stage_from_promo',
        'crm_map_stage_from_support',
        'crm_map_deal_status_from_production',
        'normalize_plan_slug',
        'billing_plan_rank',
        -- Analogous project functions in public
        'is_admin_user',
        'is_admin',
        'admin_bulk_update_profiles_status',
        'admin_bulk_update_releases_status',
        'admin_process_release_delete_request',
        'admin_log_event',
        'crm_sync_lead_from_promo',
        'crm_sync_lead_from_support',
        'crm_refresh_deal_from_production_order',
        'crm_sync_deal_from_production_order',
        'crm_sync_deal_from_production_item',
        'crm_log_invoice_event',
        'crm_log_transaction_event',
        'has_active_subscription',
        'billing_sync_profile_from_subscription',
        'create_trial_subscription_for_profile',
        'sync_legacy_subscriptions_from_billing',
        'sync_billing_from_legacy_subscriptions',
        'expire_subscriptions',
        'can_consume_ai_generation',
        'consume_ai_generation',
        'trg_consume_ai_generation_from_tool_result',
        'is_feature_enabled'
      ])
  loop
    execute format('alter function %s set search_path = public', fn.regproc);
  end loop;
end
$$;

commit;
