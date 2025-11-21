# Architecture — MyBartenderAI (MVP)

## System Overview

- Flutter app (feature-first clean architecture; Riverpod state; GoRouter)
- Azure API Management (`apim-mba-001`) as API gateway for tier management and security
- **Azure Functions v4 Programming Model** - 27 functions with code-centric registration
- **Node.js 18+ runtime** on Windows Premium Consumption plan
- **Official Azure OpenAI SDK** (@azure/openai) for all AI features
- Azure PostgreSQL for authoritative recipe corpus with AI enhancements
- Azure Blob for cocktail images (US-hosted) and JSON snapshots
- Key Vault for secrets (accessed via Managed Identity); App Insights for telemetry
- **Managed Identity** for Key Vault and Storage access
- All free features run locally on device (offline-first)
- Mobile → APIM → Azure Functions (HTTPS) → (PostgreSQL/Blob/Key Vault/Azure OpenAI)

## Current Operational Status (November 20, 2025)

### Working Features
- ✅ Recipe Vault (database download and sync via APIM)
- ✅ My Bar (inventory management)
- ✅ Favorites/bookmarks
- ✅ User authentication (Entra External ID with JWT)
- ✅ Runtime token exchange (JWT → APIM subscription key)
- ✅ AI Bartender Chat (all tiers, including Free with limited quota)
- ✅ APIM dual authentication (JWT + subscription key)
- ✅ Rate limiting per user (10 req/min on auth exchange)
- ✅ Monitoring and alerting (Application Insights)
- ✅ **Azure Functions v4 Migration Complete** - All 27 functions migrated and deployed
- ✅ **Official Azure OpenAI SDK** - All AI functions using @azure/openai package
- ✅ **Managed Identity** - Full implementation for Key Vault and Storage access

### Recent Backend Improvements (November 2025)

**Azure Functions v4 Migration (November 20, 2025):**
- ✅ **v4 Programming Model**: Code-centric registration in single `index.js` file
- ✅ **27 Functions Migrated**: 24 HTTP triggers + 3 timer triggers
- ✅ **Azure OpenAI SDK**: Migrated from `openai` to official `@azure/openai` package
- ✅ **API Updates**: Modern request/response handling (await request.json(), return jsonBody)
- ✅ **Logging Updates**: Fixed context.error() vs context.log.error() patterns
- ✅ **Module Delegation**: v4 functions delegate to v3-style modules where needed
- ✅ **96% Success Rate**: 26/27 functions verified working post-migration
- ✅ **Comprehensive Testing**: PowerShell test scripts created and validated

**Security Improvements:**
- ✅ **Runtime Token Exchange**: Per-user APIM keys obtained at runtime
- ✅ **No Hardcoded Keys**: All subscription keys removed from source/APK
- ✅ **Dual Authentication**: JWT (identity) + APIM key (authorization/quota)
- ✅ **Rate Limiting**: Azure Table Storage based per-user limits
- ✅ **Attack Detection**: High failure rate monitoring (>50 failures/5 min)
- ✅ **Key Rotation**: Monthly automatic rotation with instant revocation
- ✅ **Managed Identity**: RBAC-based access to Key Vault and Storage

## Core Features

### Current (MVP)

- AI-powered cocktail recommendations based on inventory (GPT-4o-mini via @azure/openai SDK)
- **Azure Functions v4 Programming Model** with code-centric registration
- **27 Backend Functions**: 24 HTTP triggers + 3 timer triggers
- Offline-first mobile experience with local SQLite
- JWT-based authentication via Entra External ID (fully operational)
- APIM-based rate limiting per tier using per-user subscription keys
- **Managed Identity**: Full RBAC-based access to Key Vault and Storage
- **Age Verification**: 21+ requirement enforced at signup via Entra External ID Custom Authentication Extension
- **Runtime Security**: No build-time keys, all credentials obtained at runtime

### Planned (Premium/Pro)

- **Vision AI**: Photograph home bar for automatic inventory
- **Custom Recipes**: User-created cocktails with AI enhancement

## Data Flow (Mermaid)

