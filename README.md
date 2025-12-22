# MyBartenderAI - Release Candidate

AI-powered bartender app that helps users discover and create cocktails based on their preferences and available ingredients.

## 🚀 Current Status (December 2025)

- **Backend**: ✅ Azure Functions v4 (`func-mba-fresh`) - All functions deployed
- **API Gateway**: ✅ Azure API Management (`apim-mba-002`) - Basic V2 tier
- **Database**: ✅ PostgreSQL operational (`pg-mybartenderdb`)
- **Storage**: ✅ Blob Storage configured (`mbacocktaildb3`)
- **AI**: ✅ Azure OpenAI GPT-4o-mini + Claude Haiku (Smart Scanner)
- **Authentication**: ✅ Entra External ID (Google, Facebook, Email) - JWT-only
- **Vision**: ✅ Claude Haiku for bottle/ingredient identification
- **Voice AI**: ✅ Azure OpenAI Realtime API via WebRTC (Pro tier, 45 min/month + top-ups)
- **Mobile**: 📱 Flutter app - All core features complete
- **Social Sharing**: ✅ Friends via Code fully deployed
- **Static Website**: ✅ Azure Front Door (`share.mybartenderai.com`)
- **Status**: 🚀 Release Candidate - Ready for Play Store deployment

### Mobile App Features

- ✅ Recipe Vault with 621+ cocktails, search, filters, offline-first
- ✅ My Bar inventory management with "Can Make" filter
- ✅ AI Bartender Chat with inventory integration
- ✅ Smart Scanner for bottle identification (Claude Haiku)
- ✅ Create Studio with enhanced AI Refine feature
- ✅ Favorites/Bookmarks
- ✅ Today's Special with daily notifications
- ✅ User Profile with settings and preferences
- ✅ **Friends via Code** - Social recipe sharing
- ✅ **Voice AI Bartender** - Real-time voice conversations (Pro tier only)
  - WebRTC-based audio streaming via Azure OpenAI Realtime API
  - Live transcription of user and AI speech
  - 45 minutes/month quota for Pro users (+ $4.99 for 10 min top-up)
  - Visual status indicators (listening, thinking, speaking)

### Recent Deployments

**Voice AI Feature (December 2025):**

- ✅ Voice AI backend functions deployed (voice-session, voice-usage, voice-quota)
- ✅ Azure OpenAI Realtime API integration via WebRTC
- ✅ Database schema for voice sessions, messages, and quota tracking
- ✅ Flutter Voice AI screen with real-time transcription
- ✅ Pro tier gating with 45 minutes/month quota
- ✅ Consolidated transcript display with accessibility support

**Database & Sync Fixes (December 12, 2025):**

- ✅ Fixed SQLite snapshot schema to match mobile app expectations
- ✅ Added missing columns: `updated_at`, `ingredient_order`, etc.
- ✅ Created `rebuild-sqlite-snapshot.js` for proper SQLite generation
- ✅ Atomic database sync (temp file → verify → rename)
- ✅ Fixed incorrect "Kids" tag on alcoholic drinks (Autumn Garibaldi, Spritz Veneziano)

**Azure Functions v4 Migration (November 20, 2025):**

- ✅ All 30 functions deployed using v4 programming model
- ✅ Code-centric function registration in single `index.js` file
- ✅ Migrated all AI functions to official Azure OpenAI SDK (@azure/openai)
- ✅ Updated request/response handling to v4 APIs
- ✅ Fixed logging API (context.error() instead of context.log.error())
- ✅ Added missing Azure SDK dependencies
- ✅ All functions operational
- ✅ Comprehensive migration documentation created

**Friends via Code Feature (November 15, 2025):**

- ✅ Database schema (5 tables: user_profile, custom_recipes, recipe_share, share_invite, friendships)
- ✅ Azure Functions (5 endpoints: users-me, social-share-internal, social-invite, social-inbox, social-outbox)
- ✅ APIM Operations (7 operations with JWT authentication, rate limiting, tier-based quotas)
- ✅ Static website hosting for recipe preview pages
- ✅ Azure Front Door Standard CDN
- ✅ Custom domain with SSL: `https://share.mybartenderai.com/` (validated)
- ✅ Application Insights monitoring
- ✅ Complete documentation

## 📁 Project Structure

