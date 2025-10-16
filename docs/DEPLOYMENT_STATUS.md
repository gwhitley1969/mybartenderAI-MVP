# MyBartenderAI Deployment Status

## Current Status: Azure Functions v4 Migration In Progress

### Summary
We are migrating the backend from Azure Functions v3 to v4 SDK to support deployment on Flex Consumption plan (func-cocktaildb2). The functions are not currently loading despite having a clean v4 structure.

### Completed Work

#### ✅ Infrastructure Setup
- **Function App**: `func-cocktaildb2` on Flex Consumption plan (Linux)
- **PostgreSQL**: Azure Database for PostgreSQL configured and accessible
- **Blob Storage**: `mbadrinkimages` storage account configured
- **Application Insights**: Configured and receiving logs
- **Managed Identity**: User-assigned identity with Storage Blob Data Contributor role
- **Environment Variables**:
  - `PG_CONNECTION_STRING`: ✅ Set
  - `BLOB_STORAGE_CONNECTION_STRING`: ✅ Set (pointing to mbadrinkimages)
  - `COCKTAILDB-API-KEY`: ✅ Set in app settings

#### ✅ Code Migration to v4
- Removed all `function.json` files (v3 artifact)
- Removed all function exports (`exports.functionName`)
- Updated all functions to use v4 registration patterns:
  - `app.http()` for HTTP triggers
  - `app.timer()` for timer triggers
- Created `index.js` entry point that imports all functions
- Added `"main": "index.js"` to package.json
- Fixed import paths from `../../../` to `../`

### Current Issue

Despite having a clean v4 structure, Azure Functions host reports:
- "0 functions loaded"
- "0 functions found (Custom)"
- "No job functions found"

### Functions Overview

1. **snapshots-latest** (GET /api/v1/snapshots/latest)
   - Returns latest cocktail database snapshot metadata
   - Status: Not loading

2. **sync-cocktaildb** (Timer: 0 30 3 * * *)
   - Syncs cocktail data from TheCocktailDB API
   - Builds JSON snapshot and uploads to blob storage
   - Status: Not loading

3. **recommend** (POST /api/v1/recommend)
   - AI-powered cocktail recommendations
   - Status: Not loading

4. **download-images** (POST /api/admin/download-images)
   - Downloads cocktail images to Azure Blob Storage
   - Status: Not loading

### Directory Structure
```
v4-deploy/
├── index.js                    # Main entry point
├── package.json               # With "main": "index.js"
├── host.json                  # v2.0 configuration
├── download-images/
│   └── index.js              # HTTP trigger, authLevel: 'admin'
├── recommend/
│   └── index.js              # HTTP trigger, authLevel: 'function'
├── snapshots-latest/
│   └── index.js              # HTTP trigger, authLevel: 'anonymous'
├── sync-cocktaildb/
│   └── index.js              # Timer trigger
├── services/                  # Business logic
├── shared/                    # Shared utilities
└── node_modules/             # Dependencies
```

### Next Steps

1. **External Review**: Need Azure Functions v4 expert to review why functions aren't being discovered
2. **Alternative Approaches**:
   - Try explicit function exports in index.js
   - Consider using Azure Functions Core Tools v4 locally to debug
   - Check if Flex Consumption has specific requirements

### Deployment Commands

```bash
# Deploy from v4-deploy folder
cd apps/backend/v4-deploy
func azure functionapp publish func-cocktaildb2 --javascript --nozip

# Check deployment status
func azure functionapp list-functions func-cocktaildb2

# View logs
az webapp log tail --name func-cocktaildb2 --resource-group rg-mba-prod
```

### Resources
- [Azure Functions v4 Programming Model](https://learn.microsoft.com/en-us/azure/azure-functions/functions-node-upgrade-v4)
- [Flex Consumption Plan](https://learn.microsoft.com/en-us/azure/azure-functions/flex-consumption-plan)

### Contact for Help
If reviewing this code, key areas to check:
1. Why are functions not being discovered by the host?
2. Is the index.js entry point approach correct for v4?
3. Are there Flex Consumption-specific requirements we're missing?
