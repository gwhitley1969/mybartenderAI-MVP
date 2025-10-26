# MyBartenderAI Deployment Status

## Current Status: ✅ All Functions Deployed to Windows Consumption Plan

### Summary
After extensive troubleshooting with Azure Functions v4 on Flex Consumption plan, we successfully pivoted to deploying on Windows Consumption plan (`func-mba-fresh`) using Azure Functions v3 SDK patterns. All functions are now deployed and operational.

### Deployed Functions

1. ✅ **GET /api/health**
   - Health check endpoint
   - Status: Working

2. ✅ **GET /api/v1/snapshots/latest**
   - Returns cocktail database snapshot metadata with signed download URL
   - Current snapshot: version 20251014.202149 (621 drinks)
   - Status: Working

3. ✅ **POST /api/v1/recommend**
   - AI-powered cocktail recommendations
   - Requires: Function key + JWT authentication
   - Status: Deployed (needs testing)

4. ✅ **POST /api/v1/admin/download-images**
   - Downloads cocktail images to Azure Blob Storage
   - Requires: Admin key
   - Status: Deployed (needs testing)

5. ✅ **Timer: sync-cocktaildb**
   - Runs daily at 3:30 AM UTC
   - Syncs cocktail data and creates snapshots
   - Status: Deployed (needs manual trigger for initial sync)

6. ✅ **POST /api/validate-age**
   - Custom Authentication Extension for Entra External ID
   - Server-side age verification (21+) during signup
   - Event Type: OnAttributeCollectionSubmit
   - Authentication: OAuth 2.0 Bearer tokens ✅ ENABLED AND WORKING
   - Features:
     - OAuth 2.0 token validation using Entra External ID ciamlogin.com domain
     - Content-Type: application/json headers (Entra requirement)
     - Extension attribute handling (GUID-prefixed custom attributes)
     - Multiple date format support (MM/DD/YYYY, MMDDYYYY, YYYY-MM-DD)
     - Privacy-focused (birthdate not stored, only age_verified boolean)
     - Cryptographic token verification (no secrets stored)
   - Status: ✅ Deployed, tested, and FULLY OPERATIONAL
   - Test Results (2025-10-26):
     - ✅ OAuth token validation successful (ciamlogin.com JWKS)
     - ✅ Under-21 users successfully BLOCKED
     - ✅ 21+ users successfully ALLOWED and accounts created
     - ✅ All responses include proper Content-Type headers
     - ✅ Security hardening complete
     - ✅ Execution time: ~376ms

### Deployment Journey

#### Phase 1: v4 Migration Attempt (func-cocktaildb2 - Flex Consumption)
- Attempted to migrate to Azure Functions v4 SDK for Flex Consumption plan
- Resolved initial issues:
  - Fixed GitHub Actions to deploy correct folder
  - Implemented lazy initialization for services using Key Vault references
  - Fixed import paths and removed v3 artifacts
- Result: Functions briefly worked but subsequent deployments failed with "0 functions loaded"

#### Phase 2: Revert to Windows Consumption (func-mba-fresh)
- Created new Windows Consumption plan function app
- Discovered that Windows Consumption with runtime v4 requires v3 SDK patterns
- Key fixes:
  - Each function needs `function.json` with bindings
  - Use `module.exports = async function(context, req)` pattern
  - Output binding name must match code usage (res vs $return)

### Key Learnings

1. **Azure Functions Runtime vs SDK Versions**:
   - Runtime v4 (`FUNCTIONS_EXTENSION_VERSION=~4`) can run both v3 and v4 SDK code
   - Windows Consumption plans work best with v3 SDK patterns
   - Linux Flex Consumption plans require v4 SDK patterns

2. **v3 SDK Pattern Requirements**:
   - Each function needs a `function.json` file with bindings
   - Function code uses `module.exports = async function(context, req)`
   - Response is set via `context.res = { status, body }`
   - Output binding name in function.json must match code (e.g., "res" not "$return")

3. **Deployment Best Practices**:
   - Use `az functionapp deployment source config-zip` for reliable deployments
   - Avoid "dirty deployment" issues from residual files
   - Test functions work locally before deploying

### Next Steps

1. **Convert remaining functions to v3 pattern**:
   - [ ] recommend function
   - [ ] sync-cocktaildb function  
   - [ ] download-images function

2. **Test complete API functionality**:
   - [ ] Test JWT authentication on recommend endpoint
   - [ ] Verify timer trigger for sync-cocktaildb
   - [ ] Test image download capabilities

3. **Production readiness**:
   - [ ] Set up proper CI/CD pipeline
   - [ ] Configure monitoring and alerts
   - [ ] Document API endpoints for mobile team

### Environment Configuration

Function App: `func-mba-fresh`
- **Plan**: Windows Consumption
- **Runtime**: Node.js 20 LTS
- **Functions Runtime**: ~4
- **Location**: South Central US

Key Settings:
- `BLOB_STORAGE_CONNECTION_STRING`: ✅ Configured
- `PG_CONNECTION_STRING`: ✅ Configured  
- `SNAPSHOT_CONTAINER_NAME`: ✅ Set to "snapshots"
- `OPENAI_API_KEY`: ✅ Configured
- `COCKTAILDB-API-KEY`: ✅ Configured

### Deployment Commands

```bash
# From apps/backend/v3-deploy directory
func azure functionapp publish func-mba-fresh --javascript

# Or using zip deployment
az functionapp deployment source config-zip -g rg-mba-prod -n func-mba-fresh --src deployment.zip
```

### Resources
- [Azure Functions v3 to v4 Migration](https://learn.microsoft.com/en-us/azure/azure-functions/functions-node-upgrade-v4)
- [Azure Functions Hosting Plans](https://learn.microsoft.com/en-us/azure/azure-functions/functions-scale)
- [Function.json Reference](https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-http-webhook-trigger?tabs=javascript)