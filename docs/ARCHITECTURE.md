# Architecture — MyBartenderAI (MVP)

## System Overview
- Flutter app (feature-first clean architecture; Riverpod state; GoRouter)
- Azure API Management (`apim-mba-001`) as API gateway for tier management and security
- Azure Functions (HTTP) behind APIM for backend logic
- Azure PostgreSQL for authoritative recipe corpus with AI enhancements
- Azure Blob for cocktail images (US-hosted) and JSON snapshots
- Key Vault for secrets; App Insights for telemetry
- All free features run locally on device (offline-first)
- Mobile → APIM → Azure Functions (HTTPS) → (PostgreSQL/Blob/Key Vault/Azure OpenAI)

## Core Features
### Current (MVP)
- AI-powered cocktail recommendations based on inventory (GPT-4o-mini)
- Offline-first mobile experience with local SQLite
- JWT-based authentication and APIM-based rate limiting per tier

### Planned (Premium/Pro)
- **Vision AI**: Photograph home bar for automatic inventory
- **Voice Assistant**: Interactive cocktail-making guidance via Azure Speech Services
- **Custom Recipes**: User-created cocktails with AI enhancement

## Data Flow (Mermaid)
```mermaid
sequenceDiagram
  participant M as Mobile (Flutter)
  participant APIM as API Management
  participant F as Azure Functions (HTTP)
  participant DB as PostgreSQL
  participant B as Blob Storage (US)
  participant AI as Azure OpenAI (GPT-4o-mini)
  participant Speech as Azure Speech Services

  M->>APIM: HTTPS /v1/… (API Key)
  APIM->>F: Forward with JWT validation
  F->>DB: Read/Write cocktail data
  F->>B: Upload/Fetch snapshots (SAS)
  F->>AI: Text-based recommendations (Premium/Pro)
  Note over M,Speech: Voice Flow (Premium/Pro)
  M->>Speech: Speech-to-Text (user speaks)
  M->>APIM: Text query to /ask-bartender
  APIM->>F: Forward request
  F->>AI: GPT-4o-mini processing
  F-->>M: Text response
  M->>Speech: Text-to-Speech (AI speaks)
  Note over M: All images stored locally on device
  Note over M: All free features run offline
```

## AI Model & Cost Strategy
- **Recommendations**: GPT-4o-mini (cost/latency optimized)
  - Input: $0.15 per 1M tokens
  - Output: $0.60 per 1M tokens
  - ~$0.007 per cocktail conversation
- **Voice**: Azure Speech Services (93% cheaper than OpenAI Realtime API)
  - Speech-to-Text: $1 per audio hour (~$0.017/minute)
  - Neural Text-to-Speech: $16 per 1M characters (~$0.00005 per response)
  - Total voice session cost: ~$0.10 per 5-minute interaction
- **Vision**: Azure Computer Vision (70% confidence threshold) - Future
- **Prompt Optimization**: Structured prompts for GPT-4o-mini efficiency

## Tier Quotas (Monthly)
| Feature | Free | Premium | Pro |
|---------|------|---------|-----|
| AI Recommendations | 10 | 100 | Unlimited |
| Vision Scans | 0 | 5 | 50 |
| Voice Assistant | 0 | 30 min | 5 hours |
| Custom Recipes | 3 | 25 | Unlimited |
| Snapshot Downloads | Unlimited | Unlimited | Unlimited |

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
- Features: Local cocktail database, basic search
- No AI features

**Premium Tier Product:**
- Rate limit: 1,000 calls/day
- Features: AI recommendations (100/month), Voice (30 min/month), Vision (5 scans/month)
- Priority routing

**Pro Tier Product:**
- Rate limit: Unlimited
- Features: Unlimited AI, Voice (5 hours/month), Vision (50 scans/month)
- Highest priority, dedicated support

