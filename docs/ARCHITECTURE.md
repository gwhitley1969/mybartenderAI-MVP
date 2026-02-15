# Architecture — MyBartenderAI (MVP)

## System Overview

- Flutter app (feature-first clean architecture; Riverpod state; GoRouter) - Android and iOS
- Azure API Management (`apim-mba-002`) as API gateway for entitlement management and security
- **Azure Functions v4 Programming Model** - 35 functions with code-centric registration
- **Node.js 22 runtime** on Windows Premium Consumption plan
- **Official Azure OpenAI SDK** (@azure/openai) for all AI features
- Azure PostgreSQL for authoritative recipe corpus with AI enhancements
- Azure Blob for cocktail images (US-hosted) and JSON snapshots
- Key Vault for secrets (accessed via Managed Identity); App Insights for telemetry
- **Managed Identity** for Key Vault and Storage access
- All free features run locally on device (offline-first)
- Mobile → APIM → Azure Functions (HTTPS) → (PostgreSQL/Blob/Key Vault/Azure OpenAI)
- Azure Front Door (`fd-mba-share`) for external sharing with custom domain `share.mybartenderai.com`

## Current Operational Status (February 2026)

### Working Features
- ✅ Recipe Vault (database download and sync via APIM)
- ✅ My Bar (inventory management)
- ✅ Favorites/bookmarks
- ✅ User authentication (Entra External ID with JWT)
- ✅ JWT-only authentication (APIM validates JWT on all 13 protected operations, no subscription keys on client)
- ✅ AI Bartender Chat (all users, including free with limited quota)
- ✅ Smart Scanner (Claude Haiku for bottle detection - Subscribers, 100/month)
- ✅ Voice AI (Azure OpenAI Realtime API - Subscribers only, 60 min/month + $5.99/60 min add-ons)
- ✅ User entitlement validation (backend checks entitlement in PostgreSQL)
- ✅ Rate limiting per user
- ✅ Monitoring and alerting (Application Insights)
- ✅ **Azure Functions v4 Migration Complete** - All functions migrated and deployed
- ✅ **Official Azure OpenAI SDK** - All AI functions using @azure/openai package
- ✅ **Managed Identity** - Full implementation for Key Vault and Storage access
- ✅ **Subscription System** - RevenueCat webhook integration with idempotency
- ✅ **Today's Special** - Daily cocktail with push notifications and deep linking

### Recent Backend Improvements

**Subscription System (December 2025):**
- ✅ **RevenueCat Integration**: Webhook endpoint for subscription lifecycle events
- ✅ **Idempotency**: Event deduplication via `revenuecat_event_id` unique index
- ✅ **Grace Period Handling**: BILLING_ISSUE respects `grace_period_expires_date_ms`
- ✅ **Sandbox Filtering**: Production webhook ignores sandbox test events
- ✅ **Audit Logging**: All webhook events stored in `subscription_events` table
- ✅ **3 New Functions**: subscription-config, subscription-status, subscription-webhook

**Azure Functions v4 Migration (November 20, 2025):**
- ✅ **v4 Programming Model**: Code-centric registration in single `index.js` file
- ✅ **30 Functions Deployed**: 29 HTTP triggers + 1 timer trigger
- ✅ **Azure OpenAI SDK**: Migrated from `openai` to official `@azure/openai` package
- ✅ **API Updates**: Modern request/response handling (await request.json(), return jsonBody)
- ✅ **Logging Updates**: Fixed context.error() vs context.log.error() patterns
- ✅ **Module Delegation**: v4 functions delegate to v3-style modules where needed
- ✅ **96% Success Rate**: 26/27 functions verified working post-migration
- ✅ **Comprehensive Testing**: PowerShell test scripts created and validated

**Security Improvements:**
- ✅ **JWT-Only Authentication**: Mobile sends JWT, APIM validates via policy on all protected operations
- ✅ **APIM JWT Coverage Complete**: All 13 previously-unprotected operations now have `validate-jwt` policies (Feb 11, 2026)
- ✅ **Mobile Auth Fix**: All 4 API providers (`askBartenderApi`, `recommendApi`, `createStudioApi`, `visionApi`) now use authenticated Dio with JWT interceptor
- ✅ **No Hardcoded Keys**: No API keys stored in source or APK
- ✅ **Server-Side Entitlement Validation**: Backend checks user entitlement in PostgreSQL
- ✅ **Rate Limiting**: Azure Table Storage based per-user limits
- ✅ **Attack Detection**: High failure rate monitoring (>50 failures/5 min)
- ✅ **Managed Identity**: RBAC-based access to Key Vault and Storage

## Core Features

