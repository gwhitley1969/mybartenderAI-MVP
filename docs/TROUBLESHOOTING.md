# Azure Functions - Troubleshooting Guide

**Last Updated:** 2025-10-23

## Current Status ✅

### Working System
- **Function App**: `func-mba-fresh` (Windows Consumption Plan)
- **Backend**: v3-deploy with CommonJS modules
- **Endpoints**: All operational including snapshots-latest
- **Database**: PostgreSQL connection working
- **Storage**: Blob storage with connection strings
- **Dependencies**: Fully installed node_modules

## Recent Issues Resolved (2025-10-23)

### Issue 1: PostgreSQL Connection Failures ✅ FIXED

**Symptoms:**
- snapshots-latest endpoint returning 500 Internal Server Error
- Application Insights showing `getaddrinfo ENOTFOUND base` errors
- Database queries failing to connect

**Root Cause:**
Key Vault stored PostgreSQL connection string in **wrong format**:
```
❌ WRONG: Host=pg-mybartenderdb.postgres.database.azure.com; Database=mybartender; Username=pgadmin; Password=Advocate2!; Ssl Mode=Require;
```

The `pg` library couldn't parse this named-parameter format and was trying to connect to a host called "base".

**Solution:**
1. Updated Key Vault secret to proper PostgreSQL URI format:
   ```
   ✅ CORRECT: postgresql://pgadmin:Advocate2!@pg-mybartenderdb.postgres.database.azure.com/mybartender?sslmode=require
   ```

2. Set `PG_CONNECTION_STRING` directly in Function App settings (bypassing Key Vault reference caching):
   ```bash
   az functionapp config appsettings set \
     --name func-mba-fresh \
     --resource-group rg-mba-prod \
     --settings PG_CONNECTION_STRING="postgresql://user:pass@host/db?sslmode=require"
   ```

**Verification:**
```powershell
# Test endpoint
Invoke-RestMethod -Uri 'https://func-mba-fresh.azurewebsites.net/api/v1/snapshots/latest'
# Should return snapshot metadata with signedUrl
```

---

### Issue 2: Missing Node.js Dependencies ✅ FIXED

**Symptoms:**
- Function worker unable to load functions
- Error: `Cannot find module './lib/textParsers'`
- Missing pg-types/lib directory in node_modules

**Root Cause:**
Incomplete `npm install` resulted in missing subdirectories within the `pg-types` package.

**Solution:**
```bash
cd "C:\backup dev02\mybartenderAI-MVP\apps\backend\v3-deploy"
rm -rf node_modules package-lock.json
npm install --omit=dev
```

**Verification:**
```bash
ls node_modules/pg-types/lib/
# Should show: arrayParser.js, binaryParsers.js, builtins.js, textParsers.js
```

---

### Issue 3: Duplicate Timer Triggers ✅ FIXED

**Symptoms:**
- Two snapshots created at same timestamp (e.g., 20251023.033020 and 20251023.033029)
- Both sync-cocktaildb and sync-cocktaildb-mi running simultaneously

**Root Cause:**
Both timer triggers configured with same schedule: `0 30 3 * * *` (03:30 UTC daily)

**Solution:**
Disabled `sync-cocktaildb-mi` by setting impossible schedule in `function.json`:
```json
{
  "bindings": [{
    "name": "myTimer",
    "type": "timerTrigger",
    "direction": "in",
    "schedule": "0 0 0 31 2 *"  // February 31st (never runs)
  }]
}
```

**Verification:**
```powershell
# Check database for duplicate snapshots
psql -h pg-mybartenderdb.postgres.database.azure.com -U pgadmin -d mybartender \
  -c "SELECT snapshot_version, created_at FROM snapshot_metadata ORDER BY created_at DESC LIMIT 5;"
```

---

### Issue 4: Managed Identity vs Connection Strings

