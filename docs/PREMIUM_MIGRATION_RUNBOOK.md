# Premium Function Plan Migration Runbook

**Document Version**: 1.0
**Created**: November 7, 2025
**Risk Level**: MEDIUM
**Estimated Duration**: 2-3 hours
**Rollback Time**: 15 minutes

---

## Executive Summary

This runbook documents the migration from Windows Consumption Plan to Premium Function Plan (EP1) for the MyBartenderAI production environment. This migration eliminates cold starts, enables full Managed Identity support, and provides production-grade reliability.

**Current State**: `func-mba-fresh` on Windows Consumption Plan
**Target State**: `func-mba-premium` on Premium Plan EP1
**Downtime**: Zero (using blue-green deployment)

---

## Pre-Migration Checklist

### ✅ Business Readiness
- [ ] Stakeholders notified of migration window
- [ ] Support team on standby
- [ ] Rollback decision maker identified
- [ ] Budget approved (~$150/month)

### ✅ Technical Prerequisites
- [ ] Azure CLI installed and authenticated
- [ ] Current Function App backed up
- [ ] All environment variables documented
- [ ] Connection strings verified
- [ ] SAS tokens documented for removal
- [ ] Current traffic baseline recorded

### ✅ Backup Current State
```powershell
# 1. Export current app settings
az functionapp config appsettings list `
  --name func-mba-fresh `
  --resource-group rg-mba-prod `
  --output json > backup-appsettings-$(Get-Date -Format "yyyyMMdd-HHmmss").json

# 2. Export function app configuration
az functionapp show `
  --name func-mba-fresh `
  --resource-group rg-mba-prod `
  --output json > backup-config-$(Get-Date -Format "yyyyMMdd-HHmmss").json

# 3. Document current endpoints
Write-Host "Current Endpoints:" -ForegroundColor Cyan
Write-Host "- Base: https://func-mba-fresh.azurewebsites.net/api"
Write-Host "- Ask Bartender: /v1/ask-bartender-simple"
Write-Host "- Vision: /v1/vision/analyze"
Write-Host "- Snapshots: /v1/snapshots/latest"

# 4. Test current functionality
$functionKey = az keyvault secret show `
  --vault-name kv-mybartenderai-prod `
  --name AZURE-FUNCTION-KEY `
  --query value -o tsv

curl https://func-mba-fresh.azurewebsites.net/api/health `
  -H "x-functions-key: $functionKey"
```

---

## Migration Phase 1: Create Premium Infrastructure

### Step 1.1: Create Premium Plan
```powershell
Write-Host "Creating Premium Function Plan..." -ForegroundColor Yellow

az functionapp plan create `
  --name plan-mba-premium `
  --resource-group rg-mba-prod `
  --location southcentralus `
  --sku EP1 `
  --min-instances 1 `
  --max-burst 5

# Verify creation
az functionapp plan show `
  --name plan-mba-premium `
  --resource-group rg-mba-prod `
  --query "{name:name, sku:sku.name, status:status}" -o table
```

### Step 1.2: Create New Function App
```powershell
Write-Host "Creating Premium Function App..." -ForegroundColor Yellow

az functionapp create `
  --name func-mba-premium `
  --resource-group rg-mba-prod `
  --plan plan-mba-premium `
  --storage-account mbacocktaildb3 `
  --runtime node `
  --runtime-version 18 `
  --functions-version 4 `
  --os-type Windows

# Enable Always On (prevents cold starts)
az functionapp config set `
  --name func-mba-premium `
  --resource-group rg-mba-prod `
  --always-on true
```

### Step 1.3: Configure Managed Identity
```powershell
Write-Host "Configuring Managed Identity..." -ForegroundColor Yellow

# Enable System-Assigned Managed Identity
$identity = az functionapp identity assign `
  --name func-mba-premium `
  --resource-group rg-mba-prod `
  --query principalId -o tsv

Write-Host "Identity Created: $identity" -ForegroundColor Green

# Grant Key Vault access
az role assignment create `
  --assignee $identity `
  --role "Key Vault Secrets User" `
  --scope /subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-mba-dev/providers/Microsoft.KeyVault/vaults/kv-mybartenderai-prod

# Grant Storage Blob Data Contributor
az role assignment create `
  --assignee $identity `
  --role "Storage Blob Data Contributor" `
  --scope /subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-mba-prod/providers/Microsoft.Storage/storageAccounts/mbacocktaildb3

# Grant PostgreSQL access (if needed)
# Add managed identity to PostgreSQL AAD admin
```

---

## Migration Phase 2: Configure Application Settings

