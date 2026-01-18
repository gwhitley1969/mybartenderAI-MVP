-- Migration 009: Pro Tier Voice Minutes 60
-- Date: January 2026
-- Description: Standardize Pro voice quota at 60 minutes (3600 seconds)
--              Update add-on packs to 20 minutes (1200 seconds)
--              This resolves the inconsistency where different files had 30, 45, 120, or 300 minutes

-- ============================================================================
-- Pricing Changes:
--   Pro Monthly: $14.99 -> $7.99
--   Pro Annual:  $99.99 -> $79.99
--   Pro Voice:   varied -> 60 min/month
--   Voice Add-on: $4.99/10 min -> $4.99/20 min (double value!)
--   Metering: Connected time -> Active speech time
-- ============================================================================

-- Update the voice_usage_summary view
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
    -- Pro gets 60 minutes (3600 seconds)
    CASE
        WHEN u.tier = 'pro' THEN 3600 - COALESCE(SUM(vs.duration_seconds), 0)
        ELSE 0
    END AS remaining_seconds,
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

-- Update check_voice_quota function
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

    -- Pro gets 60 minutes (3600 seconds)
    -- Free and Premium get 0 (but can purchase add-ons)
    v_monthly_limit := CASE
        WHEN v_tier = 'pro' THEN 3600  -- 60 minutes
        ELSE 0  -- No included voice for other tiers
    END;

    -- Get monthly usage (completed sessions this month)
    SELECT COALESCE(SUM(duration_seconds), 0) INTO v_monthly_used
    FROM voice_sessions
    WHERE user_id = p_user_id
      AND started_at >= DATE_TRUNC('month', CURRENT_DATE)
      AND status = 'completed';

    -- Get total addon seconds purchased (all time, non-expiring)
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

-- Update comments to reflect new pricing
COMMENT ON VIEW voice_usage_summary IS 'Monthly voice usage per user. Pro tier: 60 min/month ($7.99/mo).';
COMMENT ON FUNCTION check_voice_quota IS 'Check voice quota. Pro: 60 min/month. Add-ons: $4.99 for 20 min (1200 sec).';
COMMENT ON TABLE voice_addon_purchases IS 'Voice add-on purchases. $4.99 = 1200 seconds (20 min). Non-expiring.';

-- ============================================================================
-- Migration Complete
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE 'Migration 009: Pro tier voice quota updated to 60 minutes';
    RAISE NOTICE '  - Pro Monthly: $7.99 (was $14.99)';
    RAISE NOTICE '  - Pro Annual: $79.99 (was $99.99)';
    RAISE NOTICE '  - Voice quota: 60 min/month (was inconsistent 30-300)';
    RAISE NOTICE '  - Add-on packs: $4.99/20 min (was $4.99/10 min)';
END $$;
