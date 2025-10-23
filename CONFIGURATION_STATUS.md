# MyBartenderAI - Configuration Status

**Date**: October 22, 2025
**Configured By**: Claude Code with Gene Whitley

---

## ✅ What's Been Configured (Automated)

### 1. APIM Products Created
- ✅ **Free Tier** - 100 API calls/day
- ✅ **Premium Tier ($4.99/month)** - 1,000 API calls/day
- ✅ **Pro Tier ($9.99/month)** - 10,000 API calls/day

### 2. API Imported
- ✅ **MyBartenderAI API** imported from `spec/openapi-complete.yaml`
- ✅ All 7 endpoints imported:
  - `GET /health` - Health check
  - `GET /v1/snapshots/latest` - Get database snapshot
  - `GET /v1/images/manifest` - Get image manifest
  - `POST /v1/recommend` - AI recommendations
  - `POST /v1/ask-bartender` - AI chat
  - `GET /v1/speech/token` - Speech token
  - `POST /v1/admin/sync` - Admin sync trigger

### 3. Products Configured
- ✅ API added to all three products (Free/Premium/Pro)
- ✅ Subscription required for all products
- ✅ Products published and available

---

## ⏳ What YOU Need to Do (Manual Steps)

### Step 1: Apply APIM Policies (10 minutes) ⚠️ CRITICAL

The policies control rate limiting and tier enforcement. You MUST apply these manually:

#### Instructions:

1. **Open Azure Portal**: https://portal.azure.com
2. **Navigate to APIM**:
   - Search for "apim-mba-001"
   - Click on the service

3. **Apply Free Tier Policy**:
   - Go to **Products** → **Free Tier**
   - Click **Policies**
   - Click **</>** (Code editor button)
   - On your machine, open: `C:\backup dev02\mybartenderAI-MVP\infrastructure\apim\policies\free-tier-policy.xml`
   - Copy ALL content
   - Paste into the policy editor (replace everything)
   - Click **Save**

4. **Apply Premium Tier Policy**:
   - Go to **Products** → **Premium Tier ($4.99/month)**
   - Click **Policies** → **</>**
   - Open: `infrastructure/apim/policies/premium-tier-policy.xml`
   - Copy and paste
   - Click **Save**

5. **Apply Pro Tier Policy**:
   - Go to **Products** → **Pro Tier ($9.99/month)**
   - Click **Policies** → **</>**
   - Open: `infrastructure/apim/policies/pro-tier-policy.xml`
   - Copy and paste
   - Click **Save**

**Why Manual?** Azure CLI has limited policy management support. Portal is the recommended method.

---

### Step 2: Deploy PostgreSQL Schema (5 minutes) ⚠️ CRITICAL

The database schema must be deployed before the backend functions will work.

#### Option A: Using PowerShell Script (Recommended)

```powershell
# Open PowerShell in your project directory
cd "C:\backup dev02\mybartenderAI-MVP\infrastructure\database"

# Run deployment script
./deploy-schema.ps1 `
  -ServerName "pg-mybartenderdb.postgres.database.azure.com" `
  -DatabaseName "mybartenderai" `
  -KeyVaultName "kv-mybartenderai-prod"
