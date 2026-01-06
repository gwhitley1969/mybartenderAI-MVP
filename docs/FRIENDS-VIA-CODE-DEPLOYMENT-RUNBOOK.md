# Friends via Code - Deployment Runbook

This runbook guides you through deploying the Friends via Code feature to Azure.

**Estimated Total Time:** 2-3 hours (including waiting for HTTPS certificate)

---

## Prerequisites

### Required Tools
- [x] Azure CLI installed and authenticated (`az login`)
- [x] PowerShell 5.1+ or PowerShell Core 7+
- [x] Azure Functions Core Tools (`func` CLI)
- [x] PostgreSQL client (`psql`) for database migration
- [x] Access to Azure subscription with appropriate permissions

### Required Permissions
- [x] Contributor access to `rg-mba-prod` resource group
- [x] Database admin access to `pg-mybartenderdb`
- [x] Function App deployment permissions for `func-mba-fresh`
- [x] APIM management permissions for `apim-mba-001`

### DNS Access
- [x] Ability to add CNAME record for `share.mybartenderai.com`

---

## Phase 1: Database Setup (15 minutes)

### Step 1.1: Review Migration File

**File:** `backend/functions/migrations/005_friends_via_code.sql`

**Review:**
```powershell
code "C:\backup dev02\mybartenderAI-MVP\backend\functions\migrations\005_friends_via_code.sql"
```

**What it creates:**
- ✅ `user_profile` - User profiles with system-generated aliases
- ✅ `custom_recipes` - User-created recipes from Create Studio
- ✅ `recipe_share` - Internal recipe shares between users
- ✅ `share_invite` - External sharing via invite links
- ✅ `friendships` - Friend relationships (optional, for future use)
- ✅ Helper functions and triggers

### Step 1.2: Backup Database

**IMPORTANT:** Always backup before migrations!

```powershell
# Set your database connection details
$DB_HOST = "pg-mybartenderdb.postgres.database.azure.com"
$DB_NAME = "mybartenderdb"
$DB_USER = "your-admin-username"

# Create backup
$backupFile = "mybartenderdb_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').sql"

pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME -F c -b -v -f $backupFile

Write-Host "✓ Backup created: $backupFile" -ForegroundColor Green
```

### Step 1.3: Run Migration

```powershell
# Run migration
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f "C:\backup dev02\mybartenderAI-MVP\backend\functions\migrations\005_friends_via_code.sql"

# Verify tables were created
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "\dt user_profile custom_recipes recipe_share share_invite friendships"
```

**Expected Output:**
```
                List of relations
 Schema |      Name      | Type  |  Owner
--------+----------------+-------+---------
 public | custom_recipes | table | ...
 public | friendships    | table | ...
 public | recipe_share   | table | ...
 public | share_invite   | table | ...
 public | user_profile   | table | ...
```

**Verification:**
```powershell
# Check that migration verification passed
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('user_profile', 'custom_recipes', 'recipe_share', 'share_invite', 'friendships');"
```

Expected: `table_count = 5`

**✅ Checkpoint:** Database tables created successfully

---

## Phase 2: Backend Deployment (20 minutes)

### Step 2.1: Install Dependencies

```powershell
cd "C:\backup dev02\mybartenderAI-MVP\backend\functions"

# Install/update dependencies
npm install
```

**New dependencies used:**
- `pg` - PostgreSQL client (should already be installed)
- `jsonwebtoken` - JWT validation (should already be installed)
- `jwks-rsa` - JWKS client (should already be installed)

### Step 2.2: Verify Environment Variables

Check that Function App has required settings:

```powershell
# Check if POSTGRES_CONNECTION_STRING is set
az functionapp config appsettings list `
  --name func-mba-fresh `
  --resource-group rg-mba-prod `
  --query "[?name=='POSTGRES_CONNECTION_STRING'].{Name:name,Value:value}" `
  --output table
```

**Required settings:**
- ✅ `POSTGRES_CONNECTION_STRING` - Database connection
- ✅ `AZURE_SUBSCRIPTION_ID` - For APIM operations
- ✅ `APPLICATIONINSIGHTS_CONNECTION_STRING` - For monitoring

### Step 2.3: Test Functions Locally (Optional)

**IMPORTANT:** First configure local settings:

