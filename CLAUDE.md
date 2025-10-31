# CLAUDE.md - MyBartenderAI Project Context

## Project Instructions

## Use Context7 by Default

Always use context7 when I need code generation, setup or configuration steps, or library/API documentation.  This means you should automatically use the Contex7 MCP tools to resolve library id and get library docs without me having to explicitly ask.

## Project Overview

**MyBartenderAI** is a mobile-first AI bartender application that helps users create cocktails based on their available ingredients. The app uses device camera to inventory home bars and provides real-time voice-guided cocktail-making instructions.

### Target Platforms

- **Phase 1**: Android (initial launch)
- **Phase 2**: iOS (post-Android launch)

### Business Model

- **Free Tier**: Limited AI interactions, access to local cocktail database
- **Premium Tier**: Full AI features, advanced cocktail recommendations
- **Pro Tier**: Extended AI capabilities, premium content

## Tech Stack

### Frontend

- **Framework**: Flutter (cross-platform)
- **State Management**: Riverpod
- **Routing**: GoRouter
- **Architecture**: Feature-first clean architecture
- **IDE**: VS Code

### Backend (Azure)

- **Compute**: Azure Functions (Windows Consumption plan)
- **Database**: Azure Database for PostgreSQL Flexible Server (`pg-mybartenderdb`)
- **Storage**: Azure Blob Storage (`mbacocktaildb3`)
- **API Gateway**: Azure API Management (`apim-mba-001`) - Developer tier
- **AI Services**: 
  - Azure OpenAI Service (GPT-4o-mini for text-based recommendations)
  - Azure Speech Services (Speech-to-Text + Neural Text-to-Speech for voice)
- **Security**: Managed Identity + Azure Key Vault (`kv-mybartenderai-prod`)
- **Authentication**: PII-minimal approach with JWT

### Key Azure Resources

