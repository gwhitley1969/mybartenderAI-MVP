# Azure Functions Deployment Issue - Troubleshooting Log

**Date:** November 20, 2025
**Function App:** func-mba-fresh
**Resource Group:** rg-mba-prod
**Region:** South Central US
**Hosting Plan:** ElasticPremium (plan-mba-premium)

## Issue Summary

All Azure Functions in `func-mba-fresh` are returning 500 Internal Server Error with the following exception:

```
Worker was unable to load entry point "index.js": File does not exist
```

This affects ALL 27 functions in the function app, including simple functions like `health` that have no external dependencies.

## Original Problem

The issue started when testing the `ask-bartender-simple` function, which was returning 500 errors. Initial investigation through Application Insights revealed:

```
Cannot find module 'openai'
```

This was because the function code uses `require('openai')` to create an OpenAI client configured for Azure OpenAI endpoints (lines 58-63 in ask-bartender-simple/index.js):

```javascript
const openai = new OpenAI({
    apiKey: apiKey,
    baseURL: `${azureEndpoint}/openai/deployments/${deployment}`,
    defaultQuery: { 'api-version': '2024-10-21' },
    defaultHeaders: { 'api-key': apiKey }
});
```

**Note:** This is a valid pattern - the OpenAI npm package can be configured to work with Azure OpenAI by setting custom baseURL and headers.

## Actions Taken

### 1. Added Missing NPM Package
- Added `"openai": "^4.77.3"` to backend/functions/package.json
- Ran `npm install` locally to install the package
- Verified openai package exists in local node_modules

### 2. Multiple Deployment Attempts
Deployed the function app using various approaches:
- `func azure functionapp publish func-mba-fresh` (standard deployment)
- `func azure functionapp publish func-mba-fresh --no-build` (skip remote build)
- Stopped app, restarted, deployed fresh
- Multiple restarts with extended wait times (60-90 seconds)

### 3. Configuration Changes Attempted

#### Remote Build Configuration (First Attempt)
- Removed `WEBSITE_RUN_FROM_PACKAGE` setting
- Added `SCM_DO_BUILD_DURING_DEPLOYMENT=true`
- Reasoning: Enable remote build to run `npm install` on Azure
- Result: Functions still failed with "File does not exist" error

#### Restored Recommended Configuration (Second Attempt)
- Restored `WEBSITE_RUN_FROM_PACKAGE=1` (recommended for Windows Premium plan)
- Removed `SCM_DO_BUILD_DURING_DEPLOYMENT`
- Reasoning: According to Microsoft Learn docs, Windows Premium should use `WEBSITE_RUN_FROM_PACKAGE=1`
- Result: Functions still failed with "File does not exist" error

### 4. Verification Steps

#### Confirmed Files Are Deployed
Used Azure REST API to verify deployment:
```bash
az rest --method get --uri "https://func-mba-fresh.scm.azurewebsites.net/api/vfs/site/wwwroot/"
```
Results:
- ✅ All function folders exist (health, ask-bartender-simple, etc.)
- ✅ Each function folder contains function.json
- ✅ Each function folder contains index.js
- ✅ node_modules folder exists at root
- ✅ openai package exists in node_modules

#### Confirmed Deployment Packages Exist
```bash
az rest --method get --uri "https://func-mba-fresh.scm.azurewebsites.net/api/vfs/data/SitePackages/"
```
Results:
- ✅ Multiple deployment packages exist (25MB each)
- ✅ packagename.txt points to latest package: `20251120123942.zip`
- ✅ Package was created after most recent deployment

#### Confirmed Configuration Settings
- `WEBSITE_RUN_FROM_PACKAGE=1` ✅
- `FUNCTIONS_EXTENSION_VERSION=~4` ✅
- `FUNCTIONS_WORKER_RUNTIME=node` ✅
- `WEBSITE_NODE_DEFAULT_VERSION=~22` ✅
- `FUNCTIONS_WORKER_RUNTIME_VERSION=~22` ✅

## What Works

1. **Deployment Process:** Deployments complete successfully without errors
2. **File Upload:** Files are successfully uploaded to Azure (verified via REST API)
3. **Package Creation:** Deployment packages are created correctly in SitePackages
4. **Function App State:** App shows as "Running" with availability state "Normal"
5. **APIM Configuration:** API Management operations and policies are correctly configured
6. **Backend Authentication:** APIM is configured to pass function keys to backend

## What Doesn't Work

1. **Function Execution:** ALL functions return 500 errors
2. **Runtime File Access:** Azure Functions runtime cannot find index.js files
3. **Worker Initialization:** Node.js worker fails to load any function entry points
4. **Health Endpoint:** Even the simple health check endpoint fails with same error