### Current (MVP)

- AI-powered cocktail recommendations based on inventory (GPT-4.1-mini via @azure/openai SDK)
- **Azure Functions v4 Programming Model** with code-centric registration
- **35 Backend Functions**: 33 HTTP triggers + 2 timer triggers
- Offline-first mobile experience with local SQLite
- JWT-based authentication via Entra External ID (fully operational)
- APIM-based rate limiting per entitlement (backend validates entitlement in PostgreSQL)
- **Managed Identity**: Full RBAC-based access to Key Vault and Storage
- **Age Verification**: 21+ requirement enforced at signup via Entra External ID Custom Authentication Extension
- **Runtime Security**: No build-time keys, all credentials obtained at runtime

### Planned (Future)

- **Custom Recipes**: User-created cocktails with AI enhancement (Create Studio)
- **Social Features**: Share cocktails with friends

## Data Flow (Mermaid)

```mermaid
sequenceDiagram
  participant M as Mobile (Flutter)
  participant APIM as API Management
  participant F as Azure Functions (HTTP)
  participant DB as PostgreSQL
  participant AI as Azure OpenAI (GPT-4.1-mini)

  Note over M,AI: AI Chat Flow (JWT-Only Authentication)
  M->>APIM: HTTPS /v1/ask-bartender (JWT only)
  APIM->>APIM: Validate JWT (signature, expiration, audience)
  APIM->>F: Forward request with X-User-Id header
  F->>DB: Lookup user entitlement
  F->>AI: GPT-4.1-mini processing
  F-->>M: AI response

  Note over M,AI: Voice Flow (Subscribers Only)
  M->>APIM: POST /v1/voice/session (JWT only)
  APIM->>F: Forward to voice-session function
  F->>DB: Verify user has paid entitlement
  F->>AI: Request ephemeral WebRTC token from Realtime API
  AI-->>F: Return ephemeral token
  F-->>M: Return WebRTC token + session info
  M->>AI: Direct WebRTC connection to Azure OpenAI Realtime API
  AI-->>M: Bidirectional voice streaming
  M->>APIM: POST /v1/voice/complete (record usage)

  Note over M: All images stored locally on device
  Note over M: All free features run offline

  Note over M,AI: Subscription Flow (RevenueCat)
  M->>RC: Purchase via Google Play
  RC->>APIM: POST /v1/subscription/webhook (signature auth)
  APIM->>F: Forward webhook event
  F->>F: Verify signature, check idempotency
  F->>DB: Record event in subscription_events
  F->>DB: Upsert user_subscriptions, trigger updates users.entitlement
  F-->>RC: 200 OK (processed)
  M->>APIM: GET /v1/subscription/status (JWT)
  APIM->>F: Forward to subscription-status
  F->>DB: Query subscription status
  F-->>M: { entitlement, isActive, expiresAt }
```

**Note:** RC = RevenueCat server-to-server webhook

## Azure Functions Architecture (v4 Programming Model)

### Overview

All 35 functions use the Azure Functions v4 programming model with code-centric registration in a single `index.js` file. The migration from v3 to v4 was completed on November 20, 2025.

### Function Catalog (35 Total)

**Core & Health (1)**
- `health` - Health check endpoint (GET /api/health)
  - Anonymous access, returns version and hosting info

**AI & Vision Functions (8)**
- `ask-bartender` - AI bartender with telemetry (POST /api/v1/ask-bartender)
- `ask-bartender-simple` - Simplified AI bartender (POST /api/v1/ask-bartender-simple)
- `ask-bartender-test` - AI bartender test endpoint (POST /api/v1/ask-bartender-test)
- `recommend` - AI recommendations with JWT (POST /api/v1/recommend)
- `refine-cocktail` - Create Studio AI refinement (POST /api/v1/create-studio/refine)
- `vision-analyze` - Smart Scanner bottle detection using Claude Haiku (POST /api/v1/vision/analyze)
- `voice-bartender` - Voice-guided cocktail making (POST /api/v1/voice-bartender)
- `speech-token` - Azure Speech token generation (GET /api/speech-token)

**Authentication Functions (4)**
- `auth-exchange` - Token exchange for APIM subscriptions (POST /api/v1/auth/exchange)
- `auth-rotate` - Key rotation for APIM (POST /api/v1/auth/rotate)
- `users-me` - User profile endpoint (GET /api/v1/users/me)
- `validate-age` - Age validation (POST /api/validate-age)

