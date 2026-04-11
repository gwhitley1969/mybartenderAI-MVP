# RevenueCat Complete Setup — Google Play + Apple App Store

## Context

RevenueCat integration is **fully operational on Android**. Two real production subscriptions have been processed end-to-end:

- **Wild Heels** — Pro Annual ($79.99), expires 2027-02-25, Google Play Store
- **Xtend-AI** — Pro Monthly ($7.99), expires 2026-03-25, Google Play Store

RevenueCat Overview dashboard confirms: **2 Active Subscriptions, $88 Revenue, $15 MRR, 27 Active Customers**.

### What's Working (Android — Verified Feb 25-27, 2026)
- Google Play Console: `pro_monthly` and `pro_annual` subscriptions active
- RevenueCat Dashboard: Products mapped, `paid` entitlement configured, Default offering with `$rc_monthly`/`$rc_annual` packages
- Webhook: `subscription-webhook` receives events, verifies `Bearer` auth, processes INITIAL_PURCHASE/RENEWAL/etc.
- Database: `user_subscriptions` and `subscription_events` tables populated correctly via webhook
- PostgreSQL trigger: `sync_user_tier_from_subscription` automatically syncs `users.entitlement` to `paid`
- App: Users can subscribe, AI features unlock immediately
- `navigateOrGate()`: 3-step check (cached provider → fresh SDK call → backend) eliminates false-positive paywalls for trial/paid users on first tap after launch (Feb 27 fix)

### What's Working (iOS — Verified Feb 27, 2026)
- App Store Connect: `pro_monthly` and `pro_annual` subscriptions active, `voice_minutes_60` consumable created
- RevenueCat Dashboard: Apple products mapped, showing "Ready to Submit" (normal for pre-submission — sandbox works)
- iOS sandbox testing: Annual subscription and trial purchase verified on physical device (iPhone, iOS 26.3)
- Webhook race condition fix deployed (SUB-005): auto-creates user if webhook arrives before first API call

### What's Remaining (iOS)
- TestFlight build not yet uploaded (Xcode direct-to-device used for sandbox testing)
- Voice minutes consumable purchase not yet tested on iOS
- App Store review submission pending

### Known Dashboard Quirk
RevenueCat's **Customers list views** (Active subscription, Sandbox, etc.) show 0 even though the Overview page and API both correctly report 2 active subscribers. This is a RevenueCat dashboard propagation delay for new projects — not a data issue. Use the **Overview** page or **Ctrl+K customer search** for real-time data.

### App User ID — Entra Sub + Email Attribute (Build 17 — Feb 26, 2026)

RevenueCat uses the user's **Entra `sub` claim** (opaque GUID) as the App User ID. Email is set as the `$email` subscriber attribute for dashboard searchability. This follows RevenueCat's documented best practice: *"We don't recommend using email addresses as App User IDs."*

**Why not email:**
- Email extraction fails for Google-federated CIAM users (all 6 layers return empty) — blocked them from subscribing
- RevenueCat's Transfer Behavior doesn't migrate between identified users — existing users' purchases stayed with GUID
- RevenueCat explicitly recommends opaque, non-guessable IDs (guessability, GDPR concerns)

**How it works:**
- `Purchases.configure()` runs anonymously, then `Purchases.logIn(userId)` identifies by Entra sub (always available)
- `Purchases.setEmail(email)` sets `$email` subscriber attribute when email is available — searchable via Ctrl+K
- `Purchases.setDisplayName(name)` sets `$displayName` attribute
- No email dependency — ALL users (email, Google, Apple) can subscribe
- Backend webhook looks up users via `WHERE LOWER(azure_ad_sub) = LOWER($1)` (case-insensitive — RevenueCat lowercases App User IDs; see `BUG_FIXES.md` SUB-004)

**Existing subscribers** (Wild Heels, Xtend-AI): Reconnect automatically — their App User IDs are already the Entra sub.

**Dashboard search**: Use Ctrl+K in RevenueCat to search by email. The `$email` subscriber attribute is indexed for search. For Google-federated users where email isn't extracted, search by App User ID (Entra sub) and cross-reference with the PostgreSQL `users` table.

**Build 16 (superseded):** Attempted email-based App User ID approach. Never deployed. Auth service improvements (6-layer email extraction, diagnostic logging, HttpClient fix) retained in Build 17 for populating the `$email` attribute.

**Full analysis:** `docs/REVENUECAT_EMAIL_ID_ANALYSIS.md`

