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
| `trialing` | In 3-day free trial (same access as `active`) |
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
| Auth | RevenueCat signature (NOT JWT) |
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
- **Sandbox filtering**: Production webhook ignores `environment: 'SANDBOX'` events

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
    "entitlement": "paid",
    "subscriptionStatus": "active",
    "isActive": true,
    "expiresAt": "2026-03-23T00:00:00Z"
  }
}
```

---

## RevenueCat Product Mapping

| Item | Google Play Product ID | App Store Product ID |
|------|----------------------|---------------------|
| Entitlement ID | `paid` | `paid` |
| Monthly subscription | `pro_monthly` (base plan: `monthly-autorenewing`) | `pro_monthly` |
| Annual subscription | `pro_annual` (base plan: `annual-autorenewing`) | `pro_annual` |
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

### Subscription Providers (`subscription_provider.dart`)

| Provider | Type | Purpose |
|----------|------|---------|
| `isPaidProvider` | `Provider<bool>` | Whether user has active subscription |
| `subscriptionStatusStringProvider` | `Provider<String>` | Status string (trialing/active/expired/none) |
| `shouldShowUpgradePromptProvider` | `Provider<bool>` | True if not paid and not processing |
| `subscriptionPurchaseNotifierProvider` | `StateNotifierProvider` | Purchase flow state management |

### Pre-Navigation Paywall Gate (`subscription_sheet.dart`)

The `navigateOrGate()` helper gates AI feature buttons at the UI layer. It checks `isPaidProvider` via `ref.read()` at tap time (not `ref.watch()` — avoids rebuilds since buttons don't change appearance for free vs paid users).

```dart
void navigateOrGate({
  required BuildContext context,
  required WidgetRef ref,
  required VoidCallback navigate,
}) {
  final isPaid = ref.read(isPaidProvider);
  if (isPaid) {
    navigate();
  } else {
    showSubscriptionSheet(context, onPurchaseComplete: () {
      ref.invalidate(subscriptionStatusProvider);
    });
  }
}
```

**Gated buttons (11 total):**
- Home screen: Scan My Bar, Chat, Voice (NOT Create — Create Studio is free)
- Recipe Vault screen: Chat, Voice
- Academy screen: Chat CTA, Voice CTA
- Pro Tools screen: Chat CTA, Voice CTA
- My Bar screen: AppBar scanner icon, empty-state Scanner button

**4-layer paywall defense:**
1. **Pre-navigation gate** (`navigateOrGate`): Prevents navigation to AI screens for free users
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

## Email-Based App User ID (Feb 26, 2026)

RevenueCat now uses the user's **real email address** as the App User ID, enabling customer lookup by email in the RevenueCat dashboard.

### How It Works

**Email retrieval**: Entra External ID (CIAM) tokens do not include email claims even when configured as optional claims. The Flutter app calls Microsoft Graph API `GET /me` during sign-in to fetch the real email.

**RevenueCat initialization** (`subscription_service.dart`):
1. `Purchases.configure(PurchasesConfiguration(apiKey))` — anonymous (no `appUserID`)
2. `Purchases.logIn(normalizedEmail)` — identifies user by email
3. `Purchases.setEmail(email)` + `Purchases.setDisplayName(name)` — subscriber attributes

**Why `logIn()` instead of `appUserID` in configure**: `logIn()` triggers RevenueCat's Transfer Behavior, which automatically migrates existing subscribers' purchase history from the old sub-based ID to the new email-based ID.

### Backend Webhook Dual-Lookup

The `subscription-webhook` function handles both email-based and legacy `azure_ad_sub`-based App User IDs:

- If `app_user_id` contains `@` and doesn't end with `mybartenderai.onmicrosoft.com` → email lookup: `WHERE LOWER(email) = LOWER($1)`
- Otherwise → legacy lookup: `WHERE azure_ad_sub = $1`

**Database index**: `idx_users_email_lower` on `users(LOWER(email))` ensures efficient case-insensitive email lookups.

**Migration file**: `backend/functions/migrations/012_email_lookup_index.sql`

### Guard Clauses

RevenueCat initialization is skipped (user gets free tier) if:
- Email is empty (Graph API failed)
- Email ends with `mybartenderai.onmicrosoft.com` (UPN fallback, not a real email)

---

## Manual Configuration Steps

### 1. RevenueCat Dashboard

- ✅ Create project "MyBartenderAI"
- ✅ Add Google Play app with package name: `ai.mybartender.mybartenderai`
- ✅ Add iOS app with bundle ID: `com.mybartenderai.mybartenderai`
- ✅ Create entitlement: `paid`
- Remaining: Map store products, configure offerings, verify webhook (see `REVENUECAT_PLAN.md` Phase 3)

### 2. Google Play Console

- Create subscription `pro_monthly` ($7.99/mo, base plan `monthly-autorenewing`)
- Create subscription `pro_annual` ($79.99/yr, base plan `annual-autorenewing`)
- Create consumable product `voice_minutes_60` at $4.99
- See `REVENUECAT_PLAN.md` Phase 1 for step-by-step

### 3. App Store Connect

- ✅ Subscription `pro_monthly` created
- ✅ Subscription `pro_annual` created
- Create consumable `voice_minutes_60` at $4.99
- See `REVENUECAT_PLAN.md` Phase 2 for step-by-step

### 4. Configure Webhook

- URL: `https://apim-mba-002.azure-api.net/v1/subscription/webhook`
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

- [ ] New subscription purchase (monthly with trial)
- [ ] Trial expiration → paid conversion
- [ ] Subscription renewal (voice cycle reset)
- [ ] Cancellation (verify still active until expiry)
- [ ] Expiration (verify entitlement reverts to `none`)
- [ ] Restore purchases on new device
- [ ] Voice add-on purchase via Google Play (+60 minutes credited via `voice-purchase` endpoint)
- [ ] Duplicate purchase token (idempotent handling)

### Test Scenarios — iOS

- [ ] Subscription init logs "iOS API key retrieved"
- [ ] New subscription purchase (monthly with trial)
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

*Last Updated: February 26, 2026*
*Implementation Status: Backend + Mobile code complete for both platforms. Pre-navigation paywall gates implemented on 11 AI feature buttons across 6 screens. Profile screen uses dual-source subscription check. Diagnostic logging enabled for on-device troubleshooting. Email-based RevenueCat App User ID deployed (Graph API + dual-lookup webhook). Store product creation and RevenueCat dashboard configuration pending — see REVENUECAT_PLAN.md.*