**Current Configuration:**
Due to **Windows Consumption Plan limitations**, we're using:
- ✅ **Direct connection strings** for reliable access
- ✅ **Key Vault references** for API keys only
- ❌ **NOT using Managed Identity** for storage/database (doesn't work reliably on Windows Consumption)

**Working Environment Variables:**
```bash
# Direct connection strings (not Key Vault references)
PG_CONNECTION_STRING=postgresql://user:pass@host/db?sslmode=require
BLOB_STORAGE_CONNECTION_STRING=DefaultEndpointsProtocol=https;AccountName=...;AccountKey=...

# Key Vault references (for API keys)
COCKTAILDB-API-KEY=@Microsoft.KeyVault(VaultName=kv-mybartenderai-prod;SecretName=COCKTAILDB-API-KEY)
OPENAI_API_KEY=@Microsoft.KeyVault(VaultName=kv-mybartenderai-prod;SecretName=OpenAI)

# Container settings
SNAPSHOT_CONTAINER_NAME=snapshots
SNAPSHOT_SCHEMA_VERSION=1
SNAPSHOT_SAS_TTL_MINUTES=15
```

---

### Issue 5: Age Verification - Extension Attribute with GUID Prefix ✅ FIXED

**Symptoms:**
- Custom Authentication Extension not receiving birthdate
- Entra External ID signup shows "Something went wrong" error
- Function logs show birthdate not found in request

**Root Cause:**
Custom directory extension attributes in Entra External ID automatically receive a GUID prefix. The function was looking for `birthdate` but Entra was sending `extension_df9fd4be0b514fb38b2b3bedc47318a1_DateofBirth`.

**Solution:**
Updated `validate-age` function to search for any attribute key containing "dateofbirth" or "birthdate" (case-insensitive):

```javascript
// Search for extension attribute with GUID prefix
const birthdateKey = Object.keys(attributes).find(key =>
    key.toLowerCase().includes('dateofbirth') || key.toLowerCase().includes('birthdate')
);
if (birthdateKey) {
    birthdate = attributes[birthdateKey]?.value || attributes[birthdateKey];
    context.log(`Found birthdate in extension attribute: ${birthdateKey}`);
}
```

**Verification:**
```powershell
# Check function invocation logs in Azure Portal
# Functions → func-mba-fresh → validate-age → Invocations → Click recent execution
# Look for: "Found birthdate in extension attribute: extension_..."
```

---

### Issue 6: Age Verification - Date Format Incompatibility ✅ FIXED

**Symptoms:**
- Age verification fails even with valid birthdate
- Function logs show "Invalid birthdate format" error
- US users need MM/DD/YYYY format

**Root Cause:**
Initial function implementation expected YYYY-MM-DD (ISO format), but US signup form uses MM/DD/YYYY format. Additionally, form may strip slashes and send MMDDYYYY format.

**Solution:**
Added support for three date formats in `validate-age` function:
- `MM/DD/YYYY` (US format with slashes)
- `MMDDYYYY` (US format without separators - 8 digits)
- `YYYY-MM-DD` (ISO format)

```javascript
const usDateRegex = /^(\d{2})\/(\d{2})\/(\d{4})$/;
const usDateNoSepRegex = /^(\d{2})(\d{2})(\d{4})$/;
const isoDateRegex = /^\d{4}-\d{2}-\d{2}$/;

if (usDateRegex.test(birthdate) || usDateNoSepRegex.test(birthdate)) {
    // Parse MM/DD/YYYY or MMDDYYYY
    const match = birthdate.match(usDateRegex || usDateNoSepRegex);
    const month = parseInt(match[1], 10);
    const day = parseInt(match[2], 10);
    const year = parseInt(match[3], 10);
    birthDate = new Date(year, month - 1, day);
}
```

**Verification:**
Test with different date formats:
```powershell
# Test script available at: test-direct-call.ps1
.\test-direct-call.ps1
```

---

### Issue 7: Age Verification - Wrong Event Type ✅ FIXED

**Symptoms:**
- Custom Authentication Extension not receiving birthdate data
- Extension fires but birthdate is null/undefined
- User never sees form asking for Date of Birth

**Root Cause:**
Custom Authentication Extension was configured with `AttributeCollectionStart` event type, which fires BEFORE the user fills out the form. Birthdate not available yet.

**Solution:**
1. Delete old Custom Authentication Extension
2. Create new extension with `OnAttributeCollectionSubmit` event type
3. This event fires AFTER user submits the form with birthdate filled in

**Configuration:**
```
Event Type: OnAttributeCollectionSubmit (NOT AttributeCollectionStart)
Target URL: https://func-mba-fresh.azurewebsites.net/api/validate-age
Authentication: Create new app registration (OAuth 2.0)
Claims: birthdate
```

---

### Issue 8: Age Verification - "Something went wrong" Error ✅ RESOLVED

**Symptoms:**
- Function returns HTTP 200 success
- Function invocations show SUCCESS status
- But Entra External ID shows "Something went wrong" to users
- Accounts NOT being created in tenant

**Root Cause:** Missing `Content-Type: application/json` headers in function responses

**Resolution:** Added proper Content-Type headers to ALL responses (2025-10-26)

**Fix Applied:**
```javascript
context.res = {
    status: 200,
    headers: {
        'Content-Type': 'application/json'  // ← This was missing!
    },
    body: { /* Microsoft Graph API response */ }
};
```

**Test Results (2025-10-26):**
1. ✅ Under-21 users successfully BLOCKED with correct message
2. ✅ 21+ users successfully ALLOWED and accounts created
3. ✅ All responses include proper Content-Type headers
4. ✅ No more "Something went wrong" errors
5. ✅ Accounts appear in Entra External ID tenant

**Additional Fixes:**
- Added configurable OAuth token validation
- Implemented comprehensive error handling
- Created testing scripts and documentation

**Files Modified:**
- `apps/backend/v3-deploy/validate-age/index.js` - Added headers to all 5 response types
- `apps/backend/v3-deploy/validate-age/oauthValidator.js` - OAuth validation module
- `docs/AGE_VERIFICATION_TESTING_GUIDE.md` - Complete testing guide
- `READY_TO_TEST.md` - Personalized setup guide

---

### Issue 9: OAuth Token Validation - Wrong JWKS Domain ✅ RESOLVED

**Symptoms:**
- OAuth token validation failing: "Token validation failed - unable to validate signature"
- Application Insights showing "Expected 200 OK from the JSON Web Key Set HTTP response"
- Age verification working when OAuth disabled, failing when enabled

**Root Cause:** Using wrong JWKS endpoint domain

Entra External ID (CIAM) uses `ciamlogin.com` domain, NOT `login.microsoftonline.com`.

The OAuth validator was trying to fetch JWKS from:
```
❌ WRONG: https://login.microsoftonline.com/{tenantId}/discovery/v2.0/keys
```

But Entra External ID tokens are signed with keys from:
```
✅ CORRECT: https://{tenantId}.ciamlogin.com/{tenantId}/discovery/v2.0/keys
```

**Token Details Discovered:**
- Issuer: `https://a82813af-1054-4e2d-a8ec-c6b9c2908c91.ciamlogin.com/a82813af-1054-4e2d-a8ec-c6b9c2908c91/v2.0`
- Audience: `9d8909e8-a7e3-496e-83b3-62995d06e20b`
- Tenant ID: `a82813af-1054-4e2d-a8ec-c6b9c2908c91`

**Solution:**
Updated `oauthValidator.js` to try ciamlogin.com JWKS URL first:

```javascript
const possibleJwksUrls = [
    // Entra External ID (CIAM) - try this FIRST
    `https://${tenantId}.ciamlogin.com/${tenantId}/discovery/v2.0/keys`,
    // Regular Azure AD endpoints (fallback)
    `https://login.microsoftonline.com/${tenantId}/discovery/v2.0/keys`,
    `https://login.microsoftonline.com/${tenantId}/discovery/keys`,
    `https://login.microsoftonline.com/common/discovery/v2.0/keys`,
];
```

**Verification:**
```powershell
# Check Application Insights logs after signup test
# Should see:
# [OAuth] Trying JWKS URL: https://a82813af-1054-4e2d-a8ec-c6b9c2908c91.ciamlogin.com/.../keys
# [OAuth] ✅ Token signature validated successfully
# [OAuth] Token validated - proceeding with age verification
```

**Test Results (2025-10-26):**
1. ✅ OAuth token signature validated successfully
2. ✅ Token claims verified (issuer, audience, tenant ID)
3. ✅ Age verification proceeded normally after OAuth validation
4. ✅ 44-year-old user allowed with age_verified claim
5. ✅ Total execution: 376ms

**Files Modified:**
- `apps/backend/v3-deploy/validate-age/oauthValidator.js` - Updated JWKS URL priority

**Key Learning:**
Entra External ID (formerly Azure AD B2C CIAM) uses different endpoints than regular Azure AD:
- **Domain**: `ciamlogin.com` (not `login.microsoftonline.com`)
- **JWKS**: Must use tenant-specific ciamlogin.com endpoint
- **Issuer format**: `https://{tenantId}.ciamlogin.com/{tenantId}/v2.0`

