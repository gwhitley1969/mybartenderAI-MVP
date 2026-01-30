-- MyBartenderAI PostgreSQL Database Schema
-- This schema supports the three-tier subscription model with usage tracking

-- ======================
-- CLEANUP (for development only)
-- ======================
-- Uncomment these lines to drop existing tables (WARNING: Data loss!)
-- DROP TABLE IF EXISTS usage_tracking CASCADE;
-- DROP TABLE IF EXISTS user_inventory CASCADE;
-- DROP TABLE IF EXISTS users CASCADE;
-- DROP TABLE IF EXISTS drink_ingredients CASCADE;
-- DROP TABLE IF EXISTS ingredients CASCADE;
-- DROP TABLE IF EXISTS drinks CASCADE;
-- DROP TABLE IF EXISTS snapshots CASCADE;

-- ======================
-- Cocktail Database Tables
-- ======================

-- Snapshots metadata table
CREATE TABLE IF NOT EXISTS snapshots (
    id SERIAL PRIMARY KEY,
    schema_version VARCHAR(10) NOT NULL,
    snapshot_version VARCHAR(20) NOT NULL UNIQUE,
    created_at_utc TIMESTAMP NOT NULL DEFAULT (NOW() AT TIME ZONE 'UTC'),
    blob_url TEXT NOT NULL,
    blob_path TEXT NOT NULL,
    size_bytes BIGINT NOT NULL,
    sha256 VARCHAR(64) NOT NULL,
    drink_count INTEGER NOT NULL,
    ingredient_count INTEGER,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    CONSTRAINT check_status CHECK (status IN ('active', 'superseded', 'deleted'))
);

CREATE INDEX IF NOT EXISTS idx_snapshots_version ON snapshots(snapshot_version);
CREATE INDEX IF NOT EXISTS idx_snapshots_created ON snapshots(created_at_utc DESC);

-- Drinks table (synced from TheCocktailDB)
CREATE TABLE IF NOT EXISTS drinks (
    id VARCHAR(20) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    alternate_name VARCHAR(255),
    category VARCHAR(100),
    glass VARCHAR(100),
    instructions TEXT,
    instructions_es TEXT,
    instructions_de TEXT,
    instructions_fr TEXT,
    instructions_it TEXT,
    image_url TEXT,
    image_attribution TEXT,
    tags TEXT[],
    video_url TEXT,
    iba VARCHAR(100),
    alcoholic VARCHAR(50),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    source VARCHAR(50) DEFAULT 'thecocktaildb',
    is_custom BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_drinks_name ON drinks(name);
CREATE INDEX IF NOT EXISTS idx_drinks_category ON drinks(category);
CREATE INDEX IF NOT EXISTS idx_drinks_alcoholic ON drinks(alcoholic);
CREATE INDEX IF NOT EXISTS idx_drinks_tags ON drinks USING GIN(tags);

-- Ingredients table
CREATE TABLE IF NOT EXISTS ingredients (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    type VARCHAR(100),
    alcohol BOOLEAN DEFAULT FALSE,
    abv DECIMAL(5,2),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ingredients_name ON ingredients(name);
CREATE INDEX IF NOT EXISTS idx_ingredients_type ON ingredients(type);

-- Drink-Ingredient relationship (measures)
CREATE TABLE IF NOT EXISTS drink_ingredients (
    id SERIAL PRIMARY KEY,
    drink_id VARCHAR(20) NOT NULL REFERENCES drinks(id) ON DELETE CASCADE,
    ingredient_name VARCHAR(255) NOT NULL,
    measure VARCHAR(100),
    ingredient_order INTEGER,
    UNIQUE(drink_id, ingredient_order)
);

CREATE INDEX IF NOT EXISTS idx_drink_ingredients_drink ON drink_ingredients(drink_id);
CREATE INDEX IF NOT EXISTS idx_drink_ingredients_name ON drink_ingredients(ingredient_name);

-- ======================
-- User Management Tables
-- ======================

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    azure_ad_sub VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255),
    display_name VARCHAR(255),
    apim_subscription_key VARCHAR(100) UNIQUE,
    tier VARCHAR(20) NOT NULL DEFAULT 'pro',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMP,
    CONSTRAINT check_tier CHECK (tier IN ('free', 'premium', 'pro'))
);