**Data & Storage Functions (6)**
- `snapshots-latest` - Get latest snapshot (GET /api/snapshots/latest)
- `snapshots-latest-mi` - Snapshot with managed identity (GET /api/v1/snapshots/latest-mi)
- `download-images` - Download cocktail images (POST /api/v1/admin/download-images)
- `download-images-mi` - Images with managed identity (POST /api/v1/admin/download-images-mi)
- `sync-cocktaildb` - CocktailDB sync (DISABLED - using local PostgreSQL as master)
- `sync-cocktaildb-mi` - CocktailDB sync with managed identity (DISABLED)

**Social Features (4)**
- `social-inbox` - Social inbox (GET /api/v1/social/inbox)
- `social-invite` - Social invites (GET /api/v1/social/invite/{token?})
- `social-outbox` - Social outbox (GET /api/v1/social/outbox)
- `social-share-internal` - Internal sharing (POST /api/v1/social/share-internal)

**Subscription Functions (3)**
- `subscription-config` - RevenueCat API key for SDK initialization (GET /api/v1/subscription/config)
- `subscription-status` - User subscription status and entitlement (GET /api/v1/subscription/status)
- `subscription-webhook` - RevenueCat server-to-server webhook (POST /api/v1/subscription/webhook)
  - Handles: INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION, BILLING_ISSUE, PRODUCT_CHANGE, UNCANCELLATION, SUBSCRIPTION_PAUSED
  - Features: Idempotency via event ID, sandbox filtering, grace period handling

**Voice Purchase (1)**
- `voice-purchase` - Purchase voice minutes (POST /api/v1/voice/purchase)

**Testing & Utilities (5)**
- `test-keyvault` - Key Vault access test (GET /api/test/keyvault)
- `test-mi-access` - Managed Identity test (GET /api/test/mi-access)
- `test-write` - Blob write test (GET /api/test/write)
- `rotate-keys-timer` - Scheduled key rotation (timer)
- `voice-session-cleanup` - Hourly stale voice session expiry (timer)

### v4 Programming Model Details

**Registration Pattern:**
```javascript
// index.js - All functions registered here
const { app } = require('@azure/functions');

app.http('function-name', {
    methods: ['POST'],
    authLevel: 'anonymous',
    route: 'v1/path',
    handler: async (request, context) => {
        const body = await request.json();
        return { status: 200, jsonBody: result };
    }
});
```

**Key v4 Changes:**
- **Request**: `await request.json()` instead of `req.body`
- **Response**: `return { jsonBody }` instead of `context.res = { body }`
- **Logging**: `context.error()` instead of `context.log.error()`
- **Registration**: Code-centric in `index.js` instead of function.json files

**Module Delegation:**
Complex functions delegate to v3-style modules for maintainability:
- Auth functions (auth-exchange, auth-rotate, users-me)
- Data functions (snapshots, download-images, sync-cocktaildb)
- Social functions (social-inbox, social-invite, social-outbox, social-share-internal)

**Azure OpenAI Integration:**
All AI functions now use the official `@azure/openai` SDK:
```javascript
const { OpenAIClient, AzureKeyCredential } = require('@azure/openai');
const client = new OpenAIClient(endpoint, new AzureKeyCredential(apiKey));
const result = await client.getChatCompletions(deployment, messages, options);
```

**Migration Status:**
- ✅ 35 functions deployed and operational
- ⚠️ 1 function (speech-token) has configuration issue unrelated to migration

## AI Model & Cost Strategy

- **Recommendations**: GPT-4.1-mini via @azure/openai SDK (cost/latency optimized)
  - Input: $0.15 per 1M tokens
  - Output: $0.60 per 1M tokens
  - ~$0.007 per cocktail conversation
  - **SDK**: Official Azure package for better integration and support
- **Voice**: Azure OpenAI Realtime API (direct voice-to-voice)
  - Subscribers only: 60 minutes/month included (+ $5.99 for 60 min add-on)
  - Active speech time metering (only user + AI talking time counts)
  - WebRTC-based low-latency streaming
- **Vision/Smart Scanner**: Claude Haiku (Anthropic) via Azure - bottle detection for inventory
- **Prompt Optimization**: Structured prompts for GPT-4.1-mini efficiency

## Entitlement Quotas (Monthly)

| Feature            | Free (none) | Subscriber (paid)                     |
| ------------------ | ----------- | ------------------------------------- |
| AI Tokens          | 0           | 1,000,000                             |
| Scanner (Vision)   | 0           | 100 scans                             |
| Voice Assistant    | 0           | 60 min included + $5.99/60 min add-on |
| Custom Recipes     | Unlimited   | Unlimited                             |
| Snapshot Downloads | Unlimited   | Unlimited                             |
| Price              | Free        | $9.99/mo or $99.99/yr                 |