### Step 2.1: Replicate App Settings
```powershell
Write-Host "Migrating Application Settings..." -ForegroundColor Yellow

# Core settings (using Key Vault references)
$settings = @(
  "AZURE_OPENAI_API_KEY=@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/AZURE-OPENAI-API-KEY/)",
  "AZURE_OPENAI_ENDPOINT=@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/AZURE-OPENAI-ENDPOINT/)",
  "POSTGRES_CONNECTION_STRING=@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/POSTGRES-CONNECTION-STRING/)",
  "COCKTAILDB_API_KEY=@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/COCKTAILDB-API-KEY/)",
  "AZURE_CV_KEY=@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/AZURE-CV-KEY/)",
  "AZURE_CV_ENDPOINT=@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/AZURE-CV-ENDPOINT/)",
  "NODE_ENV=production",
  "WEBSITE_NODE_DEFAULT_VERSION=~18",
  "FUNCTIONS_WORKER_RUNTIME=node",
  "AzureWebJobsStorage__accountName=mbacocktaildb3"
)

# Apply settings
az functionapp config appsettings set `
  --name func-mba-premium `
  --resource-group rg-mba-prod `
  --settings $settings
```

### Step 2.2: Configure Managed Identity Storage Access
```powershell
Write-Host "Configuring Managed Identity Storage Access..." -ForegroundColor Yellow

# Remove SAS token dependencies
az functionapp config appsettings delete `
  --name func-mba-premium `
  --resource-group rg-mba-prod `
  --setting-names STORAGE_SAS_TOKEN BLOB_SAS_URL

# Add Managed Identity storage configuration
az functionapp config appsettings set `
  --name func-mba-premium `
  --resource-group rg-mba-prod `
  --settings `
    "AzureWebJobsStorage__credential=managedidentity" `
    "AzureWebJobsStorage__clientId=$identity"
```

---

## Migration Phase 3: Deploy Code

### Step 3.1: Deploy Function Code
```powershell
Write-Host "Deploying Function Code..." -ForegroundColor Yellow

# Navigate to function directory
cd "C:\backup dev02\mybartenderAI-MVP\apps\backend\v3-deploy"

# Deploy to new Premium Function App
func azure functionapp publish func-mba-premium --javascript

# Verify deployment
az functionapp function list `
  --name func-mba-premium `
  --resource-group rg-mba-prod `
  --query "[].{name:name}" -o table
```

### Step 3.2: Update Code for Managed Identity
```powershell
Write-Host "Note: Update storage access code to use DefaultAzureCredential" -ForegroundColor Yellow

# Example code change needed in functions:
# FROM:
# const sasToken = process.env.STORAGE_SAS_TOKEN;
# const blobUrl = `${baseUrl}?${sasToken}`;
#
# TO:
# const { DefaultAzureCredential } = require("@azure/identity");
# const { BlobServiceClient } = require("@azure/storage-blob");
# const credential = new DefaultAzureCredential();
# const blobServiceClient = new BlobServiceClient(
#   `https://mbacocktaildb3.blob.core.windows.net`,
#   credential
# );
```

---

## Migration Phase 4: Testing & Validation

### Step 4.1: Smoke Tests
```powershell
Write-Host "Running Smoke Tests..." -ForegroundColor Yellow

$newFunctionKey = az functionapp keys list `
  --name func-mba-premium `
  --resource-group rg-mba-prod `
  --query "functionKeys.default" -o tsv

# Test health endpoint
$health = Invoke-RestMethod `
  -Uri "https://func-mba-premium.azurewebsites.net/api/health" `
  -Headers @{"x-functions-key"=$newFunctionKey}

if ($health.status -eq "healthy") {
  Write-Host "✅ Health check passed" -ForegroundColor Green
} else {
  Write-Host "❌ Health check failed" -ForegroundColor Red
  exit 1
}

# Test ask-bartender
$askTest = Invoke-RestMethod `
  -Uri "https://func-mba-premium.azurewebsites.net/api/v1/ask-bartender-simple" `
  -Method Post `
  -Headers @{
    "x-functions-key"=$newFunctionKey
    "Content-Type"="application/json"
  } `
  -Body '{"message":"What is a margarita?"}'

if ($askTest.response) {
  Write-Host "✅ Ask Bartender passed" -ForegroundColor Green
} else {
  Write-Host "❌ Ask Bartender failed" -ForegroundColor Red
}

# Test snapshots
$snapshotTest = Invoke-RestMethod `
  -Uri "https://func-mba-premium.azurewebsites.net/api/v1/snapshots/latest" `
  -Headers @{"x-functions-key"=$newFunctionKey}

if ($snapshotTest.success) {
  Write-Host "✅ Snapshots passed" -ForegroundColor Green
} else {
  Write-Host "❌ Snapshots failed" -ForegroundColor Red
}
```

