-- Migration 006: Voice AI Feature Tables
-- Date: 2025-12-08
-- Description: Adds tables for Voice AI real-time conversations with Azure OpenAI Realtime API

-- ============================================================================
-- 1. Voice Messages Table (Conversation Transcripts)
-- ============================================================================
-- Note: voice_sessions table already exists in schema.sql
-- This table stores the conversation history/transcripts for each session

CREATE TABLE IF NOT EXISTS voice_messages (
    id SERIAL PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES voice_sessions(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant')),
    transcript TEXT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for efficient session transcript retrieval
CREATE INDEX IF NOT EXISTS idx_voice_messages_session ON voice_messages(session_id, timestamp);

COMMENT ON TABLE voice_messages IS 'Stores conversation transcripts for voice AI sessions';
COMMENT ON COLUMN voice_messages.role IS 'Speaker role: user or assistant';
COMMENT ON COLUMN voice_messages.transcript IS 'Transcribed text from speech';
COMMENT ON COLUMN voice_messages.timestamp IS 'When the message was spoken in the session';

-- ============================================================================
-- 2. Voice Add-on Purchases Table (Non-expiring minute packs)
-- ============================================================================
CREATE TABLE IF NOT EXISTS voice_addon_purchases (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    seconds_purchased INTEGER NOT NULL,           -- 1200 = 20 minutes
    price_cents INTEGER NOT NULL,                 -- 499 = $4.99
    transaction_id VARCHAR(255),                  -- App Store/Play Store transaction ID
    platform VARCHAR(20) CHECK (platform IN ('ios', 'android', 'web')),
    purchased_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for user purchase history
CREATE INDEX IF NOT EXISTS idx_voice_addon_user ON voice_addon_purchases(user_id, purchased_at DESC);

COMMENT ON TABLE voice_addon_purchases IS 'Tracks voice minute add-on purchases (non-expiring)';
COMMENT ON COLUMN voice_addon_purchases.seconds_purchased IS 'Number of seconds purchased (e.g., 1200 = 20 minutes)';
COMMENT ON COLUMN voice_addon_purchases.price_cents IS 'Price paid in cents (e.g., 499 = $4.99)';

-- ============================================================================
-- 3. Extend voice_sessions table with additional fields for Realtime API
-- ============================================================================
-- Add columns if they don't exist (safe for re-running migration)

DO $$
BEGIN
    -- Add input_tokens column if not exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'voice_sessions' AND column_name = 'input_tokens'
    ) THEN
        ALTER TABLE voice_sessions ADD COLUMN input_tokens INTEGER;
    END IF;

    -- Add output_tokens column if not exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'voice_sessions' AND column_name = 'output_tokens'
    ) THEN
        ALTER TABLE voice_sessions ADD COLUMN output_tokens INTEGER;
    END IF;

    -- Add status column if not exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'voice_sessions' AND column_name = 'status'
    ) THEN
        ALTER TABLE voice_sessions ADD COLUMN status VARCHAR(20) DEFAULT 'active';
        ALTER TABLE voice_sessions ADD CONSTRAINT check_voice_session_status
            CHECK (status IN ('active', 'completed', 'error', 'quota_exceeded'));
    END IF;

    -- Add error_message column if not exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'voice_sessions' AND column_name = 'error_message'
    ) THEN
        ALTER TABLE voice_sessions ADD COLUMN error_message TEXT;
    END IF;
END $$;

COMMENT ON COLUMN voice_sessions.input_tokens IS 'Total audio input tokens consumed';
COMMENT ON COLUMN voice_sessions.output_tokens IS 'Total audio output tokens consumed';
COMMENT ON COLUMN voice_sessions.status IS 'Session status: active, completed, error, quota_exceeded';
COMMENT ON COLUMN voice_sessions.error_message IS 'Error details if session failed';

-- ============================================================================
-- 4. Voice Usage View (Aggregated monthly usage per user)
-- ============================================================================
CREATE OR REPLACE VIEW voice_usage_summary AS
SELECT
    u.id AS user_id,
    u.email,
    u.tier,
    DATE_TRUNC('month', vs.started_at) AS month,
    COUNT(vs.id) AS session_count,
    COALESCE(SUM(vs.duration_seconds), 0) AS total_seconds_used,
    COALESCE(SUM(vs.input_tokens), 0) AS total_input_tokens,
    COALESCE(SUM(vs.output_tokens), 0) AS total_output_tokens,
    -- Calculate remaining quota based on tier (60 min = 3600 sec for Pro)
    CASE
        WHEN u.tier = 'pro' THEN 3600 - COALESCE(SUM(vs.duration_seconds), 0)  -- 60 min for Pro at $7.99/mo
        WHEN u.tier = 'premium' THEN 0  -- No voice for Premium
        ELSE 0  -- No voice for Free
    END AS remaining_seconds,
    -- Add any purchased add-on seconds
    COALESCE((
        SELECT SUM(vap.seconds_purchased)
        FROM voice_addon_purchases vap
        WHERE vap.user_id = u.id
    ), 0) AS addon_seconds_purchased
