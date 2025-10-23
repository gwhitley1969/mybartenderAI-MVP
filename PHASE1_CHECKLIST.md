# Phase 1 Deployment Checklist

**Quick reference guide for deploying MyBartenderAI infrastructure**

---

## ✅ Configuration Files Created

All configuration files have been created and are ready for deployment:

- [x] Enhanced OpenAPI specification (`spec/openapi-complete.yaml`)
- [x] APIM configuration script (`infrastructure/apim/configure-apim.ps1`)
- [x] APIM policy files (4 files in `infrastructure/apim/policies/`)
- [x] PostgreSQL schema (`infrastructure/database/schema.sql`)
- [x] Database deployment script (`infrastructure/database/deploy-schema.ps1`)
- [x] Infrastructure documentation (`infrastructure/README.md`)

---

## 🎯 Deployment Steps

### Step 1: Configure APIM ⏳

```powershell
cd "C:\backup dev02\mybartenderAI-MVP\infrastructure\apim"
./configure-apim.ps1 -ResourceGroup "rg-mba-prod" -ApimServiceName "apim-mba-001"
```

**Outcome**: Creates 3 products, imports OpenAPI spec, configures backend

- [ ] Script ran successfully
- [ ] Free Tier product created
- [ ] Premium Tier product created
- [ ] Pro Tier product created
- [ ] API imported and visible in APIM

---

### Step 2: Apply APIM Policies 📋

**Portal**: https://portal.azure.com → Search "apim-mba-001"

#### Apply Product Policies:

**Free Tier**:
- [ ] Go to Products → Free Tier → Policies
- [ ] Copy from `policies/free-tier-policy.xml`
- [ ] Paste and Save

**Premium Tier**:
- [ ] Go to Products → Premium Tier → Policies
- [ ] Copy from `policies/premium-tier-policy.xml`
- [ ] Paste and Save

**Pro Tier**:
- [ ] Go to Products → Pro Tier → Policies
- [ ] Copy from `policies/pro-tier-policy.xml`
- [ ] Paste and Save

#### Apply JWT Validation Policy:

- [ ] Update `jwt-validation-policy.xml` with your B2C details:
  - [ ] Replace `{tenant-name}`
  - [ ] Replace `{your-client-id}`
  - [ ] Replace `{tenant-id}`
- [ ] Go to APIs → MyBartenderAI API → All operations
- [ ] Click Inbound processing → </>
- [ ] Paste updated JWT policy
- [ ] Save

---

### Step 3: Deploy Database Schema 🗄️

```powershell
cd "C:\backup dev02\mybartenderAI-MVP\infrastructure\database"
./deploy-schema.ps1 -ServerName "pg-mybartenderdb.postgres.database.azure.com"
```

**Prerequisites**:
- [ ] PostgreSQL client tools installed (`psql`)
- [ ] Logged in to Azure CLI (`Connect-AzAccount`)
- [ ] Key Vault access granted

**Verification**:
- [ ] Script completed successfully
- [ ] Tables created (drinks, users, etc.)
- [ ] Functions created (check_user_quota, record_usage)
- [ ] Views created (user_usage_summary, monthly_tier_stats)

---

### Step 4: Test Configuration 🧪

#### Test Health Endpoint (No Auth):
```bash
curl https://apim-mba-001.azure-api.net/api/health
```

- [ ] Returns `{"status": "ok", ...}`

#### Test with Subscription Key:

1. **Get subscription key**:
   - [ ] Go to https://apim-mba-001.developer.azure-api.net
   - [ ] Sign in
   - [ ] Subscribe to Free Tier product
   - [ ] Copy Primary key

2. **Test snapshot endpoint**:
```bash
curl https://apim-mba-001.azure-api.net/api/v1/snapshots/latest \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY_HERE"
```

- [ ] Returns snapshot metadata (or 503 if no snapshot exists yet)

#### Test Rate Limiting:

- [ ] Make 101 requests with Free Tier key
- [ ] Verify 101st request returns 429 (Rate limit exceeded)

#### Test Tier Enforcement:

- [ ] Try `/v1/speech/token` with Free Tier key
- [ ] Verify returns 403 Forbidden with upgrade message

---

### Step 5: Verify Key Vault 🔐

```powershell
az keyvault secret list --vault-name kv-mybartenderai-prod
```

**Expected Secrets**:
- [ ] COCKTAILDB-API-KEY
- [ ] OpenAI
- [ ] POSTGRES-CONNECTION-STRING

**Grant Function App Access** (if needed):
```powershell
$functionAppId = (Get-AzWebApp -ResourceGroupName "rg-mba-prod" -Name "func-mba-fresh").Identity.PrincipalId

az role assignment create `
  --assignee $functionAppId `
  --role "Key Vault Secrets User" `
  --scope "/subscriptions/YOUR_SUB_ID/resourceGroups/rg-mba-dev/providers/Microsoft.KeyVault/vaults/kv-mybartenderai-prod"
```

- [ ] Function App has Key Vault access
- [ ] All secrets readable

---

## 📊 Verification Matrix

| Component | Status | Test |
|-----------|--------|------|
| APIM Products | ⬜ | Check in Azure Portal |
| APIM Policies | ⬜ | Free tier blocks voice/vision |
| JWT Validation | ⬜ | Try endpoint without token → 401 |
| Database Schema | ⬜ | Run `\dt` in psql |
| Backend Routing | ⬜ | Health endpoint returns 200 |
| Rate Limiting | ⬜ | 101st Free tier request → 429 |
| Subscription Keys | ⬜ | Can subscribe in Developer Portal |
| Key Vault | ⬜ | Function App can read secrets |

---

## 🚨 Common Issues

### Issue: "Script cannot be loaded"
**Solution**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Issue: "psql command not found"
**Solution**: Install PostgreSQL client
- Windows: https://www.postgresql.org/download/windows/
- macOS: `brew install postgresql`

### Issue: "Connection to PostgreSQL failed"
**Solution**: Check firewall rules
```bash
az postgres flexible-server firewall-rule create \
  --resource-group rg-mba-prod \
  --name pg-mybartenderdb \
  --rule-name AllowMyIP \
  --start-ip-address YOUR_IP \
  --end-ip-address YOUR_IP
```

### Issue: "Key Vault access denied"
**Solution**: Grant yourself access
```bash
az keyvault set-policy --name kv-mybartenderai-prod \
  --upn YOUR_EMAIL@domain.com \
  --secret-permissions get list
```

### Issue: "Cannot find APIM service"
**Solution**: Login to Azure
```powershell
Connect-AzAccount
Get-AzApiManagement -ResourceGroupName "rg-mba-prod"
```

---

## 📁 Quick File Reference

```
infrastructure/
├── apim/
│   ├── configure-apim.ps1          ← Run this first
│   └── policies/
│       ├── free-tier-policy.xml    ← Apply to Free Tier product
│       ├── premium-tier-policy.xml ← Apply to Premium Tier product
│       ├── pro-tier-policy.xml     ← Apply to Pro Tier product
│       └── jwt-validation-policy.xml ← Apply to API level
└── database/
    ├── schema.sql                   ← Database schema
    └── deploy-schema.ps1            ← Run this second
```

---

## ✅ Completion Criteria

Phase 1 is complete when:

- [x] All configuration files created ✅ (DONE)
- [ ] APIM configured with 3 products
- [ ] All 4 policies applied
- [ ] Database schema deployed
- [ ] Health endpoint returns 200
- [ ] Subscription keys work
- [ ] Rate limiting enforced
- [ ] Tier enforcement works (Free blocked from voice/vision)

---

## 🎯 Next Phase

Once all checkboxes above are complete, proceed to:

**Phase 2: Backend Services**
- Implement Azure Functions (sync-cocktaildb, ask-bartender, etc.)
- Test AI integration with GPT-4o-mini
- Generate first snapshot
- Verify end-to-end flow

---

**Estimated Time**: 1-2 hours (depending on familiarity with Azure Portal)

**Documentation**: See `docs/PHASE1_COMPLETE.md` for detailed instructions
**Support**: See `infrastructure/README.md` for troubleshooting guide
