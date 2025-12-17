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

## Current Task: Voice AI Feature

See `docs/VOICE_AI_IMPLEMENTATION.md` for full spec.

### Business Model

- **Free Tier**: Limited AI interactions (10,000 tokens / 30 days) (2 scans / 30 days), unlimited access to local cocktail database
- **Premium Tier** ($4.99/month or $49.99/year): Full AI Chat, Scanner (camera inventory), advanced cocktail recommendations (300,000 tokens / 30 days) (30 scans / 30 days)
- **Pro** ($14.99/month or $149.99/year): Enhanced AI features (1,000,000 tokens / 30 days) (100 scans / 30 days) (120 voice minutes / 30 days)
  
  

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
  
  - Azure OpenAI Service (GPT-4o-mini for text-based recommendations)

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

- **Azure OpenAI**: `mybartenderai-scus` (South Central US, gpt-4o-mini deployment)

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





## Architecture Highlights

### 

**Why This Approach:**

**AI Model Strategy:**

- **GPT-4o-mini**: Primary model for cocktail recommendations and instructions
  - Cost: $0.15/1M input tokens, $0.60/1M output tokens
  - Perfect for structured cocktail knowledge and conversational guidance
  - Fast response times critical for voice interaction
    
    

### Data Flow

1. **TheCocktailDB API**: Nightly sync at 03:30 UTC with throttling (doesn't seem to be happening anymore, no syncs since 11/15/2025)
2. **PostgreSQL**: Authoritative source of truth
3. **JSON Snapshots**: Compressed (gzip) snapshots for mobile consumption
4. **Blob Storage**: Static assets and snapshot distribution

### Security & Authentication

- **Current (Early Beta)**: Mixed approach based on service capabilities
  
  - **Storage Access**: Using Managed Identity
    - Managed Identity for storage (`func-cocktaildb2-uami`and `func-mba-fresh`)

- **Key Vault Access**: ✅ Managed Identity with RBAC
  
  - Function App uses System-Assigned Managed Identity
  - Granted "Key Vault Secrets User" role on `kv-mybartenderai-prod`
  - Key Vault uses RBAC authorization (not access policies)
  - Secrets accessed via `@Microsoft.KeyVault()` references in Function App settings
  - **Future State**: Migrate storage to Managed Identity when moving to Premium or Linux plans
  - **PII Policy**: Minimal collection, clearly defined retention
  - **Key Vault**: `kv-mybartenderai-prod` stores sensitive configuration

- API keys (TheCocktailDB, Azure OpenAI)

- Database connection strings

- Azure OpenAI endpoint and deployment configuration

- SAS tokens (temporary, for blob storage access)

### Azure Resource Organization

- **Primary Region**: South Central US
- **Production Resources**: `rg-mba-prod` resource group
- **Key Vault Location**: `rg-mba-dev` resource group (cross-RG access pattern)
- **Function Access Pattern (Past)**: Connection String → Key Vault → SAS Tokens/Secrets
- **Function Access Pattern (Current)**: Managed Identity → Key Vault → Secrets

### API Management (APIM) Strategy

- **Current Tier**: Basic V2 - ~$150/month 
- **Purpose**: 
- - Tier-based rate limiting (Free/Premium/Pro products)
  - API key management per mobile app installation
  - API versioning for mobile app updates
  - Security: Hides Function URLs, DDoS protection
  - Built-in analytics and monitoring
- **Products Configuration**:
  - **Free**: Local features only (10,000 tokens / 30 days) (2 scans / 30 days)
  - **Premium**: AI features with moderate limits (300,000 tokens / 30 days) (30 scans / 30 days)
  - **Pro**: AI features with higher limits (1,000,000 tokens / 30 days) (100 scans / 30 days) (120 voice minutes / 30 days)

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

- `ask-bartender`, `ask-bartender-simple`, `ask-bartender-test`: GPT-4o-mini cocktail recommendations
- `recommend`: AI-powered cocktail suggestions
- `snapshots-latest`, `snapshots-latest-mi`: JSON snapshot distribution
- `download-images`, `download-images-mi`: Image asset management
- `sync-cocktaildb`: Timer-triggered nightly sync (03:30 UTC)
- `health`: Health check endpoint
- `refine-cocktail`:
- `rotate-keys-timer`:
- `snapshots-latest`:
- `snapshots-latest-mi`:
- `social-inbox`:
- `social-invite`:
- `social-outbox`:
- `social-share-internal`:
- `speech-token`:
- `sync-cocktaildb`:
- `sync-cocktaildb-mi`:
- `test-keyvault`:
- `test-mi-access`:
- `test-write`:
- `users-me`:
- `validate-age`:
- `vision-analyze`:
- `voice-bartender`:
- `auth-exchange:`
- `auth-rotate:`
- `cocktail-preview:`
  
  

### Infrastructure

- **Bicep Templates**: Declarative Azure resource definitions
- **Naming Convention**: Lowercase with hyphens (`func-mba-fresh`, `mbacocktaildb3`)

## Current Status & Known Issues

### Completed (2025-10-31)

- ✅ Core architecture design
- ✅ Azure infrastructure setup (all resources in South Central US)
- ✅ SAS token implementation for blob storage (**PAST**)
- ✅ Cost optimization strategy
- ✅ PostgreSQL as authoritative source
- ✅ Key Vault integration with Managed Identity + RBAC
- ✅ Azure OpenAI service deployment (mybartenderai-scus)
- ✅ AI Bartender chat backend (ask-bartender-simple endpoint)
- ✅ AI Bartender chat UI with conversation tracking
- ✅ Mobile app Recipe Vault with snapshot sync
- ✅ Mobile app Inventory Management (My Bar)
- ✅ Mobile app Favorites/Bookmarks
- ✅ TheCocktailDB API integration (nightly sync)
- ✅ Offline-first SQLite database with Zstandard compression

### In Progress

- 🔄 Entra External ID authentication (Google/Facebook/Email)
- 🔄 Mobile app Taste Profile feature

### Upcoming

- 📋 Camera-based inventory feature (Smart Scanner) **(Finished, used Azure's Anthropic Haiku offering)**
- 📋 Advanced AI cocktail recommendations (recommend endpoint with JWT)**** (Seems to be working as of 12/08/2025)****
- 📋 Free/Premium/Pro tier implementation via APIM
- 📋 Create Studio cocktail creation feature
- 📋 Android Play Store deployment

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

### Current Authentication Limitations

**

- **Migration Path**: Document in MANAGED_IDENTITY_MIGRATION.md for future reference
  
  

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

**Last Updated**: December 2025  
**Project Phase**: Early Development / Beta  
**Primary Focus**: Infrastructure stability and mobile app foundation