```
mybartenderAI-MVP/
├── backend/
│   └── functions/            # Azure Functions v4 (30 functions, Node.js 22)
│       ├── index.js          # Root file with all v4 function registrations
│       ├── ask-bartender*/   # AI chat endpoint modules
│       ├── auth-*/           # Authentication & token management
│       ├── users-me/         # User profile management
│       ├── social-*/         # Social sharing endpoints
│       ├── snapshots-*/      # Cocktail database distribution
│       ├── download-images*/ # Image asset management
│       ├── sync-cocktaildb*/ # TheCocktailDB sync (TIMERS DISABLED)
│       ├── test-*/           # Testing & diagnostics
│       ├── shared/           # Shared utilities (monitoring, auth)
│       ├── services/         # Shared service modules
│       ├── config/           # Configuration management
│       └── package.json      # Dependencies including @azure/openai
├── mobile/
│   └── app/                  # Flutter mobile application
├── infrastructure/
│   ├── apim/                 # APIM policies and configuration
│   │   ├── policies/         # JWT validation, rate limiting
│   │   └── scripts/          # Deployment scripts
│   ├── storage/              # Static website configuration
│   └── monitoring/           # Application Insights queries
├── docs/                     # Architecture and documentation
│   ├── FRIENDS-VIA-CODE-*.md # Social feature documentation
│   └── *.md                  # Architecture, deployment guides
├── prompts/                  # AI system prompts
└── spec/                     # API specifications
```

## 🏗️ Architecture

### Azure Infrastructure

- **API Gateway**: Azure API Management (`apim-mba-002`)
  - Gateway: https://apim-mba-002.azure-api.net
  - Tier: Basic V2 (~$150/month)
  - JWT-only authentication (no subscription keys on client)
  - JWT validation via `validate-jwt` policy
  - Tier quotas enforced by backend functions (PostgreSQL lookup)
- **Backend**: Azure Functions (`func-mba-fresh`)
  - Hosting Plan: Premium Consumption (Windows)
  - Runtime: Node.js 22
  - Programming Model: v4 (code-centric registration)
  - Functions: 30 total (29 HTTP triggers + 1 timer trigger)
  - AI SDK: Official @azure/openai package
  - Authentication: Managed Identity for Key Vault & Storage
- **Database**: PostgreSQL Flexible Server (`pg-mybartenderdb`)
- **Storage**: Azure Blob Storage (`mbacocktaildb3`)
  - Cocktail database snapshots
  - Static website hosting ($web container)
- **CDN**: Azure Front Door Standard (`fd-mba-share`) custom domain: `share.mybartenderai.com`
  - Custom domain: https://share.mybartenderai.com
  - Managed SSL certificate
  - Global edge network
- **Security**: Azure Key Vault (`kv-mybartenderai-prod`)
  - Region: East US
  - Resource Group: rg-mba-dev
- **AI**: Azure OpenAI (GPT-4o-mini) + Claude Haiku for Smart Scanner
- **Region**: South Central US (primary)
- **Resource Group**: rg-mba-prod (except Key Vault)

### Authentication Architecture

- **Provider**: Microsoft Entra External ID (CIAM)
- **Tenant**: mybartenderai.onmicrosoft.com
- **Login Endpoint**: https://mybartenderai.ciamlogin.com
- **Supported Methods**: Email/Password, Google, Facebook
- **Token Type**: JWT with sub claim (user ID)
- **Authentication**: JWT-only (no APIM subscription keys on client)
- **Tier Detection**: Backend lookup in PostgreSQL (not JWT claims)
- **Age Verification**: Server-side validation (21+) via Custom Auth Extension

### Azure Functions (30 Total)

**Core & Health (1)**

- `health` - Health check endpoint (GET /api/health)

**AI & Vision Functions (8)**

- `ask-bartender` - AI bartender with telemetry (POST /api/v1/ask-bartender)
- `ask-bartender-simple` - Simplified AI bartender (POST /api/v1/ask-bartender-simple)
- `ask-bartender-test` - AI bartender test endpoint (POST /api/v1/ask-bartender-test)
- `recommend` - AI recommendations with JWT (POST /api/v1/recommend)
- `refine-cocktail` - Create Studio AI refinement (POST /api/v1/create-studio/refine)
- `vision-analyze` - Claude Haiku bottle/ingredient detection (POST /api/v1/vision/analyze)
- `voice-bartender` - Voice-guided cocktail making (POST /api/v1/voice-bartender)
- `speech-token` - Azure Speech token generation (GET /api/speech-token)

**Voice AI Functions (4)**