**Note**: Free users have access to the local cocktail database only. All AI features (chat, scanner, voice) require a paid subscription. 3-day free trial available on monthly plan.

## Authentication Architecture (JWT-Only)

### Overview
The mobile app uses JWT-only authentication. APIM validates the JWT token via policy, and the backend functions check user entitlement in PostgreSQL.

### Flow
1. User authenticates with Entra External ID
2. Mobile app receives JWT (access token, refresh token, ID token)
3. All API requests include `Authorization: Bearer <JWT>` header
4. APIM validates JWT (signature, expiration, audience) via `validate-jwt` policy
5. APIM extracts user ID and passes to backend via `X-User-Id` header
6. Backend function looks up user entitlement in PostgreSQL
7. Request processed based on user's entitlement and quotas

### Key Components

**APIM JWT Validation Policy**:
- Validates JWT signature via OpenID Connect discovery
- Checks token expiration and audience
- Extracts user ID for backend

**Backend Entitlement Validation**:
- Functions query PostgreSQL for user entitlement (paid/none)
- Quotas enforced server-side based on entitlement
- Usage tracked in database

### Security Benefits
- **No API keys on client** - only JWT token
- **Server-side entitlement validation** - cannot be bypassed
- **Token expiration** - short-lived access tokens (~1 hour)
- **Silent refresh** - automatic token renewal
- **Audit trail** - all requests logged with user ID

## API Management (APIM) Configuration

### Instance Details

- **Name**: `apim-mba-002`
- **Gateway URL**: https://apim-mba-002.azure-api.net
- **Developer Portal**: https://apim-mba-002.developer.azure-api.net
- **Current Tier**: Basic V2 (~$150/month)

### Subscription Entitlements

**Free (none):**

- Features: Local cocktail database, basic search, browse recipes
- AI features: None (paywall shown)

**Subscriber (paid):**

- Features: AI recommendations (1,000,000 tokens/30 days), Scanner (100 scans/30 days), Voice AI (60 minutes/30 days)
- Voice add-on: $5.99 for 60 additional minutes (non-expiring)
- Price: $9.99/month (3-day free trial) or $99.99/year
- Managed via RevenueCat with single `paid` entitlement

### Backend Integration

- APIM forwards requests to Function App: `func-mba-fresh.azurewebsites.net`
- **Authentication**: JWT validation via APIM policy (subscriptionRequired: false)
- Rate limiting based on user entitlement (checked in backend)
- Caching for read-heavy endpoints (`/v1/snapshots/latest`)
- **Public Endpoints** (5): health, snapshots-latest, cocktail-preview, subscription-webhook, social-connect-callback (no JWT required)
- **Protected Endpoints** (13): All AI, subscription, scanner, voice, social, and auth endpoints (JWT required via `validate-jwt` policy)
- **Previously Protected** (17): Voice session/quota/purchase/usage, users-me, social internal/inbox/outbox/invite, validate-age (JWT via earlier Portal deployment)

## Monitoring & Alerting

### Application Insights Integration

All authentication and key management functions include comprehensive monitoring:

**Events Tracked**:
- AuthenticationSuccess/Failure
- RateLimitExceeded
- JwtValidationFailure
- EntitlementValidationFailure
- SuspiciousActivity

**Metrics for Alerting**:
- High authentication failure rate (>50 in 5 min)
- Rate limit violations per user
- Key rotation failures
- Entitlement distribution (paid/none)

**Security Monitoring**:
- Attack detection via failure rate analysis
- Suspicious activity tracking
- JWT validation failure patterns
- Comprehensive audit trail

## Feature: Recipe Database & Snapshot Service

**Status:** ✅ **OPERATIONAL** (PostgreSQL is authoritative master)

**Note:** TheCocktailDB sync timers are DISABLED. The PostgreSQL database (`mybartender`) is now the authoritative master copy with custom modifications. Snapshots are generated manually when needed.

### Architecture Changes (Current State)

- **Storage Access**: Managed Identity with RBAC (Key Vault and Blob Storage)
- **Snapshot Format**: SQLite binary files (.db.zst) with zstd compression
- **Compression**: Built-in gzip for transport, zstd for storage
- **Images**: Downloaded from TheCocktailDB (UK) to Azure Blob Storage (US), then bundled for mobile app
- **Distribution**: Via APIM-integrated endpoints
- **Azure Functions**: v4 programming model with code-centric registration
- **AI Integration**: Official @azure/openai SDK for all AI features
- **Current Metrics** (January 2026):
  - 621 drinks, 2491 ingredients, 40 glass types, 11 categories, 67 tags
  - Snapshot size: ~172KB (SQLite binary with zstd compression)
  - Response time: <100ms

