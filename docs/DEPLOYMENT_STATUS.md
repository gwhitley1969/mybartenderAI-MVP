# MyBartenderAI Deployment Status

## Current Status: Release Candidate

**Last Updated**: February 25, 2026

The My AI Bartender mobile app and Azure backend are fully operational and in release candidate status. All core features are implemented and tested on both Android and iOS platforms, including the RevenueCat subscription system and Today's Special daily notifications.

### Recent Updates (February 2026)

- **RevenueCat Webhook Verified + Free Trial Offer + Key Vault Cleanup** (Feb 25): End-to-end subscription pipeline fully verified with two real Google Play production purchases. Three issues diagnosed and resolved:

  **1. Webhook 401 Fix:**
  - Root cause: `REVENUECAT_WEBHOOK_SECRET` Key Vault reference was not resolving — the Function App received the literal `@Microsoft.KeyVault(...)` string instead of the secret value
  - Fix: Function App restart resolved the Key Vault reference. Confirmed webhook processes `Authorization: Bearer <secret>` header correctly
  - Cleanup: Removed temporary diagnostic logging from `index.js`, switched `REVENUECAT_WEBHOOK_SECRET` from hardcoded raw value back to Key Vault reference

  **2. Google Play Free Trial Offer:**
  - Root cause: Flutter UI hardcodes "Start 3-Day Free Trial" button text, but no free trial offer existed on the `pro_monthly` base plan in Google Play Console. Google Play charged $7.99 immediately with `period_type: "NORMAL"`
  - Fix: Created a free trial **Offer** on the `pro_monthly` base plan (3-day free trial, new customer eligibility). In Google Play's model, trials are Offers attached to base plans — not settings on the base plan itself
  - Backend already handles trials: `period_type === 'TRIAL'` → `subscription_status = 'trialing'` with reduced quotas (10 voice min, 20K tokens, 5 scans)

  **3. Subscription Verification Results:**
  - Two INITIAL_PURCHASE events processed: `pro_annual` ($79.99, Wild Heels) and `pro_monthly` ($7.99, Xtend-AI)
  - RevenueCat Overview: 2 Active Subscriptions, $88 Revenue, $15 MRR, 27 Active Customers
  - Database: Both users have `entitlement = 'paid'`, `subscription_status = 'active'` in `users` table
  - RevenueCat Customers list shows 0 — known dashboard propagation delay for new projects (Overview page is accurate)

  **File modified:**
  - `backend/functions/index.js`: Added then removed temporary diagnostic logging (net zero change)

  **Azure changes:**
  - `REVENUECAT_WEBHOOK_SECRET`: Restored to `@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/REVENUECAT-WEBHOOK-SECRET/)` reference
  - Google Play Console: Created 3-day free trial offer on `pro_monthly` base plan
  - Deployed to `func-mba-fresh` (clean code, no diagnostic logging)

  **Docs updated:**
  - `docs/REVENUECAT_PLAN.md`: Updated status to reflect working Android pipeline, added Phase 1E for free trial offer instructions
  - `docs/ARCHITECTURE.md`: Corrected webhook auth description (Bearer token, not HMAC-SHA256), updated sandbox filtering status
  - `docs/USER_SUBSCRIPTION_MANAGEMENT.md`: Added webhook configuration section, troubleshooting guide, dashboard quirk note
  - `docs/DEPLOYMENT_STATUS.md`: This entry

- **Fix: Recipe Vault Missing Subscription Gate** (Feb 25): The Recipe Vault's Chat and Voice buttons navigated directly to `/ask-bartender` and `/voice-ai` without checking subscription status. Unsubscribed users reached the AI Bartender screen and saw a generic error instead of a paywall. Added `navigateOrGate()` wrapper to both buttons in `recipe_vault_screen.dart`, matching the pattern used on Home, Academy, Pro Tools, and My Bar screens. This brings the total gated buttons to **11 across 6 screens**.

  **File modified:**
  - `mobile/app/lib/src/features/recipe_vault/recipe_vault_screen.dart`: Added `navigateOrGate` to Chat and Voice buttons, added subscription_sheet.dart import

- **Fix: Profile Screen Subscription Display + Diagnostic Logging** (Feb 25): The Profile screen's subscription card checked `status.isPaid` from `subscriptionStatusProvider` (RevenueCat only), ignoring the dual-source `isPaidProvider`. Beta testers with manual DB overrides saw "No Active Subscription" even though all other screens correctly recognized them as paid. Fixed by adding `|| ref.watch(isPaidProvider)` to the subscription card's data handler. Also added `developer.log` diagnostic logging to `isPaidProvider`, `backendEntitlementProvider`, and `navigateOrGate` for on-device troubleshooting via `adb logcat | grep -i Subscription`.

  **Files modified:**
  - `mobile/app/lib/src/features/profile/profile_screen.dart`: Added `isPaidProvider` check in `_buildSubscriptionCard()`
  - `mobile/app/lib/src/providers/subscription_provider.dart`: Added diagnostic logging to `isPaidProvider`
  - `mobile/app/lib/src/features/subscription/subscription_sheet.dart`: Added diagnostic logging to `navigateOrGate`

- **Fix: Dual-Source Subscription Check — isPaidProvider + Backend Entitlement** (Feb 25): Fixed paywall appearing for paid beta testers. Root cause: `isPaidProvider` only checked RevenueCat's local SDK cache, which has no record of manual PostgreSQL `entitlement='paid'` overrides. Two sources of truth disagreed — RevenueCat (mobile) said "not paid", PostgreSQL (backend) said "paid". The fix adds a `backendEntitlementProvider` that fetches the authoritative `entitlement` from the backend's `subscription-status` endpoint and wires it into `isPaidProvider` as a fallback.

  **Root cause:** `isPaidProvider` → `subscriptionStatusProvider` → `SubscriptionService` → RevenueCat SDK `CustomerInfo.entitlements.active['paid']`. For beta testers with manual DB overrides, RevenueCat has no purchase record, so this always returned `false`. The Profile screen, `navigateOrGate`, and all other consumers all read `isPaidProvider` — so every part of the app thought the user was free.

  **Backend change** (`index.js`):
  - `subscription-status` endpoint now queries `SELECT id, tier, entitlement FROM users` (added `entitlement` column to query)
  - Response includes `entitlement: user.entitlement || 'none'` alongside existing `currentTier` and `subscription` fields
  - Deployed to `func-mba-fresh`

  **Flutter changes:**
  - `backend_service.dart`: Added `getBackendEntitlement()` method — calls `GET /v1/subscription/status`, returns the `entitlement` string (`'paid'` or `'none'`)
  - `subscription_provider.dart`: Added `backendEntitlementProvider` (FutureProvider, fetched once per session, cached by Riverpod). Modified `isPaidProvider` to check RevenueCat first (fast, local), then fall back to `backendEntitlementProvider` (PostgreSQL authoritative)
  - `subscription_sheet.dart`: `navigateOrGate()` is now async — awaits `backendEntitlementProvider.future` if still loading before deciding to show paywall. Also invalidates `backendEntitlementProvider` on purchase completion

  **All scenarios handled:**
  1. **Real RevenueCat subscriber**: RevenueCat returns paid → instant (no backend call)
  2. **Manual DB override (beta testers)**: RevenueCat returns not-paid → backend returns `entitlement: 'paid'` → navigation allowed
  3. **Free user**: Both sources return not-paid → paywall shown
  4. **Offline/backend error**: RevenueCat not-paid + backend fails → paywall shown (fail-closed)

  **Screens affected:** All consumers of `isPaidProvider` automatically get correct state — Profile screen, Home, Academy, Pro Tools, My Bar, and any future screens.

  **Files modified:**
  - `backend/functions/index.js`: Added `entitlement` to subscription-status query and response
  - `mobile/app/lib/src/services/backend_service.dart`: Added `getBackendEntitlement()` method
  - `mobile/app/lib/src/providers/subscription_provider.dart`: Added `backendEntitlementProvider`, modified `isPaidProvider` for dual-source check
  - `mobile/app/lib/src/features/subscription/subscription_sheet.dart`: Made `navigateOrGate()` async with loading-state handling
  - `mobile/app/lib/src/features/home/home_screen.dart`: Async callbacks on 3 gated buttons
  - `mobile/app/lib/src/features/academy/academy_screen.dart`: Async callbacks on 2 gated buttons
  - `mobile/app/lib/src/features/pro_tools/pro_tools_screen.dart`: Async callbacks on 2 gated buttons
  - `mobile/app/lib/src/features/my_bar/my_bar_screen.dart`: Async callbacks on 2 gated buttons