## Current Configuration

```json
{
  "WEBSITE_RUN_FROM_PACKAGE": "1",
  "FUNCTIONS_EXTENSION_VERSION": "~4",
  "FUNCTIONS_WORKER_RUNTIME": "node",
  "WEBSITE_NODE_DEFAULT_VERSION": "~22",
  "FUNCTIONS_WORKER_RUNTIME_VERSION": "~22",
  "FUNCTIONS_WORKER_PROCESS_COUNT": null,
  "use32BitWorkerProcess": true
}
```

**Function App Details:**
- OS: Windows (reserved: false)
- Plan: ElasticPremium
- Always On: false (not applicable for Premium plan)
- Node Version: ~22
- Functions Runtime: ~4

## Error Details

### Exception from Application Insights

```
Exception: Worker was unable to load entry point "index.js": File does not exist.
Learn more here: https://aka.ms/AAla7et

Stack: Error: Worker was unable to load entry point "index.js": File does not exist.
Learn more here: https://aka.ms/AAla7et
    at C:\Program Files (x86)\SiteExtensions\Functions\4.1045.200\workers\node\dist\src\worker-bundle.js:2:57305
    at Generator.next (<anonymous>)
    at o (C:\Program Files (x86)\SiteExtensions\Functions\4.1045.200\workers\node\dist\src\worker-bundle.js:2:56137)
    at process.processTicksAndRejections (node:internal/process/task_queues:105:5)
```

### Affected Functions
ALL 27 functions fail with identical error:
- ask-bartender, ask-bartender-simple, ask-bartender-test
- auth-exchange, auth-rotate
- download-images, download-images-mi
- health
- recommend, refine-cocktail
- rotate-keys-timer (timer trigger)
- snapshots-latest, snapshots-latest-mi
- social-inbox, social-invite, social-outbox, social-share-internal
- speech-token
- sync-cocktaildb (timer trigger), sync-cocktaildb-mi (timer trigger)
- test-keyvault, test-mi-access, test-write
- users-me
- validate-age
- vision-analyze
- voice-bartender

## Possible Root Causes

### 1. Package Mounting Issue (Most Likely)
When `WEBSITE_RUN_FROM_PACKAGE=1`, Azure Functions mounts the zip package as a virtual file system. The runtime may be unable to:
- Mount the package correctly
- Access files within the mounted package
- Find the correct mount point

**Evidence:**
- Files exist in deployment package (verified via REST API)
- Runtime reports files don't exist
- Issue persists across multiple deployments
- Affects ALL functions uniformly

### 2. Deployment Package Structure Problem
The package may be structured incorrectly, preventing the runtime from finding function entry points.

**Counter-evidence:**
- Same deployment process worked previously
- Package structure appears correct when inspected via REST API
- Standard `func azure functionapp publish` creates the package

### 3. Functions Runtime Corruption
The Functions runtime (v4.1045.200) may have an issue or corruption.

**Evidence:**
- Consistent error across all functions
- Error occurs at worker initialization level
- Same error pattern regardless of function complexity

### 4. Windows-Specific Premium Plan Issue
There may be a compatibility issue with Windows-based Elastic Premium plans and the current deployment package format.

**Evidence:**
- Configuration follows Microsoft Learn recommendations for Windows Premium
- Issue persists with recommended settings (`WEBSITE_RUN_FROM_PACKAGE=1`)

### 5. File System Permissions
The Functions worker process may lack permissions to access the mounted package or file system.

**Counter-evidence:**
- No permission-related errors in logs
- Function App managed identity has appropriate roles
- Other Function Apps in same subscription/region work

## Microsoft Learn Documentation References