```

The script will:
- Retrieve the database password from Key Vault
- Connect to PostgreSQL
- Deploy the complete schema
- Verify the deployment

#### Option B: Manual Deployment (If script fails)

1. **Install PostgreSQL Client** (if not installed):
   - Download from: https://www.postgresql.org/download/windows/
   - Or use `choco install postgresql` if you have Chocolatey

2. **Get Database Password**:
   ```powershell
   az keyvault secret show --vault-name kv-mybartenderai-prod --name POSTGRES-CONNECTION-STRING --query value -o tsv
   ```

3. **Deploy Schema**:
   ```bash
   psql -h pg-mybartenderdb.postgres.database.azure.com \
        -U adminuser \
        -d mybartenderai \
        -f "C:\backup dev02\mybartenderAI-MVP\infrastructure\database\schema.sql"
   ```

#### What Gets Created:
- **9 Tables**: drinks, ingredients, users, usage_tracking, voice_sessions, vision_scans, etc.
- **3 Functions**: get_user_quotas(), check_user_quota(), record_usage()
- **2 Views**: user_usage_summary, monthly_tier_stats

---

### Step 3: Test Configuration (5 minutes)

After completing Steps 1 & 2, test everything:

#### Test 1: Health Endpoint (No Auth)
```bash
curl https://apim-mba-001.azure-api.net/api/health
```

**Expected**: Should return a health check response (once Function App is deployed)

#### Test 2: Get Subscription Key

1. Go to: https://apim-mba-001.developer.azure-api.net
2. Sign in with your Azure account (bluebuildapps@gmail.com)
3. Go to **Products** → **Free Tier**
4. Click **Subscribe**
5. Create a subscription
6. Copy the **Primary key**

#### Test 3: Test with Subscription Key
```bash
curl https://apim-mba-001.azure-api.net/api/v1/snapshots/latest \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY_HERE"
```

**Expected**:
- If backend is ready: Returns snapshot metadata
- If backend not ready: 404 or 503 (that's OK for now)

#### Test 4: Test Rate Limiting

Make 101 requests with Free Tier key - the 101st should return 429 (rate limited)

---

## 📊 Configuration Summary

| Component | Status | Details |
|-----------|--------|---------|
| **APIM Products** | ✅ Created | Free, Premium, Pro |
| **API Import** | ✅ Complete | 7 endpoints |
| **Product Policies** | ⏳ **YOU NEED TO APPLY** | Via Azure Portal |
| **Database Schema** | ⏳ **YOU NEED TO DEPLOY** | Via PowerShell script |
| **Backend Functions** | ⏳ Next Phase | Phase 2 work |

---

## 🎯 Quick Checklist

Before moving to Phase 2, complete these:

- [ ] Applied Free Tier policy in Azure Portal
- [ ] Applied Premium Tier policy in Azure Portal
- [ ] Applied Pro Tier policy in Azure Portal
- [ ] Deployed PostgreSQL schema (tables exist)
- [ ] Created test subscription key
- [ ] Tested health endpoint
- [ ] Tested rate limiting

---

## 🚀 Next Steps: Phase 2

Once the above is complete, you're ready for Phase 2: Backend Services

This includes:
1. Implementing Azure Functions (sync-cocktaildb, ask-bartender, etc.)
2. Testing AI integration with GPT-4o-mini
3. Generating first cocktail database snapshot
4. End-to-end testing

**Estimated time for Phase 2**: 1-2 days of development

---

## 📁 Important Files

```
infrastructure/
├── apim/
│   └── policies/
│       ├── free-tier-policy.xml       ← You need to apply this
│       ├── premium-tier-policy.xml    ← You need to apply this
│       └── pro-tier-policy.xml        ← You need to apply this
└── database/
    ├── schema.sql                      ← Complete database schema
    └── deploy-schema.ps1               ← Run this script
```

---

## 🆘 Troubleshooting

### "Can't access Azure Portal"
- Make sure you're logged in as: bluebuildapps@gmail.com
- Navigate to https://portal.azure.com
- Search for "apim-mba-001"

### "Can't find policy editor"
- In APIM, go to: Products → [Product Name] → Policies
- Look for **</>** button (code editor)
- This opens the XML policy editor

### "deploy-schema.ps1 fails"
- Make sure you're in the correct directory: `cd infrastructure/database`
- Check PowerShell execution policy: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
- Verify you're logged in to Azure: `Connect-AzAccount`

### "psql command not found"
- Install PostgreSQL client tools
- Windows: https://www.postgresql.org/download/windows/
- Add to PATH: `C:\Program Files\PostgreSQL\16\bin`

---

## 📞 Azure Resources Info

| Resource | Name | Location | Status |
|----------|------|----------|--------|
| Resource Group | rg-mba-prod | South Central US | ✅ |
| APIM | apim-mba-001 | South Central US | ✅ Configured |
| Function App | func-mba-fresh | South Central US | ✅ Running |
| PostgreSQL | pg-mybartenderdb | South Central US | ✅ Ready |
| Storage | mbacocktaildb3 | South Central US | ✅ |
| Key Vault | kv-mybartenderai-prod | East US (rg-mba-dev) | ✅ |

**APIM Gateway**: https://apim-mba-001.azure-api.net
**Developer Portal**: https://apim-mba-001.developer.azure-api.net

---

## ✅ Success Criteria

Phase 1 is complete when:

- [x] APIM products created ✅ DONE
- [x] API imported ✅ DONE
- [ ] All policies applied ⏳ YOU DO THIS
- [ ] Database schema deployed ⏳ YOU DO THIS
- [ ] Test subscription key works
- [ ] Rate limiting enforced

---

**Time to Complete Remaining Steps**: ~20 minutes

**Questions?** Review `infrastructure/README.md` or `docs/PHASE1_COMPLETE.md`
