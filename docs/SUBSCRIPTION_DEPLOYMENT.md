# Subscription System — Deployment Documentation

## Overview

MyBartenderAI uses a **single binary entitlement model**: users are either `paid` (subscribers) or `none` (non-subscribers). Subscriptions are managed through **RevenueCat**, which handles Google Play and App Store billing, webhook lifecycle events, and cross-platform purchase restoration.

Voice minute consumables ($4.99 for 60 minutes) are handled per-platform:
- **Android**: Google Play Billing with server-side verification through the `voice-purchase` function
- **iOS**: RevenueCat SDK handles StoreKit purchase; the `subscription-webhook` function credits minutes via webhook event

---

## Subscription Model

### Entitlement Values

| Entitlement | Access Level |
|-------------|-------------|
| `paid` | Full access: AI concierge (1M tokens/mo), Smart Scanner (100 scans/mo), Voice AI (60 min/mo), unlimited custom recipes |
| `none` | Local cocktail database only. Paywall shown for gated features |

### Subscription States

| Status | Description |
|--------|-------------|
| `trialing` | In 3-day free trial (reduced quotas: 20K tokens, 5 scans, 10 voice min) |
| `active` | Paying subscriber |
| `expired` | Subscription lapsed or canceled |
| `none` | Never subscribed |

### Billing Options

| Option | Price | Trial |
|--------|-------|-------|
| Monthly | $7.99/month | 3-day free trial (auto-converts unless canceled) |
| Annual | $79.99/year | No trial |

### Voice Minutes System

- **60 included minutes** per 30-day billing cycle
- Metered on **active talk time** (user + AI audio; idle time excluded)
- **Deduction order**: included minutes consumed first, then purchased balance
- Included minutes reset on subscription renewal; **purchased minutes carry over** indefinitely
- **Add-on packs**: +60 minutes for $4.99, consumable, repeatable, requires `paid` entitlement

### Backward Compatibility

The `users.tier` column is preserved for backward compatibility. The sync trigger maps:

| Old Tier | New Entitlement |
|----------|----------------|
| `pro` | `paid` |
| `premium` | `paid` |
| `free` / `null` | `none` |

---

## Architecture

```
Mobile App (Flutter)
    |
    | 1. On login, fetch RevenueCat API key from backend
    |    GET /v1/subscription/config
    v
Azure API Management (apim-mba-002)
    | - JWT validation via validate-jwt policy
    | - Extracts user ID to x-user-id header
    v
Azure Functions (func-mba-fresh)
    |
    | subscription-config:
    |   - Reads REVENUECAT_PUBLIC_API_KEY (Android) from env
    |   - Reads REVENUECAT_PUBLIC_API_KEY_IOS (Apple) from env
    |   - Key Vault references resolve to actual keys
    |   - Returns both API keys to mobile app
    v
Mobile App selects key via Platform.isIOS
    |
    | Initializes RevenueCat SDK with platform-specific key
    |
    | 2. User makes purchase via Google Play / App Store
    v
RevenueCat (handles platform billing)
    |
    | 3. Webhook notification on subscription events
    |    POST /v1/subscription/webhook
    v
Azure Functions (func-mba-fresh)
    |
    | subscription-webhook:
    |   - Verifies RevenueCat Bearer token auth
    |   - Checks idempotency via event ID
    |   - Updates user_subscriptions table
    |   - Database trigger syncs users.tier + users.entitlement
    v
PostgreSQL (pg-mybartenderdb)
    |
    | users.entitlement now reflects subscription status
    | All entitlement-based quota checks use this column
```

### Backend Enforcement

- **APIM** validates JWT and routes requests to backend functions
- **Backend functions** look up user in PostgreSQL and enforce entitlement + quotas
- **Server is source of truth** for voice minute balances (client fetches via `GET /v1/voice/quota`, never writes)
- Voice quota uses `get_remaining_voice_minutes()` PostgreSQL function (O(1) column reads, no aggregation)