CREATE INDEX IF NOT EXISTS idx_users_sub ON users(azure_ad_sub);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_tier ON users(tier);
CREATE INDEX IF NOT EXISTS idx_users_subscription_key ON users(apim_subscription_key);

-- User inventory (bar ingredients)
CREATE TABLE IF NOT EXISTS user_inventory (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ingredient_name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    brand VARCHAR(255),
    quantity DECIMAL(10,2),
    unit VARCHAR(50),
    added_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, ingredient_name)
);

CREATE INDEX IF NOT EXISTS idx_user_inventory_user ON user_inventory(user_id);
CREATE INDEX IF NOT EXISTS idx_user_inventory_ingredient ON user_inventory(ingredient_name);

-- ======================
-- Usage Tracking Tables
-- ======================

-- Usage tracking for quota enforcement
CREATE TABLE IF NOT EXISTS usage_tracking (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    feature_type VARCHAR(50) NOT NULL,
    usage_count INTEGER NOT NULL DEFAULT 1,
    usage_value DECIMAL(10,2),
    month_year VARCHAR(7) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    metadata JSONB,
    CONSTRAINT check_feature_type CHECK (feature_type IN ('ai_recommendation', 'voice_minutes', 'vision_scan', 'custom_recipe'))
);

CREATE INDEX IF NOT EXISTS idx_usage_user_month ON usage_tracking(user_id, month_year);
CREATE INDEX IF NOT EXISTS idx_usage_feature ON usage_tracking(feature_type);
CREATE INDEX IF NOT EXISTS idx_usage_created ON usage_tracking(created_at DESC);

-- Voice sessions tracking
CREATE TABLE IF NOT EXISTS voice_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_id VARCHAR(100) NOT NULL,
    started_at TIMESTAMP NOT NULL,
    ended_at TIMESTAMP,
    duration_seconds INTEGER,
    queries_count INTEGER DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_voice_sessions_user ON voice_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_voice_sessions_started ON voice_sessions(started_at DESC);

-- Vision scans tracking
CREATE TABLE IF NOT EXISTS vision_scans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    scan_date TIMESTAMP NOT NULL DEFAULT NOW(),
    items_detected INTEGER,
    confidence_avg DECIMAL(5,4),
    blob_url TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vision_scans_user ON vision_scans(user_id);
CREATE INDEX IF NOT EXISTS idx_vision_scans_date ON vision_scans(scan_date DESC);

-- ======================
-- Helper Functions
-- ======================

