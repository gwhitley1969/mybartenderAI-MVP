# RevenueCat Complete Setup — Google Play + Apple App Store

## Context

RevenueCat integration code is **fully implemented** in both Flutter and backend. However, the **store-side configuration is incomplete/broken**:

- Google Play Console: Subscription products (`pro_monthly`, `pro_annual`) have NOT been created
- Google Play Console: Voice minutes consumable status unknown (may be `voice_minutes_20` from old spec)
- RevenueCat Dashboard: "My AI Bartender (Play Store)" has **zero products** mapped
- RevenueCat Dashboard: "Test Store" has products with wrong IDs (`monthly`/`yearly`)
- App Store Connect: Subscriptions created (`pro_monthly`, `pro_annual`) — voice consumable NOT created yet
- RevenueCat Dashboard: Apple products show "Could not check" — need entitlement/offering config
- Backend bug: `voice-purchase/index.js` hardcodes `voice_minutes_20` but app sends `voice_minutes_60`

**Goal**: Get both stores fully configured so subscriptions and voice minute purchases work on Android and iOS.

### Credentials Already Obtained
- Apple Team ID: `4ML27KY869`
- Bundle ID: `com.mybartenderai.mybartenderai`
- Apple IAP Key: `SubscriptionKey_7G25AR5XR6.p8` (Key ID: `7G25AR5XR6`)
- Apple Shared Secret: `d362e8c36cce422e9afc45dfd84a2b3b`
- RevenueCat Apple API Key: `appl_fHUlSMXyyWiYidJqYFQlqYfiJmM`
- RevenueCat Android API Key: already in Key Vault as `REVENUECAT-PUBLIC-API-KEY`

---

## Phase 1: Google Play Console — Create Store Products

**Where**: Google Play Console > select your app > left sidebar:
> **Monetize with Play** > **Products** > **Subscriptions**

### 1A. Create `pro_monthly` Subscription

