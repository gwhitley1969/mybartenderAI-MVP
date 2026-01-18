# Subscription System Deployment Documentation

## Overview

This document describes the RevenueCat-based subscription system implementation for MyBartenderAI. The system handles subscription purchases, status tracking, and tier management while keeping sensitive API keys secure in Azure Key Vault.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SUBSCRIPTION FLOW                                  │
└─────────────────────────────────────────────────────────────────────────────┘

Mobile App (Flutter)
    │
    │ 1. On login, fetch RevenueCat API key from backend
    │    GET /v1/subscription/config
    │
    ▼
Azure Front Door (share.mybartenderai.com)
    │
    ▼
Azure API Management (apim-mba-002)
    │ - JWT validation via validate-jwt policy
    │ - Extracts user ID to x-user-id header
    │
    ▼
Azure Functions (func-mba-fresh)
    │
    │ subscription-config:
    │   - Reads REVENUECAT_PUBLIC_API_KEY from env
    │   - Key Vault reference resolves to actual key
    │   - Returns API key to mobile app
    │
    ▼
Mobile App initializes RevenueCat SDK
    │
    │ 2. User makes purchase via Google Play
    │
    ▼
RevenueCat (handles Google Play billing)
    │
    │ 3. Webhook notification on subscription events
    │    POST /v1/subscription/webhook
    │
    ▼
Azure Functions (func-mba-fresh)
    │
    │ subscription-webhook:
    │   - Verifies RevenueCat signature
    │   - Updates user_subscriptions table
    │   - Database trigger updates users.tier
    │
    ▼
PostgreSQL (pg-mybartenderdb)
    │
    │ users.tier now reflects subscription status
    │ All existing tier-based quota checks continue working
    │
    └──────────────────────────────────────────────────────
```

## Why RevenueCat?

| Factor | Custom Implementation | RevenueCat |
|--------|----------------------|------------|
| Google Play integration | ~5 hours | Included |
| iOS App Store (future) | ~8 hours (separate API) | Included |
| Webhook handling | Build for both platforms | Unified webhook |
| Edge cases (refunds, grace periods) | Must implement each | Handled |
| Cross-device restoration | Manual implementation | Built-in |
| Analytics (MRR, churn, LTV) | Build custom | Dashboard included |
| Total effort | 13+ hours + maintenance | ~5 hours |

**Note:** Voice minute consumables ($4.99/20 min) remain custom via the existing `voice-purchase` function.

---

## Database Changes

### Migration: 007_subscriptions.sql

**Location:** `backend/functions/migrations/007_subscriptions.sql`

**Tables Created:**

```sql
CREATE TABLE user_subscriptions (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    revenuecat_app_user_id VARCHAR(255) NOT NULL,
    tier VARCHAR(20) NOT NULL CHECK (tier IN ('premium', 'pro')),
    product_id VARCHAR(100) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_user_subscription UNIQUE (user_id)
);
```

**Indexes:**
- `idx_user_subscriptions_user_id` - Fast lookup by user
- `idx_user_subscriptions_revenuecat` - Fast lookup by RevenueCat ID

**Trigger Function:**

```sql
CREATE OR REPLACE FUNCTION sync_user_tier()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_active THEN
        UPDATE users SET tier = NEW.tier WHERE id = NEW.user_id;
    ELSE
        IF NOT EXISTS (
            SELECT 1 FROM user_subscriptions
            WHERE user_id = NEW.user_id AND is_active = true AND id != NEW.id
        ) THEN
            UPDATE users SET tier = 'free' WHERE id = NEW.user_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

This trigger automatically syncs the `users.tier` column whenever a subscription is created or updated, ensuring all existing tier-based quota checks continue working.

---

## Backend Functions

### 1. subscription-config

**Route:** `GET /api/v1/subscription/config`

**Purpose:** Returns RevenueCat public API key to mobile app for SDK initialization.

**Authentication:** JWT required (x-user-id header from APIM)

**Response:**
```json
{
  "success": true,
  "config": {
    "revenueCatApiKey": "appl_xxxxx..."
  }
}
```

**Location in code:** `backend/functions/index.js` (section 36)

### 2. subscription-webhook

**Route:** `POST /api/v1/subscription/webhook`

**Purpose:** Receives RevenueCat server-to-server notifications for subscription events.

**Authentication:** RevenueCat webhook signature (NOT JWT)

**Events Handled:**
- `INITIAL_PURCHASE` - New subscription
- `RENEWAL` - Subscription renewed
- `PRODUCT_CHANGE` - Upgrade/downgrade
- `CANCELLATION` - User cancelled (still active until expiry)
- `EXPIRATION` - Subscription expired
- `BILLING_ISSUE` - Payment failed

