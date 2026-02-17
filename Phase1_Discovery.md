# Phase 1: Subscription Model Discovery Report

## Context

We are replacing the old tier model (Free / Premium / Pro) with a single paid entitlement (Trial + Pro). This report maps the **current** codebase so we can make informed decisions about what to change.

---

## 1. Source of Truth for "Tier" Today

### Primary: `users.tier` column (PostgreSQL)

**File:** `infrastructure/database/schema.sql` — lines 100-111

```sql
CREATE TABLE IF NOT EXISTS users (
    ...
    tier VARCHAR(20) NOT NULL DEFAULT 'pro',  -- DEFAULT is 'pro' (beta mode)
    ...
    CONSTRAINT check_tier CHECK (tier IN ('free', 'premium', 'pro'))
);
```

- **Possible values:** `'free'`, `'premium'`, `'pro'`
- **Default for new users:** `'pro'` (beta testing mode — everyone gets Pro during beta)
- This is the **authoritative source** — every backend endpoint queries this column

### Secondary: `user_subscriptions` table (RevenueCat integration)

**File:** `backend/functions/migrations/007_subscriptions.sql` — lines 11-24

```sql
CREATE TABLE IF NOT EXISTS user_subscriptions (
    user_id UUID NOT NULL REFERENCES users(id),
    revenuecat_app_user_id VARCHAR(255) NOT NULL,
    tier VARCHAR(20) NOT NULL CHECK (tier IN ('premium', 'pro')),
    product_id VARCHAR(100) NOT NULL,  -- e.g., 'premium_monthly', 'pro_yearly'
    is_active BOOLEAN NOT NULL DEFAULT true,
    auto_renewing BOOLEAN DEFAULT true,
    expires_at TIMESTAMPTZ,
    cancel_reason VARCHAR(50),
    CONSTRAINT unique_user_subscription UNIQUE (user_id)
);
```

- Only stores `'premium'` or `'pro'` (no `'free'` — absence of a record = free)
- One active subscription per user (UNIQUE on user_id)

### Sync mechanism: Trigger

**File:** `backend/functions/migrations/007_subscriptions.sql` — lines 73-103

- Function `sync_user_tier_from_subscription()` fires on INSERT/UPDATE of `user_subscriptions`
- Priority logic: **Pro > Premium > Free** (picks highest active tier)
- Automatically updates `users.tier` to stay in sync

### Additional tables:
- **`subscription_events`** (007_subscriptions.sql, line 46) — audit log of all RevenueCat webhook events
- **`voice_addon_purchases`** (migration 006, lines 31-46) — tracks $4.99/20-min voice packs
- **`voice_sessions`** (schema.sql, lines 157-169) — tracks session metadata, duration, tokens
- **`usage_tracking`** (schema.sql, lines 140-154) — general usage tracking (feature_type: `ai_recommendation`, `voice_minutes`, `vision_scan`, `custom_recipe`)
- **`token_quotas`** — used by `pgTokenQuotaService.js` for AI chat token tracking

---

## 2. Backend Enforcement Logic

All quota enforcement queries `users.tier` from PostgreSQL. APIM does **not** enforce feature quotas — only rate limiting (calls/day).

### Tier quota definitions

**File:** `backend/functions/services/userService.js` — lines 20-42

```javascript
const TIER_QUOTAS = {
    free:    { tokensPerMonth: 10000,   scansPerMonth: 2,   voiceMinutesPerMonth: 0,  voiceEnabled: false },
    premium: { tokensPerMonth: 300000,  scansPerMonth: 30,  voiceMinutesPerMonth: 0,  voiceEnabled: false },
    pro:     { tokensPerMonth: 1000000, scansPerMonth: 100, voiceMinutesPerMonth: 60, voiceEnabled: true  }
};
```

> **NOTE:** These backend quotas don't match CLAUDE.md's stated business model. CLAUDE.md says Pro gets 30 scans, but backend enforces 100. CLAUDE.md says free trial gets 10 scans/3-days, but backend has 2 scans/month for free tier. Additionally, the documentation files (PRD.md, ARCHITECTURE.md, README.md) specify yet another set of values: premium=15 scans, pro=50 scans — creating a three-way mismatch.

### Chat (AI tokens) enforcement

**File:** `backend/functions/services/pgTokenQuotaService.js` — function `incrementAndCheck()` (lines 163-201)
- Queries `users.tier` via `getMonthlyCap()` which looks up `TIER_QUOTAS[tier].tokensPerMonth`
- Tracks cumulative usage in `token_quotas` table
- Throws `QuotaExceededError` when exceeded — client sees HTTP 429

### Scanner (Vision) enforcement

