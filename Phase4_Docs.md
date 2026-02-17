# Phase 4: Documentation Updates

You are Claude Code acting as a senior engineer on "My AI Bartender".

## Context

Phases 2 and 3 replaced the old Free / Premium / Pro tier model with a single `paid` entitlement, added voice minutes tracking with consumable add-on packs, and updated the mobile app accordingly. This phase updates all documentation to match what was actually implemented.

## Important: Document what IS, not what SHOULD BE

Read the actual code changes from Phases 2 and 3 before writing documentation. If any implementation detail differs from what was planned, document the implementation — not the plan.

## Task A: Update docs/SUBSCRIPTION_DEPLOYMENT.md

Rewrite this document to cover:

### Subscription model

- Single paid entitlement: `paid`
- Two billing options:
  - Monthly: $7.99/month with 3-day free trial (auto-converts unless canceled)
  - Annual: $79.99/year (no trial)
- Voice add-on: +60 minutes for $4.99 (consumable, repeatable)

### Entitlement values

- `paid`: Full access to all features (voice, scanner, AI concierge, higher quotas)
- `none`: Limited access, shown paywall for gated features

### Subscription states

- `trialing`: In 3-day free trial (same access as `active`)
- `active`: Paying subscriber
- `expired`: Subscription lapsed or canceled
- `none`: Never subscribed

### Voice minutes system

- 60 included minutes per 30-day billing cycle
- Metered on actual talk time (user + AI audio)
- Included minutes consumed first, then purchased balance
- Included minutes reset on renewal; purchased minutes carry over
- Add-on packs: +60 min for $4.99, consumable, requires `paid` entitlement

### Backend enforcement

- APIM validates JWT and routes requests
- Backend looks up user in PostgreSQL and enforces entitlement + quotas
- Server is source of truth for voice minute balances (client fetches, never writes)

### RevenueCat product mapping

- Entitlement ID: `paid`
- Monthly product: (use actual product ID from code)
- Annual product: (use actual product ID from code)
- Voice add-on: `voice_minutes_60`

### Backward compatibility

- `pro` → `paid`
- `premium` → `paid`
- `free` / `null` → `none`

### Webhook events handled

- Subscription renewal: resets included minutes, preserves purchased balance
- Consumable purchase: credits +60 minutes (idempotent via transaction ledger)
- Subscription expiration: sets entitlement to `none`

Remove all references to Free, Premium, and Pro tiers. Remove old pricing ($X.99 Premium, etc.) if present.

## Task B: Update README.md

Find and update sections that mention:

- Free / Premium / Pro tiers or tier-based feature gating
- Old pricing
- Subscription model description

Replace with the current single-entitlement model. Keep the README updates brief — point to SUBSCRIPTION_DEPLOYMENT.md for details.

## Task C: Update PRD.md

Find and update sections that mention:

- Free / Premium / Pro tiers
- Old pricing model
- Feature access by tier
- Voice minutes allocations (was 90 min in some docs, now 60 min included + purchasable add-ons)

Ensure the PRD reflects:

- Single paid subscription with trial + monthly + annual options
- Voice add-on consumable IAP
- Updated feature access model (paid vs. not paid)

## Task D: Update any other docs that mention tiers

Search all files in `docs/` for remaining references to `Free`, `Premium`, `Pro`, old pricing, or the old tier model. Update them to match the current implementation.

Files to check (at minimum):

- docs/ARCHITECTURE.md (if it exists)
- Any API documentation
- Any deployment guides

## Task E: Consistency check

After all updates, verify:

- No document references Free, Premium, or Pro as subscription tiers
- Voice minutes are consistently described as 60/cycle (not 90)
- All docs agree on pricing: $7.99/mo, $79.99/yr, $4.99 add-on
- APIM's role is consistently described (JWT validation + routing, backend enforces entitlements)
- No doc contradicts the actual code implementation

## Output format

After completing all changes, provide:

1. List of files modified (with summary of what changed in each)
2. Any inconsistencies found between docs and implementation (flag these for my review)
3. Confirmation that no remaining references to old tier model exist

## Constraints

- Do NOT modify any code files — this phase is documentation only.
- If you find a discrepancy between what was implemented and what was planned, document what was implemented and flag the discrepancy for my review.
- Keep documentation clear and concise. Avoid duplicating detailed information across multiple docs — use cross-references.