```powershell
cd "C:\backup dev02\mybartenderAI-MVP\backend\functions"

# Get connection string from Azure
$POSTGRES_CONN = az functionapp config appsettings list `
  --name func-mba-fresh `
  --resource-group rg-mba-prod `
  --query "[?name=='POSTGRES_CONNECTION_STRING'].value" `
  --output tsv

# Update local.settings.json with your connection string
$settings = Get-Content local.settings.json | ConvertFrom-Json
$settings.Values.POSTGRES_CONNECTION_STRING = $POSTGRES_CONN
$settings.Values.AZURE_SUBSCRIPTION_ID = $env:AZURE_SUBSCRIPTION_ID
$settings | ConvertTo-Json -Depth 10 | Out-File local.settings.json

# Start local function host
func start
```

**Note:** If you get "Unable to find project root" error, ensure `host.json` and `local.settings.json` exist in the functions directory.

**Test endpoints:**
```powershell
# Open new PowerShell window for testing
# Get a JWT token from your auth flow first
$JWT_TOKEN = "your-test-jwt-token"

# Test user profile endpoint (should auto-create profile)
curl -X GET http://localhost:7071/api/v1/users/me `
  -H "Authorization: Bearer $JWT_TOKEN"
```

Press `Ctrl+C` to stop local testing.

### Step 2.4: Deploy to Azure

```powershell
cd "C:\backup dev02\mybartenderAI-MVP\backend\functions"

# Deploy all functions
func azure functionapp publish func-mba-fresh

# Wait for deployment to complete (2-5 minutes)
```

**Expected Output:**
```
Functions in func-mba-fresh:
    social-inbox - [httpTrigger]
        Invoke url: https://func-mba-fresh.azurewebsites.net/api/v1/social/inbox

    social-invite - [httpTrigger]
        Invoke url: https://func-mba-fresh.azurewebsites.net/api/v1/social/invite/{token?}

    social-outbox - [httpTrigger]
        Invoke url: https://func-mba-fresh.azurewebsites.net/api/v1/social/outbox

    social-share-internal - [httpTrigger]
        Invoke url: https://func-mba-fresh.azurewebsites.net/api/v1/social/share-internal

    users-me - [httpTrigger]
        Invoke url: https://func-mba-fresh.azurewebsites.net/api/v1/users/me
```

### Step 2.5: Verify Deployment

```powershell
# List all functions
az functionapp function list `
  --name func-mba-fresh `
  --resource-group rg-mba-prod `
  --query "[?contains(name, 'social') || contains(name, 'users-me')].name" `
  --output table
```

**Expected functions:**
- `social-inbox`
- `social-invite`
- `social-outbox`
- `social-share-internal`
- `users-me`

**✅ Checkpoint:** Backend functions deployed successfully

---

## Phase 3: APIM Configuration (10 minutes)

### Step 3.1: Review Policy Configuration

**File:** `infrastructure/apim/policies/social-endpoints-policy.xml`

**Review:**
```powershell
code "C:\backup dev02\mybartenderAI-MVP\infrastructure\apim\policies\social-endpoints-policy.xml"
```

**Key features:**
- JWT validation with Entra External ID
- Rate limiting: 5/minute, 100/day per user
- CORS configuration for share.mybartenderai.com
- Security headers

### Step 3.2: Apply APIM Policies

```powershell
cd "C:\backup dev02\mybartenderAI-MVP\infrastructure\apim\scripts"

# Run policy deployment script
.\apply-social-policies.ps1
```

**What this does:**
1. Creates 7 new operations in APIM
2. Applies JWT validation policy to each
3. Configures rate limiting
4. Sets up CORS

**Expected Output:**
```
==================================================
Applying Social Endpoints Policies
==================================================

Step 1: Checking/Creating operations...
✓ Operation users-me-get created successfully
✓ Operation users-me-patch created successfully
✓ Operation social-share-internal created successfully
✓ Operation social-invite-create created successfully
✓ Operation social-invite-claim created successfully
✓ Operation social-inbox created successfully
✓ Operation social-outbox created successfully

Step 2: Applying policies to operations...
✓ Policy applied successfully to users-me-get
✓ Policy applied successfully to users-me-patch
...

==================================================
Policy Deployment Complete!
==================================================
```

### Step 3.3: Verify APIM Configuration

```powershell
# List social operations
az apim api operation list `
  --resource-group rg-mba-prod `
  --service-name apim-mba-001 `
  --api-id mybartenderai-api `
  --query "[?contains(operationId, 'social') || contains(operationId, 'users-me')].[operationId,displayName]" `
  --output table
```

### Step 3.4: Test APIM Endpoint

```powershell
# Get your APIM subscription key
$APIM_KEY = az apim api show `
  --resource-group rg-mba-prod `
  --service-name apim-mba-001 `
  --api-id mybartenderai-api `
  --query subscriptionRequired `
  --output tsv