---

## Database Schema

### Migration: 011_subscription_entitlement_model.sql

**Columns added to `users` table:**

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `entitlement` | TEXT | `'none'` | `'paid'` or `'none'` |
| `subscription_status` | TEXT | `'none'` | `'trialing'`, `'active'`, `'expired'`, `'none'` |
| `billing_interval` | TEXT | NULL | `'monthly'`, `'annual'`, or NULL |
| `monthly_voice_minutes_included` | INTEGER | 60 | Monthly voice allotment |
| `voice_minutes_used_this_cycle` | NUMERIC(8,2) | 0 | Minutes used this billing cycle |
| `voice_minutes_purchased_balance` | NUMERIC(8,2) | 0 | Purchased minutes remaining (never expire) |
| `voice_cycle_started_at` | TIMESTAMPTZ | NULL | Start of current billing cycle |

**Tables:**

- `user_subscriptions` — Current subscription state per user (one row per user)
- `subscription_events` — Audit log of all webhook events (includes raw payload)
- `voice_purchase_transactions` — Idempotent tracking for voice minute purchases (minutes-based)

**PostgreSQL Functions:**

| Function | Purpose |
|----------|---------|
| `get_remaining_voice_minutes(user_id)` | O(1) column-based quota read. Returns `included_remaining`, `purchased_remaining`, `total_remaining`, `monthly_included`, `used_this_cycle`, `entitlement` |
| `consume_voice_minutes(user_id, minutes)` | Deducts from included first, then purchased. Atomic with row-level lock |
| `check_voice_quota_v2(user_id)` | Returns `has_quota` boolean + breakdown. Used by voice-session endpoint |

**Sync Trigger:**

`sync_user_tier_from_subscription()` fires on `user_subscriptions` changes and updates both `users.tier` (backward compat) and `users.entitlement` + `users.subscription_status`.

---

## Backend Functions

### 1. subscription-config

| Field | Value |
|-------|-------|
| Route | `GET /api/v1/subscription/config` |
| Auth | JWT required |
| Purpose | Returns RevenueCat API keys for SDK initialization (both platforms) |

**Response:**
```json
{
  "success": true,
  "config": {
    "revenueCatApiKey": "goog_xxxxx...",
    "revenueCatAppleApiKey": "appl_xxxxx..."
  }
}
```

**Notes:**
- `revenueCatApiKey` is the Android (Google Play) key
- `revenueCatAppleApiKey` is the iOS (App Store) key — may be `null` if not yet configured
- Flutter app selects the correct key at runtime via `Platform.isIOS`

### 2. subscription-webhook

| Field | Value |
|-------|-------|
| Route | `POST /api/v1/subscription/webhook` |
| Auth | Bearer token (NOT JWT) — verified against `REVENUECAT_WEBHOOK_SECRET` |
| Purpose | Receives RevenueCat server-to-server notifications |

**Events Handled:**

| Event | Action |
|-------|--------|
| `INITIAL_PURCHASE` | Activate subscription, set `entitlement = 'paid'` |
| `RENEWAL` | Extend subscription, reset voice cycle, update expiry |
| `CANCELLATION` | Keep active until expiry, set autoRenewing=false |
| `EXPIRATION` | Set `entitlement = 'none'`, `subscription_status = 'expired'` |
| `BILLING_ISSUE` | Check grace period; keep active if in grace |
| `PRODUCT_CHANGE` | Update tier/product based on new product |
| `UNCANCELLATION` | Reactivate auto-renewal |
| `SUBSCRIPTION_PAUSED` | Deactivate but retain renewal intent |
| `NON_RENEWING_PURCHASE` | Credit +60 voice minutes (consumable pack, idempotent via `voice_purchase_transactions`) |