**File:** `backend/functions/vision-analyze/index.js` — lines 78-129
- Fetches `user.tier` → looks up `TIER_QUOTAS[tier].scansPerMonth`
- Queries `usage_tracking` table for current month's `vision_scan` count
- Returns 403 (tier has 0 scans) or 429 (quota exceeded)
- Records usage in `usage_tracking` after successful scan

### Voice enforcement

**File:** `backend/functions/index.js` — lines 2674-2763 (`/v1/voice/session` endpoint)
1. Checks `tier == 'pro'` (hard gate — only Pro can use voice)
2. Calls PostgreSQL function `check_voice_quota()` (migration 010, lines 280-329)
3. Quota: Pro = 3600 seconds (60 min), all other tiers = 0
4. Also checks `voice_addon_purchases` table for purchased add-on minutes

### Voice billing (server-authoritative)

**File:** `backend/functions/migrations/010_voice_metering_server_auth.sql` — function `record_voice_session()` (lines 42-138)
- Server computes wall-clock time from `started_at` timestamp
- Client reports active speech duration — used as **discount** (never trusted above server time)
- Anti-fraud: caps at 3600s, expires stale sessions after 2 hours

---

## 3. Mobile Gating Logic

### How the app gets user tier

**Hybrid approach:**
1. **RevenueCat** (primary for subscription state): `subscription_service.dart` + `subscription_provider.dart`
   - Checks entitlements from RevenueCat `CustomerInfo`
   - Real-time updates via stream -> `subscriptionStatusProvider`
2. **Backend** (secondary for quota enforcement): Backend endpoints return 429/403 when limits exceeded

### Key providers

**File:** `mobile/app/lib/src/providers/subscription_provider.dart`

| Provider | Line | Purpose |
|----------|------|---------|
| `subscriptionStatusProvider` | 15 | Stream of current status from RevenueCat |
| `isPremiumOrHigherProvider` | 37-44 | True if Premium or Pro |
| `isProSubscriberProvider` | 47-54 | True if Pro only |
| `currentTierProvider` | 57-64 | Returns `SubscriptionTier` enum |
| `shouldShowUpgradePromptProvider` | 170 | True if free tier and not processing |

### Feature gating by feature

| Feature | Gating Location | Method |
|---------|----------------|--------|
| **Voice AI** | `voice_ai_screen.dart:155-157` | Pre-check: `voiceState.requiresUpgrade` (from provider catching `VoiceAITierRequiredException`) |
| **Voice AI** | `voice_ai_service.dart:276-383` | Backend call: throws tier/quota exceptions at session start |
| **Smart Scanner** | `smart_scanner_screen.dart` | **No client-side gating** — relies on backend 429/403 |
| **AI Chat** | `chat_provider.dart:78-80` | **Reactive only** — shows upgrade message when backend returns 429 |

### Voice upgrade UI

**File:** `mobile/app/lib/src/features/voice_ai/voice_ai_screen.dart` — lines 246-340
- Different messaging for Premium vs Free users
- Two CTAs: "Upgrade to Pro" (subscription) + "Buy 20 Minutes - $4.99" (consumable)
- `_ProUpgradeSheet` (lines 416-628): bottom sheet with RevenueCat offerings

---

## 4. RevenueCat Integration

### SDK version

**File:** `mobile/app/pubspec.yaml` — line 83: `purchases_flutter: ^8.4.2`

### Entitlement IDs (must match RevenueCat dashboard)

**File:** `mobile/app/lib/src/services/subscription_service.dart` — lines 60-61

```dart
static const String _premiumEntitlement = 'premium';
static const String _proEntitlement = 'pro';
```

### Product IDs (must match Google Play / App Store / RevenueCat)

**File:** `mobile/app/lib/src/services/subscription_service.dart` — lines 64-69

```dart
static const Set<String> subscriptionProductIds = {
  'premium_monthly',
  'premium_yearly',
  'pro_monthly',
  'pro_yearly',
};
```

**File:** `mobile/app/lib/src/services/purchase_service.dart` — line 42

```dart
static const String voiceMinutesProductId = 'voice_minutes_20';  // $4.99 consumable
```

### API key handling

**File:** `subscription_service.dart` — lines 55-57, 84-121
- API key fetched from backend at runtime: `backendService.getSubscriptionConfig()`
- Stored in `_revenueCatApiKey` — **NOT hardcoded**
- Backend retrieves from Azure Key Vault (`REVENUECAT-PUBLIC-API-KEY`)

### Initialization flow

1. User authenticates -> gets JWT
2. App calls `initializeSubscriptionService(ref, userId)` (subscription_provider.dart:71-75)
3. Service calls backend `/v1/subscription/config` to get RevenueCat API key
4. Configures `Purchases.configure()` with API key + user's `azure_ad_sub` as appUserID
5. Listens for `CustomerInfo` updates via stream

### Paywall UI