### Backend Integration
- APIM forwards requests to Function App: `func-mba-fresh.azurewebsites.net`
- JWT validation at APIM layer
- Rate limiting policies per product
- Caching for read-heavy endpoints (`/v1/snapshots/latest`)
- **Status**: ✅ Operational as of 2025-10-23
- **Direct endpoint**: https://func-mba-fresh.azurewebsites.net/api/v1/snapshots/latest
- **APIM endpoint**: TBD (pending APIM-to-Functions backend configuration)

## Feature: CocktailDB Mirror & JSON Snapshot Service

**Status:** ✅ **OPERATIONAL** (as of 2025-10-23)

**Goal:** Nightly sync from TheCocktailDB V2 API into PostgreSQL, download all images to Azure Blob Storage (US), build compressed snapshots for mobile offline use.

### Architecture Changes (Current MVP State)
- **Storage Access**: SAS tokens (due to Windows Consumption Plan Managed Identity limitations)
- **Snapshot Format**: SQLite binary files (.db.zst) with zstd compression
- **Compression**: Built-in gzip for transport, zstd for storage
- **Images**: Downloaded from TheCocktailDB (UK) to Azure Blob Storage (US), then bundled for mobile app
- **Distribution**: Via direct endpoint (APIM integration pending)
- **Current Metrics** (v20251023.033020):
  - 621 drinks, 2491 ingredients, 40 glass types, 11 categories, 67 tags
  - Snapshot size: 71KB compressed
  - Sync duration: ~16 seconds
  - Response time: <100ms

### Components
- **Timer Function** `sync-cocktaildb` (nightly @ 03:30 UTC, disabled duplicate `sync-cocktaildb-mi`)
- **HTTP Function** `GET /v1/snapshots/latest` → metadata with SAS-secured access (✅ operational)
- **HTTP Function** `GET /v1/images/manifest` → image bundle manifest for mobile sync (pending)
- **PostgreSQL**: Authoritative data with AI enhancements
  - Connection string format: `postgresql://user:pass@host/db?sslmode=require` (URI format required by pg library)
- **Blob Storage**:
  - `/snapshots/sqlite/{schemaVersion}/{snapshotVersion}.db.zst` (SQLite binary with zstd compression)
  - `/drink-images/drinks/{filename}.jpg` (original resolution from TheCocktailDB)
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
  T->>PG: Upsert normalized data
  T->>CDB: Download ALL drink images
  T->>BL: Store images (SAS - original resolution)
  T->>PG: Query all data for snapshot
  T->>T: Build SQLite binary, zstd compress
  T->>BL: Upload snapshot.db.zst (SAS)
  T->>PG: Record metadata (snapshot_version, size, sha256, counts)
  M->>APIM: GET /v1/snapshots/latest (API Key + Tier validation)
  Note right of M: Currently: Direct endpoint (APIM pending)
  APIM->>M: { version, signedUrl, sha256, counts }
  M->>BL: Download SQLite snapshot (15-min SAS)
  M->>BL: Download ALL images during install/update (SAS)
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

### Voice Assistant Functions
- `ask-bartender`: Main conversational endpoint (uses GPT-4o-mini)
- `ask-bartender-simple`: Simplified for testing
- `ask-bartender-test`: Non-auth testing endpoint

**Note:** Functions `realtime-token*` are legacy (OpenAI Realtime API approach) and will be deprecated in favor of Azure Speech Services architecture.

## Security & Privacy

### Authentication & Access
- JWT authentication via Microsoft Entra External ID
- APIM API keys per mobile installation
- SAS tokens for blob access (MVP - temporary)
- Future: Managed Identity for all service-to-service access
- Function keys for admin endpoints

### PII Policy
- **Custom recipe names**: Stripped from telemetry
- **Voice transcripts**: Opt-in storage only (default: ephemeral processing)
- **Bar photos**: Processed ephemerally, never stored
- **User ingredients**: Hashed before logging
- **Anonymization**: 90-day retention for opted-in data