**Key Features:**
- **Idempotency**: Each event has unique `event.id` stored in `subscription_events.revenuecat_event_id`
- **Grace period handling**: BILLING_ISSUE respects `grace_period_expires_date_ms`
- **Auto-create user on race condition** (SUB-005 fix, Feb 27): If the webhook arrives before the mobile app's first API call creates the user, the webhook auto-creates a minimal user record using `azure_ad_sub` from `app_user_id` and `$email`/`$displayName` from `subscriber_attributes`. Handles concurrent INSERT via `23505` unique constraint catch + retry lookup. See `BUG_FIXES.md` SUB-005
- **Sandbox filtering**: Currently **DISABLED** for end-to-end testing (sandbox events ARE processed). Re-enable before production launch by uncommenting the early-return block in `index.js:3855-3863`

### 3. subscription-status

| Field | Value |
|-------|-------|
| Route | `GET /api/v1/subscription/status` |
| Auth | JWT required |
| Purpose | Returns current subscription status for a user |

**Response:**
```json
{
  "success": true,
  "subscription": {
    "tier": "pro",
    "productId": "pro_monthly",
    "isActive": true,
    "autoRenewing": true,
    "expiresAt": "2026-03-23T00:00:00Z",
    "cancelReason": null
  },
  "currentTier": "pro",
  "entitlement": "paid"
}
```

**Notes:**
- `entitlement` is at the top level (not inside `subscription`)
- `subscription` contains data from the `user_subscriptions` table
- If user has no subscription record, defaults to `tier: 'free'`, `is_active: false`

---

## RevenueCat Product Mapping

| Item | Google Play Product ID | App Store Product ID |
|------|----------------------|---------------------|
| Entitlement ID | `paid` | `paid` |
| Monthly subscription | `pro_monthly` (base plan: `monthly-id`) | `pro_monthly` |
| Annual subscription | `pro_annual` (base plan: `annual-id`) | `pro_annual` |
| Voice add-on (consumable) | `voice_minutes_60` | `voice_minutes_60` |

**RevenueCat Offerings:**
- Default offering with `$rc_monthly` and `$rc_annual` packages
- Each package attaches both the Google Play and App Store product

The mobile app fetches available offerings dynamically from RevenueCat — subscription product IDs are not hardcoded. Voice consumable product ID (`voice_minutes_60`) is hardcoded in `PurchaseService`.

---

## Flutter/Mobile Implementation

### Subscription Service (`subscription_service.dart`)

- `SubscriptionStatus` model: `isPaid` boolean + `subscriptionStatus` string
- Single entitlement check: `_paidEntitlement = 'paid'`
- `_parseCustomerInfo()` checks `info.entitlements.active['paid']`
- Detects trial via `PeriodType.trial`
- **Entra sub-based App User ID**: Anonymous `Purchases.configure()` + `Purchases.logIn(userId)` where `userId` is the Entra `sub` claim (always available, opaque). `Purchases.setEmail(email)` sets `$email` subscriber attribute for dashboard search. No email dependency — ALL users can subscribe
- **`logout()` resets `_isInitialized`**: Enables clean re-initialization after sign-out/re-sign-in with a different account

### Subscription Providers (`subscription_provider.dart`)

| Provider | Type | Purpose |
|----------|------|---------|
| `isPaidProvider` | `Provider<bool>` | Whether user has active subscription |
| `subscriptionStatusStringProvider` | `Provider<String>` | Status string (trialing/active/expired/none) |
| `shouldShowUpgradePromptProvider` | `Provider<bool>` | True if not paid and not processing |
| `subscriptionPurchaseNotifierProvider` | `StateNotifierProvider` | Purchase flow state management |

### Lazy RevenueCat Initialization (`subscription_sheet.dart`)

The subscription sheet includes `_attemptLazyInit()` for cases where RevenueCat wasn't initialized at login (e.g., transient network failure). It passes `user.id` (Entra sub — always available) with optional `email` and `displayName` for subscriber attributes:
- No email validation guard needed — `user.id` is always present
- Google-federated users can now reach subscription offerings (previously blocked)
- On success, invalidates `subscriptionOfferingsProvider` and `subscriptionStatusProvider`

