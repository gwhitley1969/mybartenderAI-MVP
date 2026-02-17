# Subscription Tier Refactor — Prompt Guide

## Overview

These four prompts replace the old Free / Premium / Pro tier model in My AI Bartender with a single `paid` entitlement, add voice minutes tracking with consumable add-on packs, and update all documentation.

## How to use

Run each phase as a **separate Claude Code conversation**. Review the output of each phase before starting the next.

### Phase 1: Discovery (read-only)

**File:** `Phase1_Discovery.md`
**What it does:** Maps the entire codebase — finds where tiers are defined, checked, and enforced. No files are changed.
**Your action after:** Review the report. If anything surprises you (e.g., APIM is doing more than JWT validation, or tier logic is in an unexpected place), adjust Phases 2–3 before running them.

### Phase 2: Backend

**File:** `Phase2_Backend.md`
**What it does:** Updates the data model, writes migrations, updates quota enforcement, implements voice minutes tracking, and extends webhook handling.
**Your action after:** Review the migration SQL. Run it against a dev/test database first. Verify the APIM findings section. If APIM needs changes, handle them manually before Phase 3.

### Phase 3: Mobile App

**File:** `Phase3_Mobile.md`
**What it does:** Updates RevenueCat integration, redesigns the paywall, refactors feature gating, adds voice minutes display and upsell flow.
**Your action after:** Test the app against the updated backend. Verify paywall renders correctly, purchases work in sandbox, and voice minutes decrement properly.

### Phase 4: Documentation

**File:** `Phase4_Docs.md`
**What it does:** Updates all docs to match what was actually implemented. Documents the new model, removes old tier references.
**Your action after:** Read through the updated docs for accuracy.

## Manual steps you'll need to do yourself

These cannot be done by Claude Code:

1. **RevenueCat dashboard:** Create the `paid` entitlement, configure monthly/annual products, add the `voice_minutes_60` consumable product, set up webhook endpoint URL.

2. **App Store Connect:** Create the monthly subscription product with 3-day free trial, annual subscription product, and `voice_minutes_60` consumable IAP. Set pricing.

3. **Google Play Console:** Same as above for Android.

4. **Database migration:** Review and run the migration SQL against your PostgreSQL instance.

5. **APIM (if needed):** Based on Phase 2 findings, make any APIM policy adjustments manually.

## Key decisions baked into these prompts

If you want to change any of these, edit the prompts BEFORE running them:

| Decision                     | Current value                  | Where to change                          |
| ---------------------------- | ------------------------------ | ---------------------------------------- |
| Entitlement ID               | `paid`                         | Phase 2 & 3                              |
| Included voice minutes       | 60 per 30-day cycle            | Phase 2                                  |
| Voice add-on price           | $4.99 for 60 min               | Phase 2 & 3                              |
| Consume order                | Included first, then purchased | Phase 2                                  |
| Non-subs can buy voice packs | No                             | Phase 2 & 3                              |
| User-facing label            | "Subscriber"                   | Phase 3                                  |
| Low-minutes threshold        | 5 minutes                      | Phase 3                                  |
| Monthly price                | $7.99                          | Phase 3                                  |
| Annual price                 | $79.99                         | Phase 3                                  |
| Trial duration               | 3 days                         | Phase 3 (configured in stores, not code) |
