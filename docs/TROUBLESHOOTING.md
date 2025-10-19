# Azure Functions v4 Flex Consumption - Troubleshooting Guide

## Current Situation

### What Works ✅
- Simple minimal function deploys and runs successfully
- Health endpoint (`/api/HttpExample`) responds correctly
- Function App infrastructure is operational
- Flex Consumption plan itself works fine

### What Doesn't Work ❌
- Full application deployment with dependencies
- Any function that requires `services/`, `shared/`, or other modules
- Module resolution fails with "Cannot find module" errors
- Results in "0 functions loaded"

## Root Cause Analysis

### Successful Minimal Deployment
```
v4-minimal/
├── package.json (main: "src/functions/*.js")
├── host.json
├── node_modules/
└── src/
    └── functions/
        └── httpTrigger.js (simple, no external dependencies)
```

**Result**: ✅ Functions load and work perfectly

### Failed Full Deployment
```
v4-deploy/ or v4-clean/ or v4-restructured/
├── package.json (main: "src/functions/*.js" or "*.js" or "index.js")
├── host.json
├── node_modules/
├── services/          # Business logic
├── shared/            # Utilities
├── config/
├── utils/
├── types/
└── src/functions/
    ├── snapshots-latest.js
    ├── sync-cocktaildb.js
    ├── recommend.js
    └── download-images.js
```

**Result**: ❌ "0 functions loaded" - "Cannot find module '../../services/...'"

## Key Findings

1. **Module Resolution Issue**: When functions try to `require('../../services/...')`, the module system can't find them
2. **Deployment Packaging**: Something about how we're zipping/deploying breaks the folder structure
3. **Intermittent Success**: We HAD it working briefly earlier today, but couldn't reproduce
4. **Path Sensitivity**: Relative imports work locally but fail in Azure

## Attempts Made

### ❌ Attempt 1: Standard v4 Structure
- Individual function folders with index.js
- Root-level index.js importing all functions
- **Failed**: Module resolution errors

### ❌ Attempt 2: Flat Structure
- All functions in root directory
- No index.js entry point
- **Failed**: Functions not discovered

### ❌ Attempt 3: src/functions Structure
- Functions in src/functions/*.js
- package.json main: "src/functions/*.js"
- **Failed**: Module resolution errors when dependencies added

### ✅ Attempt 4: Minimal Test
- Single function, no dependencies
- **Success**: Proves infrastructure works

## Theories

### Theory 1: Compression Issue
PowerShell's `Compress-Archive` might not preserve proper directory structure or symlinks

### Theory 2: Module Path Resolution
Azure Functions v4 on Flex Consumption might have different module resolution than standard Consumption

### Theory 3: Package.json Main Entry
The `main` field might need a different pattern or might not support complex structures

### Theory 4: Node Modules
The node_modules folder might be too large or have issues that break deployment

## Recommended Next Steps

### Option A: Incremental Addition (Safest)
1. Start with working minimal deployment
2. Add ONE service file at a time
3. Test after each addition
4. Find the exact point where it breaks

### Option B: Bundle Everything (Alternative)
1. Use a bundler (webpack/esbuild) to create single-file functions
2. All dependencies included in each function file
3. No external requires needed

### Option C: Different Hosting Plan
1. Try deploying to Windows Consumption instead of Linux Flex
2. See if it's a Flex Consumption-specific issue

### Option D: Azure Support
1. Open Azure support ticket
2. Provide minimal reproducible example
3. Get official Microsoft guidance

## Critical Observations

- **The OpenAI lazy initialization fix WAS correct** - we saw that error in logs
- **The Key Vault retry logic WAS needed** - we saw that error too
- **The code itself is fine** - it compiles and structure looks correct
- **The issue is purely deployment/packaging related**

## What Was Working Earlier

At timestamp 2:58 PM today, we had:
- ✅ Health endpoint returning 200
- ✅ Snapshots endpoint returning data
- ✅ All 5 functions loaded successfully

The deployment that worked had these characteristics:
- Used the OpenAI lazy initialization
- Had proper Key Vault references configured
- Functions were discovered and loaded

## Next Session Action Plan

1. **Do NOT make new deployments randomly**
2. **Find the exact deployment from 2:58 PM that worked**
3. **Analyze that deployment structure carefully**
4. **Reproduce it exactly**
5. **Document the exact steps**

## Deployment History to Review

- Check Application Insights for logs around 2:58 PM (successful)
- Compare with logs from 3:19 PM onwards (failing)
- Look for differences in package structure or configuration

## Environment Variables Confirmed Working

- `POSTGRES_CONNECTION_STRING`: @Microsoft.KeyVault reference
- `COCKTAILDB-API-KEY`: @Microsoft.KeyVault reference  
- `OPENAI_API_KEY`: @Microsoft.KeyVault(VaultName=kv-mybartenderai-prod;SecretName=OpenAI)
- `BLOB_STORAGE_CONNECTION_STRING`: Direct connection string
- Managed Identity: `func-cocktaildb2-uami` with Key Vault Secrets User role