- **Pre-Navigation Subscription Paywalls** (Feb 25): Added UI-layer paywall gates on 9 AI feature buttons across 5 screens. Free users now see the subscription sheet *before* navigating to the feature screen, instead of reaching the screen and hitting a backend 403. This is a UX improvement — defense in depth on top of the existing backend entitlement enforcement and per-screen `EntitlementRequiredException` handlers.

  **New helper function** (`subscription_sheet.dart`):
  - `navigateOrGate()` — checks `isPaidProvider` at tap time via `ref.read()` (not `ref.watch()` — avoids unnecessary rebuilds since button appearance doesn't change). If paid, navigates immediately. If free, shows `showSubscriptionSheet()` with auto-invalidation of `subscriptionStatusProvider` on purchase completion.

  **Screens modified (9 buttons gated):**
  - **Home screen** (`home_screen.dart`): Scan My Bar, Chat, Voice buttons gated. Create button remains FREE.
  - **Academy screen** (`academy_screen.dart`): Chat and Voice CTA buttons gated. Converted `StatefulWidget` → `ConsumerStatefulWidget` for `ref` access.
  - **Pro Tools screen** (`pro_tools_screen.dart`): Chat and Voice CTA buttons gated. Converted `StatefulWidget` → `ConsumerStatefulWidget` for `ref` access.
  - **My Bar screen** (`my_bar_screen.dart`): AppBar scanner icon and empty-state Scanner button gated. Already a `ConsumerWidget`.

  **Features that remain FREE (no paywall):**
  - Recipe Vault, My Bar (manual add/remove), Favorites, Today's Special, Academy content, Pro Tools content, Create Studio (manual editing), Social sharing

  **Existing paywall layers unchanged:**
  - Layer 1 (new): Pre-navigation gate via `navigateOrGate` (this change)
  - Layer 2: Per-screen `EntitlementRequiredException` handlers (Feb 22)
  - Layer 3: Backend 403 entitlement enforcement in PostgreSQL

  **Static analysis:** Zero new errors in modified files.

  **Files modified:**
  - `mobile/app/lib/src/features/subscription/subscription_sheet.dart`: Added `navigateOrGate()` helper
  - `mobile/app/lib/src/features/home/home_screen.dart`: Gated 3 buttons (Scan, Chat, Voice)
  - `mobile/app/lib/src/features/academy/academy_screen.dart`: Gated 2 buttons, converted to ConsumerStatefulWidget
  - `mobile/app/lib/src/features/pro_tools/pro_tools_screen.dart`: Gated 2 buttons, converted to ConsumerStatefulWidget
  - `mobile/app/lib/src/features/my_bar/my_bar_screen.dart`: Gated 2 scanner buttons

- **Email Population Fix — Entra Token + Flutter Headers** (Feb 24): Fixed the `email` column in the `users` table being NULL for all users despite extraction code existing in APIM and backend. Root cause: the Entra External ID app registration (`f9f7f159`) was not configured to include the `email` optional claim in ID tokens. The `name` claim was present (display_name populated), but no email-related claim existed in the token. Three-layer fix applied:

  **1. Entra Token Configuration (Azure Portal):**
  - Added `email` optional claim to ID tokens for app registration `f9f7f159-b847-4211-98c9-18e5b8193045`
  - Path: Entra admin center → App registrations → Token configuration → Add optional claim → ID token → `email`
  - Accepted Microsoft Graph `email` permission when prompted
  - Effect: Emails now flow via APIM's existing JWT extraction on every API call (no app rebuild needed)

  **2. Flutter Belt-and-Suspenders Headers (`backend_service.dart`):**
  - Dio interceptor now decodes JWT payload client-side after setting Authorization header
  - Extracts email using CIAM fallback chain: `emails[]` (array) → `email` → `preferred_username`
  - Sends `x-user-email` and `x-user-name` headers alongside the JWT
  - Wrapped in try/catch — cannot break any API calls. Ensures email reaches backend even if APIM extraction fails

  **3. Auth Service Email Extraction (`auth_service.dart`):**
  - Updated `_handleAuthResult()` email extraction to try `emails` array first (Entra CIAM pattern)
  - Fallback chain: `emails[0]` → `email` → `preferred_username` → `unique_name`

  **4. Admin Documentation (`docs/USER_SUBSCRIPTION_MANAGEMENT.md`):**
  - Added `display_name`-based lookups (`ILIKE` partial matching) as working admin workaround
  - Added Git Bash one-liner for display_name lookup
  - Updated all Common Operations (Set Pro, Revert Free, Reset Voice) with display_name WHERE clauses
  - Added "Entra Token Configuration (Critical)" section documenting the root cause and fix
  - Updated identity column descriptions to reflect current state

  **Already in place (from earlier today):**
  - APIM policies: 12 operations extract `emails` → `email` → `preferred_username` into `X-User-Email` header
  - Backend `jwtDecode.js`: `emails[]` → `email` → `preferred_username` fallback chain
  - Backend `userService.js`: Writes email via `COALESCE($2, email)` — preserves existing data

  **Files modified:**
  - `mobile/app/lib/src/services/backend_service.dart`: JWT payload decode + email/name header extraction in Dio interceptor
  - `mobile/app/lib/src/services/auth_service.dart`: `emails` array handling in `_handleAuthResult()`
  - `docs/USER_SUBSCRIPTION_MANAGEMENT.md`: display_name lookups + Entra config documentation

  **Verification:** Open app, make any API call, then: `SELECT id, email, display_name, last_login_at FROM users ORDER BY last_login_at DESC LIMIT 5;`

- **Backend Security Hardening** (Feb 24): Applied 9 targeted security fixes to `backend/functions/index.js` based on the independent code review (`docs/independent_code_review.md`). Three categories of fixes:

  **1. Webhook Authentication (fail-closed + mandatory signature verification):**
  - `subscription-webhook`: Missing `REVENUECAT_WEBHOOK_SECRET` now returns 500 (was: warn and continue processing unsigned events)
  - `subscription-webhook`: Missing `X-RevenueCat-Webhook-Signature` header now returns 401 (was: skip verification entirely, allowing any unsigned request through)
  - `subscription-webhook`: Signature verification is now unconditional — every webhook must have a valid HMAC-SHA256 signature (was: conditional on both secret AND header being present)

  **2. Information Disclosure Removal (7 locations):**
  - `vision-analyze`: Removed unconditional `stack: error.stack` from error response (critical — exposed full stack traces to any caller)
  - `ask-bartender-simple`, `voice-bartender`, `refine-cocktail`, `speech-token`: Removed `details: process.env.NODE_ENV === 'development' ? error.stack : undefined` from error responses (defense-in-depth)
  - `test-mi-access`: Removed conditional `stack` field from error response
  - `voice-realtime-test`: Removed conditional `stack` field from error response; also removed `details: responseText` (raw Azure OpenAI API error body) and `sessionsUrl` (internal Azure endpoint URL)
  - `vision-analyze` (inner catch): Replaced `message: axiosError.message, details: axiosError.response?.data` (raw Claude API payload) with generic `message: 'Image analysis service unavailable'`

  **3. Input Size Validation (3 endpoints):**
  - `ask-bartender-simple`: Message must be under 2,000 characters; inventory JSON must be under 10KB
  - `refine-cocktail`: Cocktail name under 200 chars, max 50 ingredients, instructions under 5,000 chars
  - `vision-analyze`: Base64 image must be under 10MB; URL-fetched image must be under 10MB (checked after download, before base64 encoding)

  All changes are purely additive guards — legitimate requests under the limits pass through unchanged. Server-side logging (`context.error()`) still captures full error details for debugging.

  **File modified:**
  - `backend/functions/index.js`: 80 insertions, 38 deletions

  **Commit:** `f937881` — `fix(backend): Harden API security — webhook auth, stack trace removal, input validation`

- **Branded Splash Screen** (Feb 23): Added a branded native splash screen for both iOS and Android using the `flutter_native_splash` package. Replaces the default white placeholder launch image with the app icon centered on the primary purple brand background (`#7C3AED`). This clears the Xcode build warning about the default placeholder launch image. Configuration is YAML-driven in `pubspec.yaml` — the generator produces all native assets automatically (iOS `LaunchImage.imageset` PNGs, Android drawable XMLs, Android 12+ splash styles).

  **New dependency (dev):**
  - `flutter_native_splash: ^2.4.4`

  **Files modified:**
  - `mobile/app/pubspec.yaml`: Added `flutter_native_splash` dev dependency and `flutter_native_splash:` configuration section

  **Auto-generated files:**
  - `mobile/app/ios/Runner/Assets.xcassets/LaunchImage.imageset/`: Replaced placeholder PNGs with branded icon-on-purple images (1x, 2x, 3x)
  - `mobile/app/android/app/src/main/res/drawable/launch_background.xml`: Updated with splash image reference
  - `mobile/app/android/app/src/main/res/drawable-v21/launch_background.xml`: Updated for Android 5+
  - `mobile/app/android/app/src/main/res/values-v31/styles.xml`: New — Android 12+ splash screen styles
  - `mobile/app/android/app/src/main/res/values-night-v31/styles.xml`: New — Android 12+ dark mode splash styles
  - `mobile/app/android/app/src/main/res/drawable-*/`: Splash image density variants

- **Deep Link Domain Verification Fix** (Feb 23): Fixed Google Play Console reporting 2 unverified domains and 2 broken deep links. Three root causes addressed:
  1. **Split AndroidManifest intent-filters**: Custom scheme (`mybartender://`) and HTTPS App Link were combined in a single `<intent-filter>`, causing Android's Cartesian product behavior to generate a phantom `cocktail` domain entry. Split into two separate intent-filters — one for custom scheme (no verification), one for HTTPS with `autoVerify="true"`.
  2. **Created `assetlinks.json` endpoint**: Added new `well-known-assetlinks` Azure Function serving Digital Asset Links JSON at `/.well-known/assetlinks.json` with correct package name (`ai.mybartender.mybartenderai`) and SHA-256 signing certificate fingerprint. Configured via:
     - New APIM operation (`well-known-assetlinks`) for the path
     - New Front Door dedicated route (`route-well-known`) matching `/.well-known/*` → `og-apim` origin group with `/api` origin path
     - Also added `WellKnownRewrite` rule set on `route-default` as fallback
  3. **Fixed Android package name**: Corrected all 3 occurrences of `com.mybartenderai.app` → `ai.mybartender.mybartenderai` in `cocktail-preview/index.js` (meta tag, Google Play links).

  **Files modified:**
  - `mobile/app/android/app/src/main/AndroidManifest.xml`: Split combined intent-filter into two
  - `backend/functions/index.js`: Added `well-known-assetlinks` function registration
  - `backend/functions/cocktail-preview/index.js`: Fixed package name (3 occurrences)
  - `mobile/app/pubspec.yaml`: Build number 12 → 13

  **Azure infrastructure changes:**
  - Deployed updated functions to `func-mba-fresh`
  - Created APIM operation for `/.well-known/assetlinks.json`
  - Created Front Door route `route-well-known` (`/.well-known/*` → `og-apim`)
  - Created Front Door rule set `WellKnownRewrite` with URL rewrite rule on `route-default`
  - Verified: `https://share.mybartenderai.com/.well-known/assetlinks.json` returns valid JSON

- **Multi-Layer 403 Entitlement Defense** (Feb 22): Implemented a 3-layer server-side entitlement enforcement system to replace the broken client-side subscription gate. Previously, unpaid users hitting a backend AI endpoint saw raw `DioException` errors. Now, 403 `entitlement_required` responses are caught, typed, and surfaced as clean paywall UI on each screen. Three layers:
  1. **Layer 1 — Dio Interceptor** (`backend_service.dart`): `onError` handler inspects 403 responses for `{ error: 'entitlement_required' }`. Wraps in typed `EntitlementRequiredException` via `handler.reject()` so downstream code can catch by type instead of parsing HTTP status codes. Also invokes `onEntitlementRequired` callback (wired in `backend_provider.dart`) to trigger Layer 3.
  2. **Layer 2 — Per-Screen Handlers**: Each AI feature screen catches `EntitlementRequiredException` and shows a contextual paywall:
     - **Smart Scanner** (`smart_scanner_screen.dart`): Shows `showSubscriptionSheet()` modal
     - **Create Studio** (`edit_cocktail_screen.dart`): Shows `showSubscriptionSheet()` modal during AI refinement
     - **Ask Bartender** (`chat_provider.dart` + `ask_bartender_screen.dart`): Adds a `ChatMessage` with `isEntitlementRequired: true`, which renders a "View Plans" button inline in the chat bubble
  3. **Layer 3 — RevenueCat State Sync** (`subscription_service.dart`): When a 403 fires, `Purchases.invalidateCustomerInfoCache()` marks the local RevenueCat cache as stale, then `refreshStatus()` fetches fresh entitlement data from RevenueCat servers. This corrects any client/server state divergence (sandbox expiry, manual DB override, init failure).

  **Exception Unwrapping Pattern**: Dio wraps custom exceptions inside `DioException.error`. Each API class (`vision_api.dart`, `create_studio_api.dart`, `backend_service.dart:askBartender`) includes `if (e.error is EntitlementRequiredException) throw e.error as EntitlementRequiredException;` to unwrap before the per-screen handlers see it.

  **New file:**
  - `mobile/app/lib/src/exceptions/entitlement_exception.dart`: Typed exception class for 403 entitlement responses

  **Files modified (mobile):**
  - `mobile/app/lib/src/services/backend_service.dart`: Dio `onError` interceptor + `onEntitlementRequired` callback + `askBartender()` exception unwrap
  - `mobile/app/lib/src/providers/backend_provider.dart`: Wired `onEntitlementRequired` to invalidate `subscriptionStatusProvider` and refresh RevenueCat
  - `mobile/app/lib/src/services/subscription_service.dart`: Added `Purchases.invalidateCustomerInfoCache()` to `refreshStatus()`
  - `mobile/app/lib/src/api/vision_api.dart`: Exception unwrap before 429 check
  - `mobile/app/lib/src/api/create_studio_api.dart`: Exception unwrap in `refineCocktail()`
  - `mobile/app/lib/src/features/smart_scanner/smart_scanner_screen.dart`: `on EntitlementRequiredException` catch → subscription sheet
  - `mobile/app/lib/src/features/create_studio/edit_cocktail_screen.dart`: `on EntitlementRequiredException` catch → subscription sheet
  - `mobile/app/lib/src/features/ask_bartender/models/chat_message.dart`: Added `isEntitlementRequired` boolean field
  - `mobile/app/lib/src/features/ask_bartender/providers/chat_provider.dart`: `on EntitlementRequiredException` catch → CTA message
  - `mobile/app/lib/src/features/ask_bartender/ask_bartender_screen.dart`: "View Plans" button on entitlement-required chat bubbles

- **Build 12 Paywall Regression Fix** (Feb 22): Fixed critical bug where Build 12 showed the paywall on every feature tap, even for active subscribers. Build 11 worked correctly. Root cause: an uncommitted `_gatedNavigate()` function in `home_screen.dart` wrapped ALL feature navigation behind `isPaidProvider`, which reads from the RevenueCat SDK's local cache — NOT the backend PostgreSQL database. If RevenueCat didn't recognize the user as paid (init failure, stale cache, sandbox expiry, or manual DB override), every feature was blocked. Additionally, local-only features (Recipe Vault, My Bar, Favorites) that use the SQLite database and never call the backend were also incorrectly gated. Fix: Reverted `home_screen.dart` to the last committed version, removing `_gatedNavigate` entirely. The 3-layer 403 defense (see above) is the correct gating mechanism — it lets users navigate freely and only shows the paywall when the backend actually returns a 403.

  **File modified:**
  - `mobile/app/lib/src/features/home/home_screen.dart`: Removed `_gatedNavigate()`, restored direct `onTap: () => context.go(...)` navigation on all feature tiles

- **Beta Tester Database Update** (Feb 22): Updated 3 beta tester accounts in PostgreSQL (`pg-mybartenderdb`) to active subscriber status so they can test all features. Set `entitlement = 'paid'`, `subscription_status = 'active'`, `tier = 'pro'` for genewhitley2017@gmail.com, genewhitley@me.com, and pwhitley@me.com. Left pwhitley@xtend-ai.com (Paula A Whitley) as `entitlement = 'none'`, `subscription_status = 'none'`, `tier = 'free'` to serve as a test account for verifying the unpaid user paywall experience. No code changes — database-only update.

- **RevenueCat Cross-Platform Setup — Backend + Flutter Code Changes** (Feb 19): Implemented platform-aware RevenueCat initialization for both Google Play and Apple App Store, fixed voice-purchase product ID mismatch, and stored iOS API key in Azure Key Vault. Store-side product creation (Google Play Console, App Store Connect) and RevenueCat dashboard configuration (entitlements, offerings, product mapping) remain manual steps — see `docs/REVENUECAT_PLAN.md` for the full checklist.

  **Azure Infrastructure:**
  1. Stored `REVENUECAT-APPLE-API-KEY` (`appl_...`) in `kv-mybartenderai-prod`
  2. Linked `REVENUECAT_PUBLIC_API_KEY_IOS` app setting on `func-mba-fresh` via Key Vault reference
  3. Restarted Function App to pick up new setting

  **Backend code changes:**
  1. **voice-purchase product ID fix** (`voice-purchase/index.js:31-33`): Changed `PRODUCT_ID` from `voice_minutes_20` to `voice_minutes_60`, replaced `SECONDS_PER_PURCHASE = 1200` with `MINUTES_PER_PURCHASE = 60`, updated INSERT query and success message. Flutter was already sending `voice_minutes_60` but the endpoint rejected it
  2. **subscription-config dual keys** (`index.js:3987-4006`): Now reads `REVENUECAT_PUBLIC_API_KEY_IOS` from environment and returns both `revenueCatApiKey` (Android) and `revenueCatAppleApiKey` (iOS) in the response. Logs a warning if iOS key is missing — Android still works

  **Flutter code changes:**
  1. **SubscriptionConfig model** (`backend_service.dart:360-373`): Added nullable `revenueCatAppleApiKey` field, parsed from `config['revenueCatAppleApiKey']`
  2. **Platform-aware key selection** (`subscription_service.dart:76-78`): Added `dart:io Platform` import. Uses `config.revenueCatAppleApiKey` on iOS, `config.revenueCatApiKey` on Android. Throws if iOS key is null
  3. **iOS voice purchase path** (`purchase_service.dart`): Added `_purchaseVoiceMinutesIOS()` method using RevenueCat SDK (`purchases_flutter` imported as `rc` to avoid namespace collision with `in_app_purchase`). iOS StoreKit receipts can't be verified by Google Play API, so iOS uses RevenueCat — the webhook handles crediting 60 minutes. Android flow unchanged
  4. **Optional onVerifyPurchase** (`purchase_service.dart:64`): Changed from `required` to optional — iOS doesn't need direct backend verification
  5. **iOS quota refresh** (`purchase_provider.dart:36-63`): Added `dart:io Platform` import. Passes `null` for `onVerifyPurchase` on iOS. Listens to `purchaseStream` and refreshes `voiceQuotaProvider` 2 seconds after success (gives webhook time to process)

  **Static analysis:** Zero new errors in modified files (409 total issues are all pre-existing).

  **Files modified (backend):**
  - `backend/functions/voice-purchase/index.js`: Product ID + minutes calculation fix
  - `backend/functions/index.js`: Dual API key response in subscription-config

  **Files modified (mobile):**
  - `mobile/app/lib/src/services/backend_service.dart`: SubscriptionConfig model
  - `mobile/app/lib/src/services/subscription_service.dart`: Platform-aware key selection
  - `mobile/app/lib/src/services/purchase_service.dart`: iOS RevenueCat purchase path
  - `mobile/app/lib/src/providers/purchase_provider.dart`: iOS verification skip + quota refresh

  **Remaining manual steps** (see `docs/REVENUECAT_PLAN.md`):
  - Google Play Console: Create `pro_monthly`, `pro_annual` subscriptions + `voice_minutes_60` consumable
  - App Store Connect: Create `voice_minutes_60` consumable (subscriptions already exist)
  - RevenueCat Dashboard: Map products, configure `paid` entitlement, configure Default offering with `$rc_monthly`/`$rc_annual` packages, verify webhook
  - Deploy updated backend to `func-mba-fresh`

- **RevenueCat Google Play Integration** (Feb 18): Completed first-time RevenueCat setup for Google Play subscriptions. This was a dashboard/CLI-only change — no source code was modified. Steps completed:
  1. **RevenueCat account**: Created project, connected Google Play Store app (package `ai.mybartender.mybartenderai`)
  2. **Google Cloud service account**: Created `revenuecat@myaibartender.iam.gserviceaccount.com` with Pub/Sub Editor + Monitoring Viewer roles. Generated JSON key and uploaded to RevenueCat for purchase verification
  3. **Google Play Console**: Invited service account under Users and permissions with financial access
  4. **Entitlement**: Created `paid` entitlement (matches `_paidEntitlement = 'paid'` in `subscription_service.dart`)
  5. **Offerings**: Default offering configured with Monthly ($7.99) + Yearly ($79.99) packages (marked as current)
  6. **API key stored**: RevenueCat public API key (`goog_...`) stored in Azure Key Vault as `REVENUECAT-PUBLIC-API-KEY`
  7. **Function App linked**: Added `REVENUECAT_PUBLIC_API_KEY` app setting to `func-mba-fresh` with `@Microsoft.KeyVault(SecretUri=...)` reference
  8. **Enabled Google APIs**: `androidpublisher`, `playdeveloperreporting`, `pubsub`, `iam`, `cloudresourcemanager`

  **Apple App Store setup pending** — requires App Store Connect app creation, In-App Purchase key, and separate RevenueCat `appl_...` API key. Backend + Flutter code changes needed for platform-specific keys.

  **No files modified.** All configuration was external (RevenueCat dashboard, Google Cloud Console, Google Play Console, Azure CLI).

- **Smart Scanner 8-Bottle Limit Guidance** (Feb 18): Added instruction text advising users to scan 8 bottles or fewer at a time for best results. Testing showed Claude Haiku vision accuracy degrades with more than 8 bottles in frame. The existing instruction text now includes a second sentence: "For best results, scan 8 bottles or fewer at a time."

  **File modified:**
  - `mobile/app/lib/src/features/smart_scanner/smart_scanner_screen.dart`: Updated instruction text (line 171)

- **In-App Review & Feedback Flow** (Feb 17): Implemented best-practice in-app review prompting with a two-step UX ("Are you enjoying My AI Bartender?" pre-prompt) that routes happy users to the OS review dialog and unhappy users to a feedback email. Uses `in_app_review` package for cross-platform App Store / Play Store review prompts. Features:
  1. **Eligibility gate**: Requires >= 2 sessions across >= 2 distinct days, >= 1 win moment, 30-day cooldown between prompts, 60-day cooldown after unhappy signals, lifetime cap of 3 prompts
  2. **6 win moment hooks**: Smart Scanner success, Create Studio save, sharing success, favorites >= 3, AI Chat (3+ exchanges), Voice session > 45s
  3. **Session tracking**: `ReviewService` registers as a separate `WidgetsBindingObserver` (independent from `AppLifecycleService`) with 30-minute debounce
  4. **Persistence**: SharedPreferences keys for session counts, win moments, cooldown timestamps
  5. **Feedback flow**: Reuses existing `support@xtend-ai.com` email pattern from profile screen via `url_launcher`
  6. **Logging**: `developer.log()` with `[REVIEW]` prefix for all events (no analytics infrastructure needed)
  7. **Build number**: `1.0.0+11` → `1.0.0+12`

  **New files:**
  - `lib/src/services/review_service.dart`: Core singleton — eligibility gate, persistence, session tracking, OS review + email feedback
  - `lib/src/providers/review_provider.dart`: Riverpod providers (`reviewServiceProvider`, `reviewEligibleProvider`)
  - `lib/src/widgets/review_prompt_dialog.dart`: Pre-prompt dialog (static `show()`, follows `PurchaseSuccessDialog` pattern)

  **Modified files:**
  - `mobile/app/pubspec.yaml`: Added `in_app_review: ^2.0.10`, build number → +12
  - `lib/src/providers/providers.dart`: Added `review_provider.dart` export
  - `lib/src/providers/auth_provider.dart`: `ReviewService.instance.initialize()` alongside `AppLifecycleService`
  - `lib/src/features/smart_scanner/smart_scanner_screen.dart`: `scannerSuccess` win moment + prompt
  - `lib/src/features/create_studio/edit_cocktail_screen.dart`: `createStudioSave` win moment (prompt deferred)
  - `lib/src/features/create_studio/widgets/share_recipe_dialog.dart`: `sharingSuccess` win moment
  - `lib/src/providers/favorites_provider.dart`: `favoritesThreshold` win moment when count >= 3
  - `lib/src/providers/voice_ai_provider.dart`: `voiceSessionComplete` win moment when duration >= 45s
  - `lib/src/features/ask_bartender/chat_screen.dart`: `aiChatSave` win moment after 3 successful exchanges

  **Spec:** See `docs/Review.md` for the full codebase-grounded implementation spec.

- **Free Trial Guardrailed Limits** (Feb 16): Implemented server-side enforcement of reduced quotas for 3-day free trial users to prevent API abuse during trials. Trial users now get 10 voice minutes (vs 60), 20,000 chat tokens (vs 1,000,000), and 5 scanner scans (vs 100). Changes:
  1. **Subscription webhook** (`index.js`): `INITIAL_PURCHASE` handler now detects `period_type === 'TRIAL'` from RevenueCat payload and sets `subscription_status = 'trialing'` with `monthly_voice_minutes_included = 10`. `RENEWAL` handler explicitly sets full paid limits (60 min, 1M tokens, 100 scans)
  2. **Centralized quotas** (`userService.js`): Added `trialing` entry to `ENTITLEMENT_QUOTAS` with reduced limits. `getEntitlementQuotas()` now accepts optional `subscriptionStatus` parameter for trial-aware lookup
  3. **Scan enforcement** (`vision-analyze/index.js`): Passes `user.subscriptionStatus` to get trial-aware 5-scan limit
  4. **Chat token enforcement** (`pgTokenQuotaService.js`): Both `getMonthlyCap()` and `getCurrentUsage()` query `subscription_status` and apply 20K token cap for trial users
  5. **Voice enforcement**: No code changes needed — webhook sets `monthly_voice_minutes_included = 10` in DB, existing `get_remaining_voice_minutes()` reads from DB
  6. **Mobile UX**: Trial-specific "limit reached" messages for Smart Scanner (`VisionQuotaExceededException`), Chat (updated 429 message), and Voice AI (trial-aware quota exhausted prompt)
  7. **No DB migration needed**: Reuses existing `subscription_status` column and `'trialing'` constraint from migration 011

  **Files modified (backend):**
  - `backend/functions/index.js`: Webhook INITIAL_PURCHASE and RENEWAL blocks
  - `backend/functions/services/userService.js`: ENTITLEMENT_QUOTAS + getEntitlementQuotas()
  - `backend/functions/vision-analyze/index.js`: Pass subscriptionStatus
  - `backend/functions/services/pgTokenQuotaService.js`: getMonthlyCap() + getCurrentUsage()

  **Files modified (mobile):**
  - `mobile/app/lib/src/api/vision_api.dart`: VisionQuotaExceededException class
  - `mobile/app/lib/src/features/smart_scanner/smart_scanner_screen.dart`: Trial-specific scan limit message
  - `mobile/app/lib/src/features/ask_bartender/providers/chat_provider.dart`: Trial-specific chat limit message
  - `mobile/app/lib/src/features/voice_ai/voice_ai_screen.dart`: Trial-aware quota exhausted prompt

  **Deployment**: Backend deployed to `func-mba-fresh` (35 functions synced, health check passed). Release AAB (68.7MB) built for Play Store beta.

- **Android Release Signing Setup** (Feb 16): Created release signing keystore (`upload-keystore.jks`) and `key.properties` for signed release builds. Built release APK (93.4MB) and AAB (68.7MB) for Google Play Store deployment. `build.gradle.kts` updated to make signing config conditional on keystore existence.

- **Voice AI WebRTC Type Error Fix** (Feb 15): Fixed critical iOS-only crash where Voice AI failed to connect with `type '() => RTCRtpSender' is not a subtype of type '(() => RTCRtpSenderNative)?' of 'orElse'`. Introduced by the BUG-011 fix (iOS background audio capture). On iOS, `flutter_webrtc`'s `getSenders()` returns `List<RTCRtpSenderNative>` (concrete platform subclass), and Dart's `firstWhere` method expected the `orElse` closure to return `RTCRtpSenderNative`, but Dart inferred `() => RTCRtpSender` (abstract supertype). Fix: Removed the `orElse` callback — it was unnecessary since `addTrack()` guarantees the audio sender exists. Without `orElse`, `firstWhere` throws a `StateError` on failure (caught by existing try/catch), rather than a confusing type error. Android was unaffected.

  **File modified:**
  - `mobile/app/lib/src/services/voice_ai_service.dart`: Removed `orElse` callback from `senders.firstWhere()` (1 line)

  See `docs/BUG_FIXES.md` (BUG-012) for full details.

- **Voice AI iOS Background Audio Mute Fix** (Feb 15): Fixed iOS-only bug where Voice AI captured and transcribed background audio (TV dialogue, nearby conversations) even when the push-to-talk button was not held down. On iOS, `track.enabled = false` on a WebRTC audio track doesn't fully silence the stream — the microphone hardware stays active with `AVAudioSession` in `playAndRecord` + `voiceChat` mode. Additionally, the `conversation.item.input_audio_transcription.completed` event handler had no `_isMuted` check, so leaked audio transcripts appeared in the UI. Android was unaffected (its audio HAL properly silences disabled tracks). Two-layer defense applied:
  1. **Transcript guard**: Added `_isMuted` check on the transcript completion handler — drops background transcripts at the event level before they reach the UI
  2. **iOS `replaceTrack(null)`**: On mute, swaps the audio sender's track to `null` so the WebRTC connection sends silence frames instead of microphone data. On unmute, restores the original audio track. Prevents Azure from processing leaked audio (saves tokens and avoids AI context confusion)
  3. **`_audioSender` field**: Stores the `RTCRtpSender` reference after `addTrack()` via `getSenders()` for use in `replaceTrack`
  4. **Cleanup**: `_audioSender` reset to `null` in `_cleanup()` to prevent stale references across sessions
  5. **Build number bump**: `pubspec.yaml` version `1.0.0+10` → `1.0.0+11`

  **File modified:**
  - `mobile/app/lib/src/services/voice_ai_service.dart`: 5 changes (transcript guard, _audioSender field, getSenders capture, replaceTrack in setMicrophoneMuted, cleanup reset)
  - `mobile/app/pubspec.yaml`: Build number bump to +11

  See `docs/BUG_FIXES.md` (BUG-011) for full details.

- **Voice AI Push-to-Talk Interruption Fix** (Feb 15): Fixed Voice AI "repeating itself" bug where interrupting the AI mid-sentence via push-to-talk caused duplicate/truncated messages in the transcript. When the user pressed the push-to-talk button while the AI was speaking, `_prepareForNewUtterance()` sent `response.cancel` to Azure but did not clean up the partial transcript that was already streaming. The `response.audio_transcript.done` event still fired for the cancelled response, permanently adding truncated text to the conversation. Then the new response naturally started with similar context, creating the "repeating" illusion. Nine changes applied across two files:
  1. **State-tracking flags**: Added `_responseInProgress` and `_responseCancelled` booleans to `VoiceAIService`
  2. **Cancellation cleanup in `_prepareForNewUtterance()`**: After `response.cancel`, marks response as cancelled, clears the StringBuffer, emits empty-text signal to remove partial UI message
  3. **Guard on `_commitAudioBuffer()`**: Prevents duplicate `response.create` events if a response is already in progress
  4. **Cancelled transcript filtering**: `response.audio_transcript.delta` and `response.audio_transcript.done` handlers skip events from cancelled responses
  5. **`response.done` handler**: Resets `_responseInProgress` flag
  6. **`response.cancelled` handler**: Properly cleans up all state flags and StringBuffer
  7. **`_cleanup()` resets**: Both flags and StringBuffer cleared on session teardown
  8. **Provider cancellation signal**: `_handleTranscript()` in provider removes partial assistant message when empty-text final signal received
  9. **Build number bump**: `pubspec.yaml` version `1.0.0+9` → `1.0.0+10`

  **Files modified:**
  - `mobile/app/lib/src/services/voice_ai_service.dart`: 8 changes (flags, guards, event filters, cleanup)
  - `mobile/app/lib/src/providers/voice_ai_provider.dart`: 1 change (empty-text cancellation signal handling)
  - `mobile/app/pubspec.yaml`: Build number bump to +10

  See `docs/BUG_FIXES.md` (BUG-010) for full details.

- **Create Studio Subtitle Text Update** (Feb 14): Updated the Create Studio banner subtitle from "Add your personal custom cocktail recipes here." to "Your personal recipe book — build and save your own cocktails" to better communicate the screen's purpose. The original text ("Craft your signature cocktails with AI-powered refinement") was too vague and AI-focused, confusing users about whether this was a creation tool or an AI feature. The new copy leads with a warm metaphor ("recipe book") and clearly states what users can do.

  **File modified:**
  - `mobile/app/lib/src/features/create_studio/create_studio_screen.dart`: Updated subtitle text in banner section

- **Voice Session "Last Session Wins" Auto-Close + Parameter Type Fix** (Feb 13): Replaced the 409 Conflict concurrent session block with a "last session wins" auto-close strategy, then fixed a PostgreSQL parameter type error (`could not determine data type of parameter $3`) in the `usage_tracking` INSERT. In a mobile-only app, when the user taps "Talk," any previous active session is definitionally dead (WebRTC/audio/state already destroyed client-side). Instead of blocking with 409, the `voice-session` function now: (1) auto-expires stale sessions >2h via `close_user_stale_sessions()`, (2) auto-closes any remaining active session with `status = 'expired'` and bills 30% of wall-clock time, (3) logs the auto-close with `billing_method: 'last_session_wins'` in `usage_tracking`, then (4) creates the new session. The parameter type fix adds explicit casts (`$3::text`, `$4::integer`) inside `jsonb_build_object()` — PostgreSQL's `VARIADIC "any"` signature can't infer types from parameterized placeholders without column context.

  **File modified:**
  - `backend/functions/index.js`: Replaced 409 block with auto-close logic; added `::text` and `::integer` casts in `jsonb_build_object()`

  See `docs/BUG_FIXES.md` (BUG-009) for full details.

- **Home Screen "Scan My Bar" Rename** (Feb 12): Renamed the Scanner tile in the AI Cocktail Concierge grid from "Scanner" to "Scan My Bar" to better communicate the feature's purpose. Subtitle "Identify bottles" unchanged. This change applies only to the home screen — the My Bar screen's Scanner button remains as-is.

  **File modified:**
  - `mobile/app/lib/src/features/home/home_screen.dart`: Updated title in `_buildActionButton()` call for the Scanner tile

- **Home Screen Concierge Grid Reorder** (Feb 12): Swapped the vertical positions of the four AI Cocktail Concierge action buttons on the home screen to promote Scanner and Create to the top row. Previous layout had Chat + Voice on top and Scanner + Create on bottom. New layout places Scanner (left) + Create (right) on the top row and Chat (left) + Voice (right) on the bottom row. This prioritizes the most actionable features (scan a bottle, design a cocktail) in the prime visual position. No logic, styling, or routing changes — only the order of `_buildActionButton()` calls within the two `Row` widgets was swapped.

  **File modified:**
  - `mobile/app/lib/src/features/home/home_screen.dart`: Reordered `_buildActionButton()` calls in `_buildConciergeSection()`

- **APIM JWT Security Complete + Mobile Auth Fix** (Feb 11): Completed the APIM security audit Phase 2 by deploying `validate-jwt` policies to all 13 previously-unprotected operations, AND fixed a critical mobile app bug where 4 API providers were sending requests without JWT tokens. All 30 APIM operations now have appropriate security: 13 newly protected + 12 previously protected + 5 intentionally public.

  **Mobile App Fix (Root Cause):**
  After deploying Batch 1+2 JWT policies, chat broke because the mobile app's `askBartenderApiProvider` used a bare `dioProvider` from `bootstrap.dart` that had no auth interceptor. Before `validate-jwt` was deployed, APIM passed tokenless requests through. Now APIM correctly rejects them with 401. The audit found 3 additional providers with the same pattern.

  Four providers fixed — all now use `backendServiceProvider.dio` (which has the JWT interceptor):
  1. `askBartenderApiProvider` in `ask_bartender_api.dart` (Chat — `/v1/ask-bartender-simple`)
  2. `recommendApiProvider` in `recommend_api.dart` (Recommendations — `/v1/recommend`)
  3. `createStudioApiProvider` in `create_studio_api.dart` (Create Studio — `/v1/create-studio/refine`)
  4. `visionApiProvider` in `vision_provider.dart` (Smart Scanner — `/v1/vision-analyze`)

  **APIM Batch Deployment:**
  - Batch 1 (subscription-config, subscription-status): Previously deployed
  - Batch 2 (ask-bartender, ask-bartender-simple, recommend, refine-cocktail): Previously deployed
  - Batch 3 (vision-analyze, speech-token, voice-bartender): Deployed Feb 11
  - Batch 4 (social-connect-start, social-share-external, auth-exchange, auth-rotate): Deployed Feb 11

  **Files modified:**
  - `mobile/app/lib/src/api/ask_bartender_api.dart`: Switched from bare `dioProvider` to `backendServiceProvider.dio`
  - `mobile/app/lib/src/api/recommend_api.dart`: Same fix
  - `mobile/app/lib/src/api/create_studio_api.dart`: Same fix
  - `mobile/app/lib/src/providers/vision_provider.dart`: Same fix

  **Cleanup:** 9 temporary diagnostic scripts removed from `infrastructure/apim/scripts/`.

  See `docs/BUG_FIXES.md` (BUG-008) and `docs/APIM_SECURITY_USER_PROFILE_PLAN.md` for full details.

- **Server-Side Authoritative Voice Metering** (Feb 11): Hardened voice billing to prevent quota abuse. Previously, the backend trusted the client-reported `durationSeconds` without validation (CWE-602). A modified client could report 0 duration for unlimited free voice minutes, or never call `/v1/voice/usage` to leave sessions active with 0 billed. Now all duration computation happens in PostgreSQL using server-controlled timestamps (`NOW() - started_at`). Five changes applied:
  1. **SQL migration `010_voice_metering_server_auth.sql`**: New server-authoritative `record_voice_session()` that computes wall-clock time as a tamper-proof ceiling, caps client duration, and returns billing transparency. New `expire_stale_voice_sessions()` and `close_user_stale_sessions()` functions. Added `'expired'` status. Updated `check_voice_quota()` and `voice_usage_summary` to count expired sessions
  2. **Concurrent session enforcement**: Before creating a new voice session, stale sessions (>2h) are auto-expired and any remaining active session is auto-closed (~~returns **409 Conflict**~~ → replaced with "last session wins" auto-close on Feb 13, see above)
  3. **Billing result capture**: `/v1/voice/usage` now returns `billing.billedSeconds`, `billing.wallClockSeconds`, `billing.clientReportedSeconds`, and `billing.method` for full audit transparency
  4. **Hourly cleanup timer**: New `voice-session-cleanup` timer function runs every hour, expiring stale sessions that clients never closed. Bills 30% of wall-clock time as a conservative estimate
  5. **Flutter 409 handling**: Client handles 409 Conflict with user-friendly error message (no longer triggered after Feb 13 "last session wins" change), and logs server billing details for debugging

  **Files modified:**
  - `backend/functions/migrations/010_voice_metering_server_auth.sql` (NEW): Server-authoritative SQL functions
  - `backend/functions/index.js`: Concurrent session check, billing capture, cleanup timer
  - `mobile/app/lib/src/services/voice_ai_service.dart`: Handle 409, log server billing

  **Deployment**: Migration applied to `pg-mybartenderdb`, `func-mba-fresh` redeployed (35 functions: 33 HTTP + 2 timers), release APK built.

  See `docs/BUG_FIXES.md` (BUG-007) and `docs/VOICE_AI_IMPLEMENTATION.md` for full details.

- **Voice Minutes Counter Fix** (Feb 9): Fixed critical client-side bug where the voice minutes counter never decremented from 60 minutes despite active use. Database investigation showed `monthly_used_seconds = 0`, 8/10 sessions stuck at `active` status with NULL `duration_seconds`, and 2/10 completed with `duration_seconds = 0`. Backend was working correctly — the mobile app never called `/v1/voice/usage` to report session duration. Three changes applied:
  1. **`dispose()` method** added to `VoiceAIScreen`: Ends active session when widget unmounts (e.g., system back gesture, app lifecycle), ensuring `/v1/voice/usage` POST fires even if the PopScope dialog didn't trigger
  2. **`PopScope` navigation guard**: Wraps the Scaffold to intercept back navigation during active sessions. Shows "End Voice Session?" confirmation dialog; on confirm, awaits `endSession()` before popping. When no session is active, back navigation proceeds normally
  3. **Wall-clock duration fallback** in `VoiceAIService.endSession()`: If active speech metering reports 0 seconds but the session lasted >10 seconds, falls back to 30% of wall-clock time as a conservative estimate. Catches edge cases where Azure VAD `speech_started` events never fired (push-to-talk timing, short interactions)
  4. **Quota state nulling** in `VoiceAINotifier.endSession()`: Replaced `state.copyWith()` with direct `VoiceAISessionState()` construction so the stale `quota` field becomes null, forcing the UI to use the freshly-fetched `voiceQuotaProvider` value. `copyWith` uses `??` operator so it cannot null out existing non-null fields

  **Files modified:**
  - `lib/src/features/voice_ai/voice_ai_screen.dart`: Added `dispose()` + `PopScope` wrapper
  - `lib/src/services/voice_ai_service.dart`: Added wall-clock fallback for 0-duration sessions
  - `lib/src/providers/voice_ai_provider.dart`: Direct state construction to null out stale quota

  See `docs/BUG_FIXES.md` (BUG-006) for full technical details.

- **Facebook Identity Provider Removed** (Feb 9): Removed Facebook as a sign-in option from Entra External ID. Facebook OAuth integration had persistent configuration issues: testers encountered redirect URI errors during login, and public users saw "App not active" errors because the Facebook app was still in development mode. Rather than pursue Facebook's App Review process (which requires business verification, privacy policy review, and multi-week approval timelines), Facebook was removed from the identity providers list in the Entra portal. Users can still sign up and sign in via Email + Password or Google. No code changes required — portal-only change. Existing users who originally signed up via Facebook can still access their accounts by using the same email address with the Email + Password flow.

  **Portal change:**
  - Entra External ID → External Identities → All identity providers → Facebook removed
  - User flow `mba-signin-signup` → Facebook removed from sign-in options

- **Custom Cocktail Photo Thumbnail Fix** (Feb 7): Fixed custom cocktail photos rendering too small on the Create Studio grid card thumbnails. Photos appeared at their intrinsic pixel size in the corner of the card instead of filling the thumbnail area. Root cause: `Image.file()` in the local file path branch of `CachedCocktailImage` lacked explicit `width` and `height` constraints. Added `width: double.infinity, height: double.infinity` so the image expands to fill its parent container, allowing `BoxFit.cover` to properly scale and crop.

  **File modified:**
  - `lib/src/widgets/cached_cocktail_image.dart`: Added width/height to `Image.file()` for local photos

- **Custom Cocktail Photo Capture** (Feb 7): Added the ability for users to photograph their custom cocktails and display those photos on the cocktail detail card, Create Studio grid, and in share messages. Photos are stored locally on device (no backend upload). Key changes:
  1. **New service**: `CocktailPhotoService` singleton saves/deletes photos to `{appDocDir}/cocktail_photos/{id}.jpg` using `path_provider`
  2. **Edit Cocktail Screen**: Photo section added at top of the create/edit form with camera and gallery buttons (via `image_picker`), live preview, and remove (X) button. `_photoRemoved` flag tracks explicit removal so the `imageUrl` field can be set to null on save
  3. **Cocktail Detail Screen**: Converted from `ConsumerWidget` to `ConsumerStatefulWidget`. Custom cocktails without a photo show a tappable "Tap to add photo" placeholder in the 300px hero area. Custom cocktails with a photo show a "Change" overlay button. After capture, the photo is saved to disk, the cocktail's `imageUrl` is updated in SQLite, and both `cocktailByIdProvider` and `customCocktailsProvider` are invalidated
  4. **CachedCocktailImage**: Added early-return check — if `imageUrl` starts with `/` or `file://`, uses `Image.file()` directly instead of the network/cache pipeline. This makes the Create Studio grid, detail screen, and any other consumer of this widget automatically display local photos
  5. **Enhanced sharing**: Custom cocktails with a local photo use `Share.shareXFiles()` to attach the image as a native file through the OS share sheet. Custom cocktails without a photo fall back to text-only sharing. Standard (non-custom) cocktails are unaffected
  6. **Photo cleanup on delete**: `create_studio_screen.dart` now calls `CocktailPhotoService.deletePhoto()` after deleting a custom cocktail from SQLite
  7. **No new dependencies**: Reuses existing `image_picker` (^1.1.2), `path_provider` (^2.1.5), and `share_plus` (^7.2.1). Camera settings match Smart Scanner pattern (`maxWidth: 1024, maxHeight: 1024, imageQuality: 85`)

  **Files modified:**
  - `lib/src/services/cocktail_photo_service.dart` (NEW): Photo file save/delete/check utilities
  - `lib/src/features/create_studio/edit_cocktail_screen.dart`: Photo picker UI in create/edit form
  - `lib/src/features/recipe_vault/cocktail_detail_screen.dart`: Tap-to-add-photo hero area + photo sharing
  - `lib/src/widgets/cached_cocktail_image.dart`: Local file path display support
  - `lib/src/features/create_studio/create_studio_screen.dart`: Photo cleanup on cocktail delete

  See `docs/CREATE_STUDIO_PHOTO_CAPTURE.md` for full implementation details.

- **Homescreen AI Button Visual Upgrade** (Feb 6): Increased the visual prominence of the four AI feature buttons (Chat, Voice, Scanner, Create) in the "AI Cocktail Concierge" section. Previously these buttons used the smallest text on the homescreen (12px), despite being the app's primary selling points. Two changes applied:
  1. **Font size increase**: Title style upgraded from `buttonSmall` (12px) to `cardTitle` (16px), subtitle from `caption` (12px) to `cardSubtitle` (14px) — now matches "My Bar" and "Favorites" typography in The Lounge section
  2. **Icon scaling**: Icon circles increased from 40px to 48px (`iconCircleAction`), icon size from 16px to 20px (`iconSizeAction`) — new named constants added to `AppSpacing` design system
  3. **Subtitle brightness fix**: Subtitle text color overridden from `textSecondary` (#E5E7EB) to `textPrimary` (#FFFFFF) via `.copyWith()` — the dark nested background (`backgroundSecondary` inside the Concierge card) made the default gray appear too dim. Visual hierarchy preserved through size (14px vs 16px) and weight (w400 vs w600) differences

  **Files modified:**
  - `mobile/app/lib/src/features/home/home_screen.dart`: Updated `_buildActionButton()` method — text styles, icon sizes, subtitle color
  - `mobile/app/lib/src/theme/app_spacing.dart`: Added `iconCircleAction` (48px) and `iconSizeAction` (20px) constants

- **Cocktail Detail Screen Icon Color Update** (Feb 6): Changed the three `SliverAppBar` icons (back arrow, share, favorites) on the cocktail detail screen from white (`textPrimary` #FFFFFF) to purple (`primaryPurple` #7C3AED). White outlined icons were nearly invisible when overlaid on bright cocktail photos. Purple provides high-saturation contrast against both light images and the dark collapsed app bar background. Favorited heart remains red (`accentRed`). Five color references updated across the normal, loading, and error states.

  **File modified:**
  - `mobile/app/lib/src/features/recipe_vault/cocktail_detail_screen.dart`: Replaced `AppColors.textPrimary` with `AppColors.primaryPurple` on 5 icon color references in SliverAppBar

- **Model Fallback Update** (Feb 4): Updated all hardcoded model fallback defaults from `gpt-4o-mini` to `gpt-4.1-mini` across 7 backend files (12 occurrences total). The old `gpt-4o-mini` model is being retired March 31, 2026. While production uses the `AZURE_OPENAI_DEPLOYMENT` environment variable correctly, these fallbacks ensure resilience if the env var fails to load. Files updated:
  - `index.js` (5 locations)
  - `ask-bartender-simple/index.js`
  - `ask-bartender-test/index.js`
  - `refine-cocktail/index.js`
  - `services/azureOpenAIService.js`
  - `services/openAIRecommendationService.js`
  - `voice-bartender/index.js`

  Deployed to `func-mba-fresh` and verified working.

### Recent Updates (January 2026)

- **Voice AI Phantom "Thinking..." Fix** (Jan 31): Fixed critical bug where Voice AI periodically entered "Thinking..." state on its own without the user pressing the push-to-talk button. Also fixed occasional unrelated AI responses (e.g., "Salty Dog" when discussing bourbon). Root cause: the `speech_started` and `speech_stopped` VAD event handlers did not check `_isMuted`, allowing background noise to trigger false state transitions into `processing`. With `create_response: false` (push-to-talk mode), nothing created a response, so the state got stuck at "Thinking..." indefinitely. Four changes applied to `voice_ai_service.dart`:
  1. **Guard `speech_started`**: Added `_isMuted` as first check — when muted, ALL speech detections are background noise and are ignored
  2. **Guard `speech_stopped`**: Added `_isMuted` as first check — prevents the critical `listening → processing` transition from background noise (THE fix for phantom "Thinking...")
  3. **Speech time finalization on mute**: Captures user speech duration when button is released, since `speech_stopped` events are now ignored while muted
  4. **Processing safety timeout**: 15-second defensive timer catches any edge case where `processing` gets stuck (network issues, Azure hiccups)

  **No backend changes needed** — client-only fix. See `docs/BUG_FIXES.md` (BUG-005) for full technical details.

- **Create Studio SQLite Type-Casting Bug Fix** (Jan 30): Fixed critical crash in Create Studio where saving a second custom cocktail displayed "Error loading cocktails" with `type '_UnmodifiableUint8ArrayView' is not a subtype of type 'String' in type cast`. Root cause: Flutter's `sqflite` package can return TEXT column values as `Uint8List` (binary bytes) instead of `String` under certain buffer management conditions. The unsafe `as String` cast in `Cocktail.fromDb()` at line 102 crashed when loading the custom cocktails list.
  1. **Created** `lib/src/utils/db_type_helpers.dart`: 4 safe conversion functions (`dbString`, `dbStringOrNull`, `dbInt`, `dbIntOrNull`) that handle both `String` and `Uint8List` return types via `utf8.decode()`
  2. **Fixed** `Cocktail.fromDb()` and `DrinkIngredient.fromDb()` in `cocktail.dart`: 22 unsafe casts replaced with safe helpers
  3. **Fixed** `FavoriteCocktail.fromDb()` in `favorite_cocktail.dart`: 3 unsafe casts replaced
  4. **Fixed** `UserIngredient.fromDb()` in `user_ingredient.dart`: 5 unsafe casts replaced
  5. **Fixed** 9 inline `as String` casts in `database_service.dart` across 7 query methods (`getMetadata`, `getRandomCocktail`, `getCocktails`, `getCategories`, `getAlcoholicTypes`, `getAllIngredients`, `getCocktailsWithInventory`, `getFavoriteCocktailIds`)
  6. **Unit tests**: 22 tests in `test/utils/db_type_helpers_test.dart` — all passing, including Uint8List simulation of the exact bug scenario
  7. **Total**: 39 unsafe type casts eliminated across 4 files. Zero behavioral change — `dbString()` is a no-op passthrough for values already of type `String`

- **Suggestive Cocktail Name Fix & System Prompt Upgrade** (Jan 30): Fixed critical issue where asking about cocktails with suggestive names (e.g., "How do you make a sex on the beach?") returned "Sorry, I encountered an error" instead of the recipe. Three-layer fix:
  1. **Azure Content Filter (Layer 1)**: Created custom RAI policy `BartenderAppFilter` on `mybartenderai-scus`. Changed Sexual category `severityThreshold` from default `Medium` to `High` (only blocks genuinely explicit content, allows cocktail names). Applied to `gpt-4.1-mini` deployment.
  2. **System Prompt Upgrades (Layer 2)**: Upgraded all 6 AI endpoint prompts with `COCKTAIL NAME CONTEXT` block that explicitly instructs the model to interpret all questions in a bartending context and lists common suggestive cocktail names as legitimate recipes. Endpoints updated: `ask-bartender-simple`, `ask-bartender`, `ask-bartender-test`, `voice-bartender`, `voice-session`, `refine-cocktail`.
  3. **Content Filter Error Handling (Layer 3)**: `ask-bartender-simple` now detects Azure content filter rejections (both `finishReason: 'content_filter'` output blocks and input-blocked errors) and returns a helpful 200 response asking users to rephrase, instead of a 500 error.

  **Also fixed**: `ask-bartender-simple` system prompt upgraded from 1-sentence prompt to comprehensive expert bartender persona with expertise areas, response style, and strict boundaries (matching the voice-session quality). All chat prompts now include the same boundary rules that prevent off-topic conversations.

- **Azure Functions V4 Logging Migration & Voice Crash Fix** (Jan 30): Fixed voice feature crash caused by Azure Functions V3→V4 logging incompatibility. Two root causes identified and resolved:
  1. **`userService.js` — Root cause**: `const log = context?.log || console` extracted the `log` method from `InvocationContext`, breaking V4's TypeScript private field `this` binding. Fix: Arrow function wrappers `(msg) => context.log(msg)` that preserve `this` through closure capture.
  2. **`index.js` — V3 syntax**: 33 instances of `context.log.error()` and 11 instances of `context.log.warn()` (V3 syntax) replaced with V4-compatible `context.error()` and `context.warn()`. V4's `InvocationContext` exposes `log()`, `warn()`, `error()` as direct methods — the V3 `context.log.error()` chaining pattern no longer exists.

  **Key insight**: Azure Functions V4's `InvocationContext` is compiled from TypeScript with private fields. Extracting methods (e.g., destructuring or assigning to variables) loses the `this` binding, causing `Cannot read private member` errors at runtime.

- **APIM Security Audit & JWT Decode Deployment — Phase 1** (Jan 30): Comprehensive APIM security audit revealed 13 of 30 operations lack JWT validation at the gateway. Phase 1 deployed a safe backend-only fix to populate user email and display_name by decoding the JWT token directly in function code. See `docs/APIM_SECURITY_USER_PROFILE_PLAN.md` for the full multi-phase plan.
  1. **Created** `shared/auth/jwtDecode.js`: Lightweight JWT payload decoder (base64 only, no crypto verification — APIM handles that)
  2. **Updated** `index.js`: 4 fire-and-forget blocks (ask-bartender-simple, voice-bartender, refine-cocktail, vision-analyze) now decode the `Authorization` header directly when APIM-forwarded `X-User-Id` header is absent
  3. **Belt-and-suspenders**: Code prefers APIM headers (future Phase 2), falls back to JWT decode (current)
  4. **Zero risk**: Fire-and-forget pattern — cannot block responses, all failures caught and logged
  5. **No APIM changes**: No mobile app changes, no new npm dependencies
  6. **Deployed**: 2026-01-30 17:11 UTC, health check passed, 33 functions synced

  **Remaining phases** (see `APIM_SECURITY_USER_PROFILE_PLAN.md`):
  - Phase 2: Deploy `validate-jwt` APIM policies to 13 unprotected operations (requires audience ID investigation first)
  - Phase 3: Standardize dual-audience IDs (`f9f7f159` vs `04551003`)
  - Phase 4: Tier simplification ($7.99/month, 20 voice min) — deferred until after Apple approval

  **Verification**: `SELECT id, email, display_name, tier, last_login_at FROM users ORDER BY last_login_at DESC NULLS LAST LIMIT 10;`

- **User Email & Display Name Population from JWT** (Jan 29): Backend functions now read `X-User-Email` and `X-User-Name` headers (forwarded by APIM from JWT claims) and store them in the PostgreSQL `users` table. Changes:
  1. `services/userService.js`: `getOrCreateUser()` now accepts optional `{ email, displayName }` options parameter
  2. **Existing users**: Email and display_name refreshed on every API call via `COALESCE()` (preserves existing data if header is absent)
  3. **New users**: Email and display_name stored at account creation
  4. **Callers updated**: `ask-bartender-simple`, `vision-analyze`, `voice-bartender`, and `voice-session` (in `index.js`) all extract and pass the APIM headers
  5. **voice-session refactored**: Replaced inline user SELECT/INSERT with centralized `getOrCreateUser()` call
  6. **No schema migration needed**: `email` and `display_name` columns already exist in the `users` table
  7. **Automatic backfill**: Existing users get populated on their next API call after deployment

  **Deployment**: `func azure functionapp publish func-mba-fresh`
  **Verification**: `SELECT id, email, display_name, tier, last_login_at FROM users ORDER BY last_login_at DESC;`

- **Login Screen App Icon** (Jan 27): Replaced the generic Material Design `Icons.local_bar` with the actual app icon (`assets/icon/icon.png`) on the login screen, matching the Initial Sync screen. Changes:
  1. `login_screen.dart`: Replaced `Icon(Icons.local_bar)` with `UnconstrainedBox` wrapping a 120×120 `Container` with `Image.asset('assets/icon/icon.png')`
  2. `UnconstrainedBox` required because the Column's `CrossAxisAlignment.stretch` passes tight constraints that force children to full width — `UnconstrainedBox` breaks out of parent constraints so the icon renders at its intended 120×120 size

- **Date of Birth Format Hint** (Jan 27): Updated the Entra External ID signup page "Date of Birth" field to show format guidance. Portal-only change (no code deployment):
  1. Changed Display Name from `Date of Birth` to `Date of Birth (MM/DD/YYYY)` in User Flow page layout editor
  2. Updates both the label above the field and the placeholder text inside the field
  3. The `validate-age` function already accepts MM/DD/YYYY as its primary format and returns a helpful error message if the format doesn't match

- **Privacy Policy & Terms of Service Website** (Jan 26): Deployed legal pages to Azure Static Web Apps for app store compliance. Changes:
  1. Created `website/` folder with `index.html`, `privacy.html`, `terms.html`, and `styles.css`
  2. Content converted from `PRIVACY_POLICY.md` and `services.md` source files
  3. Created Azure Static Web App `swa-mba-legal` in `rg-mba-prod` (Free tier)
  4. Configured custom domain `www.mybartenderai.com` with automatic SSL via Azure DNS
  5. Added Xtend-AI corporate logo to page headers with cyan "By" text for visibility

  **Live URLs:**
  - https://www.mybartenderai.com/privacy.html
  - https://www.mybartenderai.com/terms.html

- **Legal Section in Profile Screen** (Jan 26): Added in-app access to legal documents via WebView. Changes:
  1. `profile_screen.dart`: Added "Legal" section with Privacy Policy and Terms of Service links
  2. `legal_webview_screen.dart`: New WebView screen for displaying legal documents in-app
  3. `pubspec.yaml`: Added `webview_flutter: ^4.10.0` dependency

  Users can tap Privacy Policy or Terms of Service in Profile to view documents without leaving the app.

- **Home Screen Header Icon Update** (Jan 23): Replaced the generic blue Material Design martini glass icon (`Icons.local_bar`) in the home screen header with the actual app icon (purple background with cyan martini glass). This creates visual consistency between the launcher icon and in-app branding. Changes:
  1. `home_screen.dart`: Changed `Icon(Icons.local_bar)` to `Image.asset('assets/icon/icon.png')` in `_buildAppHeader()` method
  2. `pubspec.yaml`: Added `assets/icon/` to the assets list for runtime loading

- **Home Screen Header Icon Color Fix** (Jan 23): Fixed incorrect colors in `icon.png` - the background was pink/magenta (`#EC4899`) instead of the brand purple (`#7C3AED`). Updated `create_icon.ps1` PowerShell script with correct colors and regenerated icon files. Changes:
  1. `assets/icon/create_icon.ps1`: Changed background color from `#EC4899` to `#7C3AED` (purple), circle accent from `#DB2777` to `#6D28D9` (darker purple)
  2. `assets/icon/icon.png`: Regenerated with correct purple background
  3. `assets/icon/icon_foreground.png`: Regenerated for consistency

- **Chat/Voice Button Color Swap** (Jan 23): Swapped the colors of Chat and Voice buttons throughout the app for visual consistency. Chat buttons are now green (teal) and Voice buttons are now blue. Changes made in:
  1. `home_screen.dart`: Home screen AI Concierge section
  2. `recipe_vault_screen.dart`: Recipe Vault AI assistance buttons
  3. `academy_screen.dart`: Academy AI Concierge CTA
  4. `pro_tools_screen.dart`: Pro Tools AI Concierge CTA

- **iOS Bundle ID & Authentication Fix** (Jan 22): Changed iOS bundle ID from `ai.mybartender.mybartenderai` to `com.mybartenderai.mybartenderai` to match Apple Developer account configuration. Updated MSAL redirect URI to `msauth.com.mybartenderai.mybartenderai://auth`. **Azure Portal Note:** The portal UI rejected this redirect URI format, but it was successfully added via the **Manifest Editor** (App Registration > Manifest > edit `replyUrlsWithType` JSON directly). See `iOS_IMPLEMENTATION.md` for details.

- **iOS Token Refresh Workaround** (Jan 22): Implemented iOS-specific token refresh strategy to address Entra External ID's 12-hour refresh token timeout. iOS uses 4-hour intervals (vs 6 hours on Android) because iOS background tasks are less reliable than Android's AlarmManager. Changes:
  1. `app_lifecycle_service.dart`: Platform-aware refresh threshold (4 hours iOS, 6 hours Android)
  2. `background_token_service.dart`: iOS uses one-off tasks with chain scheduling instead of periodic tasks
  3. `notification_service.dart`: Platform-aware alarm intervals
  4. `AppDelegate.swift`: Added native WorkManager registration for iOS BGTaskScheduler
  See `ENTRA_REFRESH_TOKEN_WORKAROUND.md` for full documentation.

- **iOS Debug Build Cold Start Fix** (Jan 26): Identified root cause of iOS cold start crashes when launching from home screen. **Root cause:** Flutter debug builds require JIT (Just-In-Time) compilation, which iOS blocks unless a debugger is attached. When launching a debug build from the home screen (no debugger), the Flutter engine can't initialize properly, causing the registrar to be null and resulting in `EXC_BAD_ACCESS` crash during plugin registration. **Solution:** Always use Release builds (`flutter run --release` or `flutter build ios --release`) for iOS device testing. See Flutter Issue #149214 for details.

- **iOS AppDelegate Cold Start Crash Fix** (Jan 22): Fixed crash caused by `WorkmanagerPlugin.registerPeriodicTask()` being called BEFORE `GeneratedPluginRegistrant.register()`. The WorkManager plugin must be registered AFTER Flutter plugins are initialized. Reordered initialization in `AppDelegate.swift`.

- **iOS Cold Start Crash Fix** (Jan 21): Fixed critical issue where iOS app crashed on restart (white screen, immediate exit to home screen). App worked after fresh install but crashed on subsequent cold starts. Root cause: `NotificationService` and `BackgroundTokenService` (WorkManager) were initialized BEFORE `runApp()` in `bootstrap.dart`. On iOS cold start from terminated state, this caused crashes because the Flutter engine wasn't fully attached to the iOS view hierarchy. Also related to flutter_local_notifications Issue #2025 (background notification handler crashes on iOS). **Solution:**
  1. Skip early notification/background initialization on iOS in `bootstrap.dart`
  2. Initialize `BackgroundTokenService` AFTER `runApp()` in `main.dart` for iOS only
  3. Disable `onDidReceiveBackgroundNotificationResponse` handler on iOS (use `getNotificationAppLaunchDetails()` instead)
  4. Added try-catch error handling in `TokenStorageService` for corrupted Keychain data
  See `iOS_IMPLEMENTATION.md` Cold Start Crash Fix section for details.

- **Azure OpenAI Model Migration** (Jan 21): Migrated from retiring models to GA replacements:
  - Chat: `gpt-4o-mini` → `gpt-4.1-mini` (South Central US)
  - Voice AI: `gpt-4o-mini-realtime-preview` → `gpt-realtime-mini` (East US 2)
  - Both Voice and Chat tested successfully after migration
  - Key Vault secrets updated with new deployment names
- **Version Number Relocated**: Moved app version from Profile screen to Home screen footer, now displayed below "21+ | Drink Responsibly" message. Profile screen footer simplified to show only "My AI Bartender".
- **Help & Support Section Added**: New "Help & Support" card on Profile screen (below Account Information) with tappable "Contact Support" that opens email client with `support@xtend-ai.com` pre-filled.
- **Android 11+ Email Fix**: Fixed Contact Support email link not working on Android 11+ (API 30+). Root cause was missing `<queries>` declaration for `mailto:` scheme in AndroidManifest.xml. Android 11's Package Visibility filtering requires apps to declare which external intents they query. Added `<intent><action android:name="android.intent.action.SENDTO"/><data android:scheme="mailto"/></intent>` to fix `canLaunchUrl()` returning false.
- **Profile Screen Cleanup**: Removed redundant profile header (avatar + name box) since name already appears in Account Information. Saves vertical space and reduces duplication.
- **iOS Social Sharing Fix**: Fixed issue where share button showed "Unable to share recipe" error on iOS. Root cause was missing `sharePositionOrigin` parameter required by iOS `UIActivityViewController`. Solution: Wrap share button in `Builder` widget and calculate position from `RenderBox`. See `iOS_IMPLEMENTATION.md` Social Sharing section for details.
- **iOS Voice AI Speaker Routing Fix**: Fixed critical issue where Voice AI audio played through iPhone earpiece instead of speaker. Root cause was timing—speaker settings called before WebRTC peer connection, then iOS overrode them. Solution: Use `setAppleAudioConfiguration()` with `defaultToSpeaker` option AFTER peer connection is established. See `iOS_IMPLEMENTATION.md` Voice AI Audio Routing section for details.
- **iOS Platform Ready**: iOS authentication fully working with Entra External ID (CIAM). MSAL configured with B2C authority type, keychain entitlements, privacy manifest, and proper URL scheme handling. Tested on physical iPhone device with successful login flow.
- **Token Refresh Notification Eliminated**: Removed the visible notification for background token refresh entirely. Users complained about seeing "Session Active" every 6 hours. Solution: Cancel the notification immediately after scheduling - the AlarmManager callback still fires, but no notification is displayed. See `NOTIFICATION_SYSTEM.md` for technical details.
- **Today's Special Deep Link Fix**: Fixed critical regression where notification deep links would flash the cocktail card briefly then redirect to home. Root cause was `routerProvider` using `ref.watch()` which recreated the entire GoRouter on state changes. Fixed with `refreshListenable` pattern per GoRouter best practices. See `TODAYS_SPECIAL_FEATURE.md` Issue #5 REGRESSION for details.
- **Voice AI Background Noise Fix**: Fixed critical issue where Voice AI would stop mid-sentence when TV dialogue or background conversations were detected. Root cause was premature state change in WebRTC `onTrack` handler and incorrect event names. See `VOICE_AI_DEPLOYED.md` for details.
- **Voice AI Phantom "Thinking..." Fix** (Jan 31): Fixed muted-mic state leakage where background noise triggered phantom processing state. See `BUG_FIXES.md` BUG-005.
- **Recipe Vault AI Concierge**: Added Chat and Voice buttons to help users find cocktails via AI
- **My Bar Smart Scanner**: Added Scanner option in empty state for quick bottle identification
- **My Bar Empty State**: Updated instructional text to explain Add (search) vs Scanner (AI photo) options
- **Academy AI Concierge**: Added Chat and Voice CTA at bottom of Academy screen
- **Pro Tools AI Concierge**: Added Chat and Voice CTA at bottom of Pro Tools screen
- **Favorites Create Prompt**: Added "Create your own signature cocktails" with Create button in empty state
- **Home Screen Footer**: Shows "21+ | Drink Responsibly" message and "Version: 1.0.0"

---

## Platform Status

| Platform | Status | Notes                                                |
| -------- | ------ | ---------------------------------------------------- |
| Android  | Ready  | Release APK builds successfully                      |
| iOS      | Ready  | Authentication working, tested on physical device    |

---

## Azure Infrastructure

### Resource Overview

| Resource        | Name                    | SKU/Tier            | Region           |
| --------------- | ----------------------- | ------------------- | ---------------- |
| Function App    | `func-mba-fresh`        | Premium Consumption | South Central US |
| API Management  | `apim-mba-002`          | Basic V2 (~$150/mo) | South Central US |
| PostgreSQL      | `pg-mybartenderdb`      | Flexible Server     | South Central US |
| Storage Account | `mbacocktaildb3`        | Standard            | South Central US |
| Key Vault       | `kv-mybartenderai-prod` | Standard            | East US          |
| Azure OpenAI    | `mybartenderai-scus`    | S0                  | South Central US |
| Azure OpenAI    | `blueb-midjmnz5-eastus2`| S0                  | East US 2        |
| Front Door      | `fd-mba-share`          | Standard            | Global           |
| Static Web App  | `swa-mba-legal`         | Free                | Central US       |

### Key Vault Secrets

All sensitive configuration stored in `kv-mybartenderai-prod`:

- `AZURE-OPENAI-API-KEY` - Azure OpenAI service key (South Central US)
- `AZURE-OPENAI-ENDPOINT` - Azure OpenAI endpoint URL (South Central US)
- `AZURE-OPENAI-DEPLOYMENT` - Chat model deployment name (`gpt-4.1-mini`)
- `AZURE-OPENAI-REALTIME-KEY` - Azure OpenAI service key (East US 2)
- `AZURE-OPENAI-REALTIME-ENDPOINT` - Azure OpenAI endpoint URL (East US 2)
- `AZURE-OPENAI-REALTIME-DEPLOYMENT` - Voice AI model deployment name (`gpt-realtime-mini`)
- `CLAUDE-API-KEY` - Anthropic Claude API key (Smart Scanner)
- `POSTGRES-CONNECTION-STRING` - Database connection
- `COCKTAILDB-API-KEY` - TheCocktailDB API key
- `SOCIAL-ENCRYPTION-KEY` - Social sharing encryption
- `REVENUECAT-PUBLIC-API-KEY` - RevenueCat SDK initialization (Google Play `goog_...` key, active)
- `REVENUECAT-APPLE-API-KEY` - RevenueCat SDK initialization (Apple `appl_...` key, active)
- `REVENUECAT-WEBHOOK-SECRET` - RevenueCat webhook signature verification (placeholder)
- Plus additional service keys

---

## Authentication System

### Status: Fully Operational

**Architecture**: JWT-only authentication (no APIM subscription keys on client)

| Component              | Status     | Details                         |
| ---------------------- | ---------- | ------------------------------- |
| Entra External ID      | Configured | Tenant: `mybartenderai`         |
| Email + Password       | Working    | Native Entra authentication     |
| Google Sign-In         | Working    | OAuth 2.0 federation            |
| Apple Sign-In          | Working    | OAuth 2.0 federation            |
| Age Verification (21+) | Working    | Custom Authentication Extension |
| JWT Validation         | Working    | APIM `validate-jwt` policy      |

### Authentication Flow

1. Mobile app authenticates with Entra External ID
2. JWT token included in API requests (`Authorization: Bearer <token>`)
3. APIM validates JWT (signature, expiration, audience)
4. Backend functions receive validated user ID via `X-User-Id` header
5. Functions check user entitlement in PostgreSQL database

**API Gateway**: `https://apim-mba-002.azure-api.net`

---

## Subscription Model

| Entitlement    | Monthly | Annual | AI Tokens | Scans | Voice                                 |
| -------------- | ------- | ------ | --------- | ----- | ------------------------------------- |
| Free (none)    | $0      | -      | 0         | 0     | -                                     |
| Trial (3 days) | Free    | -      | 20,000    | 5     | 10 min                                |
| Paid           | $7.99   | $79.99 | 1,000,000 | 100   | 60 min included + $4.99/60 min add-on |

Entitlement validation occurs in backend functions via PostgreSQL user lookup (not APIM products).

**Free Trial:** 3-day trial available on the monthly plan. Trial users get reduced quotas (20,000 tokens, 5 scans, 10 voice minutes) enforced server-side via `subscription_status = 'trialing'`. On trial→paid conversion (RENEWAL event), limits automatically upgrade to full paid quotas. No new DB migration needed — reuses existing column from migration 011.

**Voice Minutes:** Subscribers get 60 minutes included per month. Add-on packs of 60 minutes for $4.99 are available (non-expiring, repeatable). Included minutes consumed first, then purchased. Voice time is metered by active speech time (only user + AI talking counts, not idle time).

**Subscription Management:** RevenueCat handles subscription lifecycle (purchase, renewal, cancellation). Webhook events update `user_subscriptions` table, which triggers automatic `users.entitlement` updates via PostgreSQL trigger.

---

## Deployed Azure Functions

All functions deployed to `func-mba-fresh`:

### Core API Endpoints

| Function               | Method | Path                             | Auth      | Status  |
| ---------------------- | ------ | -------------------------------- | --------- | ------- |
| `ask-bartender-simple` | POST   | `/api/v1/ask-bartender-simple`   | JWT       | Working |
| `recommend`            | POST   | `/api/v1/recommend`              | JWT       | Working |
| `snapshots-latest`     | GET    | `/api/v1/snapshots/latest`       | JWT       | Working |
| `vision-analyze`       | POST   | `/api/v1/vision/analyze`         | JWT       | Working |
| `voice-session`        | POST   | `/api/v1/voice/session`          | JWT (Paid)| Working |
| `refine-cocktail`      | POST   | `/api/v1/create-studio/refine`   | JWT       | Working |
| `cocktail-preview`     | GET    | `/api/v1/cocktails/preview/{id}` | Public    | Working |
| `users-me`             | GET    | `/api/v1/users/me`               | JWT       | Working |

### Authentication Endpoints

| Function        | Method | Path                    | Auth      | Status  |
| --------------- | ------ | ----------------------- | --------- | ------- |
| `validate-age`  | POST   | `/api/validate-age`     | OAuth 2.0 | Working |
| `auth-exchange` | POST   | `/api/v1/auth/exchange` | JWT       | Working |
| `auth-rotate`   | POST   | `/api/v1/auth/rotate`   | JWT       | Working |

### Social Features

| Function                | Method | Path                    | Auth | Status  |
| ----------------------- | ------ | ----------------------- | ---- | ------- |
| `social-share-internal` | POST   | `/api/v1/social/share`  | JWT  | Working |
| `social-invite`         | POST   | `/api/v1/social/invite` | JWT  | Working |
| `social-inbox`          | GET    | `/api/v1/social/inbox`  | JWT  | Working |
| `social-outbox`         | GET    | `/api/v1/social/outbox` | JWT  | Working |

### Subscription Endpoints

| Function               | Method | Path                           | Auth                 | Status    |
| ---------------------- | ------ | ------------------------------ | -------------------- | --------- |
| `subscription-config`  | GET    | `/api/v1/subscription/config`  | JWT                  | Deployed* |
| `subscription-status`  | GET    | `/api/v1/subscription/status`  | JWT                  | Deployed* |
| `subscription-webhook` | POST   | `/api/v1/subscription/webhook` | RevenueCat Signature | Deployed* |

*Code supports both Google Play and Apple App Store. Store product creation and RevenueCat dashboard configuration pending — see `REVENUECAT_PLAN.md`.

### Voice Purchase

| Function         | Method | Path                     | Auth | Status  |
| ---------------- | ------ | ------------------------ | ---- | ------- |
| `voice-purchase` | POST   | `/api/v1/voice/purchase` | JWT  | Working |

### Admin/Utility Functions

| Function                 | Status         | Notes                           |
| ------------------------ | -------------- | ------------------------------- |
| `sync-cocktaildb`        | Timer DISABLED | Using static database copy      |
| `download-images`        | Available      | Manual trigger only             |
| `health`                 | Available      | Health check endpoint           |
| `rotate-keys-timer`      | Timer          | Key rotation (monthly)          |
| `voice-session-cleanup`  | Timer          | Stale session expiry (hourly)   |

---

## AI Services

### GPT-4.1-mini (Azure OpenAI)

**Service**: `mybartenderai-scus` (South Central US)
**Deployment**: `gpt-4.1-mini`

| Feature                  | Function               | Model        |
| ------------------------ | ---------------------- | ------------ |
| AI Bartender Chat        | `ask-bartender-simple` | gpt-4.1-mini |
| Cocktail Recommendations | `recommend`            | gpt-4.1-mini |
| Recipe Refinement        | `refine-cocktail`      | gpt-4.1-mini |

**Cost**: Similar to gpt-4o-mini (~$0.15/1M input tokens, ~$0.60/1M output tokens)

**Migration Note**: Upgraded from gpt-4o-mini (retiring March 31, 2026) on January 21, 2026.

### Claude Haiku (Anthropic)

**Used for**: Smart Scanner (vision-analyze)

| Feature                       | Function         | Model            |
| ----------------------------- | ---------------- | ---------------- |
| Bottle/Ingredient Recognition | `vision-analyze` | Claude Haiku 4.5 |

Analyzes bar photos to identify spirits, liqueurs, and mixers with high accuracy.

### GPT-realtime-mini (Azure OpenAI Realtime API)

**Service**: `blueb-midjmnz5-eastus2` (East US 2)
**Deployment**: `gpt-realtime-mini`
**Used for**: Voice AI (Subscribers only)

| Feature         | Function        | Model            |
| --------------- | --------------- | ---------------- |
| Voice Bartender | `voice-session` | gpt-realtime-mini |

**Architecture**:

1. Mobile app requests WebRTC session token from `voice-session`
2. Function returns ephemeral token for Azure OpenAI Realtime API
3. Mobile app connects directly to Azure OpenAI via WebRTC
4. Real-time voice conversation with AI bartender

**Cost**: ~$0.06/min input, ~$0.24/min output

**Migration Note**: Upgraded from gpt-4o-mini-realtime-preview (retiring Feb 28, 2026) on January 21, 2026.

---

## Mobile App Features

### Implemented Features

| Feature               | Screen                        | Status         |
| --------------------- | ----------------------------- | -------------- |
| Home Dashboard        | `home_screen.dart`            | Complete       |
| AI Bartender Chat     | `chat_screen.dart`            | Complete       |
| Recipe Vault          | `recipe_vault_screen.dart`    | Complete       |
| Cocktail Details      | `cocktail_detail_screen.dart` | Complete       |
| My Bar (Inventory)    | `my_bar_screen.dart`          | Complete       |
| Smart Scanner         | `smart_scanner_screen.dart`   | Complete       |
| Voice Bartender       | `voice_bartender_screen.dart` | Complete (Paid)|
| Create Studio         | `create_studio_screen.dart`   | Complete       |
| User Profile          | `profile_screen.dart`         | Complete       |
| Login                 | `login_screen.dart`           | Complete       |
| Today's Special       | Home card + notifications     | Complete       |
| Notification Settings | Profile screen                | Complete       |
| Social Sharing        | Share dialogs                 | Complete       |
| In-App Review         | Review prompt dialog          | Complete       |

### Key Integrations

- **Offline-First Database**: SQLite with Zstandard-compressed snapshots (~172KB)
- **State Management**: Riverpod providers
- **Routing**: GoRouter with authentication guards + deep linking
- **HTTP Client**: Dio with JWT interceptors
- **Secure Storage**: flutter_secure_storage for tokens
- **Notifications**: flutter_local_notifications for Today's Special
  - 7-day lookahead scheduling (one-time alarms, more reliable than repeating)
  - Deep link to cocktail detail via notification payload
  - Idempotent scheduling (30-minute cooldown prevents loops)
  - Battery optimization exemption for reliable delivery
  - Configurable notification time (default 5 PM)
- **In-App Review**: `in_app_review` for OS-native review prompts
  - Two-step UX with pre-prompt dialog
  - 6 win moment triggers across Smart Scanner, Create Studio, sharing, favorites, chat, voice
  - Eligibility gate with session, cooldown, and lifetime caps
  - Unhappy users routed to feedback email instead of store review
- **Background Token Refresh**: Invisible alarm-based token refresh every 6 hours
  - Notification is immediately canceled after scheduling (invisible to users)
  - AlarmManager callback still fires - only the visible notification is suppressed
  - `TOKEN_REFRESH_TRIGGER` payload filtered in main.dart to prevent navigation errors
  - See `NOTIFICATION_SYSTEM.md` for architecture details

### Profile Screen (Release Candidate)

Cleaned up for release:

- Account information (name only, email removed)
- Help & Support (tappable email link to `support@xtend-ai.com`)
- Notification settings (Today's Special Reminder)
- Measurement preferences (oz/ml)
- Sign out with confirmation
- App branding footer ("My AI Bartender")
- Developer tools removed

---

## Data Flow

### Cocktail Database

```
TheCocktailDB API (disabled sync)
         ↓
   PostgreSQL (authoritative source)
         ↓
   JSON Snapshot (Zstandard compressed, ~172KB)
         ↓
   Azure Blob Storage (mbacocktaildb3)
         ↓
   Mobile App SQLite (offline-first)
```

**Note**: Timer-triggered sync from TheCocktailDB is disabled. Using static database copy.

### Authentication Flow

```
Mobile App
    ↓ (JWT token + x-user-email/x-user-name headers)
Entra External ID (mybartenderai.ciamlogin.com)
    ↓ (JWT token with email optional claim)
APIM (apim-mba-002.azure-api.net)
    ↓ (validate-jwt policy on all 30 protected operations, extract claims)
Azure Function (func-mba-fresh)
    ↓ Primary: X-User-Id + X-User-Email headers (from APIM validate-jwt + set-header)
    ↓ Fallback: JWT decode from Authorization header (jwtDecode.js)
    ↓ Belt-and-suspenders: x-user-email header from Flutter client
PostgreSQL (entitlement lookup + email/display_name storage)
```

**Note**: All APIM operations now have appropriate security — 13 protected operations received `validate-jwt` policies on Feb 11, 2026 (completing Phase 2 of the APIM security plan). 5 operations remain intentionally public (health, snapshots-latest, cocktail-preview, subscription-webhook, social-connect-callback). See `APIM_SECURITY_USER_PROFILE_PLAN.md`.

### Voice AI Flow (Subscribers Only)

```
Mobile App
    ↓ (request session)
voice-session function
    ↓ (ephemeral WebRTC token)
Mobile App
    ↓ (direct WebRTC connection)
Azure OpenAI Realtime API
```

### Subscription Flow (RevenueCat)

```
Mobile App
    ↓ (fetch config)
subscription-config function
    ↓ (RevenueCat API key)
Mobile App → RevenueCat SDK → Google Play / App Store
    ↓ (purchase complete)
RevenueCat Server
    ↓ (webhook event)
subscription-webhook function
    ↓ (verify signature, check idempotency)
PostgreSQL (user_subscriptions)
    ↓ (trigger)
PostgreSQL (users.entitlement updated)
```

**Webhook Features:**

- Idempotency via `revenuecat_event_id` unique index
- Sandbox event filtering (production ignores sandbox events)
- Grace period handling for billing issues
- All events logged to `subscription_events` audit table

---

## External Integrations

| Service          | Purpose                                 | Status          |
| ---------------- | --------------------------------------- | --------------- |
| Azure Front Door | Custom domain `share.mybartenderai.com` | Active          |
| Azure Static Web Apps | Legal pages `www.mybartenderai.com` | Active          |
| TheCocktailDB    | Cocktail database source                | Sync disabled   |
| Google OAuth     | Social sign-in                          | Configured      |
| Apple Sign-In    | Social sign-in                          | Configured      |
| Facebook OAuth   | Social sign-in (removed Feb 2026)       | Removed         |
| Instagram        | Social sharing                          | Configured      |
| RevenueCat       | Subscription management                 | Both platforms configured* |

*Code supports both Google Play and Apple App Store with platform-aware API keys. Store product creation and RevenueCat dashboard mapping pending — see `docs/REVENUECAT_PLAN.md`.

---

## Build & Deployment

### Mobile App (Android)

```bash
# Development
cd mobile/app
flutter run

# Release APK (incremental build)
flutter build apk --release

# Output: mobile/app/build/app/outputs/flutter-apk/app-release.apk
```

**Clean Build (Recommended)**

When doing a fresh build or after `flutter clean`, use this sequence to avoid the libs.jar Gradle transform error:

```bash
cd mobile/app

# Step 1: Clean everything
flutter clean
flutter pub get

# Step 2: Build profile first (creates libs.jar)
flutter build apk --profile

# Step 3: Copy libs.jar to release directory
# Windows (Git Bash):
mkdir -p build/app/intermediates/flutter/release
cp build/app/intermediates/flutter/profile/libs.jar build/app/intermediates/flutter/release/

# Step 4: Build release
flutter build apk --release
```

> **Why?** Flutter/Gradle 4.0+ has a known issue ([#58247](https://github.com/flutter/flutter/issues/58247)) where the release build doesn't create `libs.jar`, causing `JetifyTransform` to fail. Building profile first creates the file, which can then be copied to the release directory.

### Mobile App (iOS)

**IMPORTANT: iOS Debug Build Limitation**

Flutter debug builds crash when launched from the iOS home screen without a debugger attached. This is because debug builds require JIT (Just-In-Time) compilation, which iOS blocks for security reasons. The crash manifests as a white screen flash followed by immediate exit.

**Always use Release builds for iOS device testing:**

```bash
# Development (simulator only)
cd mobile/app
flutter run -d "iPhone 16e"

# Physical device - MUST use Release build
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter run --release  # Run directly to device in Release mode

# Or build and deploy manually
flutter build ios --release
cd ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -destination 'generic/platform=iOS' -archivePath build/Runner.xcarchive archive
# Or use Xcode: Product > Archive
```

**iOS Build Requirements:**
- Xcode 15+ with Command Line Tools
- Valid Apple Developer Team ID in project.pbxproj
- CocoaPods installed (`gem install cocoapods`)
- Device must have Developer Mode enabled (iOS 16+)
- **Release build required for cold start testing** (Debug builds crash without debugger)

### Azure Functions

```bash
# Deploy from backend/functions directory
cd backend/functions
func azure functionapp publish func-mba-fresh --javascript

# Or via zip deployment
az functionapp deployment source config-zip -g rg-mba-prod -n func-mba-fresh --src deployment.zip
```

---

## Known Limitations

1. **No biometric auth**: Could add fingerprint/Face ID for better UX
2. **No offline auth**: Requires network for initial sign-in
3. **Single session**: No multi-device session management

---

## Security Configuration

- **JWT tokens**: Validated by APIM before reaching functions
- **Key Vault**: Managed Identity with RBAC for secret access
- **HTTPS only**: All communication encrypted
- **OAuth 2.0 PKCE**: flutter_appauth uses PKCE for mobile security
- **Age verification**: Server-side validation cannot be bypassed
- **Token storage**: flutter_secure_storage with Android encrypted preferences

---

## Monitoring & Operations

- **Application Insights**: Connected to Function App
- **APIM Analytics**: Built-in API metrics
- **Key rotation**: Automated via `rotate-keys-timer`

---

## Documentation References

| Document                             | Purpose                                        |
| ------------------------------------ | ---------------------------------------------- |
| `ARCHITECTURE.md`                    | System architecture and design                 |
| `AUTHENTICATION_SETUP.md`            | Entra External ID configuration                |
| `AUTHENTICATION_IMPLEMENTATION.md`   | Mobile app auth integration                    |
| `AGE_VERIFICATION_IMPLEMENTATION.md` | 21+ verification details                       |
| `BUG_FIXES.md`                       | Chronological bug fix log                      |
| `VOICE_AI_IMPLEMENTATION.md`         | Voice feature specification                    |
| `SUBSCRIPTION_DEPLOYMENT.md`         | RevenueCat subscription system                 |
| `REVENUECAT_PLAN.md`                 | RevenueCat cross-platform setup checklist       |
| `TODAYS_SPECIAL_FEATURE.md`          | Today's Special notifications and deep linking |
| `NOTIFICATION_SYSTEM.md`             | Notification architecture and token refresh    |
| `RECIPE_VAULT_AI_CONCIERGE.md`       | AI Chat/Voice buttons in Recipe Vault          |
| `MY_BAR_SCANNER_INTEGRATION.md`      | Smart Scanner option in My Bar empty state     |
| `CREATE_STUDIO_PHOTO_CAPTURE.md`     | Custom cocktail photo capture implementation   |
| `iOS_IMPLEMENTATION.md`              | iOS platform-specific configuration            |
| `APIM_SECURITY_USER_PROFILE_PLAN.md` | APIM security audit + user profile population  |
| `Review.md`                          | In-app review & feedback flow spec             |
| `CLAUDE.md`                          | Project context and conventions                |

---

**Status**: Release Candidate
**Last Updated**: February 24, 2026
