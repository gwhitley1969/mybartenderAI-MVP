-- Migration 008: Add idempotency support for RevenueCat webhooks
-- This prevents duplicate event processing when RevenueCat retries webhook delivery

-- Add column to store RevenueCat event ID for deduplication
ALTER TABLE subscription_events
ADD COLUMN IF NOT EXISTS revenuecat_event_id VARCHAR(255);

-- Create partial unique index to enforce idempotency
-- Only indexes non-null event IDs to allow legacy rows without event_id
CREATE UNIQUE INDEX IF NOT EXISTS idx_subscription_events_event_id
ON subscription_events(revenuecat_event_id)
WHERE revenuecat_event_id IS NOT NULL;

-- Add index for faster lookups during deduplication check
CREATE INDEX IF NOT EXISTS idx_subscription_events_lookup
ON subscription_events(revenuecat_event_id)
WHERE revenuecat_event_id IS NOT NULL;

COMMENT ON COLUMN subscription_events.revenuecat_event_id IS 'RevenueCat webhook event ID for idempotency/deduplication';
