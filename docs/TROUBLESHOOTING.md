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
