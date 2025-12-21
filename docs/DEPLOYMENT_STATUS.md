# MyBartenderAI Deployment Status

## Current Status: Release Candidate

**Last Updated**: December 2025

The MyBartenderAI mobile app and Azure backend are fully operational and in release candidate status. All core features are implemented and tested.

---

## Platform Status

| Platform | Status | Notes |
|----------|--------|-------|
| Android | Ready | Release APK builds successfully |
| iOS | Pending | URL scheme configuration needed in Info.plist |

---

## Azure Infrastructure

### Resource Overview

| Resource | Name | SKU/Tier | Region |
|----------|------|----------|--------|
| Function App | `func-mba-fresh` | Premium Consumption | South Central US |
| API Management | `apim-mba-002` | Basic V2 (~$150/mo) | South Central US |
| PostgreSQL | `pg-mybartenderdb` | Flexible Server | South Central US |
| Storage Account | `mbacocktaildb3` | Standard | South Central US |
| Key Vault | `kv-mybartenderai-prod` | Standard | East US |
| Azure OpenAI | `mybartenderai-scus` | S0 | South Central US |
| Front Door | `fd-mba-share` | Standard | Global |

### Key Vault Secrets

All sensitive configuration stored in `kv-mybartenderai-prod`:
- `AZURE-OPENAI-API-KEY` - Azure OpenAI service key
- `AZURE-OPENAI-ENDPOINT` - Azure OpenAI endpoint URL
- `CLAUDE-API-KEY` - Anthropic Claude API key (Smart Scanner)
- `POSTGRES-CONNECTION-STRING` - Database connection
- `COCKTAILDB-API-KEY` - TheCocktailDB API key
- `SOCIAL-ENCRYPTION-KEY` - Social sharing encryption
- Plus additional service keys

---

## Authentication System

### Status: Fully Operational

**Architecture**: JWT-only authentication (no APIM subscription keys on client)

| Component | Status | Details |
|-----------|--------|---------|
| Entra External ID | Configured | Tenant: `mybartenderai` |
| Email + Password | Working | Native Entra authentication |
| Google Sign-In | Working | OAuth 2.0 federation |
| Facebook Sign-In | Working | OAuth 2.0 federation |
| Age Verification (21+) | Working | Custom Authentication Extension |
| JWT Validation | Working | APIM `validate-jwt` policy |

### Authentication Flow

1. Mobile app authenticates with Entra External ID
2. JWT token included in API requests (`Authorization: Bearer <token>`)
3. APIM validates JWT (signature, expiration, audience)
4. Backend functions receive validated user ID via `X-User-Id` header
5. Functions check user tier in PostgreSQL database

**API Gateway**: `https://apim-mba-002.azure-api.net`

---

## Subscription Tiers

| Tier | Monthly | Annual | AI Tokens | Scans | Voice |
|------|---------|--------|-----------|-------|-------|
| Free | $0 | - | 10,000 | 2 | - |
| Premium | $4.99 | $39.99 | 300,000 | 15 | - |
| Pro | $14.99 | $99.99 | 1,000,000 | 50 | 90 min |

Tier validation occurs in backend functions via PostgreSQL user lookup (not APIM products).

---

## Deployed Azure Functions

All functions deployed to `func-mba-fresh`:

### Core API Endpoints

| Function | Method | Path | Auth | Status |
|----------|--------|------|------|--------|
| `ask-bartender-simple` | POST | `/api/v1/ask-bartender-simple` | JWT | Working |
| `recommend` | POST | `/api/v1/recommend` | JWT | Working |
| `snapshots-latest` | GET | `/api/v1/snapshots/latest` | JWT | Working |
| `vision-analyze` | POST | `/api/v1/vision/analyze` | JWT | Working |
| `voice-session` | POST | `/api/v1/voice/session` | JWT (Pro) | Working |
| `refine-cocktail` | POST | `/api/v1/create-studio/refine` | JWT | Working |
| `cocktail-preview` | GET | `/api/v1/cocktails/preview/{id}` | Public | Working |
| `users-me` | GET | `/api/v1/users/me` | JWT | Working |

### Authentication Endpoints

| Function | Method | Path | Auth | Status |
|----------|--------|------|------|--------|
| `validate-age` | POST | `/api/validate-age` | OAuth 2.0 | Working |
| `auth-exchange` | POST | `/api/v1/auth/exchange` | JWT | Working |
| `auth-rotate` | POST | `/api/v1/auth/rotate` | JWT | Working |

### Social Features

| Function | Method | Path | Auth | Status |
|----------|--------|------|------|--------|
| `social-share-internal` | POST | `/api/v1/social/share` | JWT | Working |
| `social-invite` | POST | `/api/v1/social/invite` | JWT | Working |
| `social-inbox` | GET | `/api/v1/social/inbox` | JWT | Working |
| `social-outbox` | GET | `/api/v1/social/outbox` | JWT | Working |

