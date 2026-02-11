-- Migration 010: Server-Authoritative Voice Metering
-- Date: February 2026
-- Description: Moves all duration computation into PostgreSQL where both timestamps
--              are server-controlled. Client-reported active speech time becomes a
--              discount (pauses are free) but is capped by wall-clock time (unforgeable).
--              Adds stale session expiry and concurrent session prevention support.
--
-- Threat model addressed:
--   - Client reports durationSeconds: 0   → server bills 30% of wall-clock
--   - Client reports inflated duration    → capped at wall-clock
--   - Client never calls /v1/voice/usage  → timer expires after 2h, bills 30%
--   - Multiple concurrent sessions        → 409 Conflict (enforced in JS)
--   - Session > 60 minutes               → capped at 3600s

-- ============================================================================
-- 1a. Add 'expired' to status constraint
-- ============================================================================
-- Sessions that are auto-closed by the stale session cleanup get this status.
-- Distinguishes intentional end ('completed') from server-forced end ('expired').

ALTER TABLE voice_sessions DROP CONSTRAINT IF EXISTS check_voice_session_status;
ALTER TABLE voice_sessions ADD CONSTRAINT check_voice_session_status
    CHECK (status IN ('active', 'completed', 'error', 'quota_exceeded', 'expired'));

-- ============================================================================
-- 1b. Replace record_voice_session() — server-authoritative version
-- ============================================================================
-- Same parameter signature as 006_voice_ai_tables.sql (backward-compatible).
-- Return type changes from VOID to TABLE — existing JS discards result, so safe.
--
-- Billing logic:
--   wall_clock = EXTRACT(EPOCH FROM (NOW() - started_at))  -- server-controlled
--   wall_clock = LEAST(wall_clock, 3600)                    -- 60-min hard cap
--   IF already completed/expired → return previous values   -- idempotency
--   IF client > 0  → billed = LEAST(client, wall_clock)    -- client discount, capped
--   IF client <= 0 AND wall_clock > 10 → billed = wall_clock * 0.3  -- conservative fallback
--   IF client <= 0 AND wall_clock <= 10 → billed = 0       -- short session, benefit of doubt

-- Must DROP first: return type changed from VOID to TABLE (CREATE OR REPLACE cannot do this)
DROP FUNCTION IF EXISTS record_voice_session(uuid,uuid,integer,integer,integer);

CREATE OR REPLACE FUNCTION record_voice_session(
    p_user_id UUID,
    p_session_id UUID,
    p_duration_seconds INTEGER,
    p_input_tokens INTEGER DEFAULT NULL,
    p_output_tokens INTEGER DEFAULT NULL
)
RETURNS TABLE(
    billed_seconds INTEGER,
    wall_clock_seconds INTEGER,
    client_reported_seconds INTEGER,
    billing_method TEXT
) AS $$
DECLARE
    v_started_at TIMESTAMPTZ;
    v_current_status VARCHAR(20);
    v_existing_duration INTEGER;
    v_wall_clock INTEGER;
    v_billed INTEGER;
    v_method TEXT;