# Test user profile endpoint through APIM
$JWT_TOKEN = "your-jwt-token"
$SUBSCRIPTION_KEY = "your-subscription-key"

curl -X GET "https://apim-mba-001.azure-api.net/v1/users/me" `
  -H "Authorization: Bearer $JWT_TOKEN" `
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY"
```

**Expected Response (200 OK):**
```json
{
  "userId": "00000000-0000-0000-0000-000000000000",
  "alias": "@happy-penguin-42",
  "displayName": null,
  "createdAt": "2025-11-14T...",
  "lastSeen": "2025-11-14T..."
}
```

**✅ Checkpoint:** APIM configured and operational

---

## Phase 4: Static Website Setup (15 minutes)

### Step 4.1: Configure Static Website Hosting

```powershell
cd "C:\backup dev02\mybartenderAI-MVP\infrastructure\storage"

# Run static website configuration
.\configure-static-website.ps1
```

**What this does:**
1. Enables static website hosting on `mbacocktaildb3`
2. Configures CORS
3. Uploads placeholder index.html and 404.html

**Expected Output:**
```
==================================================
Azure Blob Storage Static Website Configuration
==================================================

Step 1: Enabling static website hosting...
  ✓ Static website hosting enabled

Step 2: Getting static website endpoint...
  Primary Web Endpoint: https://mbacocktaildb3.z21.web.core.windows.net/

Step 3: Configuring CORS...
  ✓ CORS configured

Step 5: Creating placeholder files...
  ✓ index.html uploaded
  ✓ 404.html uploaded

==================================================
Static Website Configuration Complete!
==================================================
```

### Step 4.2: Test Static Website Endpoint

```powershell
# Test the static website endpoint
curl https://mbacocktaildb3.z21.web.core.windows.net/
```

**Expected:** HTML page with "My AI Bartender - Share" and placeholder content

**✅ Checkpoint:** Static website hosting enabled

---

## Phase 5: Azure Front Door Setup (30 minutes + waiting)

### Step 5.1: Configure DNS CNAME (Do First!)

**IMPORTANT:** Configure DNS before running the Front Door script!

**DNS Settings:**
- **Type:** CNAME
- **Name:** `share`
- **Value:** Will be provided by Front Door endpoint (e.g., `mba-share-xxxxx.z01.azurefd.net`)
- **TTL:** 3600 (1 hour)

**Instructions:**
1. Log into your DNS provider for `mybartenderai.com`
2. Add CNAME record: `share` → (wait for Front Door endpoint URL first)
3. Save changes

### Step 5.2: Create Azure Front Door Profile

```powershell
cd "C:\backup dev02\mybartenderAI-MVP\infrastructure\storage"

# Run Front Door configuration
.\configure-frontdoor-https.ps1
```

**What this creates:**
1. Front Door Standard profile: `fd-mba-share`
2. Front Door endpoint: `mba-share.z01.azurefd.net` (URL will vary)
3. Origin group pointing to static website
4. Route with HTTPS enforcement
5. Caching rules

**Follow the prompts:**

```
Getting static website endpoint...
  Static Website Endpoint: mbacocktaildb3.z21.web.core.windows.net

Step 1: Creating Front Door profile...
  ✓ Front Door profile created

Step 2: Creating Front Door endpoint...
  ✓ Front Door endpoint created
  Front Door Endpoint URL: https://mba-share-xxxxx.z01.azurefd.net

...

Step 6: Adding custom domain...

  IMPORTANT: Before proceeding, ensure DNS CNAME is configured:
    Name:   share
    Type:   CNAME
    Value:  mba-share-xxxxx.z01.azurefd.net

Has the CNAME been configured? (y/N)
```

**Action Required:**
1. Copy the Front Door endpoint URL shown
2. Configure DNS CNAME with this URL
3. Wait 5-10 minutes for DNS propagation
4. Type `y` and press Enter to continue

### Step 5.3: Verify DNS Propagation

```powershell
# Check DNS resolution
nslookup share.mybartenderai.com

# Or use online tool: https://dnschecker.org
```

**Expected:** CNAME pointing to Front Door endpoint

### Step 5.4: Wait for HTTPS Certificate

**Time:** 10-30 minutes for certificate provisioning

**Check status:**
```powershell
az afd custom-domain show `
  --custom-domain-name share-mybartenderai-com `
  --profile-name fd-mba-share `
  --resource-group rg-mba-prod `
  --query '{validationState:validationProperties.validationState,provisioningState:provisioningState}' `
  --output table
```