### Admin/Utility Functions

| Function | Status | Notes |
|----------|--------|-------|
| `sync-cocktaildb` | Timer DISABLED | Using static database copy |
| `download-images` | Available | Manual trigger only |
| `health` | Available | Health check endpoint |
| `rotate-keys-timer` | Timer | Key rotation automation |

---

## AI Services

### GPT-4o-mini (Azure OpenAI)

**Service**: `mybartenderai-scus` (South Central US)

| Feature | Function | Model |
|---------|----------|-------|
| AI Bartender Chat | `ask-bartender-simple` | gpt-4o-mini |
| Cocktail Recommendations | `recommend` | gpt-4o-mini |
| Recipe Refinement | `refine-cocktail` | gpt-4o-mini |

**Cost**: ~$0.15/1M input tokens, ~$0.60/1M output tokens

### Claude Haiku (Anthropic)

**Used for**: Smart Scanner (vision-analyze)

| Feature | Function | Model |
|---------|----------|-------|
| Bottle/Ingredient Recognition | `vision-analyze` | Claude 3 Haiku |

Analyzes bar photos to identify spirits, liqueurs, and mixers with high accuracy.

### Azure OpenAI Realtime API

**Used for**: Voice AI (Pro tier only)

| Feature | Function | Technology |
|---------|----------|------------|
| Voice Bartender | `voice-session` | Azure OpenAI Realtime API |

**Architecture**:
1. Mobile app requests WebRTC session token from `voice-session`
2. Function returns ephemeral token for Azure OpenAI Realtime API
3. Mobile app connects directly to Azure OpenAI via WebRTC
4. Real-time voice conversation with AI bartender

**Cost**: ~$0.06/min input, ~$0.24/min output

---

## Mobile App Features

### Implemented Features

| Feature | Screen | Status |
|---------|--------|--------|
| Home Dashboard | `home_screen.dart` | Complete |
| AI Bartender Chat | `chat_screen.dart` | Complete |
| Recipe Vault | `recipe_vault_screen.dart` | Complete |
| Cocktail Details | `cocktail_detail_screen.dart` | Complete |
| My Bar (Inventory) | `my_bar_screen.dart` | Complete |
| Smart Scanner | `smart_scanner_screen.dart` | Complete |
| Voice Bartender | `voice_bartender_screen.dart` | Complete (Pro) |
| Create Studio | `create_studio_screen.dart` | Complete |
| User Profile | `profile_screen.dart` | Complete |
| Login | `login_screen.dart` | Complete |
| Today's Special | Home card | Complete |
| Social Sharing | Share dialogs | Complete |

### Key Integrations

- **Offline-First Database**: SQLite with Zstandard-compressed snapshots (~172KB)
- **State Management**: Riverpod providers
- **Routing**: GoRouter with authentication guards
- **HTTP Client**: Dio with JWT interceptors
- **Secure Storage**: flutter_secure_storage for tokens
- **Notifications**: Local notifications for Today's Special (5 PM daily)

### Profile Screen (Release Candidate)

Cleaned up for release:
- Account information (name only, email removed)
- Notification settings (Today's Special Reminder)
- Measurement preferences (oz/ml)
- Sign out with confirmation
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

---

## External Integrations

| Service | Purpose | Status |
|---------|---------|--------|
| Azure Front Door | Custom domain `share.mybartenderai.com` | Active |
| TheCocktailDB | Cocktail database source | Sync disabled |
| Google OAuth | Social sign-in | Configured |
| Facebook OAuth | Social sign-in | Configured |
| Instagram | Social sharing | Configured |

---

## Build & Deployment

### Mobile App

```bash
# Development
cd mobile/app
flutter run

# Release APK
flutter build apk --release

# Output: mobile/app/build/app/outputs/flutter-apk/app-release.apk
```

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

1. **iOS not configured**: Need URL scheme in Info.plist for OAuth redirect
2. **No biometric auth**: Could add fingerprint/Face ID for better UX
3. **No offline auth**: Requires network for initial sign-in
4. **Single session**: No multi-device session management

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

| Document | Purpose |
|----------|---------|
| `ARCHITECTURE.md` | System architecture and design |
| `AUTHENTICATION_SETUP.md` | Entra External ID configuration |
| `AUTHENTICATION_IMPLEMENTATION.md` | Mobile app auth integration |
| `AGE_VERIFICATION_IMPLEMENTATION.md` | 21+ verification details |
| `VOICE_AI_IMPLEMENTATION.md` | Voice feature specification |
| `CLAUDE.md` | Project context and conventions |

---

**Status**: Release Candidate
**Last Updated**: December 2025
