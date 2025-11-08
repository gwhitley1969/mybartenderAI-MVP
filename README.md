# MyBartenderAI - Early Beta

AI-powered bartender app that helps users discover and create cocktails based on their preferences and available ingredients.

## 🚀 Current Status (Updated: November 8, 2025)

- **Backend**: ✅ Azure Functions deployed (`func-mba-fresh`)
- **API Gateway**: ✅ Azure API Management configured (`apim-mba-001`)
- **Database**: ✅ PostgreSQL operational (`pg-mybartenderdb`)
- **Storage**: ✅ Blob Storage configured (`mbacocktaildb3`)
- **AI**: ✅ GPT-4o-mini integrated for chat & recommendations
- **Authentication**: ⏸️ Simplified - using Azure Function Keys directly
- **Voice**: ❌ **REMOVED** - Too expensive for current business model
- **Vision**: ✅ Azure Computer Vision for bottle identification
- **Mobile**: 📱 Flutter app - Core features complete and working

### Mobile App Features
- ✅ Recipe Vault with 621+ cocktails, search, filters, offline-first
- ✅ My Bar inventory management with "Can Make" filter
- ✅ AI Bartender Chat with inventory integration
- ❌ Voice Bartender **REMOVED** (cost optimization)
- ✅ Smart Scanner for bottle identification (Azure Computer Vision)
- ✅ Create Studio with enhanced AI Refine feature
  - AI suggestions for improving recipes
  - "Save as New Recipe" option in edit mode
  - Electric blue UI accents for better visibility
- ✅ Favorites/Bookmarks
- ✅ Backend connectivity via Azure Function Keys
- ⚠️ **Premium migration pending** - EP1 quota increase submitted to Microsoft

## 📁 Project Structure

```
mybartenderAI-MVP/
├── apps/
│   └── backend/          # Azure Functions (Node.js/TypeScript)
├── mobile/
│   └── app/             # Flutter mobile application
├── docs/                # Architecture and documentation
├── prompts/             # AI system prompts
└── spec/                # API specifications
```

## 🏗️ Architecture

### Azure Infrastructure

- **API Gateway**: Azure API Management (`apim-mba-001`)
  - Gateway: https://apim-mba-001.azure-api.net
  - Three-tier products: Free, Premium ($4.99/mo), Pro ($9.99/mo)
- **Backend**: Azure Functions (`func-mba-fresh`, Windows Consumption Plan)
- **Database**: PostgreSQL (`pg-mybartenderdb`)
- **Storage**: Azure Blob Storage (`mbacocktaildb3`)
- **Security**: Azure Key Vault (`kv-mybartenderai-prod`), Region: (East US), Resource Group: (rg-mba-dev)
- **AI**: Azure OpenAI (GPT-4o-mini) + Azure Speech Services
- **Region**: South Central US (primary)
- **Resource Group**: (everything but Azure Key Vault): (rg-mba-prod)

### Key Features

- **Offline First**: Complete cocktail database (SQLite) available offline
- **AI Recommendations**: GPT-4o-mini powered suggestions (~$0.007/session)
- **Voice Assistant**: Azure Speech Services (93% cheaper than OpenAI Realtime)
- **Tiered Access**: APIM-enforced Free/Premium/Pro subscription levels
- **Privacy Focused**: No PII stored for free tier users
- **Secure Storage**: SAS tokens (MVP), Managed Identity (planned)

## 🔧 Quick Start

### Prerequisites

- Node.js 18+ (for Azure Functions)
- Flutter SDK 3.0+ (for mobile app)
- Azure CLI (for deployment)
- Azure subscription with proper permissions

### Backend Setup

```bash
cd apps/backend
npm install
npm run build

# Deploy to Azure
func azure functionapp publish func-mba-fresh
```

### Mobile Setup

```bash
cd mobile/app
flutter pub get
flutter run
```

### APIM Configuration

1. Navigate to Azure Portal → API Management (`apim-mba-001`)
2. Import OpenAPI spec from `/spec/openapi.yaml`
3. Configure three Products: Free, Premium, Pro
4. Set up rate limiting policies per tier

### Test Endpoints

```bash
# Health check (anonymous)
curl https://apim-mba-001.azure-api.net/api/health

# Get latest snapshot (requires API key)
curl https://apim-mba-001.azure-api.net/api/v1/snapshots/latest \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY"

# Ask bartender (requires Premium/Pro tier)
curl -X POST https://apim-mba-001.azure-api.net/api/v1/ask-bartender \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "How do I make a Negroni?"}'
```

## 📚 Documentation

### Core Documentation

- [Architecture Overview](docs/ARCHITECTURE.md) - Complete system design
- [Product Requirements](docs/PRD.md) - Feature specifications and roadmap
- [API Specification](spec/openapi.yaml) - OpenAPI contract
- [Development Plan](docs/PLAN.md) - Sprint planning and acceptance criteria

### Integration Guides

- [Flutter Integration](docs/FLUTTER_INTEGRATION_PLAN.md) - Mobile app setup
- [Voice Integration](docs/VOICE_INTEGRATION_PLAN.md) - Azure Speech Services
- [Authentication Setup](docs/AUTHENTICATION_SETUP.md) - Entra External ID

### Operations