**File:** `voice_ai_screen.dart` — `_ProUpgradeSheet` (lines 416-628)
- Fetches offerings from RevenueCat (lines 432-515)
- Displays Pro monthly and yearly packages
- "Save 17%" badge on yearly option
- Purchase flow via `_purchasePackage()` (lines 592-627)

### Restore purchases

**File:** `subscription_service.dart` — lines 214-232: `restorePurchases()` method
**File:** `subscription_provider.dart` — lines 120-139: `SubscriptionPurchaseNotifier.restorePurchases()`
- No dedicated "Restore" button found in UI (likely in Profile/Settings — not examined)

### Webhook handler (backend)

**File:** `backend/functions/index.js` — subscription webhook endpoint
- Receives RevenueCat webhook events
- Calls `upsert_subscription_from_webhook()` PostgreSQL function (007_subscriptions.sql:127-180)
- Uses `get_tier_from_product_id()` to extract tier from product ID pattern (`pro_%` -> `'pro'`)

---

## 5. APIM Configuration

### Products defined (old model)

**File:** `infrastructure/apim/configure-apim.ps1` — lines 74-102

| Product | Price | Rate Limit |
|---------|-------|------------|
| `free-tier` | $0 | 100 calls/day |
| `premium-tier` | $4.99/mo | 1,000 calls/day |
| `pro-tier` | $7.99/mo | 10,000 calls/day |

### Policy files (old model)

**Location:** `infrastructure/apim/policies/`

| File | Key behavior |
|------|-------------|
| `free-tier-policy.xml` | Blocks voice/vision endpoints entirely (403) |
| `premium-tier-policy.xml` | Full access, 30s timeout |
| `pro-tier-policy.xml` | Full access, 60s timeout, `X-Priority-User` header |
| Multiple `-fixed`, `-v2`, `-final` variants | Historical iterations |

### Current APIM role (actual behavior)

APIM is **NOT** used for quota enforcement. Its actual job:
1. **JWT validation** via `jwt-validation-entra-external-id.xml`
2. **Rate limiting** (calls/day as DDoS protection)
3. **Routing** to backend function app
4. **Security** (hides function URLs)

**All feature quotas are enforced by the backend** (PostgreSQL `users.tier` -> `TIER_QUOTAS`).

> **KEY FINDING:** The APIM tier products (`free-tier`, `premium-tier`, `pro-tier`) are **legacy artifacts**. They exist but the mobile app doesn't send APIM subscription keys — it uses JWT-only authentication. The tier-based policies may not even be actively applied.

---

## 6. Voice Minutes Tracking

### Infrastructure is fully built

| Table | Purpose | File |
|-------|---------|------|
| `voice_sessions` | Session metadata, duration, status | `schema.sql:157-169` |
| `voice_messages` | Conversation transcripts | `migration 006:11-27` |
| `voice_addon_purchases` | $4.99/20-min packs | `migration 006:31-46` |
| `usage_tracking` | General usage (feature_type = `voice_minutes`) | `schema.sql:140-154` |

### Session lifecycle

| Phase | Endpoint | Backend Location |
|-------|----------|-----------------|
| **Start** | `POST /v1/voice/session` | `index.js:2674` — checks Pro tier + quota -> inserts active session |
| **End** | `POST /v1/voice/usage` | `index.js:2992` — records billed duration via `record_voice_session()` |
| **Cleanup** | Timer | `expire_stale_voice_sessions()` — auto-closes sessions >2h old |

### Billing model (server-authoritative, fraud-resistant)

**File:** `backend/functions/migrations/010_voice_metering_server_auth.sql` — lines 42-138

- Wall-clock time computed from server-side `started_at` timestamp
- Client duration used as discount only (never exceeds server time)
- Fallback: 30% of wall-clock if client reports 0
- Hard cap: 3600 seconds (60 min) per session

### Quota check function

**File:** `migration 010:280-329` — `check_voice_quota(p_user_id)`

Returns: `has_quota`, `monthly_used_seconds`, `monthly_limit_seconds`, `addon_seconds_remaining`, `total_remaining_seconds`

- Pro tier: 3600s (60 min) monthly
- All other tiers: 0
- Add-on purchases from `voice_addon_purchases` are added on top (non-expiring)

---

## 7. Documentation Files

| File | Tier Model | Last Updated |
|------|-----------|--------------|
| `.claude/CLAUDE.md` | **NEW** (Trial + Pro only) | Feb 2026 |
| `docs/PRD.md` | OLD (Free/Premium/Pro) | Jan 2026 |
| `docs/ARCHITECTURE.md` | OLD (Free/Premium/Pro) | Feb 2026 |
| `docs/SUBSCRIPTION_DEPLOYMENT.md` | OLD (2-tier Premium+Pro) | Dec 2025 |
| `README.md` | OLD (Free/Premium/Pro) | ~Jan 2026 |
| `TEST_SUBSCRIPTION_LIMITS.md` | OLD (Free/Premium/Pro) | ~Jan 2026 |
| `Phase1_Discovery.md` | This report | Feb 2026 |