### Step 4.2: Performance Validation
```powershell
Write-Host "Validating Performance..." -ForegroundColor Yellow

# Measure cold start (should be <1 second on Premium)
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$response = Invoke-WebRequest `
  -Uri "https://func-mba-premium.azurewebsites.net/api/health" `
  -Headers @{"x-functions-key"=$newFunctionKey}
$stopwatch.Stop()

Write-Host "Response Time: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Cyan

if ($stopwatch.ElapsedMilliseconds -lt 1000) {
  Write-Host "✅ No cold start detected (Premium working)" -ForegroundColor Green
} else {
  Write-Host "⚠️ Slower than expected: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Yellow
}
```

---

## Migration Phase 5: Traffic Cutover

### Step 5.1: Update APIM Backend (If Using)
```powershell
Write-Host "Updating API Management Backend..." -ForegroundColor Yellow

# Update APIM backend to point to new Premium Function
az apim api backend update `
  --resource-group rg-mba-prod `
  --service-name apim-mba-001 `
  --backend-id func-backend `
  --url https://func-mba-premium.azurewebsites.net/api
```

### Step 5.2: Update Mobile App Configuration
```powershell
Write-Host "Update mobile app to use new endpoint..." -ForegroundColor Yellow

# Update AppConfig.dart
# FROM: https://func-mba-fresh.azurewebsites.net/api
# TO:   https://func-mba-premium.azurewebsites.net/api

# Or update environment variable if using configuration service
```

### Step 5.3: DNS/Traffic Manager Update (If Applicable)
```powershell
# If using custom domain or Traffic Manager
# Update to point to func-mba-premium
```

---

## Rollback Procedures

### ⚠️ EMERGENCY ROLLBACK (15 minutes)

```powershell
Write-Host "EXECUTING EMERGENCY ROLLBACK..." -ForegroundColor Red

# Step 1: Revert APIM Backend
az apim api backend update `
  --resource-group rg-mba-prod `
  --service-name apim-mba-001 `
  --backend-id func-backend `
  --url https://func-mba-fresh.azurewebsites.net/api

# Step 2: Notify mobile app users (if app was updated)
# Push notification or force app config refresh

# Step 3: Verify old endpoint working
$oldKey = az keyvault secret show `
  --vault-name kv-mybartenderai-prod `
  --name AZURE-FUNCTION-KEY `
  --query value -o tsv

curl https://func-mba-fresh.azurewebsites.net/api/health `
  -H "x-functions-key: $oldKey"

Write-Host "✅ Rollback complete - using original Consumption Plan" -ForegroundColor Yellow
```

---

## Post-Migration Tasks

### Week 1: Monitoring
```powershell
# Monitor metrics daily
az monitor metrics list `
  --resource /subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-mba-prod/providers/Microsoft.Web/sites/func-mba-premium `
  --metric "FunctionExecutionCount" `
  --interval PT1H `
  --start-time (Get-Date).AddDays(-1).ToString("yyyy-MM-ddTHH:mm:ssZ") `
  --end-time (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")

# Check for errors
az monitor activity-log list `
  --resource-group rg-mba-prod `
  --start-time (Get-Date).AddHours(-24).ToString("yyyy-MM-ddTHH:mm:ssZ") `
  --query "[?contains(resourceId, 'func-mba-premium')]"
```

### Week 2: Optimization
```powershell
# Adjust scaling settings based on usage
az functionapp plan update `
  --name plan-mba-premium `
  --resource-group rg-mba-prod `
  --min-instances 1 `
  --max-burst 3  # Reduce if not needed
```

### Week 4: Cost Review
```powershell
# Review actual costs
az consumption usage list `
  --start-date (Get-Date).AddDays(-30).ToString("yyyy-MM-dd") `
  --end-date (Get-Date).ToString("yyyy-MM-dd") `
  --query "[?contains(instanceName, 'plan-mba-premium')]"
```

---

## Decommission Old Resources (After 30 Days)

```powershell
Write-Host "Decommissioning old Consumption Plan..." -ForegroundColor Yellow

# Only execute after 30 days of stable operation

# 1. Final backup
az functionapp show `
  --name func-mba-fresh `
  --resource-group rg-mba-prod > final-backup-consumption.json

# 2. Stop the old function app
az functionapp stop `
  --name func-mba-fresh `
  --resource-group rg-mba-prod

# 3. Wait 7 days, then delete if no issues
# az functionapp delete `
#   --name func-mba-fresh `
#   --resource-group rg-mba-prod
```

---

## Troubleshooting Guide

### Issue: Managed Identity not working
```powershell
# Verify identity assigned
az functionapp identity show `
  --name func-mba-premium `
  --resource-group rg-mba-prod