### Components

- **Timer Function** `sync-cocktaildb` (v4, DISABLED)
- **Timer Function** `sync-cocktaildb-mi` (v4, DISABLED)
- **HTTP Function** `GET /api/snapshots/latest` (v4, operational)
- **HTTP Function** `GET /api/v1/snapshots/latest-mi` (v4, Managed Identity variant)
- **HTTP Function** `POST /api/v1/admin/download-images` (v4, image management)
- **HTTP Function** `POST /api/v1/admin/download-images-mi` (v4, Managed Identity variant)
- **PostgreSQL**: Authoritative data with AI enhancements
  - Connection string format: `postgresql://user:pass@host/db?sslmode=require` (URI format required by pg library)
  - Accessed via Key Vault secret with Managed Identity
- **Blob Storage**:
  - `/snapshots/sqlite/{schemaVersion}/{snapshotVersion}.db.zst` (SQLite binary with zstd compression)
  - `/drink-images/drinks/{filename}.jpg` (original resolution from TheCocktailDB)
  - Accessed via Managed Identity with Storage Blob Data Contributor role
- **Mobile**: Downloads snapshot + all images during installation, stores locally for offline use

### Data Pipeline

```mermaid
sequenceDiagram
  autonumber
  participant T as Timer Function
  participant CDB as TheCocktailDB V2 (UK)
  participant PG as PostgreSQL
  participant BL as Blob Storage (US)
  participant APIM as API Management
  participant M as Mobile App

  T->>CDB: Fetch drinks/ingredients (throttled)
  CDB-->>T: JSON data + image URLs (UK)
  T->>PG: Upsert normalized data (via Managed Identity)
  T->>CDB: Download ALL drink images
  T->>BL: Store images (Managed Identity - original resolution)
  T->>PG: Query all data for snapshot
  T->>T: Build SQLite binary, zstd compress
  T->>BL: Upload snapshot.db.zst (Managed Identity)
  T->>PG: Record metadata (snapshot_version, size, sha256, counts)
  M->>APIM: GET /v1/snapshots/latest (public endpoint)
  APIM->>M: { version, signedUrl, sha256, counts }
  M->>BL: Download SQLite snapshot (signed URL)
  M->>BL: Download ALL images during install/update (signed URL)
  M->>M: Store images + data locally
  M->>M: All free features run offline
```

### Snapshot Retention

- Keep last 7 daily snapshots (1 week rollback)
- Metadata tracks version, size, drink count
- Mobile app caches and checks for updates

## Voice Interaction Architecture (Subscribers Only)

### Implementation: Azure OpenAI Realtime API

Voice AI is implemented using **Azure OpenAI Realtime API** for direct voice-to-voice interactions via WebRTC. This provides a natural, conversational experience for guided cocktail making with sub-100ms latency.

### Implementation Flow

```
1. User initiates voice session → Backend returns ephemeral WebRTC token
2. Mobile app establishes WebRTC connection to Azure OpenAI Realtime API
3. User speaks → Audio streamed directly via WebRTC
4. Azure OpenAI processes speech and generates voice response
5. AI voice response streamed back in real-time
6. Bidirectional voice conversation continues until session ends
```

### Azure OpenAI Realtime API Features

