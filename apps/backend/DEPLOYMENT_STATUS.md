# Backend Deployment Status

**Last Updated:** 2025-10-14

## ✅ Working Infrastructure

### Azure Resources (South Central US)
- **Function App:** `func-mba-fresh` (Windows Consumption Plan)
  - Base URL: https://func-mba-fresh.azurewebsites.net
  - Runtime: Node.js 20
  - SDK: @azure/functions v3.5.0 (CommonJS)
  
- **PostgreSQL:** `pg-mybartenderdb.postgres.database.azure.com`
  - Database: `mybartender`
  - User: `pgadmin`
  - Schema: All tables created (drinks, ingredients, snapshot_metadata, etc.)
  
- **Blob Storage:** `cocktaildbfun`
  - Container: `snapshots`

- **Key Vault:** `kv-mybartenderai-prod` (in rg-mba-dev)
  - Secrets: COCKTAILDB-API-KEY, OpenAI

### Working Endpoints

**✅ GET /api/v1/snapshots/latest**
- Status: Returns HTTP 503 (expected - no snapshot yet)
- Database connectivity: ✅ Working
- Response format: ✅ Correct JSON

### Environment Variables Configured
```
PG_CONNECTION_STRING=postgresql://pgadmin:[PASSWORD]@pg-mybartenderdb.postgres.database.azure.com:5432/mybartender?sslmode=require
BLOB_STORAGE_CONNECTION_STRING=[CONFIGURED]
SNAPSHOT_CONTAINER_NAME=snapshots
SNAPSHOT_SCHEMA_VERSION=1
SNAPSHOT_SAS_TTL_MINUTES=15
PROMPT_SYSTEM_VERSION=2025-10-08
MONTHLY_TOKEN_LIMIT=200000
COCKTAILDB-API-KEY=961249867 (V2 API - set directly, needs to move to Key Vault)
OPENAI_API_KEY=@Microsoft.KeyVault(...) 
```

## ❌ Known Issues

### sync-cocktaildb Timer Function
**Status:** Triggers but fails to complete

**Last Error (from App Insights):**
```
better_sqlite3.node is not a valid Win32 application
```

**Root Cause:** Native module binary mismatch
- better-sqlite3 package requires platform-specific binaries
- node_modules may have been compiled on Linux/WSL
- Windows Function App needs Windows-compiled binaries

**Solution Attempted:**
- Rebuilt node_modules on Windows: `npm install`
- Need to verify deployment includes correct Windows binaries

**Other Observations:**
- Function loads and triggers successfully (HTTP 202)
- Starts execution (logs show "[sync-cocktaildb] Starting synchronization...")
- Fails when trying to use better-sqlite3
- Times out after 10 minutes without creating snapshot

### recommend Function
**Status:** Not yet tested
- Deployed but not verified
- May have similar issues

## 📋 Next Steps

1. **Immediate:** Debug sync-cocktaildb better-sqlite3 issue
   - Verify Windows binaries are in deployment package
   - Consider alternative: build SQLite on Linux Function App
   - Or: Use a different SQLite library compatible with Windows Functions

2. **Key Vault Integration:**
   - COCKTAILDB-API-KEY currently set directly (works)
   - Need to fix Key Vault reference resolution
   - Verify managed identity has proper RBAC permissions

3. **Test recommend endpoint:**
   - Verify it loads and accepts requests
   - Test with sample inventory data

4. **Once working:**
   - Run full smoke check end-to-end
   - Verify snapshot creation workflow
   - Test mobile app can download snapshots

## 🔧 Deployment Commands

**Deploy current package:**
```powershell
cd apps/backend/deploy-windows-final
Compress-Archive -Path * -DestinationPath ../deploy.zip -Force
az functionapp deployment source config-zip -g rg-mba-prod -n func-mba-fresh --src ../deploy.zip
```

**Run smoke check:**
```powershell
.\smoke-check.ps1 -ResourceGroup rg-mba-prod -FunctionApp func-mba-fresh -TailLogs
```

**Check logs:**
- Azure Portal → func-mba-fresh → Monitoring → Logs (Application Insights)
- Query: `traces | where operation_Name == "sync-cocktaildb" | take 20`

## 📝 Notes

- TheCocktailDB V2 API key verified working (tested manually)
- Database schema matches code expectations  
- Function routing works correctly
- Core infrastructure is solid
- Issue is isolated to native module compatibility