### Pricing inconsistencies across docs

| Source | Pro Monthly | Pro Annual | Premium Monthly | Premium Annual |
|--------|------------|------------|-----------------|----------------|
| CLAUDE.md | $7.99 | $79.99 | *(not listed)* | *(not listed)* |
| PRD.md | $7.99 | $79.99 | $4.99 | $39.99 |
| ARCHITECTURE.md | $7.99 | $79.99 | $4.99 | $39.99 |
| README.md | $7.99 | $79.99 | $4.99 | $39.99 |
| Migration 009 | $7.99 (reduced from $14.99) | $79.99 | -- | -- |
| Backend code (`userService.js:38`) | $7.99 (comment) | -- | -- | -- |
| DB view (`schema.sql:313`) | $7.99 | -- | $4.99 | -- |

> **CRITICAL CONFLICT:** CLAUDE.md says $7.99/mo and $79.99/yr. All other docs and code comments say $7.99/mo and $79.99/yr. The analytics view `monthly_tier_stats` uses $7.99 (matching CLAUDE.md), adding confusion about which is authoritative.

### Quota inconsistencies across docs vs backend

| Metric | CLAUDE.md | Docs (PRD/ARCH/README) | Backend Code |
|--------|-----------|------------------------|--------------|
| Free scans | 10 / 3 days | 2 / month | 2 / month |
| Premium scans | *(not listed)* | 15 / month | 30 / month |
| Pro scans | 30 / month | 50 / month | 100 / month |
| Free tokens | 100,000 / 3 days | 10,000 / month | 10,000 / month |
| Pro voice | 30 min / month | 60 min / month | 60 min / month |

---

## Surprises and Inconsistencies

### 1. TWO COMPETING PRICING MODELS
- **CLAUDE.md** (project instructions) describes: 3-day trial -> Pro ($7.99/mo or $79.99/yr), no Premium
- **All code, infrastructure, and other docs** implement: permanent Free tier + Premium ($4.99/mo) + Pro ($7.99/mo)
- The new model exists only in CLAUDE.md — no code changes have been made for it yet

### 2. THREE-WAY QUOTA MISMATCH
The CLAUDE.md business model, the documentation files, and the backend code all disagree on quota numbers. The backend code is the actual enforcement — documentation and CLAUDE.md are both stale/aspirational. See the quota comparison table in Section 7 above.

### 3. Premium tier is fully implemented but slated for removal
- DB constraint: `tier IN ('free', 'premium', 'pro')`
- `user_subscriptions` constraint: `tier IN ('premium', 'pro')`
- Backend: `TIER_QUOTAS.premium` fully defined
- Mobile: `SubscriptionTier.premium` enum, `_premiumEntitlement`, `isPremiumOrHigherProvider`
- 4 product IDs: `premium_monthly`, `premium_yearly`, `pro_monthly`, `pro_yearly`
- Voice UI: Different upgrade copy for Premium vs Free users
- Removing Premium touches many files across backend, mobile, infrastructure, and docs

### 4. APIM tier products are likely unused
- Mobile app authenticates with JWT only (no APIM subscription keys)
- APIM products (`free-tier`, `premium-tier`, `pro-tier`) exist but may not be active
- All real quota enforcement happens in backend PostgreSQL

### 5. Default tier is 'pro' (beta mode)
- `schema.sql:106`: `DEFAULT 'pro'` — all new users get Pro during beta
- `userService.js:115`: `INSERT ... VALUES ($1, 'pro', ...)` — hardcoded in code too
- This needs to change before launch (should default to `'free'` or trigger trial logic)

### 6. No trial infrastructure exists
- CLAUDE.md says "3-Day Free Trial" but there's no trial tracking in the database
- No `trial_start_date`, `trial_end_date`, or trial-specific quota logic
- The 3-day trial likely needs to be a RevenueCat free trial offer (store-level), not custom backend logic

### 7. Voice minutes: 30 vs 60
- CLAUDE.md says 30 min/month for Pro
- Migration 009 explicitly changed to 60 min/month
- Backend `check_voice_quota()` enforces 60 min (3600s)
- This needs a business decision on the correct value

### 8. Platform-specific API key delivery unresolved
- RevenueCat gives separate API keys per platform (`goog_xxx`, `appl_xxx`)
- Backend has single `REVENUECAT-PUBLIC-API-KEY` in Key Vault
- `/v1/subscription/config` endpoint returns one key — no platform detection logic exists

---

*Report generated: February 2026*
*Status: Read-only discovery — no code changes made*