BEGIN
    -- Get session info
    SELECT vs.started_at, vs.status, vs.duration_seconds
    INTO v_started_at, v_current_status, v_existing_duration
    FROM voice_sessions vs
    WHERE vs.id = p_session_id AND vs.user_id = p_user_id;

    -- Session not found
    IF v_started_at IS NULL THEN
        RAISE EXCEPTION 'Voice session % not found for user %', p_session_id, p_user_id;
    END IF;

    -- Idempotency: if already completed or expired, return previous billing
    IF v_current_status IN ('completed', 'expired') THEN
        RETURN QUERY SELECT
            COALESCE(v_existing_duration, 0)::INTEGER,
            EXTRACT(EPOCH FROM (NOW() - v_started_at))::INTEGER,
            p_duration_seconds,
            'already_recorded'::TEXT;
        RETURN;
    END IF;

    -- Compute server-controlled wall-clock time
    v_wall_clock := EXTRACT(EPOCH FROM (NOW() - v_started_at))::INTEGER;
    v_wall_clock := LEAST(v_wall_clock, 3600);  -- 60-minute hard cap

    -- Determine billed seconds
    IF p_duration_seconds > 0 THEN
        -- Client reported active speech time — trust it but cap by wall-clock
        v_billed := LEAST(p_duration_seconds, v_wall_clock);
        v_method := 'client_capped_by_wallclock';
    ELSIF v_wall_clock > 10 THEN
        -- No client report but session was substantial — conservative 30% estimate
        v_billed := (v_wall_clock * 0.3)::INTEGER;
        v_method := 'server_fallback_30pct';
    ELSE
        -- Short session with no client report — benefit of the doubt
        v_billed := 0;
        v_method := 'short_session_free';
    END IF;

    -- Update the voice session with completion data
    UPDATE voice_sessions
    SET
        ended_at = NOW(),
        duration_seconds = v_billed,
        input_tokens = p_input_tokens,
        output_tokens = p_output_tokens,
        status = 'completed'
    WHERE id = p_session_id AND user_id = p_user_id;

    -- Record in usage_tracking for unified quota management
    INSERT INTO usage_tracking (user_id, feature_type, usage_count, usage_value, month_year, metadata)
    VALUES (
        p_user_id,
        'voice_minutes',
        1,
        v_billed::DECIMAL / 60,  -- Convert to minutes
        TO_CHAR(NOW(), 'YYYY-MM'),
        jsonb_build_object(
            'session_id', p_session_id,
            'input_tokens', p_input_tokens,
            'output_tokens', p_output_tokens,
            'wall_clock_seconds', v_wall_clock,
            'client_reported_seconds', p_duration_seconds,
            'billing_method', v_method
        )
    );

    -- Return billing details
    RETURN QUERY SELECT
        v_billed,
        v_wall_clock,
        p_duration_seconds,
        v_method;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION record_voice_session IS 'Server-authoritative voice billing. Client duration is a discount capped by wall-clock time.';

-- ============================================================================
-- 1c. expire_stale_voice_sessions(p_max_age_hours)
-- ============================================================================
-- Finds 'active' sessions older than N hours, marks them 'expired', bills 30%
-- of capped wall-clock time. Called by the hourly timer as last line of defense.

CREATE OR REPLACE FUNCTION expire_stale_voice_sessions(p_max_age_hours INTEGER DEFAULT 2)
RETURNS TABLE(
    session_id UUID,
    user_id UUID,
    age_seconds INTEGER,
    billed_seconds INTEGER
) AS $$
DECLARE
    rec RECORD;
    v_wall_clock INTEGER;
    v_billed INTEGER;
BEGIN
    FOR rec IN
        SELECT vs.id, vs.user_id AS uid, vs.started_at
        FROM voice_sessions vs
        WHERE vs.status = 'active'
          AND vs.started_at < NOW() - (p_max_age_hours || ' hours')::INTERVAL
    LOOP
        v_wall_clock := LEAST(
            EXTRACT(EPOCH FROM (NOW() - rec.started_at))::INTEGER,
            3600  -- 60-min cap
        );

        -- Bill 30% of wall-clock for abandoned sessions
        IF v_wall_clock > 10 THEN
            v_billed := (v_wall_clock * 0.3)::INTEGER;
        ELSE
            v_billed := 0;
        END IF;

        -- Mark session as expired
        UPDATE voice_sessions
        SET status = 'expired',
            ended_at = NOW(),
            duration_seconds = v_billed,
            error_message = 'Auto-expired: stale session after ' || p_max_age_hours || ' hours'
        WHERE voice_sessions.id = rec.id;

        -- Record in usage_tracking
        INSERT INTO usage_tracking (user_id, feature_type, usage_count, usage_value, month_year, metadata)
        VALUES (
            rec.uid,
            'voice_minutes',
            1,
            v_billed::DECIMAL / 60,
            TO_CHAR(NOW(), 'YYYY-MM'),
            jsonb_build_object(
                'session_id', rec.id,
                'wall_clock_seconds', v_wall_clock,
                'billing_method', 'stale_session_expired',
                'max_age_hours', p_max_age_hours
            )
        );

        RETURN QUERY SELECT rec.id, rec.uid, v_wall_clock, v_billed;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION expire_stale_voice_sessions IS 'Expire active sessions older than N hours. Bills 30% of wall-clock. Last line of defense.';