- **Resource Group**: `rg-mba-prod` (South Central US)
- **Function App**: `func-mba-fresh` (URL: https://func-mba-fresh.azurewebsites.net)
- **API Management**: `apim-mba-001` (Developer tier)
  - Gateway: https://apim-mba-001.azure-api.net
  - Developer Portal: https://apim-mba-001.developer.azure-api.net
- **Storage Account**: `mbacocktaildb3`
- **Database**: `pg-mybartenderdb` (PostgreSQL - authoritative data source)
- **Key Vault**: `kv-mybartenderai-prod` (in `rg-mba-dev` resource group)
- **Azure OpenAI**: `mybartenderai-scus` (South Central US, gpt-4o-mini deployment)
- **Speech Services**: TBD (for voice features)

### Azure Key Vault Secrets

Located in `kv-mybartenderai-prod`:

1. **COCKTAILDB-API-KEY**: API key for thecocktaildb.com
2. **AZURE-OPENAI-API-KEY**: API key for Azure OpenAI service (mybartenderai-scus)
3. **AZURE-OPENAI-ENDPOINT**: Azure OpenAI endpoint URL (https://mybartenderai-scus.openai.azure.com)
4. **OpenAI**: Legacy API key (deprecated, use AZURE-OPENAI-API-KEY)
5. **POSTGRES-CONNECTION-STRING**: Connection string for `pg-mybartenderdb`
6. **Storage SAS tokens**: For MVP blob access (temporary)

## Architecture Highlights

### Voice Interaction Architecture (Premium/Pro Feature)

**Cost-Optimized Alternative to OpenAI Realtime API:**

```
User speaks → Azure Speech-to-Text → 
Flutter App → APIM → Azure Function → GPT-4o-mini (text) → 
Azure Function → Flutter App → Azure Text-to-Speech → User hears
```

**Why This Approach:**

- **93% cost savings** vs OpenAI Realtime API (~$0.10 vs ~$1.50 per 5-min session)
- Azure Speech-to-Text: ~$0.017/minute
- GPT-4o-mini text API: ~$0.007 per conversation
- Azure Neural Text-to-Speech: ~$0.00005 per response
- Client-side speech processing for lower latency
- Custom vocabulary for bartending terms

**AI Model Strategy:**

- **GPT-4o-mini**: Primary model for cocktail recommendations and instructions
  - Cost: $0.15/1M input tokens, $0.60/1M output tokens
  - Perfect for structured cocktail knowledge and conversational guidance
  - Fast response times critical for voice interaction
- **Azure Speech Services**: Custom models with bartending terminology

### Data Flow

1. **TheCocktailDB API**: Nightly sync at 03:30 UTC with throttling
2. **PostgreSQL**: Authoritative source of truth
3. **JSON Snapshots**: Compressed (gzip) snapshots for mobile consumption
4. **Blob Storage**: Static assets and snapshot distribution

### Security & Authentication

- **Current (Early Beta)**: Mixed approach based on service capabilities
  - **Storage Access**: Using SAS tokens due to Windows Consumption Plan limitations
    - Managed Identity for storage is limited on Windows Consumption Plans
    - SAS tokens provide reliable storage access for MVP phase
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
- **Function Access Pattern (Current)**: Connection String → Key Vault → SAS Tokens/Secrets
- **Function Access Pattern (Future)**: Managed Identity → Key Vault → Secrets

### API Management (APIM) Strategy

- **Current Tier**: Developer (No SLA) - ~$50/month for development
- **Production Plan**: Migrate to Consumption tier (~$5-15/month)
- **Purpose**: 
  - Tier-based rate limiting (Free/Premium/Pro products)
  - API key management per mobile app installation
  - API versioning for mobile app updates
  - Security: Hides Function URLs, DDoS protection
  - Built-in analytics and monitoring
- **Products Configuration**:
  - **Free**: Limited API calls, local features only
  - **Premium**: AI features with moderate limits
  - **Pro**: Unlimited AI features, priority support

### Cost Optimization

- **Target**: $2-5/month operational cost
- **Strategies**: 
  - Windows Consumption Functions (pay-per-execution)
  - Efficient JSON snapshots vs. continuous sync
  - SAS tokens (Key Vault access, simpler than MI setup costs during MVP)
  - Trade-off: Security best practices deferred until post-MVP for cost efficiency

## Development Environment

### Required Tools

- **IDE**: VS Code
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
- **Storage Access**: SAS tokens (temporary solution for Windows Consumption Plan limitations)
- **Future Plan**: Migrate to DefaultAzureCredential/Managed Identity when upgrading hosting plan

**Deployed Functions:**

- `ask-bartender`, `ask-bartender-simple`, `ask-bartender-test`: GPT-4o-mini cocktail recommendations
- `recommend`: AI-powered cocktail suggestions
- `realtime-token`, `realtime-token-simple`, `realtime-token-test`: Legacy (replaced by Azure Speech)
- `snapshots-latest`, `snapshots-latest-mi`: JSON snapshot distribution
- `download-images`, `download-images-mi`: Image asset management
- `sync-cocktaildb`: Timer-triggered nightly sync (03:30 UTC)
- `health`: Health check endpoint

### Infrastructure

- **Bicep Templates**: Declarative Azure resource definitions
- **Naming Convention**: Lowercase with hyphens (`func-mba-fresh`, `mbacocktaildb3`)

## Current Status & Known Issues

### Completed (2025-10-31)

- ✅ Core architecture design
- ✅ Azure infrastructure setup (all resources in South Central US)
- ✅ SAS token implementation for blob storage
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

- 📋 Camera-based inventory feature (Smart Scanner)
- 📋 AI voice interaction with Azure Speech Services
- 📋 Advanced AI cocktail recommendations (recommend endpoint with JWT)
- 📋 Free/Premium/Pro tier implementation via APIM
- 📋 Create Studio cocktail creation feature
- 📋 Android Play Store deployment

## Developer Background

**Author**: Experienced infrastructure architect with 30+ years in the field

- **Certifications**: AZ-305, AZ-104, AZ-700, AZ-900, IBM Certified Architect L2, TOGAF Certified Master Architect
- **Expertise**: Windows, Microsoft Networking, Active Directory, Azure infrastructure
- **New Skills**: Transitioning to "Vibe Coding" with AI-assisted development
- **Authorship**: 5 technical books (IIS, Windows, Security, Active Directory)

## Important Notes for AI Assistants

### When Helping with Code

1. **Azure Best Practices**: Currently using SAS tokens for MVP due to Windows Consumption Plan limitations
2. **Key Vault Access**: All secrets retrieved via connection strings from `kv-mybartenderai-prod`
3. **Cost Consciousness**: Always consider Azure consumption costs (reason for Consumption Plan)
4. **Security First**: PII-minimal, RBAC prepared for future, Key Vault integration
5. **Pragmatic Approach**: MVP uses what works (SAS), production will use Managed Identity
6. **Cross-Platform**: Remember Flutter targets both Android and iOS
7. **Windows Expertise**: Developer has strong Windows/Azure background

### Current Authentication Limitations

- **Windows Consumption Plan**: Limited Managed Identity support, especially for storage
- **MVP Strategy**: Use SAS tokens stored in Key Vault for reliable access
- **Migration Path**: Document in MANAGED_IDENTITY_MIGRATION.md for future reference
- **Future Plan**: Upgrade to Premium or Linux Consumption Plan for full MI support

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

**Last Updated**: October 2025  
**Project Phase**: Early Development / MVP  
**Primary Focus**: Infrastructure stability and mobile app foundation
