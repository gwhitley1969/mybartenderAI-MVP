-- Migration 012: Add case-insensitive email lookup index
-- Required for RevenueCat webhook dual-lookup (email-based app_user_id)
-- Run manually via psql before deploying backend changes

CREATE INDEX IF NOT EXISTS idx_users_email_lower ON users(LOWER(email));