**Location in code:** `backend/functions/index.js` (section 34)

### 3. subscription-status

**Route:** `GET /api/v1/subscription/status`

**Purpose:** Returns current subscription status for a user.

**Authentication:** JWT required (x-user-id header from APIM)

**Response:**
```json
{
  "success": true,
  "subscription": {
    "tier": "premium",
    "productId": "premium_monthly",
    "isActive": true,
    "expiresAt": "2025-01-23T00:00:00Z"
  }
}
```

**Location in code:** `backend/functions/index.js` (section 35)

---

## Flutter/Mobile Changes

### Files Modified

#### 1. `mobile/app/lib/src/services/subscription_service.dart`

**Key Changes:**
- Removed hardcoded API key
- Added `BackendService` parameter to `initialize()` method
- Fetches API key from backend at runtime via `getSubscriptionConfig()`

```dart
Future<void> initialize(String userId, BackendService backendService) async {
  // Fetch RevenueCat API key from backend (stored in Azure Key Vault)
  final config = await backendService.getSubscriptionConfig();
  _revenueCatApiKey = config.revenueCatApiKey;

  // Configure RevenueCat
  await Purchases.configure(
    PurchasesConfiguration(_revenueCatApiKey!)..appUserID = userId,
  );
  // ...
}
```

#### 2. `mobile/app/lib/src/services/backend_service.dart`

**Added:**
- `getSubscriptionConfig()` method
- `SubscriptionConfig` model class

```dart
Future<SubscriptionConfig> getSubscriptionConfig() async {
  final response = await _dio.get('/v1/subscription/config');
  return SubscriptionConfig.fromJson(response.data);
}

class SubscriptionConfig {
  final String revenueCatApiKey;
  // ...
}
```

#### 3. `mobile/app/lib/src/providers/auth_provider.dart`

**Changes:**
- Added `BackendService` dependency to `AuthNotifier`
- Updated `_initializeSubscription()` to pass `BackendService`

```dart
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final SubscriptionService _subscriptionService;
  final BackendService _backendService;  // Added

  Future<void> _initializeSubscription(String userId) async {
    await _subscriptionService.initialize(userId, _backendService);
  }
}
```

#### 4. `mobile/app/lib/src/providers/subscription_provider.dart`

**Changes:**
- Updated `initializeSubscriptionService()` helper to include `BackendService`

```dart
Future<void> initializeSubscriptionService(Ref ref, String userId) async {
  final subscriptionService = ref.read(subscriptionServiceProvider);
  final backendService = ref.read(backendServiceProvider);
  await subscriptionService.initialize(userId, backendService);
}
```

### Existing Files (No Changes Required)

These files were already implemented and work with the new backend:
- `mobile/app/lib/src/services/subscription_service.dart` - RevenueCat SDK wrapper
- `mobile/app/lib/src/providers/subscription_provider.dart` - Riverpod providers
- `mobile/app/pubspec.yaml` - Already has `purchases_flutter: ^8.0.0`

---

## APIM Configuration

### Operations Added

| Operation | Method | Route | Auth | Notes |
|-----------|--------|-------|------|-------|
| `subscription-config` | GET | `/api/v1/subscription/config` | JWT | Returns API key |
| `subscription-webhook` | POST | `/api/v1/subscription/webhook` | Signature | RevenueCat webhook |
| `subscription-status` | GET | `/api/v1/subscription/status` | JWT | User status |

### Policy Notes