### Credentials Already Obtained
- Apple Team ID: `4ML27KY869`
- Bundle ID: `com.mybartenderai.mybartenderai`
- Apple IAP Key: `SubscriptionKey_7G25AR5XR6.p8` (Key ID: `7G25AR5XR6`)
- Apple Shared Secret: `d362e8c36cce422e9afc45dfd84a2b3b`
- RevenueCat Apple API Key: `appl_fHUlSMXyyWiYidJqYFQlqYfiJmM`
- RevenueCat Android API Key: already in Key Vault as `REVENUECAT-PUBLIC-API-KEY`

---

## Phase 1: Google Play Console — Create Store Products

### Status: COMPLETED (Feb 25, 2026)

**Where**: Google Play Console > select your app > left sidebar:
> **Monetize with Play** > **Products** > **Subscriptions**

### 1A. Create `pro_monthly` Subscription ✅

- **Product ID**: `pro_monthly`
- **Base plan ID**: `monthly-id`
- **Billing period**: 1 Month
- **Price**: $3.99 USD
- **Free trial offer**: 7-day (1 week) free trial (originally 5-day, harmonized to 7-day on Apr 11, 2026 — see [Phase 1E](#1e-add-free-trial-offer-to-pro_monthly))

### 1B. Create `pro_annual` Subscription ✅

- **Product ID**: `pro_annual`
- **Base plan ID**: `annual-id`
- **Billing period**: 1 Year
- **Price**: $39.99 USD

### 1C. Create `voice_minutes_60` Consumable

**Where**: Same sidebar:
> **Monetize with Play** > **Products** > **One-time products**

1. Click **"Create product"**
2. **Product ID**: `voice_minutes_60`
3. **Name**: `60 Voice Minutes`
4. **Description**: `Add 60 minutes of AI voice bartender conversation`
5. Set **price**: $3.99 USD
6. **Status**: Active

### 1D. Verify All Three Products Exist ✅

- **Subscriptions**: `pro_monthly` (Active), `pro_annual` (Active)
- **One-time products**: `voice_minutes_60` (status TBD)

### 1E. Add Free Trial Offer to `pro_monthly`

### Status: COMPLETED (Feb 25, 2026)

**Important**: In Google Play's subscription model, a free trial is an **Offer** attached to a base plan — not a setting on the base plan itself. The hierarchy is:

```
Subscription (pro_monthly)
  └── Base Plan (monthly-id)
        └── Offer (free-trial)
              └── Phase 1: Free trial (7 days, $0)
              └── Auto-renews at base plan price ($3.99/mo)
```

**Steps to create the offer:**
1. Go to **Monetize with Play** > **Products** > **Subscriptions** > click **`pro_monthly`**
2. Click **"Add offer"** (near the base plan, not inside it)
3. Select the base plan this offer applies to
4. Configure:
   - **Offer ID**: Choose a permanent ID (e.g., `free-trial-1week`). Note: the original offer was named `free-trial-5day`; on Apr 11, 2026 the phase duration was changed from 5 days to 7 days. Google Play offer IDs are permanent — if recreating, use a new ID; if keeping the existing offer, the legacy name no longer matches the phase duration.
   - **Eligibility**: **"New customer acquisition"** > **"Never had this subscription"**
   - **Tags**: Leave empty (RevenueCat auto-detects trials)
5. Under **"Phases"**, click **"Add phase"**:
   - **Type**: Free trial
   - **Duration**: 7 days (1 week)
6. **Activate** the offer

**RevenueCat handles this automatically** — no additional RevenueCat dashboard configuration needed. The SDK detects the free trial offer and presents it to eligible users.

**Backend handling**: Already implemented. When `period_type === 'TRIAL'`, the webhook sets `subscription_status = 'trialing'` with reduced quotas (30 voice min, 50K tokens, 10 scans). On `RENEWAL` (trial→paid conversion), it upgrades to full paid limits.

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
6. Set **price**: $3.99 (Price Schedule > "+")
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
- **Base plan ID**: `monthly-id` (from Phase 1A step 6)

**Product 2 — Pro Annual**:
- **App**: My AI Bartender (Play Store)
- **Store product ID**: `pro_annual`
- **Base plan ID**: `annual-id` (from Phase 1B step 6)

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
  - `pro_monthly` (Play Store) — with base plan `monthly-id`
  - `pro_monthly` (App Store)

**Package: Annual**
- **Identifier**: `$rc_annual`
- **Attach products**:
  - `pro_annual` (Play Store) — with base plan `annual-id`
  - `pro_annual` (App Store)

### 3E. Clean Up Test Store (Optional)

1. Go to **Product catalog** > **Products** tab
2. Find products under **"Test Store"** (`monthly`, `yearly` from Feb 17)
3. Delete them — they use wrong product IDs and aren't connected to any real store

### 3F. Verify Webhook ✅

**Status**: COMPLETED and VERIFIED (Feb 25, 2026)

- Webhook URL: `https://apim-mba-002.azure-api.net/api/v1/subscription/webhook` (routes through APIM)
- Authentication: `Bearer` token using `REVENUECAT_WEBHOOK_SECRET` (Key Vault reference)
- Verified working: Two production INITIAL_PURCHASE events processed successfully
- RevenueCat dashboard shows "Sent" status for webhook events

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

### 7A. Backend Deployment ✅
1. Deploy `index.js` and `voice-purchase/index.js` to `func-mba-fresh` — DONE
2. Call `GET /v1/subscription/config` — confirmed response has both `revenueCatApiKey` and `revenueCatAppleApiKey`

### 7B. Flutter static analysis ✅
```bash
flutter analyze --no-pub
```
Filter results for modified files only (pre-existing errors exist elsewhere).
**Status**: COMPLETED — zero new errors in modified files.

### 7C. Android build ✅
```bash
flutter build appbundle --release
```
Verified: app launches and subscription init logs "Android API key retrieved".

### 7D. RevenueCat sandbox testing ✅
1. RevenueCat dashboard: Play Store products show green "Published" checkmarks
2. Two real Google Play production purchases verified (Wild Heels annual, Xtend-AI monthly)
3. Webhook fires and backend processes events correctly

### 7E. iOS testing ✅ (Feb 27, 2026)
1. ✅ Subscription init logs "iOS API key retrieved"
2. ✅ Sandbox annual subscription purchase — Paul (pwhitley1967@gmail.com)
3. ✅ Sandbox trial subscription purchase — verified working
4. ✅ Webhook race condition discovered (SUB-005) — auto-create user fix deployed
5. ✅ App Store products show "Ready to Submit" (yellow) in RevenueCat — normal for pre-submission, sandbox purchases work
6. [ ] Voice minutes consumable purchase via RevenueCat SDK
7. [ ] Verify webhook credits 60 minutes for voice pack

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

1. **Phases 1-3** (manual portal work) — DONE (Android complete, iOS subscriptions created)
2. **Phase 4** (Azure CLI) — DONE
3. **Phase 5** (backend code) — DONE, deployed to `func-mba-fresh`
4. **Phase 6** (Flutter code) — DONE
5. **Phase 7** (verification) — DONE (Android production + iOS sandbox verified)

## Known Items (Not In Scope)

- ~~"Restore Purchases" button only exists on `voice_ai_screen.dart`~~ — **RESOLVED**: Restore Purchases now available on the subscription paywall sheet (`subscription_sheet.dart`, accessible from any gated feature) and on the Profile screen (`profile_screen.dart`). Apple requirement satisfied.
- Reviewer screenshots needed for App Store IAP review — can be added later before submission
- ~~CLAUDE.md references old pricing "$4.99 for 20 minutes"~~ — **RESOLVED**: Updated to "$4.99 for 60 minutes"
- ~~Webhook returning 401~~ — **RESOLVED** (Feb 25, 2026): Key Vault reference for `REVENUECAT_WEBHOOK_SECRET` was not resolving. Fixed by restarting Function App; secret now uses `@Microsoft.KeyVault(SecretUri=...)` reference pattern.
- ~~No free trial on `pro_monthly`~~ — **RESOLVED** (Feb 25, 2026): Free trial is a Google Play **Offer** (not a base plan setting). Created 5-day free trial offer on `pro_monthly` base plan. Backend already handles `period_type === 'TRIAL'`.
- ~~Webhook race condition — user not found~~ — **RESOLVED** (Feb 27, 2026): Webhook auto-creates user record if not found. See `BUG_FIXES.md` SUB-005.
- **RevenueCat Customers list shows 0**: Known dashboard propagation delay for new projects. Overview page and API correctly report 2 active subscribers. Not a data issue.
- **App Store products "Ready to Submit"**: Normal for pre-submission apps. Sandbox purchases work correctly. Status resolves when app binary is submitted to App Store Connect.

---

**Last Updated**: February 27, 2026