```mermaid
sequenceDiagram
  participant M as Mobile (Flutter)
  participant APIM as API Management
  participant AE as Auth Exchange Function
  participant F as Azure Functions (HTTP)
  participant DB as PostgreSQL
  participant B as Blob Storage (US)
  participant AI as Azure OpenAI (GPT-4o-mini)
  participant Speech as Azure Speech Services

  Note over M,AE: Runtime Token Exchange Flow
  M->>APIM: POST /v1/auth/exchange (JWT only)
  APIM->>AE: Forward with validated JWT
  AE->>AE: Verify JWT, check rate limit
  AE->>APIM: Create/retrieve user subscription
  AE-->>M: Return subscription key + quotas

  Note over M,AI: AI Chat Flow (All Tiers)
  M->>APIM: HTTPS /v1/ask-bartender (JWT + APIM Key)
  APIM->>F: Forward with dual auth validation
  F->>AI: GPT-4o-mini processing
  F-->>M: AI response

  Note over M,Speech: Voice Flow (Premium/Pro - Future)
  M->>Speech: Speech-to-Text (user speaks)
  M->>APIM: Text query to /ask-bartender
  APIM->>F: Forward request
  F->>AI: GPT-4o-mini processing
  F-->>M: Text response
  M->>Speech: Text-to-Speech (AI speaks)

  Note over M: All images stored locally on device
  Note over M: All free features run offline
```

## Azure Functions Architecture (v4 Programming Model)

### Overview

All 27 functions use the Azure Functions v4 programming model with code-centric registration in a single `index.js` file. The migration from v3 to v4 was completed on November 20, 2025.

### Function Catalog (27 Total)

**Core & Health (1)**
- `health` - Health check endpoint (GET /api/health)
  - Anonymous access, returns version and hosting info

**AI & Vision Functions (8)**
- `ask-bartender` - AI bartender with telemetry (POST /api/v1/ask-bartender)
- `ask-bartender-simple` - Simplified AI bartender (POST /api/v1/ask-bartender-simple)
- `ask-bartender-test` - AI bartender test endpoint (POST /api/v1/ask-bartender-test)
- `recommend` - AI recommendations with JWT (POST /api/v1/recommend)
- `refine-cocktail` - Create Studio AI refinement (POST /api/v1/create-studio/refine)
- `vision-analyze` - Computer Vision bottle detection (POST /api/v1/vision/analyze)
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
- `sync-cocktaildb` - Daily cocktail DB sync (timer: 03:30 UTC)
- `sync-cocktaildb-mi` - Cocktail sync with managed identity (timer)

**Social Features (4)**
- `social-inbox` - Social inbox (GET /api/v1/social/inbox)
- `social-invite` - Social invites (GET /api/v1/social/invite/{token?})
- `social-outbox` - Social outbox (GET /api/v1/social/outbox)
- `social-share-internal` - Internal sharing (POST /api/v1/social/share-internal)

**Testing & Utilities (4)**
- `test-keyvault` - Key Vault access test (GET /api/test/keyvault)
- `test-mi-access` - Managed Identity test (GET /api/test/mi-access)
- `test-write` - Blob write test (GET /api/test/write)
- `rotate-keys-timer` - Scheduled key rotation (timer)

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
- ✅ 27/27 functions migrated to v4
- ✅ 26/27 functions verified working (96% success rate)
- ⚠️ 1 function (speech-token) has configuration issue unrelated to migration

## AI Model & Cost Strategy

- **Recommendations**: GPT-4o-mini via @azure/openai SDK (cost/latency optimized)
  - Input: $0.15 per 1M tokens
  - Output: $0.60 per 1M tokens
  - ~$0.007 per cocktail conversation
  - **SDK**: Official Azure package for better integration and support
- **Voice**: Azure Speech Services (93% cheaper than OpenAI Realtime API)
  - Speech-to-Text: $1 per audio hour (~$0.017/minute)
  - Neural Text-to-Speech: $16 per 1M characters (~$0.00005 per response)
  - Total voice session cost: ~$0.10 per 5-minute interaction
- **Vision**: Azure Computer Vision (70% confidence threshold) - Future
- **Prompt Optimization**: Structured prompts for GPT-4o-mini efficiency

## Tier Quotas (Monthly) - UPDATED

| Feature            | Free      | Premium        | Pro            |
| ------------------ | --------- | -------------- | -------------- |
| AI Tokens          | 10,000    | 300,000        | 1,000,000      |
| Scanner (Vision)   | 2         | 30 scans       | 100 scans      |
| Voice Assistant    | 0         | Future Feature | Future Feature |
| Custom Recipes     | 3         | 25             | Unlimited      |
| Snapshot Downloads | Unlimited | Unlimited      | Unlimited      |
| Price              | Free      | $4.99/mo       | $8.99/mo       |

