-- Migration 005: Friends via Code Social Sharing Feature
-- Date: 2025-11-14
-- Description: Adds tables for alias-based social sharing with support for both standard and custom recipes

-- ============================================================================
-- 1. User Profile Table with System-Generated Aliases
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_profile (
  user_id       TEXT PRIMARY KEY,              -- CIAM sub claim (Entra External ID)
  alias         TEXT UNIQUE NOT NULL,          -- System-generated e.g. '@happy-penguin-42'
  display_name  TEXT CHECK (char_length(display_name) <= 30), -- Optional user-chosen name
  share_code    TEXT UNIQUE,                   -- Optional backup/legacy code
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen     TIMESTAMPTZ
);

-- Ensure alias uniqueness
CREATE UNIQUE INDEX IF NOT EXISTS uq_user_profile_alias ON user_profile(alias);

-- Index for lookup by alias
CREATE INDEX IF NOT EXISTS idx_user_profile_alias ON user_profile(alias);

COMMENT ON TABLE user_profile IS 'User social profiles with privacy-focused system-generated aliases';
COMMENT ON COLUMN user_profile.user_id IS 'Entra External ID sub claim - durable user identifier';
COMMENT ON COLUMN user_profile.alias IS 'System-generated alias format: @adjective-animal-###';
COMMENT ON COLUMN user_profile.display_name IS 'Optional 30-char display name shown alongside alias';

