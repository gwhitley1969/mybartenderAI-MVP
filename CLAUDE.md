# CLAUDE.md - MyBartenderAI Project Context

## Project Instructions

## Use Context7 by Default

Always use context7 when I need code generation, setup or configuration steps, or library/API documentation.  This means you should automatically use the Contex7 MCP tools to resolve library id and get library docs without me having to explicitly ask.

##Use Microsoft Documentation when needed

You have both the Microsoft Documentation and Azure MCP Servers installed.  Use them, when needed

## ## Project Overview

**My AI Bartender** is a mobile-first AI bartender application that helps users create cocktails based on their available ingredients. The app uses device camera to inventory home bars and provides real-time voice-guided cocktail-making instructions.

### Target Platforms

- **Phase 1**: Android (initial launch)
- **Phase 2**: iOS (post-Android launch)

## Current Status: Release Candidate

All core features implemented and tested. Ready for Play Store deployment.

### Business Model

- **Free Tier**: Limited AI interactions (10,000 tokens / 30 days) (2 scans / 30 days), unlimited access to local cocktail database
- **Premium Tier** ($4.99/month or $39.99/year): Full AI Chat, Scanner (300,000 tokens / 30 days) (15 scans / 30 days) + Voice AI available as $4.99/20 min purchase
- **Pro** ($7.99/month or $79.99/year): Enhanced AI features (1,000,000 tokens / 30 days) (50 scans / 30 days) (60 voice minutes / 30 days included + $4.99/20 min top-up)
  
  

## Tech Stack

### Frontend

- **Framework**: Flutter (cross-platform)
- **State Management**: Riverpod
- **Routing**: GoRouter
- **Architecture**: Feature-first clean architecture
- **IDE**: VS Code

### Backend (Azure)

- **Compute**: Azure Functions (`func-mba-fresh`) (Premium Consumption plan used to be called Elastic Premium) 

- **Database**: Azure Database for PostgreSQL Flexible Server (`pg-mybartenderdb`)

- **Storage**: Azure Blob Storage (`mbacocktaildb3`)

- **API Gateway**: Azure API Management (`apim-mba-002`) - Basic V2 tier

- **AI Services**:

  - Azure OpenAI Service (GPT-4.1-mini for chat recommendations, GPT-realtime-mini for Voice AI) (Claude Haiku for Smart Scanner)

- **Security**: Managed Identity + Azure Key Vault (`kv-mybartenderai-prod`)

- **Authentication**: PII-minimal approach with JWT

- **Load Balancer**: Azure Front Door (`fd-mba-share`) external custom domain `share.mybartenderai.com`. 

### Key Azure Resources

- **Resource Groups**: `rg-mba-prod` (South Central US) and `rg-mba-dev` (East US) (location of  `kv-mybartenderai-prod`) 