-- Function to get user's tier quotas
CREATE OR REPLACE FUNCTION get_user_quotas(p_tier VARCHAR(20))
RETURNS TABLE(
    feature VARCHAR(50),
    quota_limit INTEGER,
    quota_unit VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM (VALUES
        -- Free tier
        ('ai_recommendation', CASE WHEN p_tier = 'free' THEN 10 WHEN p_tier = 'premium' THEN 100 ELSE -1 END, 'per_month'),
        ('voice_minutes', CASE WHEN p_tier = 'free' THEN 0 WHEN p_tier = 'premium' THEN 0 ELSE 60 END, 'per_month'),
        ('vision_scan', CASE WHEN p_tier = 'free' THEN 0 WHEN p_tier = 'premium' THEN 5 ELSE 50 END, 'per_month'),
        ('custom_recipe', CASE WHEN p_tier = 'free' THEN 3 WHEN p_tier = 'premium' THEN 25 ELSE -1 END, 'total')
    ) AS quotas(feature, quota_limit, quota_unit);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to check if user has exceeded quota
CREATE OR REPLACE FUNCTION check_user_quota(
    p_user_id UUID,
    p_feature_type VARCHAR(50)
)
RETURNS TABLE(
    has_quota BOOLEAN,
    used INTEGER,
    quota_limit INTEGER,
    remaining INTEGER
) AS $$
DECLARE
    v_tier VARCHAR(20);
    v_month_year VARCHAR(7);
    v_used INTEGER;
    v_limit INTEGER;
BEGIN
    -- Get current month
    v_month_year := TO_CHAR(NOW(), 'YYYY-MM');

    -- Get user tier
    SELECT tier INTO v_tier FROM users WHERE id = p_user_id;

    -- Get quota limit for tier
    SELECT quota_limit INTO v_limit
    FROM get_user_quotas(v_tier)
    WHERE feature = p_feature_type;

    -- Get current usage
    SELECT COALESCE(SUM(usage_count), 0) INTO v_used
    FROM usage_tracking
    WHERE user_id = p_user_id
      AND feature_type = p_feature_type
      AND month_year = v_month_year;

    -- Return result
    RETURN QUERY
    SELECT
        (v_limit < 0 OR v_used < v_limit) AS has_quota,
        v_used AS used,
        v_limit AS quota_limit,
        CASE WHEN v_limit < 0 THEN -1 ELSE GREATEST(0, v_limit - v_used) END AS remaining;
END;
$$ LANGUAGE plpgsql;

-- Function to record usage
CREATE OR REPLACE FUNCTION record_usage(
    p_user_id UUID,
    p_feature_type VARCHAR(50),
    p_usage_count INTEGER DEFAULT 1,
    p_usage_value DECIMAL DEFAULT NULL,
    p_metadata JSONB DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_month_year VARCHAR(7);
BEGIN
    v_month_year := TO_CHAR(NOW(), 'YYYY-MM');

    INSERT INTO usage_tracking (user_id, feature_type, usage_count, usage_value, month_year, metadata)
    VALUES (p_user_id, p_feature_type, p_usage_count, p_usage_value, v_month_year, p_metadata);
END;
$$ LANGUAGE plpgsql;

-- ======================
-- Seed Data
-- ======================

-- Insert test user (for development)
-- Uncomment for local testing
/*
INSERT INTO users (azure_ad_sub, email, display_name, tier)
VALUES
    ('test-user-001', 'test@mybartenderai.com', 'Test User Free', 'free'),
    ('test-user-002', 'premium@mybartenderai.com', 'Test User Premium', 'premium'),
    ('test-user-003', 'pro@mybartenderai.com', 'Test User Pro', 'pro')
ON CONFLICT (azure_ad_sub) DO NOTHING;
*/

-- ======================
-- Views for Analytics
-- ======================

-- User usage summary view
CREATE OR REPLACE VIEW user_usage_summary AS
SELECT
    u.id AS user_id,
    u.email,
    u.tier,
    ut.feature_type,
    ut.month_year,
    SUM(ut.usage_count) AS total_usage,
    SUM(ut.usage_value) AS total_value
FROM users u
LEFT JOIN usage_tracking ut ON u.id = ut.user_id
GROUP BY u.id, u.email, u.tier, ut.feature_type, ut.month_year;

-- Monthly revenue potential view
CREATE OR REPLACE VIEW monthly_tier_stats AS
SELECT
    DATE_TRUNC('month', created_at) AS month,
    tier,
    COUNT(*) AS user_count,
    CASE
        WHEN tier = 'premium' THEN COUNT(*) * 4.99
        WHEN tier = 'pro' THEN COUNT(*) * 9.99
        ELSE 0
    END AS potential_revenue
FROM users
GROUP BY DATE_TRUNC('month', created_at), tier;

COMMENT ON TABLE users IS 'User accounts with tier information';
COMMENT ON TABLE drinks IS 'Cocktail recipes from TheCocktailDB and custom user recipes';
COMMENT ON TABLE usage_tracking IS 'Track feature usage for quota enforcement';
COMMENT ON FUNCTION check_user_quota IS 'Check if user has remaining quota for a feature';
COMMENT ON FUNCTION record_usage IS 'Record usage of a feature for quota tracking';

-- Grant permissions (adjust as needed for your environment)
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO mybartenderai_app;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO mybartenderai_app;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO mybartenderai_app;