1. On the **Subscriptions** page, click **"Create subscription"**
2. **Product ID**: `pro_monthly` (exact — must match RevenueCat and code)
3. **Name**: `Pro Monthly`
4. Click **Create**
5. On the subscription detail page, click **"Add base plan"**
6. **Base plan ID**: `monthly-autorenewing` (you choose this — it's permanent once activated)
7. **Auto-renewing**: Yes
8. **Billing period**: 1 Month
9. Set **price**: $7.99 USD (click "Set price" > select countries > set base price)
10. Click **Activate** on the base plan
11. *(Optional for later)* Add a **free trial offer**: Click "Add offer" > Free trial > 3 days

**Write down**: Base plan ID = `monthly-autorenewing` (needed for RevenueCat in Phase 2)

### 1B. Create `pro_annual` Subscription

1. Back on **Subscriptions** page, click **"Create subscription"** again
2. **Product ID**: `pro_annual`
3. **Name**: `Pro Annual`
4. Click **Create**
5. Click **"Add base plan"**
6. **Base plan ID**: `annual-autorenewing`
7. **Auto-renewing**: Yes
8. **Billing period**: 1 Year
9. Set **price**: $79.99 USD
10. Click **Activate** on the base plan

**Write down**: Base plan ID = `annual-autorenewing` (needed for RevenueCat in Phase 2)

### 1C. Create `voice_minutes_60` Consumable

**Where**: Same sidebar:
> **Monetize with Play** > **Products** > **One-time products**

1. Click **"Create product"**
2. **Product ID**: `voice_minutes_60`
3. **Name**: `60 Voice Minutes`
4. **Description**: `Add 60 minutes of AI voice bartender conversation`
5. Set **price**: $4.99 USD
6. **Status**: Active

### 1D. Verify All Three Products Exist

Before moving on, confirm you see these on their respective pages:
- **Subscriptions**: `pro_monthly` (Active), `pro_annual` (Active)
- **One-time products**: `voice_minutes_60` (Active)

---

## Phase 2: App Store Connect — Create Voice Consumable

Subscriptions (`pro_monthly`, `pro_annual`) are already created. Only the consumable is missing.

**Where**: App Store Connect > My Apps > My AI Bartender > left sidebar:
> **MONETIZATION** > **In-App Purchases**

### 2A. Create `voice_minutes_60` Consumable

1. Click **"Create"** (or "+" button)
2. **Type**: Consumable
3. **Reference Name**: `Voice Minutes 60`
4. **Product ID**: `voice_minutes_60` (must match Google Play exactly)
5. Click **Create**
6. Set **price**: $4.99 (Price Schedule > "+")
7. Add **localization**: English (US) — Display Name: "60 Voice Minutes", Description: "Add 60 minutes of AI voice bartender conversation"
8. Reviewer screenshot can be added later during app submission

---

## Phase 3: RevenueCat Dashboard — Configure Everything

**Navigation reference**:
- Left sidebar has: Overview, Charts, Customers, **Product catalog**, Paywalls, Targeting, Experiments, Web, Customer Center, **Apps & providers**, API keys, Integrations, Project settings
- **Product catalog** has tabs across the top: **Offerings** | **Products** | **Entitlements** | Virtual currencies

### 3A. Add Google Play Products to RevenueCat

1. Go to **Product catalog** (left sidebar) > **Products** tab (top)
2. You should see products grouped by app. Find **"My AI Bartender (Play Store)"**
3. Click **"+ New"** (or "Create Product" button) to add each product:

**Product 1 — Pro Monthly**:
- **App**: My AI Bartender (Play Store)
- **Store product ID (Identifier)**: `pro_monthly`
- **Base plan ID**: `monthly-autorenewing` (from Phase 1A step 6)

**Product 2 — Pro Annual**:
- **App**: My AI Bartender (Play Store)
- **Store product ID**: `pro_annual`
- **Base plan ID**: `annual-autorenewing` (from Phase 1B step 6)

**Product 3 — Voice Minutes**:
- **App**: My AI Bartender (Play Store)
- **Store product ID**: `voice_minutes_60`
- **Base plan ID**: Leave blank (consumables don't have base plans)

### 3B. Verify Apple Products in RevenueCat

1. Still on **Product catalog** > **Products** tab
2. Find **"My AI Bartender (App Store)"** — should show 3 products: `pro_monthly`, `pro_annual`, `voice_minutes_60`
3. If any are missing, add them (same process as 3A but select the App Store app)
4. Status should change from "Could not check" to valid once store products are created and propagated

### 3C. Configure Entitlements

1. Go to **Product catalog** > **Entitlements** tab
2. You should see the **`paid`** entitlement (created previously)
   - If it doesn't exist: click **"+ New"**, identifier: `paid`, display name: "Paid"
3. Click on the **`paid`** entitlement to open it
4. **Attach products** — you need ALL FOUR subscription products attached:
   - `pro_monthly` (Play Store)
   - `pro_annual` (Play Store)
   - `pro_monthly` (App Store)
   - `pro_annual` (App Store)
5. Do NOT attach `voice_minutes_60` to the entitlement — it's a consumable, not a subscription

### 3D. Configure Offerings

1. Go to **Product catalog** > **Offerings** tab
2. You should see a **"Default"** offering (or create one: click **"+ New"**, identifier: `default`)
3. Inside the Default offering, create/verify **packages**:

**Package: Monthly**
- Click **"+ New"** (or edit existing)
- **Identifier**: `$rc_monthly` (RevenueCat standard identifier for monthly)
- **Attach products**:
  - `pro_monthly` (Play Store) — with base plan `monthly-autorenewing`
  - `pro_monthly` (App Store)

**Package: Annual**
- **Identifier**: `$rc_annual`
- **Attach products**:
  - `pro_annual` (Play Store) — with base plan `annual-autorenewing`
  - `pro_annual` (App Store)

### 3E. Clean Up Test Store (Optional)

1. Go to **Product catalog** > **Products** tab
2. Find products under **"Test Store"** (`monthly`, `yearly` from Feb 17)
3. Delete them — they use wrong product IDs and aren't connected to any real store

### 3F. Verify Webhook

1. Go to **Apps & providers** (left sidebar)
2. Click on each app and verify the **webhook URL** points to your backend:
   `https://apim-mba-002.azure-api.net/v1/subscription/webhook`
   (or whatever your current webhook endpoint is)
3. Webhook should already be configured — just confirm it's there

---

## Phase 4: Azure Infrastructure — Store iOS API Key

### Status: COMPLETED

### 4A. Store Apple API key in Key Vault
```powershell
az keyvault secret set `
  --vault-name kv-mybartenderai-prod `
  --name REVENUECAT-APPLE-API-KEY `
  --value "appl_fHUlSMXyyWiYidJqYFQlqYfiJmM"
```

### 4B. Link to Function App as app setting
```powershell
az functionapp config appsettings set `
  --name func-mba-fresh `
  --resource-group rg-mba-prod `
  --settings "REVENUECAT_PUBLIC_API_KEY_IOS=@Microsoft.KeyVault(VaultName=kv-mybartenderai-prod;SecretName=REVENUECAT-APPLE-API-KEY)"
```

### 4C. Restart Function App
```powershell
az functionapp restart --name func-mba-fresh --resource-group rg-mba-prod
```

---

## Phase 5: Backend Code Changes

### Status: COMPLETED

### 5A. Fix voice-purchase product ID mismatch

**File**: `backend/functions/voice-purchase/index.js:31-33`

Changed from:
```javascript
const PRODUCT_ID = 'voice_minutes_20';
const SECONDS_PER_PURCHASE = 1200; // 20 minutes
const PRICE_CENTS = 499;
```
To:
```javascript
const PRODUCT_ID = 'voice_minutes_60';
const MINUTES_PER_PURCHASE = 60;
const PRICE_CENTS = 499;
```

Also updated the INSERT query to use `secondsPurchased = MINUTES_PER_PURCHASE * 60` and `minutesCredited = MINUTES_PER_PURCHASE` directly.

**Why**: Flutter sends `voice_minutes_60` but backend rejected anything except `voice_minutes_20`. The webhook already credits 60 minutes correctly — this endpoint needed to match.

### 5B. Return both API keys from subscription-config

**File**: `backend/functions/index.js:3987-4006`

Now reads `REVENUECAT_PUBLIC_API_KEY_IOS` from environment and returns both keys:
```javascript
jsonBody: {
    success: true,
    config: {
        revenueCatApiKey: revenueCatApiKey,
        revenueCatAppleApiKey: revenueCatAppleApiKey || null
    }
}
```

Logs a warning (not error) if the iOS key is missing — Android still works.

---

## Phase 6: Flutter Code Changes

### Status: COMPLETED

### 6A. Add Apple key to SubscriptionConfig

**File**: `mobile/app/lib/src/services/backend_service.dart:360-373`

Added `revenueCatAppleApiKey` nullable field to `SubscriptionConfig` class and parses it from `config['revenueCatAppleApiKey']`.

### 6B. Platform-aware RevenueCat initialization

**File**: `mobile/app/lib/src/services/subscription_service.dart:65-82`

Added `import 'dart:io' show Platform;`. Uses `config.revenueCatAppleApiKey` on iOS, `config.revenueCatApiKey` on Android.

### 6C. iOS voice minutes purchase via RevenueCat

**File**: `mobile/app/lib/src/services/purchase_service.dart`

- Added `dart:io`, `flutter/services.dart`, and `purchases_flutter` (as `rc`) imports
- iOS routes through `_purchaseVoiceMinutesIOS()` using RevenueCat SDK
- Android flow completely unchanged

**Why iOS is different**: Android voice purchases go through Google Play's `in_app_purchase` plugin with direct backend verification. iOS StoreKit receipts can't be verified by the Google Play API, so iOS uses RevenueCat SDK — the RevenueCat webhook handles crediting 60 minutes.

### 6D. Make onVerifyPurchase optional + iOS quota refresh

**File**: `mobile/app/lib/src/services/purchase_service.dart:64`
- `onVerifyPurchase` parameter changed from `required` to optional

**File**: `mobile/app/lib/src/providers/purchase_provider.dart:36-63`
- Added `import 'dart:io' show Platform;`
- `onVerifyPurchase` is `null` on iOS (no direct backend verification needed)
- iOS listens to `purchaseStream` and refreshes `voiceQuotaProvider` 2 seconds after success (gives webhook time to process)

---

## Phase 7: Verification

### 7A. Backend Deployment
1. Deploy `index.js` and `voice-purchase/index.js` to `func-mba-fresh`
2. Call `GET /v1/subscription/config` — confirm response has both `revenueCatApiKey` and `revenueCatAppleApiKey`

### 7B. Flutter static analysis
```bash
flutter analyze --no-pub
```
Filter results for modified files only (pre-existing errors exist elsewhere).
**Status**: COMPLETED — zero new errors in modified files.

### 7C. Android build
```bash
flutter build appbundle --release
```
Verify app launches and subscription init logs "Android API key retrieved".

### 7D. RevenueCat sandbox testing
1. In RevenueCat dashboard, verify products show green checkmarks (not "Could not check")
2. Use a Google Play test account to test sandbox subscription purchase
3. Verify webhook fires and backend processes the event

### 7E. iOS testing (when TestFlight ready)
1. Verify subscription init logs "iOS API key retrieved"
2. Test sandbox subscription purchase
3. Test sandbox voice minutes consumable purchase
4. Verify webhook credits 60 minutes

---

## Critical Files Summary

| File | Change | Phase |
|------|--------|-------|
| `backend/functions/voice-purchase/index.js:31-33` | Fix product ID `voice_minutes_20` > `voice_minutes_60` | 5A |
| `backend/functions/index.js:3987-4006` | Return both Android + iOS API keys | 5B |
| `mobile/app/lib/src/services/backend_service.dart:360-373` | Add `revenueCatAppleApiKey` field | 6A |
| `mobile/app/lib/src/services/subscription_service.dart:76-78` | `Platform.isIOS` key selection | 6B |
| `mobile/app/lib/src/services/purchase_service.dart:64,135` | iOS RevenueCat purchase path + optional callback | 6C, 6D |
| `mobile/app/lib/src/providers/purchase_provider.dart:36-63` | Skip Android verification on iOS + quota refresh | 6D |

## Execution Order

1. **Phases 1-3** (manual portal work) — can be done immediately, no code changes needed
2. **Phase 4** (Azure CLI) — DONE
3. **Phase 5** (backend code) — DONE, needs deployment to `func-mba-fresh`
4. **Phase 6** (Flutter code) — DONE
5. **Phase 7** (verification) — after everything above

## Known Items (Not In Scope)

- "Restore Purchases" button only exists on `voice_ai_screen.dart` — Apple may require it on the main subscription screen (address during App Store review)
- Reviewer screenshots needed for App Store IAP review — can be added later before submission
- CLAUDE.md references old pricing "$4.99 for 20 minutes" — should be updated to "$4.99 for 60 minutes"

---

**Last Updated**: February 19, 2026