**Expected progression:**
1. `validationState: Pending` → Validating ownership
2. `validationState: Approved` → Certificate provisioning
3. `provisioningState: Succeeded` → ✅ Ready!

### Step 5.5: Test Custom Domain

```powershell
# Test HTTPS endpoint
curl -I https://share.mybartenderai.com

# Should return 200 OK with security headers
```

**✅ Checkpoint:** Azure Front Door configured with custom domain and HTTPS

---

## Phase 6: Verification & Testing (20 minutes)

### Step 6.1: End-to-End API Test

**Test 1: Create User Profile**
```powershell
$JWT_TOKEN = "your-jwt-token"
$APIM_KEY = "your-apim-subscription-key"

# Create/get user profile
$response = curl -X GET "https://apim-mba-001.azure-api.net/v1/users/me" `
  -H "Authorization: Bearer $JWT_TOKEN" `
  -H "Ocp-Apim-Subscription-Key: $APIM_KEY" | ConvertFrom-Json

$myAlias = $response.alias
Write-Host "My alias: $myAlias" -ForegroundColor Cyan
```

**Test 2: Share Recipe (requires 2 test users)**
```powershell
# Share a recipe with another user
curl -X POST "https://apim-mba-001.azure-api.net/v1/social/share-internal" `
  -H "Authorization: Bearer $JWT_TOKEN" `
  -H "Ocp-Apim-Subscription-Key: $APIM_KEY" `
  -H "Content-Type: application/json" `
  -d '{
    "toAlias": "@clever-dolphin-99",
    "recipeType": "standard",
    "recipeId": "11007",
    "message": "Try this amazing Margarita!"
  }'
```

**Test 3: Check Inbox**
```powershell
# View received shares
curl -X GET "https://apim-mba-001.azure-api.net/v1/social/inbox" `
  -H "Authorization: Bearer $JWT_TOKEN" `
  -H "Ocp-Apim-Subscription-Key: $APIM_KEY"
```

**Test 4: Create Invite**
```powershell
# Create shareable invite link
$invite = curl -X POST "https://apim-mba-001.azure-api.net/v1/social/invite" `
  -H "Authorization: Bearer $JWT_TOKEN" `
  -H "Ocp-Apim-Subscription-Key: $APIM_KEY" `
  -H "Content-Type: application/json" `
  -d '{
    "recipeType": "standard",
    "recipeId": "11007",
    "message": "Check out this cocktail!",
    "oneTime": true
  }' | ConvertFrom-Json

Write-Host "Share URL: $($invite.shareUrl)" -ForegroundColor Green
```

### Step 6.2: Test Rate Limiting

```powershell
# Make 6 rapid requests (should fail on 6th)
for ($i = 1; $i -le 6; $i++) {
    Write-Host "Request $i..." -ForegroundColor Cyan

    $response = curl -X GET "https://apim-mba-001.azure-api.net/v1/users/me" `
      -H "Authorization: Bearer $JWT_TOKEN" `
      -H "Ocp-Apim-Subscription-Key: $APIM_KEY" `
      -w "\nHTTP Status: %{http_code}\n"

    Start-Sleep -Seconds 1
}
```

**Expected:** First 5 succeed (200), 6th fails (429 Too Many Requests)

### Step 6.3: Verify Database Records

```powershell
# Check user profiles created
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT user_id, alias, display_name, created_at FROM user_profile ORDER BY created_at DESC LIMIT 10;"

# Check recipe shares
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT id, recipe_type, recipe_id, from_user_id, to_user_id, created_at FROM recipe_share ORDER BY created_at DESC LIMIT 10;"

# Check invite tokens
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT token, recipe_type, recipe_id, status, created_at, expires_at FROM share_invite ORDER BY created_at DESC LIMIT 10;"
```

### Step 6.4: Check Application Insights

**Azure Portal:**
1. Navigate to Application Insights
2. Go to "Logs"
3. Run query:

```kusto
traces
| where timestamp > ago(1h)
| where message contains "social" or message contains "users-me"
| project timestamp, message, severityLevel
| order by timestamp desc
| take 50
```

**Look for:**
- User profile creation logs
- Share creation logs
- JWT validation logs
- Rate limit events

**✅ Checkpoint:** All features working end-to-end

---

## Phase 7: Monitoring Setup (10 minutes)

### Step 7.1: Create Alert Rules

**Alert 1: High Rate Limit Hits**
```powershell
# Create alert for excessive rate limiting
az monitor metrics alert create `
  --name "Social-High-RateLimit" `
  --resource-group rg-mba-prod `
  --scopes "/subscriptions/<sub-id>/resourceGroups/rg-mba-prod/providers/Microsoft.ApiManagement/service/apim-mba-001" `
  --condition "count Microsoft.ApiManagement/service/StatusCode 429 > 100" `
  --window-size 5m `
  --evaluation-frequency 1m `
  --description "High rate limit hits on social endpoints"
```