**Key Change**: Free tier now includes 10,000 AI tokens per month to enable a freemium model and drive conversion.

## Runtime Token Exchange Architecture

### Overview
Instead of build-time API key injection, the app obtains per-user APIM subscription keys at runtime by exchanging JWT tokens.

### Components

**Auth Exchange Function** (`/v1/auth/exchange`):
- Validates Entra External ID JWT
- Checks user rate limit (10 req/min via Azure Table Storage)
- Creates/retrieves user-specific APIM subscription
- Returns subscription key with tier and quotas
- Tracks success/failure metrics in Application Insights

**Auth Rotate Function** (`/v1/auth/rotate`):
- Manual key rotation for compromised accounts
- Instant revocation capability
- Monitoring integration for audit trail

**Rotate Keys Timer** (`rotate-keys-timer`):
- Monthly automatic key rotation (1st of each month)
- Bulk rotation with progress tracking
- Skips new subscriptions (<7 days old)
- Comprehensive monitoring and alerting

### Security Benefits
- **No hardcoded keys** in source or APK
- **Per-user revocable** access
- **Automatic monthly rotation**
- **Rate limiting** prevents token exchange abuse
- **Attack detection** via failure rate monitoring
- **Audit trail** for all authentication events

## API Management (APIM) Configuration

### Instance Details

- **Name**: `apim-mba-001`
- **Gateway URL**: https://apim-mba-001.azure-api.net
- **Developer Portal**: https://apim-mba-001.developer.azure-api.net
- **Current Tier**: Developer (No SLA) for development
- **Production Plan**: Consumption tier for cost optimization

### Products (Subscription Tiers)

**Free Tier Product:**

- Rate limit: 100 calls/day
- Features: Local cocktail database, basic search, AI chat (10K tokens/month)
- AI features: LIMITED (10,000 tokens per 30 days, 2 scans per 30 days)

**Premium Tier Product:**

- Rate limit: 1,000 calls/day
- Features: AI recommendations (300,000 tokens/30 days), Scanner (30 scans/30 days)
- Price: $4.99/month or $49.99/year
- Priority routing

**Pro Tier Product:**

- Rate limit: Unlimited
- Features: AI recommendations (1,000,000 tokens/30 days), Scanner (100 scans/30 days)
- Price: $8.99/month or $89.99/year
- Highest priority, dedicated support

### Backend Integration

- APIM forwards requests to Function App: `func-mba-fresh.azurewebsites.net`
- **Authentication**: Dual JWT + APIM subscription key validation
- Rate limiting policies per product
- Caching for read-heavy endpoints (`/v1/snapshots/latest`)
- **Public Endpoints**: snapshots-latest, download-images, health (subscription key only)
- **AI Endpoints**: ask-bartender, ask-bartender-simple, recommend (dual auth required)
- **Auth Endpoints**: auth/exchange, auth/rotate (JWT required)

## Monitoring & Alerting

### Application Insights Integration

All authentication and key management functions include comprehensive monitoring:

**Events Tracked**:
- AuthenticationSuccess/Failure
- RateLimitExceeded
- JwtValidationFailure
- KeyRotationSuccess/Failure
- SuspiciousActivity
- BulkKeyRotation

**Metrics for Alerting**:
- High authentication failure rate (>50 in 5 min)
- Rate limit violations per user
- Key rotation failures
- Tier distribution (free/premium/pro)

**Security Monitoring**:
- Attack detection via failure rate analysis
- Suspicious activity tracking
- JWT validation failure patterns
- Comprehensive audit trail

## Feature: CocktailDB Mirror & JSON Snapshot Service

**Status:** ✅ **OPERATIONAL** (as of 2025-10-23)

**Goal:** Nightly sync from TheCocktailDB V2 API into PostgreSQL, download all images to Azure Blob Storage (US), build compressed snapshots for mobile offline use.

### Architecture Changes (Current State)

- **Storage Access**: Managed Identity with RBAC (Key Vault and Blob Storage)
- **Snapshot Format**: SQLite binary files (.db.zst) with zstd compression
- **Compression**: Built-in gzip for transport, zstd for storage
- **Images**: Downloaded from TheCocktailDB (UK) to Azure Blob Storage (US), then bundled for mobile app
- **Distribution**: Via APIM-integrated endpoints
- **Azure Functions**: v4 programming model with code-centric registration
- **AI Integration**: Official @azure/openai SDK for all AI features
- **Current Metrics** (v20251023.033020):
  - 621 drinks, 2491 ingredients, 40 glass types, 11 categories, 67 tags
  - Snapshot size: 71KB compressed
  - Sync duration: ~16 seconds
  - Response time: <100ms

