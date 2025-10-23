# Phase 1: Azure Infrastructure - Configuration Complete ✅

**Date**: October 22, 2025
**Status**: Configuration files created - Ready for deployment

---

## What We've Accomplished

### 1. ✅ Enhanced OpenAPI Specification
**File**: `spec/openapi-complete.yaml`

Created a comprehensive OpenAPI 3.0 spec that includes:
- All endpoints for three-tier system (Free/Premium/Pro)
- Health check endpoint (anonymous)
- Snapshot and image manifest endpoints
- AI recommendation and chat endpoints
- Voice assistant endpoints (Speech token, session tracking)
- Vision scanning endpoints
- User inventory management
- User tier and quota management
- Authentication/registration endpoints
- Admin endpoints

**Security Schemes**:
- `apiKeyAuth`: APIM subscription key (per mobile app)
- `bearerAuth`: Azure AD B2C JWT token
- `functionKeyAuth`: Function key for admin endpoints

### 2. ✅ APIM Configuration Script
**File**: `infrastructure/apim/configure-apim.ps1`

PowerShell script that automates:
- Backend configuration pointing to Function App
- Creation of three Products (Free/Premium/Pro)
- OpenAPI spec import
- API addition to all products

**Usage**:
```powershell
cd infrastructure/apim
./configure-apim.ps1 -ResourceGroup "rg-mba-prod" -ApimServiceName "apim-mba-001"
```

### 3. ✅ APIM Policy Files

Created four comprehensive policy XML files:

#### **Free Tier Policy** (`policies/free-tier-policy.xml`)
- Rate limit: 100 calls/day
- Blocks voice and vision features (403 Forbidden)
- Allows limited AI (10/month enforced by backend)
- Adds tier headers and correlation IDs

#### **Premium Tier Policy** (`policies/premium-tier-policy.xml`)
- Rate limit: 1,000 calls/day
- Allows all features with Premium quotas
- Caches snapshot endpoint (5 min)
- Priority routing (30s timeout)

#### **Pro Tier Policy** (`policies/pro-tier-policy.xml`)
- Rate limit: 10,000 calls/day (abuse prevention)
- Unlimited access to all features
- Highest priority routing (60s timeout)
- Adds Pro tier indicators

#### **JWT Validation Policy** (`policies/jwt-validation-policy.xml`)
- Validates Azure AD B2C JWT tokens
- Extracts user ID and email claims
- Adds headers for backend consumption
- Custom 401 error responses

### 4. ✅ PostgreSQL Database Schema
**File**: `infrastructure/database/schema.sql`

Complete database schema with:

**Core Tables**:
- `snapshots`: Metadata for JSON database snapshots
- `drinks`: Cocktail recipes (621+ drinks)
- `ingredients`: Master ingredient list
- `drink_ingredients`: Recipe-ingredient relationships
- `users`: User accounts with tier information
- `user_inventory`: User's bar ingredients
- `usage_tracking`: Feature usage for quota enforcement
- `voice_sessions`: Voice assistant session tracking
- `vision_scans`: Vision scan history

**Helper Functions**:
- `get_user_quotas(tier)`: Returns quota limits for a tier
- `check_user_quota(user_id, feature_type)`: Check remaining quota
- `record_usage(user_id, feature_type, count)`: Record usage

**Views**:
- `user_usage_summary`: Usage by feature and month
- `monthly_tier_stats`: Revenue potential by tier

### 5. ✅ Database Deployment Script
**File**: `infrastructure/database/deploy-schema.ps1`

PowerShell script that:
- Retrieves connection string from Key Vault
- Tests database connection
- Deploys schema using psql
- Verifies deployment (table and function counts)

**Usage**:
```powershell
cd infrastructure/database
./deploy-schema.ps1 -ServerName "pg-mybartenderdb.postgres.database.azure.com"
```

### 6. ✅ Infrastructure Documentation
**File**: `infrastructure/README.md`

Comprehensive guide covering:
- Directory structure
- Configuration steps
- Three-tier subscription model details
- All API endpoints
- Database schema overview
- Monitoring and analytics
- Cost optimization breakdown
- Security best practices
- Troubleshooting guide

---

## Next Steps - Action Items for You

### Step 1: Run APIM Configuration Script ⏳