### Secrets Management
- **Key Vault**: `kv-mybartenderai-prod` (in `rg-mba-dev`)
  - Secret `COCKTAILDB-API-KEY`: TheCocktailDB V2 API key
  - Secret `OpenAI`: Azure OpenAI API key (GPT-4o-mini)
  - Secret `POSTGRES-CONNECTION-STRING`: PostgreSQL URI format (updated 2025-10-23)
    - **CRITICAL**: Must use URI format `postgresql://user:pass@host/db?sslmode=require`
    - Named parameter format (`Host=...;Database=...;`) causes `getaddrinfo ENOTFOUND base` errors
  - Temporary: SAS tokens for blob access
- **Function App (Current MVP)**:
  - Direct connection strings set in app settings (bypasses Key Vault caching issues)
  - `PG_CONNECTION_STRING`: PostgreSQL URI
  - `BLOB_STORAGE_CONNECTION_STRING`: Storage account connection string with AccountKey
  - API keys via Key Vault references: `@Microsoft.KeyVault(VaultName=kv-mybartenderai-prod;SecretName=...)`
- **Future**: Migrate to Managed Identity (`func-mba-fresh-uami`) with Key Vault Secrets User role when upgrading from Windows Consumption Plan

## Mobile App Updates

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
- **Premium Features Only**: AI recommendations, vision, voice require network + APIM validation

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
- Migrate to Managed Identity (all services)
- APIM Consumption tier for production
- Azure Front Door for global CDN (if needed)
- Premium/Dedicated PostgreSQL tier for scale

## Development & Deployment

### Local Development
```bash
# Backend
cd apps/backend
npm install  # Windows-compatible, no native modules
npm run build
func start

# Mobile
cd mobile/app
flutter pub get
flutter run

# APIM local testing
# Use APIM test console or Postman with API keys
```

### Deployment
- **Azure Functions**: ZIP deployment to Windows Consumption plan (`func-mba-fresh`)
- **SDK**: Azure Functions v3 (@azure/functions v3.5.0) with CommonJS modules
- **Runtime**: Node.js 20 on Windows
- **Module Pattern**: `module.exports = async function (context, req) { ... }`
- **No native dependencies**: Pure JavaScript (no better-sqlite3, no native addons)
- **Deployment Command**: `func azure functionapp publish func-mba-fresh --javascript`
- **CI/CD**: GitHub Actions workflow (`.github/workflows/main_func-mba-fresh.yml`)
- **Secrets**: Direct connection strings in app settings, API keys via Key Vault references
- **Access**: Connection strings (MVP), Managed Identity (future post-Consumption plan upgrade)
- **APIM**: Manual configuration via Azure Portal (Developer tier)
- **Known Issues**:
  - Connection string parsing requires indexOf() for keys ending in `==`
  - PostgreSQL URI format required (not named parameters)
  - Full dependency install required (pg-types/lib subdirectories)

## Cost Optimization

### Current MVP Cost (~$60-70/month)
- **APIM Developer**: ~$50/month (fixed cost for development)
- **Functions**: Windows Consumption plan (~$0.20/million executions, minimal for MVP)
- **Storage**: ~$0.50-1/month (snapshots + ~621 images)
- **PostgreSQL**: Basic tier ~$12-30/month (smallest tier)
- **Azure OpenAI (GPT-4o-mini)**: Pay-per-use, ~$0.40/user/month for Premium
- **Azure Speech Services**: Free tier: 5 hours/month, then $1/hour

### Production Target (~$20-30/month + usage)
- **APIM Consumption**: ~$5-15/month (based on actual usage)
- **Functions**: Same (~$0.20/million executions)
- **Storage**: ~$0.50-1/month
- **PostgreSQL**: Optimized tier ~$12-20/month
- **AI Services**: Covered by Premium/Pro subscription revenue
- **Speech Services**: ~$10-20/month for moderate usage

### Revenue Model
- **Premium ($4.99/month)**: Covers AI + Speech costs ($0.40-0.50/user/month)
- **Pro ($9.99/month)**: Higher limits, improved margins
- **Target**: 1,000 Premium users = $5,000 revenue, ~$500 AI costs = **90% margin**