- [Deployment Status](docs/DEPLOYMENT_STATUS.md) - Current deployment state
- [Managed Identity Migration](docs/MANAGED_IDENTITY_MIGRATION.md) - Future MI plan

## 🎯 Feature Tiers

### Free Tier

- ✅ Offline cocktail database (~621 drinks)
- ✅ Local search and filtering
- ✅ 10 AI recommendations/month
- ❌ No voice assistant
- ❌ No vision scanning

### Premium Tier ($4.99/month)

- ✅ 100 AI recommendations/month
- ✅ 30 minutes voice assistant/month
- ✅ 5 vision scans/month
- ✅ 25 custom recipes

### Pro Tier ($9.99/month)

- ✅ Unlimited AI recommendations
- ✅ 5 hours voice assistant/month
- ✅ 50 vision scans/month
- ✅ Unlimited custom recipes
- ✅ Priority support

## 🔮 Roadmap

### Phase 1: Early Beta (Current)

- ✅ Core backend infrastructure
- ✅ APIM configuration for tier management
- ✅ Database synchronization from TheCocktailDB
- ✅ JSON snapshot generation and delivery
- ✅ GPT-4o-mini integration
- ✅ Authentication with Entra External ID (Email, Google, Facebook)
- ✅ Server-side age verification (21+) via Custom Authentication Extension
- ✅ Flutter design system matching UI mockups
- ✅ Flutter home screen implementation
- ✅ Flutter backend connection (snapshots endpoint)
- ✅ Recipe Vault screen with search, filters, and cocktail detail views
- ✅ Offline-first SQLite database with Zstandard compression
- ✅ Inventory management system (My Bar)
- ✅ User ingredient tracking with quick-add functionality
- ✅ "Can Make" filter for cocktails based on user inventory
- 🚧 Voice Chat/Ask the Bartender screen integration
- 🚧 AI recommendations with JWT authentication
- 🚧 Voice assistant implementation

### Phase 2: Premium Features (Q1 2026)

- 📋 Azure Speech Services integration
- 📋 Voice-guided cocktail making
- 📋 Azure Computer Vision for bar scanning
- 📋 Custom recipe AI enhancement
- 📋 iOS app launch

### Phase 3: Advanced Features (Q2 2026)

- 📋 Real-time collaboration on recipes
- 📋 Social features (share custom cocktails)
- 📋 Ingredient substitution AI
- 📋 Cocktail preferences learning
- 📋 Multi-language support

### Phase 4: Scale & Optimize (Q3 2026)

- 📋 Migrate to Managed Identity
- 📋 APIM Consumption tier
- 📋 Azure Front Door (global CDN)
- 📋 Premium PostgreSQL tier
- 📋 Advanced analytics

## 💰 Cost Structure

### Development (Current)

- APIM Developer tier: ~$50/month
- Azure Functions: ~$0.20/month (minimal usage)
- PostgreSQL Basic: ~$12-30/month
- Storage: ~$1/month
- **Total: ~$60-70/month**

### Production (Target)

- APIM Consumption: ~$5-15/month
- Azure Functions: ~$0.20/month
- PostgreSQL Optimized: ~$12-20/month
- Storage: ~$1/month
- AI Services: Covered by subscription revenue
- **Total: ~$20-30/month base + usage**

### Per-User Costs (Premium)

- AI (GPT-4o-mini): ~$0.40/month
- Voice (Azure Speech): ~$0.10/month
- **Total: ~$0.50/user/month**

### Revenue Model

- 1,000 Premium users @ $4.99 = $5,000/month
- AI costs: ~$500/month
- **Profit margin: ~90%**

## 🔐 Security

### Authentication

- Microsoft Entra External ID (Azure AD B2C)
- JWT tokens validated at APIM layer
- APIM subscription keys per app installation

### Secrets Management

- All secrets in Azure Key Vault (`kv-mybartenderai-prod`)
- No secrets in code or configuration files
- Key Vault references in Function App settings

### Privacy

- No PII stored for Free tier
- Voice transcripts ephemeral (unless user opts in)
- Bar photos never stored
- User ingredients hashed in logs
- 90-day retention for opted-in data

## 🧪 Testing

### Backend Testing

```bash
cd apps/backend
npm test                    # Unit tests
npm run test:integration   # Integration tests
```

### Mobile Testing

```bash
cd mobile/app
flutter test               # Unit + widget tests
flutter drive             # Integration tests
```

### API Testing

Use the APIM Developer Portal test console:

1. Navigate to https://apim-mba-001.developer.azure-api.net
2. Sign in with your Azure account
3. Select an API and operation
4. Click "Try it" to test endpoints

## 🤝 Contributing

This is a private MVP project. For questions or access, please contact the project owner.

## 📞 Support

- **Technical Issues**: Check [DEPLOYMENT_STATUS.md](docs/DEPLOYMENT_STATUS.md)
- **API Documentation**: See [OpenAPI spec](spec/openapi.yaml)
- **Feature Requests**: Contact project owner

## 📄 License

Proprietary - All rights reserved

---

**Built with:**

- Flutter (Mobile)
- Azure Functions (Backend)
- Azure API Management (Gateway)
- Azure OpenAI (GPT-4o-mini)
- Azure Speech Services (Voice)
- PostgreSQL (Database)
- Azure Blob Storage (Assets)