### Components

- **Timer Function** `sync-cocktaildb` (v4, nightly @ 03:30 UTC)
- **Timer Function** `sync-cocktaildb-mi` (v4, Managed Identity variant)
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
  M->>APIM: GET /v1/snapshots/latest (API Key + Tier validation)
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

## Voice Interaction Architecture (Premium/Pro)

### Why Azure Speech Services vs OpenAI Realtime API

**Cost Comparison (5-minute cocktail session):**

- OpenAI Realtime API: ~$1.50/session
- Azure Speech + GPT-4o-mini: ~$0.10/session
- **93% cost savings**

### Implementation Flow

```
1. User speaks → Azure Speech SDK (client-side)
2. Speech-to-Text → Text transcription
3. Text → APIM → Function → GPT-4o-mini
4. Response text → Azure Text-to-Speech SDK (client-side)
5. Audio playback to user
```

### Azure Speech Services Features

- **Speech-to-Text**: Real-time recognition with custom vocabulary (bartending terms)
- **Neural Text-to-Speech**: Natural voice with SSML control
- **Custom Models**: Train on cocktail-specific terminology
- **Offline Capability**: Download voices for offline TTS

### Voice Assistant Functions (v4)

- `ask-bartender`: Main conversational endpoint (v4, @azure/openai SDK, GPT-4o-mini)
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

## Security & Privacy

### Authentication & Access

- **Current Status (November 20, 2025)**:
  - JWT authentication via Microsoft Entra External ID (fully operational)
  - Runtime token exchange for per-user APIM subscription keys
  - Dual authentication: JWT (identity) + APIM key (authorization/quota)
  - Rate limiting on token exchange (10 req/min per user)
  - Monthly automatic key rotation with instant revocation
  - **Azure Functions v4 Programming Model**: All 27 functions migrated
  - **Official Azure OpenAI SDK**: All AI features using @azure/openai
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
  - APIM subscription keys obtained at runtime, cached securely
  - No build-time API keys

## Mobile App Updates

### Runtime Token Management

1. User authenticates with Entra External ID
2. Exchange JWT for APIM subscription key via `/v1/auth/exchange`
3. Cache subscription key with expiry in secure storage
4. Include both JWT and APIM key in all API requests
5. On 401/403, attempt re-exchange (max 1 retry)
6. Clear cached keys on logout

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
- **Premium Features**: AI recommendations, vision, voice require network + APIM validation

## Future Enhancements

### Phase 2: Premium Features

- Vision AI integration for inventory scanning (Azure Computer Vision)
- Voice-guided cocktail making (Azure Speech Services)
- Custom recipe creation with AI assistance (GPT-4o-mini)

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
# Use APIM test console or Postman with runtime-obtained keys
```

### Deployment

- **Azure Functions**: ZIP deployment to Windows Premium Consumption plan (`func-mba-fresh`)
- **Programming Model**: Azure Functions v4 with code-centric registration
- **Runtime**: Node.js 18+ on Windows
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
- **Azure OpenAI (GPT-4o-mini)**: Pay-per-use, ~$0.40/user/month for Premium
- **Azure Speech Services**: Free tier: 5 hours/month, then $1/hour
- **Application Insights**: ~$5/month for monitoring

### Production Target (~$20-30/month + usage)

- **APIM Consumption**: ~$5-15/month (based on actual usage)
- **Functions**: Same (~$0.20/million executions)
- **Storage**: ~$0.50-1/month
- **PostgreSQL**: Optimized tier ~$12-20/month
- **AI Services**: Covered by Premium/Pro subscription revenue
- **Speech Services**: ~$10-20/month for moderate usage
- **Monitoring**: Scales with usage, covered by revenue

### Revenue Model

- **Free ($0/month)**: Limited AI access drives conversion (10K tokens)
- **Premium ($4.99/month)**: Covers AI + Speech costs ($0.40-0.50/user/month)
- **Pro ($8.99/month)**: Higher limits, improved margins
- **Target**: 1,000 Premium users = $5,000 revenue, ~$500 AI costs = **90% margin**

---

**Last Updated**: November 20, 2025
**Architecture Version**: 3.0 (v4 Functions + Managed Identity + Azure OpenAI SDK)
**Programming Model**: Azure Functions v4
**Security Level**: Production-ready with Managed Identity