**Alert 2: High Error Rate**
```powershell
# Create alert for backend errors
az monitor metrics alert create `
  --name "Social-High-ErrorRate" `
  --resource-group rg-mba-prod `
  --scopes "/subscriptions/<sub-id>/resourceGroups/rg-mba-prod/providers/Microsoft.Web/sites/func-mba-fresh" `
  --condition "count Microsoft.Web/sites/Http5xx > 50" `
  --window-size 5m `
  --evaluation-frequency 1m `
  --description "High error rate on social functions"
```

### Step 7.2: Create Dashboard (Optional)

**Azure Portal:**
1. Go to Dashboards → New Dashboard
2. Name: "Friends via Code Monitoring"
3. Add tiles:
   - APIM request count (filter: social operations)
   - Function execution count
   - Database connection pool metrics
   - Front Door data transfer

**✅ Checkpoint:** Monitoring configured

---

## Phase 8: Documentation & Handoff

### Step 8.1: Update README

Document the following in your project README:

- New endpoints available
- Authentication requirements
- Rate limits
- Custom domain for sharing

### Step 8.2: Create Runbook Summary

**File created:** `FRIENDS-VIA-CODE-DEPLOYMENT-RUNBOOK.md` (this file!)

### Step 8.3: Share Knowledge

**Key Information:**
- Share domain: https://share.mybartenderai.com
- APIM endpoints: https://apim-mba-001.azure-api.net/v1/social/*
- Rate limits: 5/min, 100/day per user
- Database tables: 5 new tables created

---

## Rollback Procedures

### If Migration Fails

```powershell
# Restore from backup
pg_restore -h $DB_HOST -U $DB_USER -d $DB_NAME -v $backupFile
```

### If Function Deployment Fails

```powershell
# Redeploy previous version (if available)
func azure functionapp publish func-mba-fresh --slot staging
```

### If APIM Configuration Fails

```powershell
# Remove operations
az apim api operation delete `
  --resource-group rg-mba-prod `
  --service-name apim-mba-001 `
  --api-id mybartenderai-api `
  --operation-id <operation-id>
```

### If Front Door Causes Issues

```powershell
# Delete Front Door profile
az afd profile delete `
  --profile-name fd-mba-share `
  --resource-group rg-mba-prod
```

---

## Post-Deployment Checklist

- [ ] Database migration successful (5 tables created)
- [ ] Backend functions deployed (5 new functions)
- [ ] APIM operations configured (7 operations)
- [ ] JWT validation working
- [ ] Rate limiting functional
- [ ] Static website accessible
- [ ] Front Door endpoint working
- [ ] Custom domain HTTPS working
- [ ] End-to-end API tests passing
- [ ] Database records being created
- [ ] Application Insights logging
- [ ] Monitoring alerts configured
- [ ] Documentation updated

---

## Cost Summary

| Resource | Type | Monthly Cost |
|----------|------|--------------|
| PostgreSQL | Existing | $0 (no change) |
| Function App | Existing | $0 (no change) |
| APIM | Existing | $0 (no change) |
| Blob Storage | Existing | $0 (negligible) |
| **Front Door Standard** | **New** | **~$35** |
| **TOTAL NEW COST** | | **~$35/month** |

Plus data transfer costs (~$0.08/GB)

---

## Support & Troubleshooting

### Common Issues

**Issue:** JWT validation fails
**Solution:** Verify audience and issuer in APIM policy match backend

**Issue:** Rate limit too restrictive
**Solution:** Adjust policy XML and reapply with script

**Issue:** Custom domain not resolving
**Solution:** Check DNS propagation, verify CNAME

**Issue:** Functions can't connect to database
**Solution:** Check `POSTGRES_CONNECTION_STRING` in Function App settings

### Getting Help

- Check Application Insights logs
- Review APIM trace logs (Ocp-Apim-Trace header)
- Check Function App logs in Azure Portal
- Review this runbook: `FRIENDS-VIA-CODE-DEPLOYMENT-RUNBOOK.md`

---

**Deployment runbook complete!**
Version: 1.0
Last Updated: 2025-11-14
Author: Claude + Development Team