According to [Microsoft Learn - Run functions from package](https://learn.microsoft.com/en-us/azure/azure-functions/run-functions-from-deployment-package):

> "When deploying your function app to Windows, you should set `WEBSITE_RUN_FROM_PACKAGE` to `1` and publish with zip deployment."

According to [Microsoft Learn - Remote builds](https://learn.microsoft.com/en-us/azure/azure-functions/functions-infrastructure-as-code#remote-builds):

> "If your project needs to use remote build, don't use the `WEBSITE_RUN_FROM_PACKAGE` app setting. Instead, add the `SCM_DO_BUILD_DURING_DEPLOYMENT=true` deployment customization app setting."

We followed both approaches without success.

## Testing Performed

### Direct Function Testing
```powershell
Invoke-RestMethod -Uri 'https://func-mba-fresh.azurewebsites.net/api/v1/ask-bartender-simple?code=[FUNCTION_KEY]' -Method Post
Result: 500 Internal Server Error
```

### Health Endpoint Testing
```powershell
Invoke-RestMethod -Uri 'https://func-mba-fresh.azurewebsites.net/api/health' -Method Get
Result: 500 Internal Server Error
```

### Through APIM Testing
```powershell
Invoke-RestMethod -Uri 'https://apim-mba-002.azure-api.net/v1/ask-bartender-simple' -Method Post -Headers @{"Ocp-Apim-Subscription-Key"="..."}
Result: 500 Internal Server Error (propagated from Function App)
```

## Recommended Next Steps

### Immediate Actions

1. **Check Azure Service Health**
   - Verify no regional issues with Azure Functions in South Central US
   - Check for any ongoing incidents affecting Windows Premium plans

2. **Review Function App Logs via Portal**
   - Access Azure Portal → func-mba-fresh → Log Stream
   - Look for additional initialization errors not visible in Application Insights

3. **Test with Minimal Function**
   - Create a new, minimal test function with no dependencies
   - Deploy only that function to see if issue is dependency-related

4. **Compare with Working Function App**
   - If other Function Apps exist in subscription, compare configurations
   - Look for differences in settings or deployment approach

### Investigation Actions

5. **Enable Detailed Logging**
   - Set `FUNCTIONS_WORKER_PROCESS_COUNT=1` to reduce concurrency
   - Enable verbose logging for worker process
   - Check for mount point or path issues in detailed logs

6. **Verify Package Contents**
   - Download the deployment package from SitePackages
   - Manually inspect zip file structure
   - Verify function.json and index.js are at correct paths within zip

7. **Test Deployment Without Run-From-Package**
   - Set `WEBSITE_RUN_FROM_PACKAGE=0` (deploy to wwwroot instead)
   - Redeploy and test if functions work without package mounting
   - If successful, indicates issue is with package mounting mechanism

### Alternative Approaches

8. **Recreate Function App**
   - Create new Function App with same settings
   - Deploy functions to new app
   - If successful, indicates corruption in original Function App resource

9. **Try Linux Function App**
   - Create Linux-based Function App (reserved: true)
   - Deploy same functions
   - Verify if issue is Windows-specific

10. **Contact Azure Support**
    - Open Azure support ticket with deployment details
    - Provide Application Insights correlation IDs
    - Request investigation of Functions runtime behavior

## Related Resources

- Function App: `func-mba-fresh`
- APIM Instance: `apim-mba-002`
- Azure Front Door: `fd-mba-share`
- Application Insights: `func-mba-fresh`
- Key Vault: `kv-mybartenderai-prod`

## Additional Context

### Project Architecture
- Mobile app uses Azure Front Door (fd-mba-share) as entry point
- Front Door routes to APIM (apim-mba-002)
- APIM applies policies and routes to Function App (func-mba-fresh)
- Functions use Azure OpenAI (mybartenderai-scus) for AI features
- PostgreSQL database for data storage
- Blob storage for static assets

### Recent Changes
- APIM operations were recently recreated in apim-mba-002
- Backend authentication policy applied to pass function keys
- Tier-based products configured (Free, Premium, Pro)
- Function key rotation implemented via rotate-keys-timer function

### Working Components
- ✅ Azure Front Door routing
- ✅ APIM operations and policies
- ✅ APIM subscription key authentication
- ✅ Backend authentication (function key passing)
- ✅ Azure OpenAI service endpoint
- ✅ PostgreSQL database connections
- ✅ Blob storage access

### Non-Working Components
- ❌ All Azure Functions (runtime cannot load entry points)
- ❌ AI Bartender features (dependent on functions)
- ❌ Function-based endpoints via APIM
- ❌ Function-based endpoints via Front Door

## Timeline of Events

1. **Initial Issue Detected:** Functions returning 500 errors
2. **First Investigation:** Found "Cannot find module 'openai'" error
3. **Package Added:** Added openai npm package to dependencies
4. **Multiple Deployments:** Attempted various deployment configurations
5. **Configuration Changes:** Tried both with and without WEBSITE_RUN_FROM_PACKAGE
6. **Verification:** Confirmed files are deployed correctly via REST API
7. **Current State:** All functions fail with "File does not exist" error

## Contact Information

For questions or additional information about this issue, reference:
- Application Insights Query: `exceptions | where timestamp > ago(1h) | where outerMessage contains 'index.js'`
- Deployment Timestamps: Multiple deployments between 12:09 UTC and 12:39 UTC on Nov 20, 2025
- Latest Package: `20251120123942.zip` (25,064,281 bytes)

---

**Status:** UNRESOLVED - Requires Azure expertise or platform-level investigation
