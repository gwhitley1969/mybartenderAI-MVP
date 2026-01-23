# MyBartenderAI Deployment Status

## Current Status: Release Candidate

**Last Updated**: January 23, 2026

The My AI Bartender mobile app and Azure backend are fully operational and in release candidate status. All core features are implemented and tested on both Android and iOS platforms, including the RevenueCat subscription system (awaiting account configuration) and Today's Special daily notifications.

### Recent Updates (January 2026)

- **Home Screen Header Icon Update** (Jan 23): Replaced the generic blue Material Design martini glass icon (`Icons.local_bar`) in the home screen header with the actual app icon (purple background with cyan martini glass). This creates visual consistency between the launcher icon and in-app branding. Changes:
  1. `home_screen.dart`: Changed `Icon(Icons.local_bar)` to `Image.asset('assets/icon/icon.png')` in `_buildAppHeader()` method
  2. `pubspec.yaml`: Added `assets/icon/` to the assets list for runtime loading

- **iOS Bundle ID & Authentication Fix** (Jan 22): Changed iOS bundle ID from `ai.mybartender.mybartenderai` to `com.mybartenderai.mybartenderai` to match Apple Developer account configuration. Updated MSAL redirect URI to `msauth.com.mybartenderai.mybartenderai://auth`. **Azure Portal Note:** The portal UI rejected this redirect URI format, but it was successfully added via the **Manifest Editor** (App Registration > Manifest > edit `replyUrlsWithType` JSON directly). See `iOS_IMPLEMENTATION.md` for details.

- **iOS Token Refresh Workaround** (Jan 22): Implemented iOS-specific token refresh strategy to address Entra External ID's 12-hour refresh token timeout. iOS uses 4-hour intervals (vs 6 hours on Android) because iOS background tasks are less reliable than Android's AlarmManager. Changes:
  1. `app_lifecycle_service.dart`: Platform-aware refresh threshold (4 hours iOS, 6 hours Android)
  2. `background_token_service.dart`: iOS uses one-off tasks with chain scheduling instead of periodic tasks
  3. `notification_service.dart`: Platform-aware alarm intervals
  4. `AppDelegate.swift`: Added native WorkManager registration for iOS BGTaskScheduler
  See `ENTRA_REFRESH_TOKEN_WORKAROUND.md` for full documentation.

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
- `REVENUECAT-PUBLIC-API-KEY` - RevenueCat SDK initialization (placeholder)
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
| Facebook Sign-In       | Working    | OAuth 2.0 federation            |
| Age Verification (21+) | Working    | Custom Authentication Extension |
| JWT Validation         | Working    | APIM `validate-jwt` policy      |

### Authentication Flow

1. Mobile app authenticates with Entra External ID
2. JWT token included in API requests (`Authorization: Bearer <token>`)
3. APIM validates JWT (signature, expiration, audience)
4. Backend functions receive validated user ID via `X-User-Id` header
5. Functions check user tier in PostgreSQL database

**API Gateway**: `https://apim-mba-002.azure-api.net`

---

## Subscription Tiers

| Tier    | Monthly | Annual | AI Tokens | Scans | Voice                   |
| ------- | ------- | ------ | --------- | ----- | ----------------------- |
| Free    | $0      | -      | 10,000    | 2     | -                       |
| Premium | $4.99   | $39.99 | 300,000   | 15    | $4.99/20 min purchase   |
| Pro     | $7.99   | $79.99 | 1,000,000 | 50    | 60 min + $4.99/20 min   |

Tier validation occurs in backend functions via PostgreSQL user lookup (not APIM products).

**Voice Minutes:** Premium users can purchase voice minutes at $4.99 for 20 minutes. Pro users get 60 minutes included per month and can purchase additional minutes at the same rate. Voice time is metered by active speech time (only user + AI talking counts, not idle time).

**Subscription Management:** RevenueCat handles subscription lifecycle (purchase, renewal, cancellation). Webhook events update `user_subscriptions` table, which triggers automatic `users.tier` updates via PostgreSQL trigger.

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
| `voice-session`        | POST   | `/api/v1/voice/session`          | JWT (Pro) | Working |
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

