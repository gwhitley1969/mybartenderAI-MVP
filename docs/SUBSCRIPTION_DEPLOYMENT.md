# Subscription System — Deployment Documentation

## Overview

MyBartenderAI uses a **single binary entitlement model**: users are either `paid` (subscribers) or `none` (non-subscribers). Subscriptions are managed through **RevenueCat**, which handles Google Play and App Store billing, webhook lifecycle events, and cross-platform purchase restoration.

Voice minute consumables ($5.99 for 60 minutes) are handled separately via **Google Play Billing** with server-side verification through the `voice-purchase` function.

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
| Monthly | $9.99/month | 3-day free trial (auto-converts unless canceled) |
| Annual | $99.99/year | No trial |

### Voice Minutes System

- **60 included minutes** per 30-day billing cycle
- Metered on **active talk time** (user + AI audio; idle time excluded)
- **Deduction order**: included minutes consumed first, then purchased balance
- Included minutes reset on subscription renewal; **purchased minutes carry over** indefinitely
- **Add-on packs**: +60 minutes for $5.99, consumable, repeatable, requires `paid` entitlement

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
    |   - Reads REVENUECAT_PUBLIC_API_KEY from env
    |   - Key Vault reference resolves to actual key
    |   - Returns API key to mobile app
    v
Mobile App initializes RevenueCat SDK
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
    |   - Verifies RevenueCat signature (HMAC-SHA256)
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
| Purpose | Returns RevenueCat public API key for SDK initialization |

**Response:**
```json
{
  "success": true,
  "config": {
    "revenueCatApiKey": "appl_xxxxx..."
  }
}
```

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

| Item | Value |
|------|-------|
| Entitlement ID | `paid` |
| Monthly subscription | (configured in RevenueCat dashboard) |
| Annual subscription | (configured in RevenueCat dashboard) |
| Voice add-on (consumable) | `voice_minutes_60` (mobile product ID) |

The mobile app fetches available offerings dynamically from RevenueCat — subscription product IDs are not hardcoded.

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

### Purchase Service (`purchase_service.dart`)

- Handles Google Play consumable purchases for voice minutes
- Product ID: `voice_minutes_60`
- Backend verification via `POST /v1/voice/purchase`

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
| `subscription-webhook` | POST | `/api/v1/subscription/webhook` | Signature | RevenueCat webhook |
| `subscription-status` | GET | `/api/v1/subscription/status` | JWT | User status |

- `subscription-webhook` does NOT use JWT validation (RevenueCat doesn't send JWT)
- Authentication is via `X-RevenueCat-Webhook-Signature` header verified against `REVENUECAT_WEBHOOK_SECRET`

---

## Azure Key Vault Configuration

### Secrets

| Secret Name | Purpose |
|-------------|---------|
| `REVENUECAT-PUBLIC-API-KEY` | RevenueCat SDK initialization (mobile) |
| `REVENUECAT-WEBHOOK-SECRET` | Webhook signature verification |

### Function App Settings

| Setting | Value |
|---------|-------|
| `REVENUECAT_PUBLIC_API_KEY` | `@Microsoft.KeyVault(VaultName=kv-mybartenderai-prod;SecretName=REVENUECAT-PUBLIC-API-KEY)` |
| `REVENUECAT_WEBHOOK_SECRET` | `@Microsoft.KeyVault(VaultName=kv-mybartenderai-prod;SecretName=REVENUECAT-WEBHOOK-SECRET)` |

---

## Security Considerations

1. **Remote Configuration**: RevenueCat public API key fetched from backend at runtime (key rotation without app update)
2. **Key Vault Storage**: All secrets stored in Azure Key Vault with Managed Identity access
3. **Webhook Verification**: RevenueCat webhooks verified via HMAC-SHA256 signature
4. **JWT Validation**: All user-facing endpoints validate Entra External ID JWT
5. **Server-Side Enforcement**: Voice minute balances maintained server-side; client can only read, never write
6. **Idempotent Processing**: All purchase and webhook operations are idempotent via unique transaction/event IDs

---

## Manual Configuration Steps

### 1. RevenueCat Dashboard

- Create project "MyBartenderAI"
- Add Google Play app with package name: `ai.mybartender.mybartenderai`
- Add iOS app (when ready)
- Create entitlement: `paid`
- Create products for monthly ($9.99) and annual ($99.99) subscriptions
- Attach both subscription products to the `paid` entitlement
- Create default offering with monthly + annual packages
- Configure 3-day free trial on the monthly subscription

### 2. Google Play Console

- Create subscription products matching RevenueCat configuration
- Create consumable product `voice_minutes_60` at $5.99
- Configure 3-day free trial on monthly subscription product

### 3. Configure Webhook

- URL: `https://share.mybartenderai.com/api/v1/subscription/webhook`
- Enable all subscription lifecycle events
- Copy webhook secret to Key Vault

### 4. Update Key Vault Secrets

```powershell
az keyvault secret set --vault-name kv-mybartenderai-prod --name REVENUECAT-PUBLIC-API-KEY --value "YOUR_REVENUECAT_PUBLIC_API_KEY"
az keyvault secret set --vault-name kv-mybartenderai-prod --name REVENUECAT-WEBHOOK-SECRET --value "YOUR_WEBHOOK_SECRET"
```

### 5. Restart Function App

```powershell
az functionapp restart --name func-mba-fresh --resource-group rg-mba-prod
```

---

## Testing

### Sandbox Testing

1. RevenueCat provides sandbox mode for free test purchases
2. Add tester emails in Google Play Console
3. RevenueCat dashboard shows all test transactions

### Test Scenarios

- [ ] New subscription purchase (monthly with trial)
- [ ] Trial expiration → paid conversion
- [ ] Subscription renewal (voice cycle reset)
- [ ] Cancellation (verify still active until expiry)
- [ ] Expiration (verify entitlement reverts to `none`)
- [ ] Restore purchases on new device
- [ ] Voice add-on purchase (+60 minutes credited)
- [ ] Duplicate purchase token (idempotent handling)

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
- `GOOGLE_PLAY_BILLING_SETUP.md` — Google Play service account setup for voice purchase verification
- `CLAUDE.md` — Project context and conventions

---

*Last Updated: February 2026*
*Implementation Status: Backend + Mobile Complete, Awaiting RevenueCat Account Configuration*