---

## Deployment Best Practices

### Working Deployment Process

1. **Ensure dependencies are installed:**
   ```bash
   cd apps/backend/v3-deploy
   npm install --omit=dev
   ```

2. **Verify critical files exist:**
   ```bash
   ls node_modules/pg-types/lib/textParsers.js
   ls services/snapshotStorageService.js
   ls services/snapshotMetadataService.js
   ```

3. **Deploy to Azure:**
   ```bash
   func azure functionapp publish func-mba-fresh --javascript
   ```

4. **Test endpoints:**
   ```powershell
   # Test snapshots endpoint
   Invoke-RestMethod -Uri 'https://func-mba-fresh.azurewebsites.net/api/v1/snapshots/latest'

   # Should return JSON with:
   # - schemaVersion
   # - snapshotVersion
   # - signedUrl (SAS token)
   # - sha256
   # - counts (drinks, ingredients, etc.)
   ```

---

## Common Diagnostic Commands

### Check Function App Logs
```bash
# Stream live logs
az functionapp log tail --name func-mba-fresh --resource-group rg-mba-prod

# Query Application Insights
az monitor app-insights query \
  --app func-mba-fresh \
  --resource-group rg-mba-prod \
  --analytics-query "exceptions | where timestamp > ago(1h) | order by timestamp desc | take 10"
```