*Awaiting RevenueCat account setup. See `SUBSCRIPTION_DEPLOYMENT.md` for configuration steps.

### Voice Purchase

| Function         | Method | Path                     | Auth | Status  |
| ---------------- | ------ | ------------------------ | ---- | ------- |
| `voice-purchase` | POST   | `/api/v1/voice/purchase` | JWT  | Working |

### Admin/Utility Functions

| Function            | Status         | Notes                      |
| ------------------- | -------------- | -------------------------- |
| `sync-cocktaildb`   | Timer DISABLED | Using static database copy |
| `download-images`   | Available      | Manual trigger only        |
| `health`            | Available      | Health check endpoint      |
| `rotate-keys-timer` | Timer          | Key rotation automation    |

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
**Used for**: Voice AI (Pro tier only)

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
| Voice Bartender       | `voice_bartender_screen.dart` | Complete (Pro) |
| Create Studio         | `create_studio_screen.dart`   | Complete       |
| User Profile          | `profile_screen.dart`         | Complete       |
| Login                 | `login_screen.dart`           | Complete       |
| Today's Special       | Home card + notifications     | Complete       |
| Notification Settings | Profile screen                | Complete       |
| Social Sharing        | Share dialogs                 | Complete       |

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
    ↓
Entra External ID (mybartenderai.ciamlogin.com)
    ↓ (JWT token)
APIM (apim-mba-002.azure-api.net)
    ↓ (validate-jwt policy)
Azure Function (func-mba-fresh)
    ↓ (X-User-Id header)
PostgreSQL (tier lookup)
```

### Voice AI Flow (Pro Tier)

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
Mobile App → RevenueCat SDK → Google Play
    ↓ (purchase complete)
RevenueCat Server
    ↓ (webhook event)
subscription-webhook function
    ↓ (verify signature, check idempotency)
PostgreSQL (user_subscriptions)
    ↓ (trigger)
PostgreSQL (users.tier updated)
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
| TheCocktailDB    | Cocktail database source                | Sync disabled   |
| Google OAuth     | Social sign-in                          | Configured      |
| Facebook OAuth   | Social sign-in                          | Configured      |
| Instagram        | Social sharing                          | Configured      |
| RevenueCat       | Subscription management                 | Awaiting setup* |

*Backend code deployed, Key Vault placeholders created. Requires RevenueCat account configuration.

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

```bash
# Development (simulator)
cd mobile/app
flutter run -d "iPhone 16e"

# Release build
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ios --release

# Deploy to physical device
cd ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -destination 'generic/platform=iOS' -archivePath build/Runner.xcarchive archive
# Or use Xcode: Product > Archive

# Note: Debug builds require debugger attachment; use Release for standalone testing
```

**iOS Build Requirements:**
- Xcode 15+ with Command Line Tools
- Valid Apple Developer Team ID in project.pbxproj
- CocoaPods installed (`gem install cocoapods`)
- Device must have Developer Mode enabled (iOS 16+)

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
| `VOICE_AI_IMPLEMENTATION.md`         | Voice feature specification                    |
| `SUBSCRIPTION_DEPLOYMENT.md`         | RevenueCat subscription system                 |
| `TODAYS_SPECIAL_FEATURE.md`          | Today's Special notifications and deep linking |
| `NOTIFICATION_SYSTEM.md`             | Notification architecture and token refresh    |
| `RECIPE_VAULT_AI_CONCIERGE.md`       | AI Chat/Voice buttons in Recipe Vault          |
| `MY_BAR_SCANNER_INTEGRATION.md`      | Smart Scanner option in My Bar empty state     |
| `iOS_IMPLEMENTATION.md`              | iOS platform-specific configuration            |
| `CLAUDE.md`                          | Project context and conventions                |

---

**Status**: Release Candidate
**Last Updated**: January 23, 2026