- **Direct Voice-to-Voice**: No separate STT/TTS steps - seamless conversation
- **Low Latency**: Real-time streaming via WebRTC (UDP-based)
- **Natural Conversation**: AI bartender with cocktail expertise
- **Pacing Control**: System prompt instructions for relaxed, clear speech
- **Subscribers Only**: 60 minutes/month included (+ $5.99/60 min add-on available)
- **iOS Audio Muting**: Two-layer defense — `replaceTrack(null)` removes audio track from WebRTC sender on iOS (where `track.enabled = false` doesn't fully silence the stream), plus transcript guard filters any leaked audio

### Voice Assistant Functions (v4)

- `ask-bartender`: Main conversational endpoint (v4, @azure/openai SDK, GPT-4.1-mini)
- `ask-bartender-simple`: Simplified for testing (v4, @azure/openai SDK)
- `ask-bartender-test`: Non-auth testing endpoint (v4, @azure/openai SDK)
- `voice-bartender`: Voice-guided cocktail making (v4, POST /api/v1/voice-bartender)
- `speech-token`: Azure Speech token generation (v4, GET /api/speech-token)

**Note:** All AI functions now use the official `@azure/openai` SDK instead of the generic `openai` package for better Azure integration and support.

### Age Verification Function

- `validate-age`: Custom Authentication Extension for Entra External ID
  - **Purpose**: Server-side age verification (21+) during account signup
  - **Event Type**: OnAttributeCollectionSubmit (fires AFTER user submits birthdate)
  - **Authentication**: OAuth 2.0 Bearer tokens from Entra External ID
  - **Features**:
    - Extension attribute handling (GUID-prefixed custom attributes)
    - Multiple date format support (MM/DD/YYYY, MMDDYYYY, YYYY-MM-DD)
    - Privacy-focused (birthdate not stored, only age_verified boolean)
  - **Status**: ✅ Deployed and tested
  - **URL**: https://func-mba-fresh.azurewebsites.net/api/validate-age

## Subscription Architecture (RevenueCat)

### Overview

Subscription management is handled via **RevenueCat** for unified subscription lifecycle across platforms (Android and iOS). The backend receives server-to-server webhooks to maintain authoritative subscription state in PostgreSQL.

### Components

**Database Tables:**
- `user_subscriptions` - Current subscription state per user (one row per user)
- `subscription_events` - Audit log of all webhook events (includes raw payload)

**Functions:**
- `subscription-config` - Returns RevenueCat public API key for SDK initialization
- `subscription-status` - Returns user's current subscription entitlement and status
- `subscription-webhook` - Receives RevenueCat server-to-server notifications

### Webhook Event Handling

| Event Type | Action |
|------------|--------|
| `INITIAL_PURCHASE` | Activate subscription, set entitlement to `paid` |
| `RENEWAL` | Extend subscription, update expiry |
| `CANCELLATION` | Keep active until expiry, set autoRenewing=false |
| `EXPIRATION` | Deactivate subscription, set entitlement to `none` |
| `BILLING_ISSUE` | Check grace period; keep active if in grace |
| `PRODUCT_CHANGE` | Update billing interval based on new product |
| `UNCANCELLATION` | Reactivate auto-renewal |
| `SUBSCRIPTION_PAUSED` | Deactivate but retain renewal intent |

### Key Features

**Idempotency:**
- Each webhook event has unique `event.id`
- Stored in `subscription_events.revenuecat_event_id` with unique index
- Duplicate events return 200 OK but skip processing

**Grace Period Handling:**
- BILLING_ISSUE checks `grace_period_expires_date_ms`
- Users retain access during grace period
- Subscription deactivates only after grace expires

**Sandbox Filtering:**
- Production webhook ignores `environment: 'SANDBOX'` events
- Sandbox events logged for debugging but don't update subscriptions

**Entitlement Sync Trigger:**
- PostgreSQL trigger `sync_user_tier_from_subscription` automatically updates `users.entitlement` and `users.tier` (backward compat)
- Ensures authoritative entitlement is always in sync with subscription state

### Authentication

- **subscription-config**: JWT required (user must be authenticated)
- **subscription-status**: JWT required (returns current user's status)
- **subscription-webhook**: RevenueCat signature verification (HMAC-SHA256)
  - No JWT - uses `X-RevenueCat-Webhook-Signature` header
  - Secret stored in Key Vault: `REVENUECAT-WEBHOOK-SECRET`

## Today's Special Architecture (January 2026)

### Overview

The Today's Special feature displays a daily featured cocktail on the home screen with push notification reminders. The system is designed for reliability across Android OEM battery optimization and supports deep linking from notifications.

### Components

**Mobile App:**
- `todays_special_provider.dart` - Riverpod FutureProvider for cocktail selection
- `notification_service.dart` - flutter_local_notifications integration
- `battery_optimization_service.dart` - Android battery exemption handling
- `home_screen.dart` - Today's Special card UI

**Key Features:**
- **Midnight Refresh**: Timer-based provider invalidation at local midnight
- **7-Day Scheduling**: One-time alarms for next 7 days (more reliable than repeating)
- **Idempotent Scheduling**: 30-minute cooldown prevents infinite notification loops
- **Battery Exemption**: Requests `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` for reliable alarms
- **Deep Linking**: Notification payload contains cocktail ID for direct navigation

### Data Flow

```mermaid
sequenceDiagram
  participant P as Provider
  participant DB as SQLite
  participant SP as SharedPreferences
  participant N as NotificationService
  participant OS as Android AlarmManager

  P->>SP: Check today's cached selection
  alt Cache Hit (same day)
    SP-->>P: Return cached cocktail ID
    P->>DB: Fetch cocktail by ID
  else Cache Miss
    P->>DB: Get random cocktail
    P->>SP: Store selection for today
  end
  P->>N: Schedule notifications (if not recently scheduled)
  N->>N: Check idempotency (30-min cooldown)
  N->>OS: Schedule 7 one-time exact alarms
  Note over OS: Alarms fire at configured time
  OS->>N: Notification delivered
  Note over N: User taps notification
  N->>App: Deep link to /cocktail/:id
```

### Notification Scheduling Details

**SharedPreferences Keys:**
- `todays_special_date` - Date key (YYYY-MM-DD)
- `todays_special_id` - Selected cocktail ID
- `notification_enabled` - User preference (default: true)
- `notification_hour` / `notification_minute` - Notification time (default: 5:00 PM)
- `notification_last_scheduled` - Idempotency timestamp

**Android Permissions:**
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
```

### Bug Fixes (January 2026)

1. **Infinite Loop Prevention**: Added idempotency check - scheduling skipped if done within 30 minutes
2. **Deep Link Protection**: Protected `/cocktail/:id` route from router redirects
3. **Battery Optimization**: Request exemption for reliable alarm delivery on Samsung/Xiaomi/Huawei

## Security & Privacy

### Authentication & Access

- **Current Status (January 2026)**:
  - JWT authentication via Microsoft Entra External ID (fully operational)
  - JWT-only authentication (APIM validates JWT via policy)
  - Server-side entitlement validation in PostgreSQL
  - Rate limiting based on user entitlement
  - **Azure Functions v4 Programming Model**: All 35 functions deployed
  - **Official Azure OpenAI SDK**: All AI features using @azure/openai
  - **RevenueCat Subscriptions**: Webhook-based subscription management
- **Storage Access**: Managed Identity with Storage Blob Data Contributor role
- **Key Vault Access**: Managed Identity with Key Vault Secrets User role (RBAC)
- **PostgreSQL Access**: Connection string retrieved from Key Vault via Managed Identity
- **Function Keys**: For admin endpoints and direct access (supplemental security)

### PII Policy

- **Birthdate (Age Verification)**:
  - Collected ONLY during signup for one-time validation
  - Processed by `validate-age` function but NOT stored
  - Only boolean `age_verified: true` flag persisted in identity system
  - Not transmitted in JWT tokens, not accessible via API
  - Complies with minimal PII storage principles
- **Custom recipe names**: Stripped from telemetry
- **Voice transcripts**: Opt-in storage only (default: ephemeral processing)
- **Bar photos**: Processed ephemerally, never stored
- **User ingredients**: Hashed before logging
- **Anonymization**: 90-day retention for opted-in data

### Secrets Management

- **Key Vault**: `kv-mybartenderai-prod` (in `rg-mba-dev`)
  - Secret `COCKTAILDB-API-KEY`: TheCocktailDB V2 API key
  - Secret `AZURE-OPENAI-API-KEY`: Azure OpenAI API key
  - Secret `AZURE-OPENAI-ENDPOINT`: Azure OpenAI endpoint
  - Secret `POSTGRES-CONNECTION-STRING`: PostgreSQL URI format
    - **CRITICAL**: Must use URI format `postgresql://user:pass@host/db?sslmode=require`
- **Function App**:
  - Environment variables for runtime configuration
  - API keys via Key Vault references: `@Microsoft.KeyVault(VaultName=kv-mybartenderai-prod;SecretName=...)`
  - No hardcoded keys in code or configuration
- **Mobile App**:
  - JWT tokens stored in secure device storage
  - No API keys on client (JWT-only authentication)
  - Silent token refresh on expiration

## Mobile App Updates

### JWT Token Management

1. User authenticates with Entra External ID
2. Store JWT tokens (access, refresh, ID) in secure storage
3. Include `Authorization: Bearer <JWT>` header in all API requests
4. On 401 response, trigger silent token refresh
5. Retry original request with new token (max 1 retry)
6. Clear all tokens on logout

### Snapshot Download Strategy

1. Download compressed SQLite snapshot (.db.zst) via signed URL
2. Verify sha256 checksum for integrity
3. Decompress zstd file
4. Atomic database file swap
5. Verify local database integrity (drink count, schema version)

### Image Storage Strategy

- **Initial Install**: Download ALL drink images (~621 images) from Azure Blob to device
- **Updates**: Download only new/changed images (delta sync via manifest)
- **Source**: TheCocktailDB images re-hosted in Azure Blob Storage (US region)
- **Local Storage**: All images stored on device for instant offline access
- **No Network**: Free features (browse, search, view recipes) work 100% offline
- **Subscriber Features**: AI recommendations, vision, voice require network + JWT authentication + paid entitlement

## Future Enhancements

### Phase 2: Premium Features

- Vision AI integration for inventory scanning (Azure Computer Vision)
- Voice-guided cocktail making (Azure Speech Services)
- Custom recipe creation with AI assistance (GPT-4.1-mini)

### Phase 3: Advanced

- Real-time collaboration on recipes
- Social features (share custom cocktails)
- Ingredient substitution AI
- Cocktail history and preferences learning
- Multi-language support (Azure Speech Translation)

### Phase 4: Platform Optimization

- ✅ Managed Identity implementation (completed November 2025)
- ✅ Azure Functions v4 migration (completed November 2025)
- 📋 APIM Consumption tier for production
- 📋 Azure Front Door for global CDN (if needed)
- 📋 Premium/Dedicated PostgreSQL tier for scale
- 📋 Performance optimization and caching strategies

## Development & Deployment

### Local Development

```bash
# Backend
cd backend/functions
npm install  # Windows-compatible, no native modules
npm run build
func start

# Mobile
cd mobile/app
flutter pub get
flutter run

# Build APK (no hardcoded keys)
flutter build apk --release

# APIM local testing
# Use APIM test console or Postman with valid JWT token
```

### Deployment

- **Azure Functions**: ZIP deployment to Windows Premium Consumption plan (`func-mba-fresh`)
- **Programming Model**: Azure Functions v4 with code-centric registration
- **Runtime**: Node.js 22 on Windows
- **Dependencies**: All declared in package.json, including:
  - `@azure/functions` - v4 runtime
  - `@azure/openai` - Official Azure OpenAI SDK
  - `@azure/storage-blob` - Blob storage operations
  - `@azure/identity` - Managed Identity authentication
  - `@azure/cognitiveservices-computervision` - Vision AI
  - `applicationinsights` - Telemetry and monitoring
- **Deployment Command**: `func azure functionapp publish func-mba-fresh`
- **CI/CD**: GitHub Actions workflow (`.github/workflows/main_func-mba-fresh.yml`)
- **Secrets**: Environment variables and Key Vault references (no hardcoded keys)
- **Access**:
  - Managed Identity for Azure services (Key Vault, Storage)
  - Runtime token exchange for all user access
  - Function keys for admin endpoints
- **APIM**: Manual configuration via Azure Portal (Developer tier)
- **Testing**: PowerShell test scripts for v4 verification
  - `test-v4-functions.ps1` - Basic function tests
  - `test-auth-functions.ps1` - Authentication tests
  - `test-v4-comprehensive.ps1` - Full test suite
  - `test-specific-routes.ps1` - Route verification
- **Security Features**:
  - Managed Identity for service authentication
  - Runtime token exchange for user authentication
  - Per-user rate limiting
  - Monthly key rotation
  - Attack detection
  - Comprehensive monitoring

## Cost Optimization

### Current MVP Cost (~$60-70/month)

- **APIM Developer**: ~$50/month (fixed cost for development)
- **Functions**: Windows Consumption plan (~$0.20/million executions, minimal for MVP)
- **Storage**: ~$0.50-1/month (snapshots + ~621 images)
- **PostgreSQL**: Basic tier ~$12-30/month (smallest tier)
- **Azure OpenAI (GPT-4.1-mini)**: Pay-per-use, ~$0.40/user/month for subscribers
- **Azure Speech Services**: Free tier: 5 hours/month, then $1/hour
- **Application Insights**: ~$5/month for monitoring

### Production Target (~$20-30/month + usage)

- **APIM Consumption**: ~$5-15/month (based on actual usage)
- **Functions**: Same (~$0.20/million executions)
- **Storage**: ~$0.50-1/month
- **PostgreSQL**: Optimized tier ~$12-20/month
- **AI Services**: Covered by subscription revenue
- **Speech Services**: ~$10-20/month for moderate usage
- **Monitoring**: Scales with usage, covered by revenue

### Revenue Model

- **Free ($0/month)**: Local cocktail database only, drives conversion
- **Subscriber ($9.99/month or $99.99/year)**: Full AI access (1M tokens, 100 scans, 60 min voice)
- **Voice Add-on ($5.99)**: +60 minutes, non-expiring, repeatable
- **Target**: 1,000 subscribers = $10,000 revenue, ~$500 AI costs = **95% margin**

---

**Last Updated**: February 16, 2026
**Architecture Version**: 3.8 (v4 Functions + Managed Identity + Azure OpenAI SDK + Realtime Voice + Server-Authoritative Metering + RevenueCat Subscriptions + Binary Entitlement Model + Today's Special Notifications + iOS Platform + Full APIM JWT Coverage + Push-to-Talk Interruption Fix)
**Programming Model**: Azure Functions v4
**Platforms**: Android and iOS (Flutter cross-platform)
**Security Level**: Production-ready with Managed Identity + Complete APIM JWT Validation