- `subscription-config` and `subscription-status` use the standard API-level JWT validation policy
- `subscription-webhook` does NOT use JWT validation (RevenueCat doesn't send JWT)
  - Authentication is via `X-RevenueCat-Webhook-Signature` header
  - Verified in the function code against `REVENUECAT_WEBHOOK_SECRET`

---

## Azure Key Vault Configuration

### Secrets

| Secret Name | Purpose | Current State |
|-------------|---------|---------------|
| `REVENUECAT-PUBLIC-API-KEY` | RevenueCat SDK initialization | Placeholder (needs real value) |
| `REVENUECAT-WEBHOOK-SECRET` | Webhook signature verification | Placeholder (needs real value) |

### Function App Settings

| Setting | Value |
|---------|-------|
| `REVENUECAT_PUBLIC_API_KEY` | `@Microsoft.KeyVault(VaultName=kv-mybartenderai-prod;SecretName=REVENUECAT-PUBLIC-API-KEY)` |
| `REVENUECAT_WEBHOOK_SECRET` | `@Microsoft.KeyVault(VaultName=kv-mybartenderai-prod;SecretName=REVENUECAT-WEBHOOK-SECRET)` |

**Note:** The Key Vault references use the `VaultName;SecretName` format rather than `SecretUri` format due to shell escaping issues with trailing slashes in URLs.

---

## Subscription Products

| Product ID | Tier | Price | Period |
|------------|------|-------|--------|
| `premium_monthly` | premium | $4.99 | month |
| `premium_yearly` | premium | $39.99 | year |
| `pro_monthly` | pro | $7.99 | month |
| `pro_yearly` | pro | $79.99 | year |

### RevenueCat Entitlements

| Entitlement ID | Grants Access To |
|----------------|------------------|
| `premium` | Premium tier features |
| `pro` | Pro tier features |

---

## Security Considerations

1. **Remote Configuration**: RevenueCat public API key is fetched from backend at runtime for operational flexibility (key rotation, environment switching without app updates). Note: RevenueCat public keys are designed to be safe for mobile use; the secret API key (sk_...) is what must remain server-side only.
2. **Key Vault Storage**: All secrets stored in Azure Key Vault with Managed Identity access
3. **Webhook Verification**: RevenueCat webhooks verified via HMAC signature
4. **JWT Validation**: All user-facing endpoints validate Entra External ID JWT
5. **Database Constraints**: Foreign key to users table ensures data integrity

---

## Testing

### Sandbox Testing
1. RevenueCat provides sandbox mode for free test purchases
2. Add tester emails in Google Play Console
3. RevenueCat dashboard shows all test transactions

### Test Scenarios
- [ ] New subscription purchase
- [ ] Subscription renewal
- [ ] Upgrade from Premium to Pro
- [ ] Downgrade from Pro to Premium
- [ ] Cancellation (verify still active until expiry)
- [ ] Expiration (verify tier reverts to free)
- [ ] Restore purchases on new device

---

## Remaining Manual Steps

The following steps require manual action and cannot be automated:

### 1. Create RevenueCat Account
- Go to https://app.revenuecat.com
- Create account and new project "MyBartenderAI"

### 2. Configure RevenueCat Project
- Add Google Play app with package name: `ai.mybartender.mybartenderai`
- Upload Google Play service account JSON (same one used for voice purchases)

### 3. Create Entitlements
- Create entitlement: `premium`
- Create entitlement: `pro`

### 4. Create Products in Google Play Console
- Create subscription products matching the Product IDs above
- Set pricing and billing periods

### 5. Map Products to Entitlements in RevenueCat
- `premium_monthly` → `premium` entitlement
- `premium_yearly` → `premium` entitlement
- `pro_monthly` → `pro` entitlement
- `pro_yearly` → `pro` entitlement

### 6. Create Default Offering
- Create offering with all 4 subscription packages

### 7. Configure Webhook in RevenueCat
- URL: `https://share.mybartenderai.com/api/v1/subscription/webhook`
- Enable all subscription lifecycle events
- Copy the webhook secret

### 8. Update Key Vault Secrets
After completing RevenueCat setup:

```powershell
# Update the public API key
az keyvault secret set --vault-name kv-mybartenderai-prod --name REVENUECAT-PUBLIC-API-KEY --value "YOUR_REVENUECAT_PUBLIC_API_KEY"

# Update the webhook secret
az keyvault secret set --vault-name kv-mybartenderai-prod --name REVENUECAT-WEBHOOK-SECRET --value "YOUR_WEBHOOK_SECRET"
```

### 9. Restart Function App
After updating secrets, restart the Function App to pick up new values:

```powershell
az functionapp restart --name func-mba-fresh --resource-group rg-mba-prod
```

### 10. Test End-to-End
- Build debug APK
- Test subscription purchase flow
- Verify webhook receives events
- Confirm user tier updates in database

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
- Verify database trigger is working: `SELECT * FROM pg_trigger WHERE tgname = 'trigger_sync_user_tier';`
- Check user_subscriptions table for recent entries

---

## Related Documentation

- [RevenueCat Documentation](https://docs.revenuecat.com/)
- [Google Play Billing](https://developer.android.com/google/play/billing)
- [Azure Key Vault References](https://docs.microsoft.com/en-us/azure/app-service/app-service-key-vault-references)
- `ARCHITECTURE.md` - Overall system architecture
- `CLAUDE.md` - Project context and conventions

---

*Last Updated: December 2025*
*Implementation Status: Backend Complete, Awaiting RevenueCat Account Setup*
