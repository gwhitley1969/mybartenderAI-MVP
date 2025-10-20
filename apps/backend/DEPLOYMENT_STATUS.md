# Backend Deployment Status

**Last Updated:** 2025-10-20 (MANAGED IDENTITY MIGRATION WITH SAS RE-ENABLED ✅)

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
  
- **Blob Storage:** `mbacocktaildb3` (SAS re-enabled for Function App runtime)
  - Containers: `snapshots`, `drink-images`
  - Using User-Assigned Managed Identity: `func-cocktaildb2-uami`
  - Note: SAS had to be re-enabled due to Windows Consumption plan limitations

- **Key Vault:** `kv-mybartenderai-prod` (in rg-mba-dev)
  - Secrets: COCKTAILDB-API-KEY, OpenAI

### ✅ Working Endpoints

**GET /api/v1/snapshots/latest**
- Status: ✅ WORKING
- Returns snapshot metadata with signed URL
- Latest snapshot: 621 drinks, 2491 ingredients, 66KB compressed

**POST /admin/functions/sync-cocktaildb** (Timer Trigger)
- Status: ✅ WORKING
- Successfully syncs with TheCocktailDB V2 API
- Creates JSON snapshots (gzip compressed)
- Schedule: Daily at 3:30 AM UTC

### Environment Variables Configured
```
PG_CONNECTION_STRING=postgresql://pgadmin:[PASSWORD]@pg-mybartenderdb.postgres.database.azure.com:5432/mybartender?sslmode=require
STORAGE_ACCOUNT_NAME=mbacocktaildb3
AZURE_CLIENT_ID=94d9cf74-99a3-49d5-9be4-98ce2eae1d33
SNAPSHOT_CONTAINER_NAME=snapshots
SNAPSHOT_SCHEMA_VERSION=1
SNAPSHOT_SAS_TTL_MINUTES=15  # For User Delegation SAS via Managed Identity
PROMPT_SYSTEM_VERSION=2025-10-08
MONTHLY_TOKEN_LIMIT=200000
COCKTAILDB-API-KEY=961249867 (V2 API - set directly)
OPENAI_API_KEY=@Microsoft.KeyVault(...) 
```

## ✅ Resolved Issues

### 1. Native Module Compatibility
**Problem:** `better-sqlite3` native module incompatible with Azure Functions Windows runtime
**Solution:** 
- Removed `better-sqlite3` dependency completely
- Implemented pure JavaScript JSON snapshot builder
- Replaced zstd compression with built-in gzip compression

### 2. Azure Functions SDK Mismatch
**Problem:** Code using v4 SDK syntax with v3 runtime
**Solution:**
- Converted all functions to v3 CommonJS pattern
- Fixed import paths (removed `.js` extensions)
- Updated module.exports patterns

### 3. Deployment Package Structure
**Problem:** Functions not at root level of deployment package
**Solution:**
- Restructured deployment to place functions at root
- Maintained services/shared/types folder structure

## 📊 Latest Metrics

**Snapshot Details (as of 2025-10-14):**
- Version: 20251014.201106
- Size: 66KB (compressed)
- Contents:
  - 621 drinks
  - 2491 ingredients & measures
  - 40 glass types
  - 11 categories
  - 67 tags

**Performance:**
- Sync execution time: ~16 seconds
- Snapshot generation: <2 seconds
- API response time: <100ms

## 🚀 Deployment Process

**Current deployment method:**
```powershell
# From apps/backend directory
npm run build  # Note: This will fail due to v4 imports, but we use pre-built JS

# Create deployment package
Copy-Item dist/functions/sync-cocktaildb/index.js deploy/sync-cocktaildb/index.js -Force
Copy-Item dist/services/*.js deploy/services/ -Force
Compress-Archive -Path deploy/* -DestinationPath deploy.zip -Force

# Deploy to Azure
az functionapp deployment source config-zip -g rg-mba-prod -n func-mba-fresh --src deploy.zip
```

## 📝 Notes

- JSON snapshots work perfectly for the mobile app use case
- No native dependencies = reliable cross-platform deployment
- PostgreSQL remains the authoritative data store for future AI features
- Front Door configuration pending for US-based image hosting

## 🔧 Maintenance Commands

**Trigger sync manually:**
```powershell
$masterKey = az functionapp keys list -g rg-mba-prod -n func-mba-fresh --query masterKey -o tsv
$headers = @{ "Content-Type" = "application/json"; "x-functions-key" = $masterKey }
Invoke-WebRequest -Uri "https://func-mba-fresh.azurewebsites.net/admin/functions/sync-cocktaildb" -Method POST -Headers $headers -Body "{}"
```

**Check latest snapshot:**
```powershell
Invoke-RestMethod -Uri "https://func-mba-fresh.azurewebsites.net/api/v1/snapshots/latest" | ConvertTo-Json
```

**Run smoke check:**
```powershell
.\smoke-check.ps1 -ResourceGroup rg-mba-prod -FunctionApp func-mba-fresh
```

## Managed Identity Migration Details (2025-10-20)

### What Changed
1. **Removed all SAS-based code**
   - Deleted `snapshotStorageService.js` (used storage account keys)
   - Deleted `imageDownloadService.js` (used connection strings)
   - Removed all `StorageSharedKeyCredential` usage

2. **Implemented MI-based services**
   - `snapshotStorageServiceMI.js` - Uses User Delegation SAS via MI
   - `imageDownloadServiceMI.js` - Uses MI for blob operations
   - All functions updated to use MI services

3. **Storage Configuration**
   - Storage account: `mbacocktaildb3` (SAS re-enabled)
   - User-Assigned MI: `func-cocktaildb2-uami`
   - Required RBAC roles assigned

### Platform Limitations & SAS Re-enablement
- Windows Consumption plans require a connection string for `WEBSITE_CONTENTAZUREFILECONNECTIONSTRING`
- This is where the Function App code is deployed (Azure Files)
- Cannot use MI for this specific setting on Windows Consumption
- **IMPORTANT**: We had to re-enable SAS on the storage account `mbacocktaildb3` for the Function App to work
- The application code still uses Managed Identity for all data operations
- SAS is only used by Azure infrastructure for deployment and runtime file access