FROM users u
LEFT JOIN voice_sessions vs ON u.id = vs.user_id
    AND vs.started_at >= DATE_TRUNC('month', CURRENT_DATE)
    AND vs.status = 'completed'
GROUP BY u.id, u.email, u.tier, DATE_TRUNC('month', vs.started_at);

COMMENT ON VIEW voice_usage_summary IS 'Aggregated monthly voice usage per user with quota calculations';

-- ============================================================================
-- 5. Helper Function: Check Voice Quota
-- ============================================================================
CREATE OR REPLACE FUNCTION check_voice_quota(p_user_id UUID)
RETURNS TABLE(
    has_quota BOOLEAN,
    monthly_used_seconds INTEGER,
    monthly_limit_seconds INTEGER,
    addon_seconds_remaining INTEGER,
    total_remaining_seconds INTEGER
) AS $$
DECLARE
    v_tier VARCHAR(20);
    v_monthly_used INTEGER;
    v_monthly_limit INTEGER;
    v_addon_remaining INTEGER;
    v_addon_used INTEGER;
BEGIN
    -- Get user tier
    SELECT tier INTO v_tier FROM users WHERE id = p_user_id;

    -- Set monthly limit based on tier (60 minutes = 3600 seconds for Pro at $7.99/mo)
    v_monthly_limit := CASE
        WHEN v_tier = 'pro' THEN 3600  -- 60 minutes
        ELSE 0  -- No voice for other tiers
    END;

    -- Get monthly usage (completed sessions this month)
    SELECT COALESCE(SUM(duration_seconds), 0) INTO v_monthly_used
    FROM voice_sessions
    WHERE user_id = p_user_id
      AND started_at >= DATE_TRUNC('month', CURRENT_DATE)
      AND status = 'completed';

    -- Get total addon seconds purchased (all time)
    SELECT COALESCE(SUM(seconds_purchased), 0) INTO v_addon_remaining
    FROM voice_addon_purchases
    WHERE user_id = p_user_id;

    -- Calculate how much addon has been used (usage beyond monthly limit)
    v_addon_used := GREATEST(0, v_monthly_used - v_monthly_limit);
    v_addon_remaining := GREATEST(0, v_addon_remaining - v_addon_used);

    -- Return results
    RETURN QUERY
    SELECT
        (v_monthly_used < v_monthly_limit OR v_addon_remaining > 0) AS has_quota,
        v_monthly_used AS monthly_used_seconds,
        v_monthly_limit AS monthly_limit_seconds,
        v_addon_remaining AS addon_seconds_remaining,
        GREATEST(0, v_monthly_limit - v_monthly_used) + v_addon_remaining AS total_remaining_seconds;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION check_voice_quota IS 'Check remaining voice quota for a user (monthly + addon seconds)';

-- ============================================================================
-- 6. Helper Function: Record Voice Usage
-- ============================================================================
CREATE OR REPLACE FUNCTION record_voice_session(
    p_user_id UUID,
    p_session_id UUID,
    p_duration_seconds INTEGER,
    p_input_tokens INTEGER DEFAULT NULL,
    p_output_tokens INTEGER DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    -- Update the voice session with completion data
    UPDATE voice_sessions
    SET
        ended_at = NOW(),
        duration_seconds = p_duration_seconds,
        input_tokens = p_input_tokens,
        output_tokens = p_output_tokens,
        status = 'completed'
    WHERE id = p_session_id AND user_id = p_user_id;

    -- Also record in usage_tracking for unified quota management
    INSERT INTO usage_tracking (user_id, feature_type, usage_count, usage_value, month_year, metadata)
    VALUES (
        p_user_id,
        'voice_minutes',
        1,
        p_duration_seconds::DECIMAL / 60,  -- Convert to minutes
        TO_CHAR(NOW(), 'YYYY-MM'),
        jsonb_build_object(
            'session_id', p_session_id,
            'input_tokens', p_input_tokens,
            'output_tokens', p_output_tokens
        )
    );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION record_voice_session IS 'Record completed voice session and update usage tracking';

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
      AND table_name IN ('voice_messages', 'voice_addon_purchases');

    IF table_count = 2 THEN
        RAISE NOTICE 'Migration 006: Voice AI Tables - Successfully created % new tables', table_count;
    ELSE
        RAISE WARNING 'Migration 006: Only % of 2 expected tables were created', table_count;
    END IF;
END $$;