```powershell
# Navigate to APIM directory
cd "C:\backup dev02\mybartenderAI-MVP\infrastructure\apim"

# Run configuration script
./configure-apim.ps1 -ResourceGroup "rg-mba-prod" -ApimServiceName "apim-mba-001" -FunctionAppUrl "https://func-mba-fresh.azurewebsites.net"
```

**Expected Output**:
- ✅ Backend configured
- ✅ Three products created (Free/Premium/Pro)
- ✅ OpenAPI spec imported
- ✅ API added to all products

### Step 2: Apply APIM Policies Manually 📋

The policies must be applied through Azure Portal:

1. **Navigate to Azure Portal**:
   - Go to https://portal.azure.com
   - Search for "apim-mba-001"
   - Click on your APIM instance

2. **Apply Product Policies**:

   **For Free Tier**:
   - Go to **Products** → **Free Tier**
   - Click **Policies**
   - Click **</> Code editor**
   - Copy content from `infrastructure/apim/policies/free-tier-policy.xml`
   - Paste and **Save**

   **For Premium Tier**:
   - Go to **Products** → **Premium Tier**
   - Click **Policies**
   - Click **</> Code editor**
   - Copy content from `infrastructure/apim/policies/premium-tier-policy.xml`
   - Paste and **Save**

   **For Pro Tier**:
   - Go to **Products** → **Pro Tier**
   - Click **Policies**
   - Click **</> Code editor**
   - Copy content from `infrastructure/apim/policies/pro-tier-policy.xml`
   - Paste and **Save**

3. **Apply JWT Validation Policy** (API Level):
   - Go to **APIs** → **MyBartenderAI API**
   - Select **All operations**
   - Click **Inbound processing** → **</>**
   - **Before applying**: Update the following placeholders in `jwt-validation-policy.xml`:
     - `{tenant-name}`: Your Azure AD B2C tenant name
     - `{your-client-id}`: Your app's client ID from B2C
     - `{tenant-id}`: Your B2C tenant ID
   - Copy the updated content
   - Paste in the policy editor and **Save**

### Step 3: Deploy Database Schema 🗄️

```powershell
# Navigate to database directory
cd "C:\backup dev02\mybartenderAI-MVP\infrastructure\database"

# Deploy schema (will retrieve password from Key Vault)
./deploy-schema.ps1 `
  -ServerName "pg-mybartenderdb.postgres.database.azure.com" `
  -DatabaseName "mybartenderai" `
  -KeyVaultName "kv-mybartenderai-prod"
```

**Prerequisites**:
- PostgreSQL client tools installed (`psql` command)
- Azure CLI authenticated (`Connect-AzAccount`)
- Access to Key Vault with POSTGRES-CONNECTION-STRING secret

**Alternative - Manual Deployment**:
```bash
# If script fails, deploy manually
psql -h pg-mybartenderdb.postgres.database.azure.com \
     -U adminuser \
     -d mybartenderai \
     -f schema.sql
```

### Step 4: Test APIM Configuration 🧪

```bash
# Test health endpoint (no auth required)
curl https://apim-mba-001.azure-api.net/api/health

# Expected response:
# {
#   "status": "ok",
#   "message": "MyBartenderAI API is running",
#   "timestamp": "2025-10-22T..."
# }
```

### Step 5: Create Test Subscription Keys 🔑

1. Go to APIM Developer Portal: https://apim-mba-001.developer.azure-api.net
2. Sign in with your Azure account
3. Go to **Products** → **Free Tier** → **Subscribe**
4. Create a subscription and note the **Primary key**
5. Test with subscription key:

```bash
curl https://apim-mba-001.azure-api.net/api/v1/snapshots/latest \
  -H "Ocp-Apim-Subscription-Key: YOUR_SUBSCRIPTION_KEY"
```

### Step 6: Verify Key Vault Access 🔐

```powershell
# Check Key Vault secrets
az keyvault secret list --vault-name kv-mybartenderai-prod

# Expected secrets:
# - COCKTAILDB-API-KEY
# - OpenAI
# - POSTGRES-CONNECTION-STRING
# - (Future) AZURE-SPEECH-KEY
```

---

## Architecture Overview

```
Mobile App (Flutter)
    |
    | HTTPS + API Key + JWT
    ↓
Azure API Management (apim-mba-001)
    |
    | Rate Limiting per Tier
    | JWT Validation
    | Tier-based Access Control
    ↓