-- ============================================================================
-- 2. Custom Recipes Table (Create Studio)
-- ============================================================================
CREATE TABLE IF NOT EXISTS custom_recipes (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       TEXT NOT NULL REFERENCES user_profile(user_id) ON DELETE CASCADE,
  name          TEXT NOT NULL CHECK (char_length(name) <= 100),
  description   TEXT CHECK (char_length(description) <= 500),
  ingredients   JSONB NOT NULL,                -- [{name, amount, unit}]
  instructions  TEXT NOT NULL,
  glass_type    TEXT,
  garnish       TEXT,
  notes         TEXT,
  image_url     TEXT,                          -- Optional user-uploaded image
  is_public     BOOLEAN DEFAULT FALSE,
  allow_remix   BOOLEAN DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for user's custom recipes
CREATE INDEX IF NOT EXISTS idx_custom_recipes_user ON custom_recipes(user_id);

-- Index for public custom recipes
CREATE INDEX IF NOT EXISTS idx_custom_recipes_public ON custom_recipes(is_public) WHERE is_public = TRUE;

COMMENT ON TABLE custom_recipes IS 'User-created cocktail recipes from Create Studio';
COMMENT ON COLUMN custom_recipes.ingredients IS 'JSONB array of ingredient objects with name, amount, unit';
COMMENT ON COLUMN custom_recipes.allow_remix IS 'Allow other users to clone and modify this recipe';

-- ============================================================================
-- 3. Recipe Share Table (Internal Sharing Between App Users)
-- ============================================================================
CREATE TABLE IF NOT EXISTS recipe_share (
  id               BIGSERIAL PRIMARY KEY,
  from_user_id     TEXT NOT NULL REFERENCES user_profile(user_id) ON DELETE CASCADE,
  to_user_id       TEXT NOT NULL REFERENCES user_profile(user_id) ON DELETE CASCADE,
  recipe_id        TEXT,                       -- For standard cocktails from TheCocktailDB
  custom_recipe_id UUID REFERENCES custom_recipes(id) ON DELETE CASCADE, -- For custom recipes
  recipe_type      TEXT NOT NULL CHECK (recipe_type IN ('standard', 'custom')),
  message          TEXT CHECK (char_length(message) <= 200),
  tagline          TEXT CHECK (char_length(tagline) <= 120), -- Optional AI-generated tagline
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  viewed_at        TIMESTAMPTZ,

  -- Ensure exactly one recipe reference is provided
  CONSTRAINT recipe_reference CHECK (
    (recipe_type = 'standard' AND recipe_id IS NOT NULL AND custom_recipe_id IS NULL) OR
    (recipe_type = 'custom' AND custom_recipe_id IS NOT NULL AND recipe_id IS NULL)
  )
);

-- Index for recipient's inbox (most common query)
CREATE INDEX IF NOT EXISTS idx_share_to_created ON recipe_share(to_user_id, created_at DESC);

-- Index for sender's outbox
CREATE INDEX IF NOT EXISTS idx_share_from_created ON recipe_share(from_user_id, created_at DESC);

-- Index for custom recipe shares
CREATE INDEX IF NOT EXISTS idx_share_custom_recipe ON recipe_share(custom_recipe_id) WHERE custom_recipe_id IS NOT NULL;

COMMENT ON TABLE recipe_share IS 'Internal recipe shares between app users via aliases';
COMMENT ON COLUMN recipe_share.recipe_id IS 'Standard cocktail ID from TheCocktailDB';
COMMENT ON COLUMN recipe_share.custom_recipe_id IS 'Custom recipe ID from Create Studio';
COMMENT ON COLUMN recipe_share.tagline IS 'AI-generated catchy one-liner (optional)';

-- ============================================================================
-- 4. Share Invite Table (External Sharing via URLs)
-- ============================================================================
CREATE TABLE IF NOT EXISTS share_invite (
  token            TEXT PRIMARY KEY,           -- URL-safe random 22+ character string
  recipe_id        TEXT,                       -- For standard cocktails
  custom_recipe_id UUID REFERENCES custom_recipes(id) ON DELETE CASCADE, -- For custom recipes
  recipe_type      TEXT NOT NULL CHECK (recipe_type IN ('standard', 'custom')),
  from_user_id     TEXT NOT NULL REFERENCES user_profile(user_id) ON DELETE CASCADE,
  message          TEXT CHECK (char_length(message) <= 200),
  tagline          TEXT CHECK (char_length(tagline) <= 120),
  one_time         BOOLEAN NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at       TIMESTAMPTZ DEFAULT (now() + interval '30 days'),
  claimed_by       TEXT REFERENCES user_profile(user_id),
  claimed_at       TIMESTAMPTZ,
  status           TEXT NOT NULL DEFAULT 'issued' CHECK (status IN ('issued', 'claimed', 'expired', 'revoked')),
  view_count       INTEGER DEFAULT 0,          -- Track views of static preview page

  -- Ensure exactly one recipe reference is provided
  CONSTRAINT invite_recipe_reference CHECK (
    (recipe_type = 'standard' AND recipe_id IS NOT NULL AND custom_recipe_id IS NULL) OR
    (recipe_type = 'custom' AND custom_recipe_id IS NOT NULL AND recipe_id IS NULL)
  )
);

-- Index for sender's invites
CREATE INDEX IF NOT EXISTS idx_invite_from_created ON share_invite(from_user_id, created_at DESC);

-- Index for status lookups
CREATE INDEX IF NOT EXISTS idx_invite_status ON share_invite(status);

-- Index for expiry cleanup
CREATE INDEX IF NOT EXISTS idx_invite_expires ON share_invite(expires_at) WHERE status = 'issued';

-- Index for custom recipe invites
CREATE INDEX IF NOT EXISTS idx_invite_custom_recipe ON share_invite(custom_recipe_id) WHERE custom_recipe_id IS NOT NULL;

COMMENT ON TABLE share_invite IS 'External recipe share invites via URLs with static preview pages';
COMMENT ON COLUMN share_invite.token IS 'Cryptographically secure random token for URL';
COMMENT ON COLUMN share_invite.one_time IS 'Whether invite can only be claimed once';
COMMENT ON COLUMN share_invite.view_count IS 'Number of times static preview page was viewed';

-- ============================================================================
-- 5. Friendship Table (Optional - for future features)
-- ============================================================================
CREATE TABLE IF NOT EXISTS friendships (
  user_id_1     TEXT NOT NULL REFERENCES user_profile(user_id) ON DELETE CASCADE,
  user_id_2     TEXT NOT NULL REFERENCES user_profile(user_id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Ensure user_id_1 < user_id_2 for symmetric relationship
  CONSTRAINT friendships_order CHECK (user_id_1 < user_id_2),

  PRIMARY KEY (user_id_1, user_id_2)
);

-- Index for friend lookups
CREATE INDEX IF NOT EXISTS idx_friendships_user1 ON friendships(user_id_1);
CREATE INDEX IF NOT EXISTS idx_friendships_user2 ON friendships(user_id_2);

COMMENT ON TABLE friendships IS 'Symmetric friendship relationships between users';
COMMENT ON CONSTRAINT friendships_order ON friendships IS 'Ensures symmetric storage: always user_id_1 < user_id_2';

-- ============================================================================
-- 6. Helper Functions
-- ============================================================================

-- Function to check if two users are friends
CREATE OR REPLACE FUNCTION are_friends(uid1 TEXT, uid2 TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM friendships
    WHERE (user_id_1 = LEAST(uid1, uid2) AND user_id_2 = GREATEST(uid1, uid2))
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION are_friends IS 'Check if two users are friends (symmetric)';

-- Function to get user's alias from user_id
CREATE OR REPLACE FUNCTION get_user_alias(uid TEXT)
RETURNS TEXT AS $$
BEGIN
  RETURN (SELECT alias FROM user_profile WHERE user_id = uid);
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_user_alias IS 'Get user alias by user_id';

-- Function to get user_id from alias
CREATE OR REPLACE FUNCTION get_user_id_by_alias(user_alias TEXT)
RETURNS TEXT AS $$
BEGIN
  RETURN (SELECT user_id FROM user_profile WHERE alias = user_alias);
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_user_id_by_alias IS 'Get user_id by alias lookup';

-- ============================================================================
-- 7. Triggers for Updated Timestamps
-- ============================================================================

-- Trigger function to update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to custom_recipes
DROP TRIGGER IF EXISTS update_custom_recipes_updated_at ON custom_recipes;
CREATE TRIGGER update_custom_recipes_updated_at
  BEFORE UPDATE ON custom_recipes
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 8. Sample Data for Testing (Optional - Comment out for production)
-- ============================================================================

-- Uncomment below to insert test data for development
/*
-- Insert test users
INSERT INTO user_profile (user_id, alias, display_name) VALUES
  ('test-user-001', '@happy-penguin-42', 'CocktailMaster'),
  ('test-user-002', '@clever-dolphin-99', 'MixologyPro'),
  ('test-user-003', '@swift-eagle-17', NULL)
ON CONFLICT (user_id) DO NOTHING;

-- Insert test custom recipe
INSERT INTO custom_recipes (id, user_id, name, description, ingredients, instructions, is_public, allow_remix) VALUES
  (
    'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    'test-user-001',
    'Blue Sunset',
    'A tropical blend with a mysterious blue hue',
    '[
      {"name": "Blue Curaçao", "amount": "1.5", "unit": "oz"},
      {"name": "Vodka", "amount": "1", "unit": "oz"},
      {"name": "Pineapple Juice", "amount": "2", "unit": "oz"},
      {"name": "Lime Juice", "amount": "0.5", "unit": "oz"}
    ]'::jsonb,
    'Shake all ingredients with ice. Strain into a chilled glass. Garnish with lime wheel.',
    TRUE,
    TRUE
  )
ON CONFLICT (id) DO NOTHING;

-- Insert test friendship
INSERT INTO friendships (user_id_1, user_id_2) VALUES
  ('test-user-001', 'test-user-002')
ON CONFLICT DO NOTHING;
*/

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
    AND table_name IN ('user_profile', 'custom_recipes', 'recipe_share', 'share_invite', 'friendships');

  IF table_count = 5 THEN
    RAISE NOTICE 'Migration 005: Friends via Code - Successfully created % tables', table_count;
  ELSE
    RAISE WARNING 'Migration 005: Only % of 5 expected tables were created', table_count;
  END IF;
END $$;