-- ============================================================================
-- 1d. close_user_stale_sessions(p_user_id, p_max_age_hours)
-- ============================================================================
-- Per-user version called during session creation. Auto-closes stale sessions
-- for a specific user before allowing a new one.

CREATE OR REPLACE FUNCTION close_user_stale_sessions(
    p_user_id UUID,
    p_max_age_hours INTEGER DEFAULT 2
)
RETURNS INTEGER AS $$
DECLARE
    rec RECORD;
    v_wall_clock INTEGER;
    v_billed INTEGER;
    v_closed_count INTEGER := 0;
BEGIN
    FOR rec IN
        SELECT vs.id, vs.started_at
        FROM voice_sessions vs
        WHERE vs.user_id = p_user_id
          AND vs.status = 'active'
          AND vs.started_at < NOW() - (p_max_age_hours || ' hours')::INTERVAL
    LOOP
        v_wall_clock := LEAST(
            EXTRACT(EPOCH FROM (NOW() - rec.started_at))::INTEGER,
            3600
        );

        IF v_wall_clock > 10 THEN
            v_billed := (v_wall_clock * 0.3)::INTEGER;
        ELSE
            v_billed := 0;
        END IF;

        UPDATE voice_sessions
        SET status = 'expired',
            ended_at = NOW(),
            duration_seconds = v_billed,
            error_message = 'Auto-expired: user started new session'
        WHERE voice_sessions.id = rec.id;

        INSERT INTO usage_tracking (user_id, feature_type, usage_count, usage_value, month_year, metadata)
        VALUES (
            p_user_id,
            'voice_minutes',
            1,
            v_billed::DECIMAL / 60,
            TO_CHAR(NOW(), 'YYYY-MM'),
            jsonb_build_object(
                'session_id', rec.id,
                'wall_clock_seconds', v_wall_clock,
                'billing_method', 'stale_closed_for_new_session'
            )
        );

        v_closed_count := v_closed_count + 1;
    END LOOP;

    RETURN v_closed_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION close_user_stale_sessions IS 'Close stale active sessions for a user. Called before creating a new session.';

-- ============================================================================
-- 1e. Update check_voice_quota() to count expired sessions
-- ============================================================================
-- Critical: previous version only summed status = 'completed'.
-- Must also count 'expired' or stale-session billing won't affect quota.

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
    v_monthly_limit := CASE
        WHEN v_tier = 'pro' THEN 3600  -- 60 minutes
        ELSE 0  -- No included voice for other tiers
    END;

    -- Get monthly usage (completed AND expired sessions this month)
    SELECT COALESCE(SUM(duration_seconds), 0) INTO v_monthly_used
    FROM voice_sessions
    WHERE user_id = p_user_id
      AND started_at >= DATE_TRUNC('month', CURRENT_DATE)
      AND status IN ('completed', 'expired');

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

COMMENT ON FUNCTION check_voice_quota IS 'Check voice quota. Counts both completed and expired sessions. Pro: 60 min/month.';

-- ============================================================================
-- 1f. Update voice_usage_summary view to include expired sessions
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
    AND vs.status IN ('completed', 'expired')
GROUP BY u.id, u.email, u.tier, DATE_TRUNC('month', vs.started_at);

COMMENT ON VIEW voice_usage_summary IS 'Monthly voice usage per user. Includes completed and expired sessions. Pro: 60 min/month.';

-- ============================================================================
-- Migration Complete
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE 'Migration 010: Server-authoritative voice metering';
    RAISE NOTICE '  - Added "expired" to voice_sessions status constraint';
    RAISE NOTICE '  - record_voice_session() now returns billing details (wall-clock capped)';
    RAISE NOTICE '  - New: expire_stale_voice_sessions() for hourly cleanup';
    RAISE NOTICE '  - New: close_user_stale_sessions() for per-user cleanup';
    RAISE NOTICE '  - check_voice_quota() now counts expired sessions';
    RAISE NOTICE '  - voice_usage_summary view updated for expired sessions';
END $$;