# Check role assignments
az role assignment list `
  --assignee <principalId> `
  --all
```

### Issue: Cold starts still occurring
```powershell
# Verify Always On is enabled
az functionapp config show `
  --name func-mba-premium `
  --resource-group rg-mba-prod `
  --query alwaysOn

# Check minimum instances
az functionapp plan show `
  --name plan-mba-premium `
  --resource-group rg-mba-prod `
  --query "sku.capacity"
```

### Issue: Key Vault access denied
```powershell
# Re-grant access
$identity = az functionapp identity show `
  --name func-mba-premium `
  --resource-group rg-mba-prod `
  --query principalId -o tsv

az role assignment create `
  --assignee $identity `
  --role "Key Vault Secrets User" `
  --scope /subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-mba-dev/providers/Microsoft.KeyVault/vaults/kv-mybartenderai-prod
```

---

## Success Criteria

✅ **Migration is successful when:**
1. All endpoints respond in <1 second (no cold starts)
2. Zero errors in Application Insights
3. Managed Identity working for all resources
4. All functions executing successfully
5. Mobile app working with new endpoint
6. Cost tracking enabled and within budget

---

## Appendix A: Cost Tracking Script

```powershell
# Save as Monitor-PremiumCosts.ps1
param(
    [int]$Days = 7
)

$startDate = (Get-Date).AddDays(-$Days).ToString("yyyy-MM-dd")
$endDate = (Get-Date).ToString("yyyy-MM-dd")

Write-Host "Cost Analysis for Premium Function Plan" -ForegroundColor Cyan
Write-Host "Period: $startDate to $endDate" -ForegroundColor Gray

$costs = az consumption usage list `
  --start-date $startDate `
  --end-date $endDate `
  --query "[?contains(instanceName, 'plan-mba-premium')].{name:instanceName, cost:pretaxCost, currency:currency}" `
  -o json | ConvertFrom-Json

$totalCost = ($costs | Measure-Object -Property cost -Sum).Sum
Write-Host "Total Cost: $$totalCost" -ForegroundColor Yellow

$dailyAverage = $totalCost / $Days
Write-Host "Daily Average: $$dailyAverage" -ForegroundColor Green

$projectedMonthly = $dailyAverage * 30
Write-Host "Projected Monthly: $$projectedMonthly" -ForegroundColor Cyan
```

---

## Appendix B: Validation Script

```powershell
# Save as Validate-Premium.ps1
param(
    [string]$FunctionAppName = "func-mba-premium"
)

Write-Host "Validating Premium Function App: $FunctionAppName" -ForegroundColor Cyan

# Get function key
$key = az functionapp keys list `
  --name $FunctionAppName `
  --resource-group rg-mba-prod `
  --query "functionKeys.default" -o tsv

# Test all endpoints
$endpoints = @(
    "/api/health",
    "/api/v1/ask-bartender-simple",
    "/api/v1/snapshots/latest",
    "/api/v1/vision/analyze"
)

$results = @()
foreach ($endpoint in $endpoints) {
    $uri = "https://$FunctionAppName.azurewebsites.net$endpoint"

    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -Uri $uri -Headers @{"x-functions-key"=$key} -Method Get -TimeoutSec 10
        $stopwatch.Stop()

        $results += [PSCustomObject]@{
            Endpoint = $endpoint
            Status = "✅ Pass"
            ResponseTime = "$($stopwatch.ElapsedMilliseconds)ms"
            StatusCode = $response.StatusCode
        }
    } catch {
        $results += [PSCustomObject]@{
            Endpoint = $endpoint
            Status = "❌ Fail"
            ResponseTime = "N/A"
            StatusCode = $_.Exception.Response.StatusCode.value__
        }
    }
}

$results | Format-Table -AutoSize

# Summary
$passed = ($results | Where-Object { $_.Status -eq "✅ Pass" }).Count
$total = $results.Count

if ($passed -eq $total) {
    Write-Host "`n✅ All tests passed ($passed/$total)" -ForegroundColor Green
} else {
    Write-Host "`n⚠️ Some tests failed ($passed/$total)" -ForegroundColor Yellow
}
```

---

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| DevOps Lead | | | |
| Development Lead | | | |
| Product Owner | | | |
| Finance Approval | | | |

**Notes**: Document any deviations from this runbook during actual migration.

---

*End of Runbook - Total Pages: 14*