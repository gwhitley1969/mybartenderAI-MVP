-- Migration 007: Subscription Management Tables (RevenueCat Integration)
-- Date: 2025-12-23
-- Description: Adds tables for tracking user subscriptions from RevenueCat

-- ============================================================================
-- 1. User Subscriptions Table
-- ============================================================================
-- Tracks subscription status from RevenueCat webhooks
-- The tier in this table drives the users.tier column via trigger

CREATE TABLE IF NOT EXISTS user_subscriptions (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    revenuecat_app_user_id VARCHAR(255) NOT NULL,  -- The azure_ad_sub used as RevenueCat appUserID
    tier VARCHAR(20) NOT NULL CHECK (tier IN ('premium', 'pro')),
    product_id VARCHAR(100) NOT NULL,  -- e.g., 'premium_monthly', 'pro_yearly'
    is_active BOOLEAN NOT NULL DEFAULT true,
    auto_renewing BOOLEAN DEFAULT true,
    expires_at TIMESTAMPTZ,
    cancel_reason VARCHAR(50),  -- e.g., 'CUSTOMER_CANCELLED', 'BILLING_ERROR'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_user_subscription UNIQUE (user_id)  -- One active subscription per user
);

-- Indexes for efficient lookups
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_id ON user_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_revenuecat ON user_subscriptions(revenuecat_app_user_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_active ON user_subscriptions(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_expires ON user_subscriptions(expires_at) WHERE is_active = true;

COMMENT ON TABLE user_subscriptions IS 'Tracks subscription status from RevenueCat webhooks';
COMMENT ON COLUMN user_subscriptions.revenuecat_app_user_id IS 'User ID passed to RevenueCat (azure_ad_sub)';
COMMENT ON COLUMN user_subscriptions.tier IS 'Subscription tier: premium or pro';
COMMENT ON COLUMN user_subscriptions.product_id IS 'RevenueCat/Play Store product ID';
COMMENT ON COLUMN user_subscriptions.is_active IS 'Whether subscription is currently active';
COMMENT ON COLUMN user_subscriptions.auto_renewing IS 'Whether subscription will auto-renew';
COMMENT ON COLUMN user_subscriptions.expires_at IS 'When subscription expires (null for active auto-renewing)';
COMMENT ON COLUMN user_subscriptions.cancel_reason IS 'Reason for cancellation if applicable';

-- ============================================================================
-- 2. Subscription Events Table (Audit Log)
-- ============================================================================
-- Records all subscription lifecycle events for debugging and analytics

CREATE TABLE IF NOT EXISTS subscription_events (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,  -- Allow null for unknown users
    revenuecat_app_user_id VARCHAR(255) NOT NULL,
    event_type VARCHAR(50) NOT NULL,  -- e.g., 'INITIAL_PURCHASE', 'RENEWAL', 'CANCELLATION', 'EXPIRATION'
    product_id VARCHAR(100),
    tier VARCHAR(20),
    expires_at TIMESTAMPTZ,
    raw_event JSONB,  -- Full RevenueCat webhook payload for debugging
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for efficient event history retrieval
CREATE INDEX IF NOT EXISTS idx_subscription_events_user ON subscription_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_subscription_events_revenuecat ON subscription_events(revenuecat_app_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_subscription_events_type ON subscription_events(event_type, created_at DESC);

COMMENT ON TABLE subscription_events IS 'Audit log of all subscription lifecycle events from RevenueCat';
COMMENT ON COLUMN subscription_events.event_type IS 'RevenueCat event type: INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION, etc.';
COMMENT ON COLUMN subscription_events.raw_event IS 'Full webhook payload for debugging';

-- ============================================================================
-- 3. Trigger Function: Sync User Tier from Subscription
-- ============================================================================
-- When subscription changes, update the users.tier column
-- Pro > Premium > Free (pick highest active tier)

CREATE OR REPLACE FUNCTION sync_user_tier_from_subscription()
RETURNS TRIGGER AS $$
DECLARE
    v_best_tier VARCHAR(20);
BEGIN
    -- Determine the best active tier for this user
    SELECT
        CASE
            WHEN EXISTS (SELECT 1 FROM user_subscriptions WHERE user_id = NEW.user_id AND tier = 'pro' AND is_active = true) THEN 'pro'
            WHEN EXISTS (SELECT 1 FROM user_subscriptions WHERE user_id = NEW.user_id AND tier = 'premium' AND is_active = true) THEN 'premium'
            ELSE 'free'
        END
    INTO v_best_tier;

    -- Update the users table
    UPDATE users SET tier = v_best_tier WHERE id = NEW.user_id;

    -- Set updated_at on the subscription
    NEW.updated_at := NOW();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION sync_user_tier_from_subscription IS 'Syncs users.tier when subscription status changes (pro > premium > free)';

-- Create the trigger (BEFORE to allow updating NEW.updated_at)
DROP TRIGGER IF EXISTS trigger_sync_user_tier ON user_subscriptions;
CREATE TRIGGER trigger_sync_user_tier
BEFORE INSERT OR UPDATE ON user_subscriptions
FOR EACH ROW EXECUTE FUNCTION sync_user_tier_from_subscription();

-- ============================================================================
-- 4. Helper Function: Map Product ID to Tier
-- ============================================================================
-- Extracts tier from product ID (e.g., 'premium_monthly' -> 'premium')

CREATE OR REPLACE FUNCTION get_tier_from_product_id(p_product_id VARCHAR)
RETURNS VARCHAR(20) AS $$
BEGIN
    RETURN CASE
        WHEN p_product_id LIKE 'pro_%' THEN 'pro'
        WHEN p_product_id LIKE 'premium_%' THEN 'premium'
        ELSE NULL
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION get_tier_from_product_id IS 'Extracts tier name from product ID (e.g., pro_monthly -> pro)';

-- ============================================================================
-- 5. Helper Function: Upsert Subscription from RevenueCat Webhook
-- ============================================================================

CREATE OR REPLACE FUNCTION upsert_subscription_from_webhook(
    p_user_id UUID,
    p_revenuecat_app_user_id VARCHAR,
    p_product_id VARCHAR,
    p_is_active BOOLEAN,
    p_auto_renewing BOOLEAN DEFAULT true,
    p_expires_at TIMESTAMPTZ DEFAULT NULL,
    p_cancel_reason VARCHAR DEFAULT NULL
)
RETURNS user_subscriptions AS $$
DECLARE
    v_tier VARCHAR(20);
    v_result user_subscriptions;
BEGIN
    -- Get tier from product ID
    v_tier := get_tier_from_product_id(p_product_id);

    IF v_tier IS NULL THEN
        RAISE EXCEPTION 'Invalid product_id: %. Cannot determine tier.', p_product_id;
    END IF;

    -- Upsert the subscription
    INSERT INTO user_subscriptions (
        user_id,
        revenuecat_app_user_id,
        tier,
        product_id,
        is_active,
        auto_renewing,
        expires_at,
        cancel_reason
    ) VALUES (
        p_user_id,
        p_revenuecat_app_user_id,
        v_tier,
        p_product_id,
        p_is_active,
        p_auto_renewing,
        p_expires_at,
        p_cancel_reason
    )
    ON CONFLICT (user_id) DO UPDATE SET
        tier = v_tier,
        product_id = p_product_id,
        is_active = p_is_active,
        auto_renewing = COALESCE(p_auto_renewing, user_subscriptions.auto_renewing),
        expires_at = p_expires_at,
        cancel_reason = p_cancel_reason,
        updated_at = NOW()
    RETURNING * INTO v_result;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION upsert_subscription_from_webhook IS 'Upserts subscription record from RevenueCat webhook data';

-- ============================================================================
-- 6. Helper Function: Get Subscription Status
-- ============================================================================

CREATE OR REPLACE FUNCTION get_subscription_status(p_user_id UUID)
RETURNS TABLE(
    tier VARCHAR,
    product_id VARCHAR,
    is_active BOOLEAN,
    auto_renewing BOOLEAN,
    expires_at TIMESTAMPTZ,
    cancel_reason VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        us.tier,
        us.product_id,
        us.is_active,
        us.auto_renewing,
        us.expires_at,
        us.cancel_reason
    FROM user_subscriptions us
    WHERE us.user_id = p_user_id;

    -- Return free tier info if no subscription found
    IF NOT FOUND THEN
        RETURN QUERY SELECT
            'free'::VARCHAR,
            NULL::VARCHAR,
            false::BOOLEAN,
            false::BOOLEAN,
            NULL::TIMESTAMPTZ,
            NULL::VARCHAR;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_subscription_status IS 'Returns subscription status for a user (or free tier if none)';

-- ============================================================================
-- Migration Complete
-- ============================================================================

-- Verify tables were created
DO $$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name IN ('user_subscriptions', 'subscription_events');

    IF table_count = 2 THEN
        RAISE NOTICE 'Migration 007: Subscription Tables - Successfully created % tables', table_count;
    ELSE
        RAISE WARNING 'Migration 007: Only % of 2 expected tables were created', table_count;
    END IF;
END $$;