### Pre-Navigation Paywall Gate (`subscription_sheet.dart`)

The `navigateOrGate()` helper gates AI feature buttons at the UI layer. It uses a 3-step check with increasing latency:

1. **`isPaidProvider` via `ref.read()`** — cached Riverpod state (instant, no network)
2. **Fresh RevenueCat SDK `getStatus()`** — reads SDK local cache directly, bypasses lazy stream provider init race (~1-5ms). Only runs if step 1 returned `false`. On success, invalidates `subscriptionStatusProvider` so future taps use the fast path
3. **`backendEntitlementProvider` await** — PostgreSQL authoritative source, handles manual DB overrides and webhook timing. Only runs if steps 1-2 both returned not-paid

```dart
Future<void> navigateOrGate({
  required BuildContext context,
  required WidgetRef ref,
  required VoidCallback navigate,
}) async {
  // Step 1: Cached provider (instant)
  final isPaid = ref.read(isPaidProvider);
  if (isPaid) { navigate(); return; }

  // Step 2: Fresh SDK check (bypasses lazy provider init race)
  final service = ref.read(subscriptionServiceProvider);
  if (service.isInitialized) {
    final freshStatus = await service.getStatus();
    if (freshStatus.isPaid) {
      ref.invalidate(subscriptionStatusProvider);
      navigate(); return;
    }
  }

  // Step 3: Backend entitlement (PostgreSQL authoritative)
  // ... await backendEntitlementProvider if loading ...

  // All checks failed → show paywall
  showSubscriptionSheet(context, ...);
}
```

**Gated buttons (11 total):**
- Home screen: Scan My Bar, Chat, Voice (NOT Create — Create Studio is free)
- Recipe Vault screen: Chat, Voice
- Academy screen: Chat CTA, Voice CTA
- Pro Tools screen: Chat CTA, Voice CTA
- My Bar screen: AppBar scanner icon, empty-state Scanner button

**4-layer paywall defense:**
1. **Pre-navigation gate** (`navigateOrGate`): Prevents navigation to AI screens for free users. Includes fresh SDK check to handle lazy provider init race (Feb 27 fix)
2. **Profile screen dual-source check**: `isPaidProvider` (RevenueCat + backend) displayed in subscription card
3. **Per-screen handlers**: `EntitlementRequiredException` catch blocks show paywall if user reaches screen
4. **Backend enforcement**: 403 `entitlement_required` response from Azure Functions

**Diagnostic logging** (`developer.log` with `name: 'Subscription'`):
- `isPaidProvider`: Logs RevenueCat result, backend entitlement value, loading/error states
- `navigateOrGate`: Logs `isPaid` value, backend async state, paywall trigger
- `backendEntitlementProvider`: Logs fetched entitlement or error
- On-device: `adb logcat | grep -i Subscription`

### Purchase Service (`purchase_service.dart`)

- Product ID: `voice_minutes_60` (hardcoded constant)
- **Android**: Uses `in_app_purchase` plugin → Google Play Billing → backend verification via `POST /v1/voice/purchase`
- **iOS**: Uses RevenueCat SDK (`Purchases.purchaseStoreProduct()`) → StoreKit → RevenueCat webhook → `subscription-webhook` credits 60 minutes
- `onVerifyPurchase` callback is `null` on iOS (RevenueCat handles validation)
- iOS quota refresh: listens to `purchaseStream` and invalidates `voiceQuotaProvider` 2 seconds after success

### Voice Quota Model (`voice_ai_service.dart`)

```dart
class VoiceQuota {
  final bool hasAccess;        // paid entitlement
  final bool hasQuota;         // remaining minutes > 0
  final String entitlement;    // 'paid' or 'none'
  final double remainingMinutes;
  final double includedRemaining;
  final double purchasedRemaining;
  final int monthlyIncluded;   // 60
  final double usedThisCycle;
  final int percentUsed;
}
```

---

## APIM Configuration