### Check Database Connection
```powershell
# Query snapshot metadata
$env:PGPASSWORD = "Advocate2!"
psql -h pg-mybartenderdb.postgres.database.azure.com \
  -U pgadmin \
  -d mybartender \
  -c "SELECT * FROM snapshot_metadata ORDER BY created_at DESC LIMIT 5;"
```

### Check Blob Storage
```bash
# List recent snapshots
az storage blob list \
  --account-name mbacocktaildb3 \
  --container-name snapshots \
  --prefix "snapshots/sqlite/1/" \
  --auth-mode login
```

### Manually Trigger Sync
```powershell
$masterKey = az functionapp keys list -g rg-mba-prod -n func-mba-fresh --query masterKey -o tsv
$headers = @{
    'x-functions-key' = $masterKey
    'Content-Type' = 'application/json'
}
Invoke-WebRequest `
  -Uri 'https://func-mba-fresh.azurewebsites.net/admin/functions/sync-cocktaildb' `
  -Method POST `
  -Headers $headers `
  -Body '{}'
```

---

## When Things Go Wrong

### Function Returns 500 Error

1. **Check Application Insights for exceptions:**
   ```bash
   az monitor app-insights query \
     --app func-mba-fresh \
     --resource-group rg-mba-prod \
     --analytics-query "exceptions | where timestamp > ago(30m) | project timestamp, innermostMessage"
   ```

2. **Common causes:**
   - Missing environment variables
   - Incorrect connection string format
   - Missing node_modules dependencies
   - Database connection failures

### "Cannot find module" Errors

1. **Check if dependencies are installed:**
   ```bash
   ls apps/backend/v3-deploy/node_modules/pg-types/lib/
   ```

2. **Reinstall if needed:**
   ```bash
   cd apps/backend/v3-deploy
   rm -rf node_modules package-lock.json
   npm install --omit=dev
   ```

3. **Redeploy:**
   ```bash
   func azure functionapp publish func-mba-fresh --javascript
   ```

### Key Vault Reference Not Resolving

**Symptom:** Environment variables show `@Microsoft.KeyVault(...)` instead of actual value

**Solution:** Set value directly instead of Key Vault reference:
```bash
# Get value from Key Vault
az keyvault secret show --vault-name kv-mybartenderai-prod --name SECRET-NAME --query value -o tsv

# Set directly in Function App
az functionapp config appsettings set \
  --name func-mba-fresh \
  --resource-group rg-mba-prod \
  --settings VARIABLE_NAME="actual_value"
```

---

## Performance Monitoring

### Key Metrics

- **Snapshot endpoint response time:** < 500ms
- **Sync function duration:** ~16 seconds
- **Database query latency:** < 100ms
- **Blob SAS generation:** < 50ms

### Monitor with Application Insights

```bash
# Check response times
az monitor app-insights query \
  --app func-mba-fresh \
  --resource-group rg-mba-prod \
  --analytics-query "requests | where name contains 'snapshots-latest' | summarize avg(duration), max(duration) by bin(timestamp, 1h)"
```

---

## Historical Context

### Previous Architecture Attempts

1. **Flex Consumption (Linux)** - Failed due to module resolution issues
2. **Managed Identity** - Failed on Windows Consumption Plan (limited support)
3. **JSON Snapshots** - Successfully replaced SQLite to avoid native modules
4. **Connection Strings** - Current working solution for Windows Consumption

### Why Windows Consumption?

- **Lowest cost:** Pay-per-execution model
- **Simplest deployment:** No container images needed
- **Fastest cold starts:** < 1 second
- **Trade-off:** Limited Managed Identity support, uses SAS tokens instead

---

## Getting Help

### Azure Support Resources

- **Documentation:** https://docs.microsoft.com/azure/azure-functions/
- **GitHub Issues:** https://github.com/Azure/azure-functions-nodejs-worker/issues
- **Stack Overflow:** Tag `azure-functions` + `node.js`

### Internal Documentation

- `apps/backend/DEPLOYMENT_STATUS.md` - Current deployment state
- `docs/ARCHITECTURE.md` - System architecture
- `docs/PLAN.md` - Feature acceptance criteria

---

**Remember:** When in doubt, check Application Insights logs first. Most issues show clear error messages there.
