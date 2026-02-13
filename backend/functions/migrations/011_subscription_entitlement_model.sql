-- Migration 011: Subscription Entitlement Model
-- Date: February 2026
-- Description: Replaces 3-tier model (Free/Premium/Pro) with binary entitlement
--              model (paid/none). Additive — tier column preserved for mobile
--              backward compatibility until Phase 3.
--
-- Changes:
--   1a. Add entitlement/subscription columns to users table
--   1b. Create voice_purchase_transactions table
--   1c. Backward-compat data migration (tier -> entitlement)
--   1d. New PG functions: get_remaining_voice_minutes, consume_voice_minutes, check_voice_quota_v2
--   1e. Extend sync trigger to set entitlement when subscription changes

-- ============================================================================
-- 1a. Add columns to users table
-- ============================================================================

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS entitlement TEXT NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS subscription_status TEXT NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS billing_interval TEXT,
  ADD COLUMN IF NOT EXISTS monthly_voice_minutes_included INTEGER NOT NULL DEFAULT 60,
  ADD COLUMN IF NOT EXISTS voice_minutes_used_this_cycle NUMERIC(8,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS voice_minutes_purchased_balance NUMERIC(8,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS voice_cycle_started_at TIMESTAMPTZ;

-- Constraints (use DO block to avoid error if they already exist)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'check_entitlement'
  ) THEN
    ALTER TABLE users ADD CONSTRAINT check_entitlement
      CHECK (entitlement IN ('paid', 'none'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'check_subscription_status'
  ) THEN
    ALTER TABLE users ADD CONSTRAINT check_subscription_status
      CHECK (subscription_status IN ('trialing', 'active', 'expired', 'none'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'check_billing_interval'
  ) THEN
    ALTER TABLE users ADD CONSTRAINT check_billing_interval
      CHECK (billing_interval IN ('monthly', 'annual') OR billing_interval IS NULL);
  END IF;
END $$;

-- ============================================================================
-- 1b. Create voice_purchase_transactions table
-- ============================================================================
-- Provides idempotent tracking for voice minute purchases (separate from
-- the legacy voice_addon_purchases table which tracks seconds).

CREATE TABLE IF NOT EXISTS voice_purchase_transactions (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  transaction_id TEXT UNIQUE NOT NULL,
  minutes_credited NUMERIC(8,2) NOT NULL,
  credited_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vpt_user ON voice_purchase_transactions(user_id);

COMMENT ON TABLE voice_purchase_transactions IS 'Idempotent voice minute purchase tracking. Minutes-based (not seconds). Phase 2+.';

-- ============================================================================
-- 1c. Backward compatibility data migration
-- ============================================================================
-- Map existing tiers to entitlement. Safe to re-run (idempotent).

-- Paid users: pro or premium -> entitlement = 'paid'
UPDATE users SET entitlement = 'paid', subscription_status = 'active'
  WHERE tier IN ('pro', 'premium') AND entitlement = 'none';

-- Free/null users stay as entitlement = 'none'
UPDATE users SET entitlement = 'none', subscription_status = 'none'
  WHERE (tier = 'free' OR tier IS NULL) AND entitlement = 'none' AND subscription_status = 'none';

-- Initialize voice cycle for paid users (only if not already set)
UPDATE users SET voice_minutes_used_this_cycle = 0, voice_cycle_started_at = NOW()
  WHERE entitlement = 'paid' AND voice_cycle_started_at IS NULL;

-- Migrate existing purchased voice balance from voice_addon_purchases
-- Compute: total_purchased_minutes - consumed_from_addons
-- consumed_from_addons = MAX(0, this_month_used_minutes - 60)
-- Only runs for paid users whose purchased balance is still 0 (first migration)
UPDATE users u SET voice_minutes_purchased_balance = GREATEST(0, sub.balance)
FROM (
  SELECT
    u2.id,
    COALESCE(purchased.total_mins, 0) - GREATEST(0, COALESCE(used.total_secs, 0) / 60.0 - 60) AS balance
  FROM users u2
  LEFT JOIN (
    SELECT user_id, SUM(seconds_purchased) / 60.0 AS total_mins
    FROM voice_addon_purchases GROUP BY user_id
  ) purchased ON purchased.user_id = u2.id
  LEFT JOIN (
    SELECT user_id, SUM(duration_seconds) AS total_secs
    FROM voice_sessions
    WHERE started_at >= DATE_TRUNC('month', CURRENT_DATE)
      AND status IN ('completed', 'expired')
    GROUP BY user_id
  ) used ON used.user_id = u2.id
  WHERE u2.entitlement = 'paid'
) sub
WHERE sub.id = u.id AND u.voice_minutes_purchased_balance = 0;

-- ============================================================================
-- 1d. New PostgreSQL functions
-- ============================================================================

-- get_remaining_voice_minutes(p_user_id)
-- Reads the new columns directly — O(1), no aggregation needed.
CREATE OR REPLACE FUNCTION get_remaining_voice_minutes(p_user_id UUID)
RETURNS TABLE(
    included_remaining NUMERIC(8,2),
    purchased_remaining NUMERIC(8,2),
    total_remaining NUMERIC(8,2),
    monthly_included INTEGER,
    used_this_cycle NUMERIC(8,2),
    entitlement TEXT
) AS $$
DECLARE
    v_entitlement TEXT;
    v_monthly_included INTEGER;
    v_used NUMERIC(8,2);
    v_purchased NUMERIC(8,2);
    v_incl_remaining NUMERIC(8,2);
BEGIN
    SELECT u.entitlement, u.monthly_voice_minutes_included,
           u.voice_minutes_used_this_cycle, u.voice_minutes_purchased_balance
    INTO v_entitlement, v_monthly_included, v_used, v_purchased
    FROM users u WHERE u.id = p_user_id;

    IF v_entitlement IS NULL THEN
        RAISE EXCEPTION 'User % not found', p_user_id;
    END IF;

    -- If not paid, no voice access
    IF v_entitlement != 'paid' THEN
        RETURN QUERY SELECT
            0::NUMERIC(8,2),
            0::NUMERIC(8,2),
            0::NUMERIC(8,2),
            0::INTEGER,
            0::NUMERIC(8,2),
            v_entitlement;
        RETURN;
    END IF;

    v_incl_remaining := GREATEST(0, v_monthly_included - v_used);

    RETURN QUERY SELECT
        v_incl_remaining,
        v_purchased,
        v_incl_remaining + v_purchased,
        v_monthly_included,
        v_used,
        v_entitlement;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_remaining_voice_minutes IS 'O(1) voice minutes check using users table columns. Phase 2 replacement for check_voice_quota.';

-- consume_voice_minutes(p_user_id, p_minutes_used)
-- Deducts from included first, then purchased. Caps at 0.
CREATE OR REPLACE FUNCTION consume_voice_minutes(
    p_user_id UUID,
    p_minutes_used NUMERIC(8,2)
)
RETURNS TABLE(
    included_remaining NUMERIC(8,2),
    purchased_remaining NUMERIC(8,2),
    total_remaining NUMERIC(8,2),
    deducted_from_included NUMERIC(8,2),
    deducted_from_purchased NUMERIC(8,2)
) AS $$
DECLARE
    v_monthly_included INTEGER;
    v_used NUMERIC(8,2);
    v_purchased NUMERIC(8,2);
    v_incl_available NUMERIC(8,2);
    v_from_included NUMERIC(8,2);
    v_from_purchased NUMERIC(8,2);
BEGIN
    -- Lock the user row for atomic update
    SELECT u.monthly_voice_minutes_included,
           u.voice_minutes_used_this_cycle,
           u.voice_minutes_purchased_balance
    INTO v_monthly_included, v_used, v_purchased
    FROM users u WHERE u.id = p_user_id FOR UPDATE;

    IF v_monthly_included IS NULL THEN
        RAISE EXCEPTION 'User % not found', p_user_id;
    END IF;

    -- How much included quota is left?
    v_incl_available := GREATEST(0, v_monthly_included - v_used);

    -- Deduct from included first
    v_from_included := LEAST(p_minutes_used, v_incl_available);
    v_from_purchased := GREATEST(0, p_minutes_used - v_from_included);

    -- Cap purchased deduction at available balance
    v_from_purchased := LEAST(v_from_purchased, v_purchased);

    -- Update the user row
    UPDATE users
    SET voice_minutes_used_this_cycle = voice_minutes_used_this_cycle + v_from_included,
        voice_minutes_purchased_balance = GREATEST(0, voice_minutes_purchased_balance - v_from_purchased)
    WHERE id = p_user_id;

    -- Return updated remaining
    RETURN QUERY SELECT
        GREATEST(0, v_monthly_included - (v_used + v_from_included)),
        GREATEST(0, v_purchased - v_from_purchased),
        GREATEST(0, v_monthly_included - (v_used + v_from_included)) + GREATEST(0, v_purchased - v_from_purchased),
        v_from_included,
        v_from_purchased;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION consume_voice_minutes IS 'Deducts voice minutes: included first, then purchased. Called after record_voice_session billing.';

-- check_voice_quota_v2(p_user_id)
-- Replacement for check_voice_quota() using the new column-based model.
CREATE OR REPLACE FUNCTION check_voice_quota_v2(p_user_id UUID)
RETURNS TABLE(
    has_quota BOOLEAN,
    included_remaining_minutes NUMERIC(8,2),
    purchased_remaining_minutes NUMERIC(8,2),
    total_remaining_minutes NUMERIC(8,2),
    entitlement TEXT
) AS $$
DECLARE
    v_entitlement TEXT;
    v_monthly_included INTEGER;
    v_used NUMERIC(8,2);
    v_purchased NUMERIC(8,2);
    v_incl_remaining NUMERIC(8,2);
BEGIN
    SELECT u.entitlement, u.monthly_voice_minutes_included,
           u.voice_minutes_used_this_cycle, u.voice_minutes_purchased_balance
    INTO v_entitlement, v_monthly_included, v_used, v_purchased
    FROM users u WHERE u.id = p_user_id;

    IF v_entitlement IS NULL THEN
        RETURN QUERY SELECT false, 0::NUMERIC(8,2), 0::NUMERIC(8,2), 0::NUMERIC(8,2), 'none'::TEXT;
        RETURN;
    END IF;

    IF v_entitlement != 'paid' THEN
        RETURN QUERY SELECT false, 0::NUMERIC(8,2), 0::NUMERIC(8,2), 0::NUMERIC(8,2), v_entitlement;
        RETURN;
    END IF;

    v_incl_remaining := GREATEST(0, v_monthly_included - v_used);

    RETURN QUERY SELECT
        (v_incl_remaining + v_purchased) > 0,
        v_incl_remaining,
        v_purchased,
        v_incl_remaining + v_purchased,
        v_entitlement;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION check_voice_quota_v2 IS 'Column-based voice quota check. Phase 2 replacement for check_voice_quota.';

-- ============================================================================
-- 1e. Extend sync trigger
-- ============================================================================
-- Update sync_user_tier_from_subscription() to also set entitlement and
-- subscription_status when user_subscriptions changes. Preserves existing
-- tier sync behavior.

CREATE OR REPLACE FUNCTION sync_user_tier_from_subscription()
RETURNS TRIGGER AS $$
DECLARE
    v_best_tier VARCHAR(20);
BEGIN
    -- Determine the best active tier for this user (existing logic)
    SELECT
        CASE
            WHEN EXISTS (SELECT 1 FROM user_subscriptions WHERE user_id = NEW.user_id AND tier = 'pro' AND is_active = true) THEN 'pro'
            WHEN EXISTS (SELECT 1 FROM user_subscriptions WHERE user_id = NEW.user_id AND tier = 'premium' AND is_active = true) THEN 'premium'
            ELSE 'free'
        END
    INTO v_best_tier;

    -- Update the users table: tier (existing) + entitlement/subscription_status (new)
    -- Also reset voice cycle when transitioning to active
    UPDATE users
    SET tier = v_best_tier,
        entitlement = CASE WHEN NEW.is_active THEN 'paid' ELSE 'none' END,
        subscription_status = CASE WHEN NEW.is_active THEN 'active' ELSE 'expired' END,
        voice_minutes_used_this_cycle = CASE
            WHEN NEW.is_active AND entitlement != 'paid' THEN 0
            ELSE voice_minutes_used_this_cycle
        END,
        voice_cycle_started_at = CASE
            WHEN NEW.is_active AND entitlement != 'paid' THEN NOW()
            ELSE voice_cycle_started_at
        END
    WHERE id = NEW.user_id;

    -- Set updated_at on the subscription
    NEW.updated_at := NOW();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION sync_user_tier_from_subscription IS 'Syncs users.tier + entitlement when subscription changes (Phase 2).';

-- ============================================================================
-- Migration Complete
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE 'Migration 011: Subscription Entitlement Model';
    RAISE NOTICE '  - Added entitlement, subscription_status, billing_interval to users';
    RAISE NOTICE '  - Added voice_minutes_used_this_cycle, voice_minutes_purchased_balance to users';
    RAISE NOTICE '  - Created voice_purchase_transactions table';
    RAISE NOTICE '  - Migrated existing tier data to entitlement';
    RAISE NOTICE '  - Created get_remaining_voice_minutes(), consume_voice_minutes(), check_voice_quota_v2()';
    RAISE NOTICE '  - Extended sync trigger for entitlement sync';
END $$;