Azure Functions (func-mba-fresh)
    |
    ├─→ PostgreSQL (quota tracking, user data)
    ├─→ Blob Storage (snapshots, images)
    ├─→ Azure OpenAI (GPT-4o-mini)
    └─→ Azure Speech Services (future)
```

---

## Three-Tier System at a Glance

| Feature | Free | Premium ($4.99) | Pro ($9.99) |
|---------|------|-----------------|-------------|
| **Rate Limit** | 100/day | 1,000/day | 10,000/day |
| **AI Recommendations** | 10/month | 100/month | Unlimited |
| **Voice Assistant** | ❌ Blocked | 30 min/month | 5 hours/month |
| **Vision Scanning** | ❌ Blocked | 5 scans/month | 50 scans/month |
| **Custom Recipes** | 3 total | 25 total | Unlimited |
| **Priority Routing** | No | Yes | Highest |
| **Timeout** | 15s | 30s | 60s |

---

## Cost Analysis

### Current Development Costs (~$60-70/month)
- APIM Developer tier: $50/month
- Azure Functions: ~$0.20/month
- PostgreSQL Basic: $12-30/month
- Storage: ~$1/month

### Production Target (~$20-30/month + usage)
- APIM Consumption: $5-15/month ← **Migrate after testing**
- Azure Functions: ~$0.20/month
- PostgreSQL Optimized: $12-20/month
- Storage: ~$1/month
- AI services: Covered by subscription revenue

### Per-User AI Costs (Premium)
- GPT-4o-mini: ~$0.40/month
- Azure Speech: ~$0.10/month
- **Total: ~$0.50/user/month**

### Revenue Model
- 1,000 Premium users @ $4.99 = **$5,000/month**
- AI costs @ $0.50/user = **$500/month**
- **Profit margin: 90%** 🎯

---

## File Summary

### Created Files:
```
✅ spec/openapi-complete.yaml                    # Enhanced OpenAPI spec
✅ infrastructure/apim/configure-apim.ps1        # APIM automation script
✅ infrastructure/apim/policies/free-tier-policy.xml
✅ infrastructure/apim/policies/premium-tier-policy.xml
✅ infrastructure/apim/policies/pro-tier-policy.xml
✅ infrastructure/apim/policies/jwt-validation-policy.xml
✅ infrastructure/database/schema.sql            # Complete DB schema
✅ infrastructure/database/deploy-schema.ps1     # DB deployment script
✅ infrastructure/README.md                      # Infrastructure guide
✅ docs/PHASE1_COMPLETE.md                       # This document
```

---

## What's Next: Phase 2 - Backend Services

After completing the steps above, we'll move to Phase 2:

1. **Implement Azure Functions**:
   - `sync-cocktaildb`: Nightly sync from TheCocktailDB
   - `snapshots-latest`: Serve JSON snapshots
   - `ask-bartender`: GPT-4o-mini conversational AI
   - `recommend`: Structured AI recommendations
   - `speech-token`: Azure Speech token endpoint

2. **Test End-to-End**:
   - Sync cocktail database
   - Generate first snapshot
   - Test AI recommendations
   - Verify quota enforcement

3. **Mobile App Integration**:
   - Configure API client with APIM URL
   - Implement snapshot download
   - Build offline SQLite database
   - Test tier-based access

---

## Resources

- **APIM Gateway**: https://apim-mba-001.azure-api.net
- **Developer Portal**: https://apim-mba-001.developer.azure-api.net
- **Azure Portal**: https://portal.azure.com
- **Documentation**: `/docs/ARCHITECTURE.md`, `/docs/PLAN.md`

---

## Troubleshooting

### "psql command not found"
Install PostgreSQL client:
- **Windows**: https://www.postgresql.org/download/windows/
- **macOS**: `brew install postgresql`
- **Linux**: `sudo apt-get install postgresql-client`

### "APIM service not found"
Ensure you're logged in to Azure CLI:
```powershell
Connect-AzAccount
Get-AzApiManagement -ResourceGroupName "rg-mba-prod"
```

### "Key Vault access denied"
Grant yourself access:
```bash
az keyvault set-policy --name kv-mybartenderai-prod \
  --upn YOUR_EMAIL@domain.com \
  --secret-permissions get list
```

---

**Status**: ✅ Configuration Complete - Ready for Deployment
**Next**: Execute Steps 1-6 above, then proceed to Phase 2

---

**Questions?** Review the detailed documentation in `infrastructure/README.md`