| Operation | Method | Route | Auth | Notes |
|-----------|--------|-------|------|-------|
| `subscription-config` | GET | `/api/v1/subscription/config` | JWT | Returns API key |
| `subscription-webhook` | POST | `/api/v1/subscription/webhook` | Bearer token | RevenueCat webhook |
| `subscription-status` | GET | `/api/v1/subscription/status` | JWT | User status |

- `subscription-webhook` does NOT use JWT validation (RevenueCat doesn't send JWT)
- Authentication is via `Authorization: Bearer <secret>` header sent by RevenueCat, verified against `REVENUECAT_WEBHOOK_SECRET`

---

## Azure Key Vault Configuration

### Secrets

| Secret Name | Purpose |
|-------------|---------|
| `REVENUECAT-PUBLIC-API-KEY` | RevenueCat Android API key (`goog_...`) |
| `REVENUECAT-APPLE-API-KEY` | RevenueCat iOS API key (`appl_...`) |
| `REVENUECAT-WEBHOOK-SECRET` | Webhook signature verification |

### Function App Settings

| Setting | Value |
|---------|-------|
| `REVENUECAT_PUBLIC_API_KEY` | `@Microsoft.KeyVault(VaultName=kv-mybartenderai-prod;SecretName=REVENUECAT-PUBLIC-API-KEY)` |
| `REVENUECAT_PUBLIC_API_KEY_IOS` | `@Microsoft.KeyVault(VaultName=kv-mybartenderai-prod;SecretName=REVENUECAT-APPLE-API-KEY)` |
| `REVENUECAT_WEBHOOK_SECRET` | `@Microsoft.KeyVault(VaultName=kv-mybartenderai-prod;SecretName=REVENUECAT-WEBHOOK-SECRET)` |

---

## Security Considerations

1. **Remote Configuration**: RevenueCat public API key fetched from backend at runtime (key rotation without app update)
2. **Key Vault Storage**: All secrets stored in Azure Key Vault with Managed Identity access
3. **Webhook Verification**: RevenueCat webhooks verified via Bearer token auth
4. **JWT Validation**: All user-facing endpoints validate Entra External ID JWT
5. **Server-Side Enforcement**: Voice minute balances maintained server-side; client can only read, never write
6. **Idempotent Processing**: All purchase and webhook operations are idempotent via unique transaction/event IDs

---

## Entra Sub-Based App User ID (Feb 26, 2026)

RevenueCat uses the user's **Entra `sub` claim** (opaque GUID) as the App User ID. Email is set as the `$email` subscriber attribute for dashboard searchability via Ctrl+K. This follows RevenueCat's documented best practice: *"We don't recommend using email addresses as App User IDs."*

### How It Works

**RevenueCat initialization** (`subscription_service.dart`):
1. `Purchases.configure(PurchasesConfiguration(apiKey))` — anonymous (no `appUserID`)
2. `Purchases.logIn(userId)` — identifies user by Entra sub (always available)
3. `Purchases.setEmail(email)` — sets `$email` subscriber attribute when email is available
4. `Purchases.setDisplayName(name)` — sets `$displayName` subscriber attribute

**Why Entra sub, not email**: Email extraction fails for Google-federated CIAM users (all 6 layers return empty). Using the Entra sub ensures ALL users can subscribe. Email is still valuable for dashboard searchability — that's handled by the `$email` subscriber attribute, which RevenueCat's Ctrl+K search indexes.

**Email retrieval** (for `$email` attribute): The Flutter app's 6-layer email extraction chain populates `user.email` when possible. This is passed as an optional parameter to `initialize()` and set via `Purchases.setEmail()`. If email is unavailable (Google-federated users), RevenueCat init still succeeds — the `$email` attribute is simply not set.

### Backend Webhook Lookup

The `subscription-webhook` function looks up users by `azure_ad_sub` using **case-insensitive** comparison:

- `app_user_id` is always the Entra sub → `WHERE LOWER(azure_ad_sub) = LOWER($1)`
- **Critical**: RevenueCat normalizes App User IDs to **lowercase** when sending webhook events, but Entra `sub` claims contain mixed case (base64url encoding). Case-insensitive lookup is required to match. See `BUG_FIXES.md` SUB-004 for the full root cause analysis
- The email lookup path (`WHERE LOWER(email)`) remains for backward compatibility but is unused for new events
- ALL `azure_ad_sub` lookups across the backend use `LOWER()` (10 locations in 3 files) for consistency

**Database indexes**:
- `idx_users_email_lower` on `users(LOWER(email))` — efficient case-insensitive email lookups
- `idx_users_azure_ad_sub_lower` on `users(LOWER(azure_ad_sub))` — efficient case-insensitive sub lookups (added Feb 27, 2026)

**Migration file**: `backend/functions/migrations/012_email_lookup_index.sql`

### Guard Clauses

RevenueCat initialization is skipped (user gets free tier) if:
- `userId` (Entra sub) is empty — should never happen, but guarded defensively

Email is NOT required for initialization. The `$email` subscriber attribute is set only when a valid email is available (non-empty, contains `@`, not a `mybartenderai.onmicrosoft.com` UPN).

---

## Manual Configuration Steps

### 1. RevenueCat Dashboard

- ✅ Create project "MyBartenderAI"
- ✅ Add Google Play app with package name: `ai.mybartender.mybartenderai`
- ✅ Add iOS app with bundle ID: `com.mybartenderai.mybartenderai`
- ✅ Create entitlement: `paid`
- Remaining: Map store products, configure offerings, verify webhook (see `REVENUECAT_PLAN.md` Phase 3)

### 2. Google Play Console

- Create subscription `pro_monthly` ($7.99/mo, base plan `monthly-id`)
- Create subscription `pro_annual` ($79.99/yr, base plan `annual-id`)
- Create consumable product `voice_minutes_60` at $4.99
- See `REVENUECAT_PLAN.md` Phase 1 for step-by-step

### 3. App Store Connect

- ✅ Subscription `pro_monthly` created
- ✅ Subscription `pro_annual` created
- Create consumable `voice_minutes_60` at $4.99
- See `REVENUECAT_PLAN.md` Phase 2 for step-by-step

### 4. Configure Webhook

- URL: `https://apim-mba-002.azure-api.net/api/v1/subscription/webhook`
- Enable all subscription lifecycle events
- Copy webhook secret to Key Vault

### 5. Update Key Vault Secrets

```powershell
# Android key (already done)
az keyvault secret set --vault-name kv-mybartenderai-prod --name REVENUECAT-PUBLIC-API-KEY --value "goog_xxxxx"
# iOS key (already done)
az keyvault secret set --vault-name kv-mybartenderai-prod --name REVENUECAT-APPLE-API-KEY --value "appl_xxxxx"
# Webhook secret
az keyvault secret set --vault-name kv-mybartenderai-prod --name REVENUECAT-WEBHOOK-SECRET --value "YOUR_WEBHOOK_SECRET"
```

### 6. Restart Function App

```powershell
az functionapp restart --name func-mba-fresh --resource-group rg-mba-prod
```

---

## Testing

### Sandbox Testing

1. RevenueCat provides sandbox mode for free test purchases
2. Add tester emails in Google Play Console
3. RevenueCat dashboard shows all test transactions

### Test Scenarios — Android

- [x] New subscription purchase (monthly with trial) — verified Feb 25
- [x] New subscription purchase (annual) — verified Feb 25 (Wild Heels)
- [ ] Trial expiration → paid conversion
- [ ] Subscription renewal (voice cycle reset)
- [ ] Cancellation (verify still active until expiry)
- [ ] Expiration (verify entitlement reverts to `none`)
- [ ] Restore purchases on new device
- [ ] Voice add-on purchase via Google Play (+60 minutes credited via `voice-purchase` endpoint)
- [ ] Duplicate purchase token (idempotent handling)

### Test Scenarios — iOS

- [x] Subscription init logs "iOS API key retrieved" — verified Feb 27
- [x] New subscription purchase (annual) — verified Feb 27 (Paul, sandbox)
- [x] New subscription purchase (trial) — verified Feb 27 (sandbox)
- [x] Webhook auto-creates user on race condition — verified Feb 27 (SUB-005)
- [ ] Subscription renewal
- [ ] Restore purchases on new device
- [ ] Voice add-on purchase via RevenueCat SDK (+60 minutes credited via webhook)
- [ ] Verify `voiceQuotaProvider` refreshes after purchase success

---

## Troubleshooting

### Key Vault Reference Not Resolving

- Verify Function App has "Key Vault Secrets User" role on `kv-mybartenderai-prod`
- Check Application Insights for Key Vault access errors
- Ensure secret name matches exactly (case-sensitive)

### Webhook Not Receiving Events

- Verify webhook URL in RevenueCat dashboard
- Check that APIM operation exists for `/v1/subscription/webhook`
- Verify Front Door is routing to APIM correctly

### Subscription Status Not Updating

- Check webhook function logs in Application Insights
- Verify database trigger: `SELECT * FROM pg_trigger WHERE tgname = 'trigger_sync_user_tier';`
- Check `subscription_events` table for recent entries
- Verify `users.entitlement` column reflects expected state
- Check for `user_id = NULL` in `subscription_events` — indicates webhook couldn't find the user (race condition or case mismatch). The SUB-005 auto-create fix should prevent this going forward, but if it recurs, manually link the event and update the user's entitlement (see `BUG_FIXES.md` SUB-005)

### Webhook Race Condition (User Not Found)

If `subscription_events` has a row with `user_id = NULL`:
1. The webhook arrived before `getOrCreateUser()` created the user record
2. As of SUB-005 fix (Feb 27), the webhook auto-creates the user — this should not recur
3. If it does, manually fix: find the user by `azure_ad_sub`, UPDATE their entitlement, and link the orphaned event:
```sql
-- Find the user
SELECT id, azure_ad_sub FROM users WHERE LOWER(azure_ad_sub) = LOWER('THE_APP_USER_ID');
-- Update entitlement
UPDATE users SET entitlement = 'paid', subscription_status = 'active', tier = 'pro' WHERE id = 'USER_UUID';
-- Link orphaned event
UPDATE subscription_events SET user_id = 'USER_UUID' WHERE user_id IS NULL AND revenuecat_app_user_id = 'THE_APP_USER_ID';
```

---

## Related Documentation

- [RevenueCat Documentation](https://docs.revenuecat.com/)
- [Google Play Billing](https://developer.android.com/google/play/billing)
- [Azure Key Vault References](https://docs.microsoft.com/en-us/azure/app-service/app-service-key-vault-references)
- `ARCHITECTURE.md` — Overall system architecture
- `REVENUECAT_PLAN.md` — Cross-platform RevenueCat setup checklist (store products, dashboard config, code changes)
- `GOOGLE_PLAY_BILLING_SETUP.md` — Google Play service account setup for voice purchase verification
- `CLAUDE.md` — Project context and conventions

---

*Last Updated: February 27, 2026*
*Implementation Status: Backend + Mobile code complete for both platforms. iOS sandbox subscription testing verified (annual + trial purchases). Webhook auto-creates user records on race condition (SUB-005 fix). Pre-navigation paywall gates implemented on 11 AI feature buttons across 6 screens with fresh SDK check to handle lazy provider init race. Profile screen uses dual-source subscription check. Diagnostic logging enabled for on-device troubleshooting. Entra sub-based RevenueCat App User ID deployed (Graph API + dual-lookup webhook). All `azure_ad_sub` lookups use case-insensitive `LOWER()` comparison (SUB-004 fix). App Store products show "Ready to Submit" in RevenueCat — normal for pre-submission; sandbox purchases work correctly.*