- **Function App**: `func-mba-fresh` (URL: https://func-mba-fresh.azurewebsites.net)

- **API Management**: `apim-mba-002` (Basic V2 tier)

- - Gateway: https://apim-mba-002.azure-api.net
  - Developer Portal: https://apim-mba-002.developer.azure-api.net

- **Storage Account**: `mbacocktaildb3`

- **Database**: `pg-mybartenderdb` (PostgreSQL - authoritative data source)

- **Key Vault**: `kv-mybartenderai-prod` (in `rg-mba-dev` resource group)

- **Azure OpenAI**:
  - `mybartenderai-scus` (South Central US) - Chat: `gpt-4.1-mini` deployment
  - `blueb-midjmnz5-eastus2` (East US 2) - Voice AI: `gpt-realtime-mini` deployment

- **Azure Front Door**: `fd-mba-share` (Global) custom domain: `share.mybartenderai.com`
  
  
  
  

### Azure Key Vault Secrets

Located in `kv-mybartenderai-prod`:

1. **COCKTAILDB-API-KEY**: API key for thecocktaildb.com

2. **AZURE-OPENAI-API-KEY**: API key for Azure OpenAI service (mybartenderai-scus)

3. **AZURE-OPENAI-ENDPOINT**: Azure OpenAI endpoint URL (https://mybartenderai-scus.openai.azure.com)

4. **OpenAI**: Legacy API key (deprecated, use AZURE-OPENAI-API-KEY)

5. **POSTGRES-CONNECTION-STRING**: Connection string for `pg-mybartenderdb`

6. **APIM-SUBSCRIPTION-KEY**:

7. **AZURE-CV-ENDPOINT**:

8. **AZURE-CV-KEY**:

9. **AZURE-FUNCTION-KEY**:

10. **AZURE-SPEECH-API-KEY**: Old, isn't used

11. **AZURE-SPEECH-ENDPOINT**: Old, isn't used

12. **AZURE-SPEECH-KEY**: Old, isn't used

13. **AZURE-SPEECH-REGION**: Old, isn't used

14. **CLAUDE-API-KEY**

15. **CLAUDE-ENDPOINT**

16. **META-FACEBOOK-APP-ID**

17. **META-FACEBOOK-APP-SECRET**

18. **SOCIAL-ENCRYPTION-KEY**

19. **AZURE-OPENAI-DEPLOYMENT**: Chat model deployment name (`gpt-4.1-mini`)

20. **AZURE-OPENAI-REALTIME-DEPLOYMENT**: Voice AI model deployment name (`gpt-realtime-mini`)

21. **AZURE-OPENAI-REALTIME-ENDPOINT**: East US 2 endpoint for Voice AI

22. **AZURE-OPENAI-REALTIME-KEY**: API key for Voice AI (East US 2 resource)

## Architecture Highlights

### 

**Why This Approach:**

**AI Model Strategy:**

- **GPT-4.1-mini** (South Central US): Primary model for cocktail chat recommendations
  - Cost-effective replacement for GPT-4o-mini (retired March 2026)
  - Perfect for structured cocktail knowledge and conversational guidance

- **GPT-realtime-mini** (East US 2): Voice AI for real-time audio conversations
  - GA replacement for gpt-4o-mini-realtime-preview (retired Feb 2026)
  - Low-latency audio streaming for voice-guided cocktail making

- **Claude Haiku 4.5**: Smart Scanner for bottle/ingredient recognition
    
    

### Data Flow

1. **TheCocktailDB API**: Timer sync DISABLED - using static database copy
2. **PostgreSQL**: Authoritative source of truth
3. **JSON Snapshots**: Compressed (Zstandard) snapshots for mobile consumption (~172KB)
4. **Blob Storage**: Static assets and snapshot distribution

### Security & Authentication

- **Authentication**: JWT-only via Entra External ID
  - Mobile app authenticates with Entra External ID
  - APIM validates JWT via `validate-jwt` policy
  - Backend functions receive validated user ID in headers
  - No APIM subscription keys sent from mobile client

- **Storage Access**: Managed Identity
  - Function App (`func-mba-fresh`) uses System-Assigned Managed Identity

- **Key Vault Access**: Managed Identity with RBAC
  - Granted "Key Vault Secrets User" role on `kv-mybartenderai-prod`
  - Key Vault uses RBAC authorization (not access policies)
  - Secrets accessed via `@Microsoft.KeyVault()` references

- **PII Policy**: Minimal collection, clearly defined retention

### Azure Resource Organization

- **Primary Region**: South Central US
- **Production Resources**: `rg-mba-prod` resource group
- **Key Vault Location**: `rg-mba-dev` resource group (cross-RG access pattern)
- **Function Access Pattern (Past)**: Connection String → Key Vault → SAS Tokens/Secrets
- **Function Access Pattern (Current)**: Managed Identity → Key Vault → Secrets

### API Management (APIM) Strategy

- **Current Tier**: Basic V2 - ~$150/month
- **Authentication**: JWT-only (no subscription keys sent from mobile client)
- **Purpose**:
  - JWT validation via `validate-jwt` policy
  - API versioning for mobile app updates
  - Security: Hides Function URLs, DDoS protection
  - Built-in analytics and monitoring
- **Tier Validation**: Backend functions check user tier in PostgreSQL (not APIM products)
- **Quotas** (enforced by backend):
  - **Free**: 10,000 tokens / 30 days, 2 scans / 30 days
  - **Premium**: 300,000 tokens / 30 days, 15 scans / 30 days (+ $4.99/20 min voice purchase)
  - **Pro**: 1,000,000 tokens / 30 days, 50 scans / 30 days, 60 voice minutes / 30 days (+ $4.99/20 min top-up)

### ## Development Environment

### Required Tools

- **IDE**: VS Code or Cursor (primarily VS Code)
- **Languages**: Dart/Flutter, PowerShell, Azure Bicep
- **Node.js**: Required for Azure Functions and tooling
- **Azure CLI**: For infrastructure deployment
- **Flutter SDK**: For mobile development

### Key Scripts & Templates

- **Azure Bicep**: Infrastructure as Code templates
- **PowerShell**: Deployment and automation scripts

## Code Conventions

### Flutter/Dart

- Feature-first folder structure
- Riverpod providers for state management
- GoRouter for declarative routing
- Clean architecture principles (domain, data, presentation layers)

### Azure Functions

- **Language**: JavaScript/Node.js (removed native dependencies like better-sqlite3)
- **Authentication**: Connection strings with Key Vault for MVP phase
- **Storage Access**: Managed Identities
- **Current**: Migrate to DefaultAzureCredential/Managed Identity when upgrading hosting plan

**Deployed Functions:**

- `ask-bartender`, `ask-bartender-simple`, `ask-bartender-test`: GPT-4.1-mini cocktail recommendations
- `recommend`: AI-powered cocktail suggestions
- `snapshots-latest`, `snapshots-latest-mi`: JSON snapshot distribution
- `download-images`, `download-images-mi`: Image asset management
- `sync-cocktaildb`, `sync-cocktaildb-mi`: Database sync (TIMERS DISABLED)
- `health`: Health check endpoint
- `refine-cocktail`: AI recipe refinement for Create Studio
- `rotate-keys-timer`: Automated key rotation
- `social-inbox`, `social-invite`, `social-outbox`, `social-share-internal`: Social features
- `speech-token`: Speech service token exchange
- `users-me`: User profile endpoint
- `validate-age`: Age verification for Entra External ID
- `vision-analyze`: Smart Scanner using Claude Haiku
- `voice-bartender`: Legacy voice (Azure Speech Services)
- `voice-session`: Voice AI using GPT-realtime-mini via Azure OpenAI Realtime API (Pro tier)
- `auth-exchange`, `auth-rotate`: Token management
- `cocktail-preview`: Public cocktail preview for sharing
- `test-keyvault`, `test-mi-access`, `test-write`: Diagnostic endpoints
  
  

### Infrastructure

- **Bicep Templates**: Declarative Azure resource definitions
- **Naming Convention**: Lowercase with hyphens (`func-mba-fresh`, `mbacocktaildb3`)

## Current Status & Known Issues

### Completed (January 2026)

**Infrastructure:**
- ✅ Azure infrastructure (South Central US + East US 2 for Voice AI)
- ✅ PostgreSQL as authoritative source
- ✅ Key Vault integration with Managed Identity + RBAC
- ✅ Azure OpenAI service (mybartenderai-scus for chat, blueb-midjmnz5-eastus2 for voice)
- ✅ APIM Basic V2 with JWT validation
- ✅ Azure Front Door (share.mybartenderai.com)
- ✅ Model migration: GPT-4o-mini → GPT-4.1-mini, gpt-4o-mini-realtime-preview → gpt-realtime-mini

**Authentication:**
- ✅ Entra External ID (Email, Google, Facebook)
- ✅ Age verification (21+) with Custom Authentication Extension
- ✅ JWT-only authentication flow
- ✅ Token refresh and secure storage

**Mobile App Features:**
- ✅ AI Bartender Chat (GPT-4.1-mini)
- ✅ Recipe Vault with offline SQLite database
- ✅ My Bar inventory management
- ✅ Smart Scanner (Claude Haiku)
- ✅ Voice AI (GPT-realtime-mini via Azure OpenAI Realtime API, Pro tier)
- ✅ Create Studio with AI refinement
- ✅ Today's Special with notifications
- ✅ Social sharing (Instagram/Facebook)
- ✅ Friends via Code sharing
- ✅ User profile with settings

**Backend:**
- ✅ All API endpoints deployed and operational
- ✅ Tier-based quota enforcement in PostgreSQL

### In Progress

- 🔄 Taste Profile feature (UI design)

### Upcoming

- 📋 Android Play Store deployment
- 📋 iOS configuration and TestFlight

## Developer Background

**Author**: Experienced infrastructure architect with 30+ years in the field

- **Certifications**: AZ-305, AZ-104, AZ-700, AZ-900, IBM Certified Architect L2, TOGAF Certified Master Architect
- **Expertise**: Windows, Microsoft Networking, Active Directory, Azure infrastructure
- **New Skills**: Transitioning to "Vibe Coding" with AI-assisted development, learning Context Engineering
- **Authorship**: 5 technical books (IIS, Windows, Security, Active Directory)

## Important Notes for AI Assistants

### When Helping with Code

1. **Azure Best Practices**: Azure MCP Server and Microsoft Documentation MCP server connected
2. **Key Vault Access**: All secrets retrieved via connection strings from `kv-mybartenderai-prod`
3. **Cost Consciousness**: Always consider Azure consumption costs 
4. **Security First**: PII-minimal, RBAC prepared for future, Key Vault integration
5. **Pragmatic Approach**: Production uses Managed Identity
6. **Cross-Platform**: Remember Flutter targets both Android and iOS
7. **Windows Expertise**: Developer has strong Windows/Azure background

### Preferred Patterns

- Bicep over ARM templates
- PowerShell for Azure automation
- Feature-first architecture in Flutter
- Managed Identity over secrets/keys
- Clean architecture principles

### Areas of Growth

- Mobile development (Flutter/Dart) - provide guidance
- AI integration patterns - explain clearly
- Modern JavaScript patterns - be explicit

## Related Documentation

Refer to these files in the repository:

- `README.md`: Project overview and setup instructions (may be outdated - verify before relying on)
- `ARCHITECTURE.md`: Detailed architecture documentation
- `DEPLOYMENT_STATUS.md`: Current deployment state and progress
- `FLUTTER_INTEGRATION_PLAN.md`: Mobile app integration strategy
- `MANAGED_IDENTITY_MIGRATION.md`: Documentation of MI migration attempts and future plans (currently using SAS for MVP)
- `PLAN.md`: Project roadmap and planning documentation
- `/docs/`: Additional technical documentation (if exists)
- `/infrastructure/`: Bicep templates and deployment scripts (if exists)

## Quick Commands Reference

### Azure Key Vault

```bash
# Retrieve a secret
az keyvault secret show --vault-name kv-mybartenderai-prod --name COCKTAILDB-API-KEY

# List all secrets
az keyvault secret list --vault-name kv-mybartenderai-prod

# Grant Function App access to Key Vault
az role assignment create \
  --assignee <function-managed-identity-id> \
  --role "Key Vault Secrets User" \
  --scope /subscriptions/<sub-id>/resourceGroups/rg-mba-dev/providers/Microsoft.KeyVault/vaults/kv-mybartenderai-prod
```

### Azure

```bash
# Deploy infrastructure
az deployment group create --resource-group rg-mba-prod --template-file main.bicep

# Assign Managed Identity permissions
az role assignment create --assignee <identity-id> --role "Storage Blob Data Contributor" --scope <storage-account-id>

# View Function logs
az functionapp logs tail --name func-mba-fresh --resource-group rg-mba-prod
```

### Flutter

```bash
# Run on Android
flutter run

# Build release APK
flutter build apk --release

# Run tests
flutter test
```

---

**Last Updated**: January 2026
**Project Phase**: Release Candidate
**Primary Focus**: Play Store deployment preparation
**Recent Changes**: Azure OpenAI model migration (GPT-4.1-mini, gpt-realtime-mini)