- `voice-session` - Create voice session and get ephemeral token (POST /api/v1/voice/session)
- `voice-usage` - Record voice session usage and transcripts (POST /api/v1/voice/usage)
- `voice-quota` - Get voice quota status for user (GET /api/v1/voice/quota)
- `voice-realtime-test` - Test Realtime API connectivity (GET/POST /api/v1/voice/test)

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
- `sync-cocktaildb` - Cocktail DB sync (TIMER DISABLED)
- `sync-cocktaildb-mi` - Cocktail sync with managed identity (TIMER DISABLED)

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

**Programming Model**: All functions use Azure Functions v4 with code-centric registration in `index.js`. Complex functions delegate to v3-style modules as needed.

### Key Features

- **Offline First**: Complete cocktail database (SQLite with Zstandard compression) available offline
- **AI Recommendations**: GPT-4o-mini powered suggestions using official @azure/openai SDK (~$0.007/session)
- **Social Sharing**: Share recipes internally (by alias) or externally (via invite links)
- **Privacy-Focused**: System-generated aliases (@adjective-animal-###), minimal PII collection
- **Tiered Access**: Free/Premium/Pro subscription levels with quotas enforced by backend
- **Secure Storage**: Managed Identity for Key Vault and Storage access
- **Global CDN**: Azure Front Door for fast recipe sharing worldwide

## 🔧 Quick Start

### Prerequisites

- Node.js 22 (for Azure Functions)
- Flutter SDK 3.0+ (for mobile app)
- Azure CLI (for deployment)
- Azure subscription with proper permissions

### Backend Setup

```bash
cd backend/functions
npm install

# Deploy to Azure
func azure functionapp publish func-mba-fresh
```

### Mobile Setup

```bash
cd mobile/app
flutter pub get
flutter run

# Build release APK
flutter build apk --release
```

### APIM Configuration

The APIM is configured with JWT validation policies and tier-based quotas. See:

- `infrastructure/apim/policies/social-endpoints-policy.xml` for social endpoints
- `FRIENDS-VIA-CODE-DEPLOYMENT-RUNBOOK.md` for deployment steps

### Test Endpoints

```bash
# Health check (anonymous)
curl https://func-mba-fresh.azurewebsites.net/api/health

# Get latest snapshot (public endpoint, no JWT required)
curl https://apim-mba-002.azure-api.net/api/v1/snapshots/latest

# Get user profile (requires JWT)
curl https://apim-mba-002.azure-api.net/api/v1/users/me \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Share recipe internally (requires JWT)
curl -X POST https://apim-mba-002.azure-api.net/api/v1/social/share-internal \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "recipeId": "12345",
    "recipeName": "Margarita",
    "recipeType": "standard",
    "recipientAlias": "@cool-panda-123",
    "message": "Try this!"
  }'
```

## 📚 Documentation

### Core Documentation

- [Architecture Overview](docs/ARCHITECTURE.md) - Complete system design
- [Deployment Status](docs/DEPLOYMENT_STATUS.md) - Current deployment state
- [API Specification](spec/openapi.yaml) - OpenAPI contract
- [v4 Migration Guide](V4_MIGRATION_COMPLETE.md) - Azure Functions v4 migration details

### Friends via Code (Social Sharing)

- [API Documentation](docs/FRIENDS-VIA-CODE-API.md) - Complete endpoint reference
- [Deployment Guide](FRIENDS-VIA-CODE-DEPLOYMENT-RUNBOOK.md) - Step-by-step deployment
- [Deployment Summary](FRIENDS-VIA-CODE-DEPLOYMENT-COMPLETE.md) - Status and next steps
- [Feature Specification](FEATURE-FriendsViaCode.md) - Complete feature design
- [Implementation Plan](IMPLEMENTATION-PLAN-FriendsViaCode.md) - 16-day plan
- [UI Mockups](FRIENDS-VIA-CODE-UI-MOCKUPS.md) - Flutter UI designs
- [HTML Templates](FRIENDS-VIA-CODE-HTML-TEMPLATES.md) - Web preview pages

### Integration Guides

- [Flutter Integration](docs/FLUTTER_INTEGRATION_PLAN.md) - Mobile app setup
- [Authentication Setup](docs/AUTHENTICATION_SETUP.md) - Entra External ID configuration
- [Authentication Implementation](docs/AUTHENTICATION_IMPLEMENTATION.md) - Mobile app auth integration

### Operations & Monitoring

- [Monitoring Setup](infrastructure/monitoring/MONITORING-SETUP.md) - Application Insights queries and alerts
- [Monitoring Script](infrastructure/monitoring/check-social-metrics.ps1) - Real-time metrics dashboard
- [JWT Policy Guide](infrastructure/apim/JWT_POLICY_DEPLOYMENT_GUIDE.md) - APIM authentication setup

## 🎯 Feature Tiers

### Free Tier

- ✅ Offline cocktail database (~621 drinks)
- ✅ Local search and filtering
- ✅ My Bar inventory management
- ✅ Favorites/Bookmarks
- ✅ Limited AI chat: 10,000 tokens/month
- ✅ Smart Scanner: 2 scans/month

### Premium Tier ($4.99/month or $39.99/year)

- ✅ Everything in Free
- ✅ AI chat: 300,000 tokens/month
- ✅ Smart Scanner: 15 scans/month
- ✅ Create Studio with AI Refine
- ✅ Social sharing features
- ✅ **Voice AI**: Available for purchase ($4.99/10 minutes)

### Pro Tier ($14.99/month or $99.99/year)

- ✅ Everything in Premium
- ✅ AI chat: 1,000,000 tokens/month
- ✅ Smart Scanner: 50 scans/month
- ✅ **Voice AI Bartender**: 45 minutes/month (+ $4.99/10 min top-up)
- ✅ Unlimited custom recipes
- ✅ Priority support

## 🔮 Roadmap

### Phase 1: Core Features ✅ Complete (November 2025)

- ✅ Core backend infrastructure
- ✅ Azure Functions v4 programming model
- ✅ Official Azure OpenAI SDK integration
- ✅ APIM configuration with JWT validation
- ✅ SQLite snapshot generation with Zstandard compression
- ✅ GPT-4o-mini integration
- ✅ Authentication with Entra External ID
- ✅ Server-side age verification (21+)
- ✅ Managed Identity for Key Vault and Storage access
- ✅ Flutter design system
- ✅ Recipe Vault with search, filters, detail views
- ✅ Inventory management (My Bar)
- ✅ AI Bartender Chat
- ✅ Smart Scanner (Claude Haiku)
- ✅ Create Studio with AI Refine

### Phase 2: Release Candidate ✅ Complete (December 2025)

- ✅ Voice AI Bartender (Azure OpenAI Realtime API)
- ✅ Friends via Code (social sharing)
- ✅ User profile with settings
- ✅ Today's Special with notifications
- ✅ Social sharing (Instagram/Facebook)
- ✅ Azure Front Door with custom domain
- ✅ Profile screen polish for release
- 📋 Android Play Store submission

### Phase 3: iOS Launch (Q1 2026)

- 📋 iOS app development
- 📋 MSAL authentication for iOS
- 📋 iOS-specific UI polish
- 📋 TestFlight beta testing
- 📋 App Store submission
- 📋 Cross-platform feature parity

### Phase 4: Advanced Features (Q2 2026)

- 📋 Real-time collaboration on recipes
- 📋 Friend relationships (symmetric friendships)
- 📋 Ingredient substitution AI
- 📋 Cocktail preferences learning
- 📋 Multi-language support
- 📋 Advanced search filters

### Phase 5: Scale & Optimize (Q3 2026)

- 📋 Migrate APIM to Consumption tier
- 📋 Premium PostgreSQL tier
- 📋 Advanced analytics dashboard
- 📋 A/B testing framework
- 📋 Performance optimization

## 💰 Cost Structure

### Beta (Current Monthly Costs)

- APIM Basic V2 tier: ~$150/month
- Azure Functions (Premium Consumption): ~$160/month
- PostgreSQL Flexible Server: ~$30/month
- Storage: ~$2/month
- Azure Front Door Standard: ~$35/month
- Application Insights: ~$3/month
- **Total: ~$380/month**

### Production (Target Monthly Costs)

- APIM Consumption: ~$70/month
- Azure Functions: ~$160/month
- PostgreSQL: ~$30/month
- Storage: ~$2/month
- Azure Front Door: ~$36/month + data transfer
- Application Insights: ~$5/month
- **Total: ~$$$300 - $$$400/month base + usage**

### Per-User Costs (Premium)

- AI (GPT-4o-mini): ~$0.40/month
- Vision (Smart Scanner): ~ unknown as of 12/08/2025
- **Total: ~$.75/user/month**

### Revenue Model

- 1,000 Premium users @ $4.99 = $4,990/month
- 200 Pro users @ $14.99 = $2,998/month
- **Total Revenue**: $7,988/month
- AI costs: ~$540/month
- Infrastructure: ~$650/month
- **Net Profit**: ~$6,798/month (~70% margin)

## 🔐 Security

### Authentication & Authorization

- Microsoft Entra External ID (Azure AD B2C successor)
- JWT tokens validated at APIM layer (`validate-jwt` policy)
- JWT-only authentication (no subscription keys on mobile client)
- Tier-based access control via PostgreSQL lookup
- Quotas enforced by backend functions

### Secrets Management

- All secrets in Azure Key Vault (`kv-mybartenderai-prod`)
- Function App uses Managed Identity for Key Vault access
- No secrets in code or configuration files
- Key Vault references in Function App settings (@Microsoft.KeyVault)

### Privacy & Compliance

- **Minimal PII**: System-generated aliases for social features
- **No email storage**: Only Entra ID stores identity
- **Ephemeral data**: Voice transcripts not stored
- **Bar photos**: Never uploaded or stored
- **User ingredients**: Hashed in logs
- **Data retention**: 90-day retention for opted-in data
- **Age verification**: Server-side validation (21+)

### Network Security

- **HTTPS only**: All endpoints enforce TLS 1.2+
- **CORS**: Configured for web sharing domain only
- **HSTS**: Strict-Transport-Security headers
- **Content Security**: X-Content-Type-Options, X-Frame-Options
- **DDoS Protection**: Azure Front Door built-in protection

## 🧪 Testing

### Backend Testing

**PowerShell Test Scripts (v4 Migration):**

```powershell
# Basic function tests
.\test-v4-functions.ps1

# Authentication function tests
.\test-auth-functions.ps1

# Comprehensive test suite
.\test-v4-comprehensive.ps1

# Route-specific tests
.\test-specific-routes.ps1
```

**Unit & Integration Tests:**

```bash
cd backend/functions
npm test                    # Unit tests
npm run test:integration   # Integration tests
```

### Mobile Testing

```bash
cd mobile/app
flutter test               # Unit + widget tests
flutter drive             # Integration tests

# Test on physical device
flutter run --release
```

### API Testing

**Test social endpoints:**

```bash
# Get user profile (auto-creates on first call)
curl https://apim-mba-002.azure-api.net/api/v1/users/me \
  -H "Authorization: Bearer $JWT_TOKEN"

# Create external invite
curl -X POST https://apim-mba-002.azure-api.net/api/v1/social/invite \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"recipeId":"12345","recipeName":"Margarita","recipeType":"standard"}'
```

**Use APIM Developer Portal:**

1. Navigate to https://apim-mba-002.developer.azure-api.net
2. Sign in with your Azure account
3. Select an API and operation
4. Click "Try it" to test endpoints

### Monitoring & Metrics

```powershell
# Run real-time metrics dashboard
.\infrastructure\monitoring\check-social-metrics.ps1

# Check last 6 hours
.\infrastructure\monitoring\check-social-metrics.ps1 -TimeRangeHours 6
```

## 📊 Monitoring

### Application Insights

- **Resource**: `func-mba-fresh`
- **Instrumentation Key**: Configured in Function App settings
- **Auto-collection**: Functions requests, dependencies, exceptions

### Key Metrics

- Social endpoint request counts
- Error rates by endpoint
- Response time percentiles (P50, P95, P99)
- Rate limit violations (429 responses)
- User tier distribution
- Database query performance

### Dashboards

- Azure Portal: Real-time metrics and logs
- Custom queries: See `infrastructure/monitoring/MONITORING-SETUP.md`
- Alerts: Configured for error rates and slow responses

## 🤝 Contributing

This is a private MVP project. For questions or access, please contact the project owner.

## 📞 Support

- **Technical Issues**: Check [DEPLOYMENT_STATUS.md](docs/DEPLOYMENT_STATUS.md)
- **API Documentation**: See [FRIENDS-VIA-CODE-API.md](docs/FRIENDS-VIA-CODE-API.md)
- **Monitoring**: Run `.\infrastructure\monitoring\check-social-metrics.ps1`
- **Troubleshooting**: See [MONITORING-SETUP.md](infrastructure/monitoring/MONITORING-SETUP.md)

## 📄 License

Proprietary - All rights reserved

---

**Built with:**

- Flutter (Mobile)
- Azure Functions (Backend)
- Azure API Management (Gateway)
- Azure OpenAI GPT-4o-mini (AI Chat)
- Azure OpenAI Realtime API (Voice AI)
- Claude Haiku (Smart Scanner)
- Azure Front Door (CDN)
- PostgreSQL (Database)
- Azure Blob Storage (Assets & Static Website)
- Microsoft Entra External ID (Authentication)

---

**Last Updated**: December 2025
**Version**: 1.0.0-rc
**Status**: Release Candidate - Ready for Play Store deployment
