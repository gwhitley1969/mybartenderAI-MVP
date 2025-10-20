# Fix Storage Write Access for func-mba-fresh
# This script diagnoses and fixes Managed Identity write access to mbacocktaildb3

param(
    [switch]$DiagnoseOnly,
    [switch]$Apply
)

$ErrorActionPreference = "Stop"

# Configuration
$resourceGroup = "rg-mba-prod"
$functionAppName = "func-mba-fresh"
$storageAccountName = "mbacocktaildb3"
$managedIdentityName = "func-cocktaildb2-uami"
$managedIdentityClientId = "94d9cf74-99a3-49d5-9be4-98ce2eae1d33"

Write-Host "=== Azure Function Storage Write Access Fix ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check Function App Settings
Write-Host "[1/5] Checking Function App configuration..." -ForegroundColor Yellow
$settings = az functionapp config appsettings list `
    --name $functionAppName `
    --resource-group $resourceGroup `
    --query "[?name=='STORAGE_ACCOUNT_NAME' || name=='AZURE_CLIENT_ID' || name=='SNAPSHOT_CONTAINER_NAME'].{name:name, value:value}" `
    --output json | ConvertFrom-Json

$settingsMap = @{}
foreach ($setting in $settings) {
    $settingsMap[$setting.name] = $setting.value
}

$missingSettings = @()

# Check required settings
if (-not $settingsMap.ContainsKey("STORAGE_ACCOUNT_NAME")) {
    Write-Host "  ❌ STORAGE_ACCOUNT_NAME is missing" -ForegroundColor Red
    $missingSettings += "STORAGE_ACCOUNT_NAME=$storageAccountName"
} elseif ($settingsMap["STORAGE_ACCOUNT_NAME"] -ne $storageAccountName) {
    Write-Host "  ⚠️  STORAGE_ACCOUNT_NAME is '$($settingsMap["STORAGE_ACCOUNT_NAME"])' but should be '$storageAccountName'" -ForegroundColor Yellow
    $missingSettings += "STORAGE_ACCOUNT_NAME=$storageAccountName"
} else {
    Write-Host "  ✅ STORAGE_ACCOUNT_NAME = $storageAccountName" -ForegroundColor Green
}

if (-not $settingsMap.ContainsKey("AZURE_CLIENT_ID")) {
    Write-Host "  ❌ AZURE_CLIENT_ID is missing" -ForegroundColor Red
    $missingSettings += "AZURE_CLIENT_ID=$managedIdentityClientId"
} elseif ($settingsMap["AZURE_CLIENT_ID"] -ne $managedIdentityClientId) {
    Write-Host "  ⚠️  AZURE_CLIENT_ID is '$($settingsMap["AZURE_CLIENT_ID"])' but should be '$managedIdentityClientId'" -ForegroundColor Yellow
    $missingSettings += "AZURE_CLIENT_ID=$managedIdentityClientId"
} else {
    Write-Host "  ✅ AZURE_CLIENT_ID = $managedIdentityClientId" -ForegroundColor Green
}

if (-not $settingsMap.ContainsKey("SNAPSHOT_CONTAINER_NAME")) {
    Write-Host "  ❌ SNAPSHOT_CONTAINER_NAME is missing" -ForegroundColor Red
    $missingSettings += "SNAPSHOT_CONTAINER_NAME=snapshots"
} else {
    Write-Host "  ✅ SNAPSHOT_CONTAINER_NAME = $($settingsMap["SNAPSHOT_CONTAINER_NAME"])" -ForegroundColor Green
}

Write-Host ""

# Step 2: Check Managed Identity Assignment
Write-Host "[2/5] Checking Managed Identity assignment..." -ForegroundColor Yellow
$assignedIdentities = az functionapp identity show `
    --name $functionAppName `
    --resource-group $resourceGroup `
    --query "userAssignedIdentities" `
    --output json | ConvertFrom-Json

$identityKey = "/subscriptions/$(az account show --query id -o tsv)/resourcegroups/$resourceGroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$managedIdentityName"
$hasIdentity = $assignedIdentities.PSObject.Properties.Name -contains $identityKey

if ($hasIdentity) {
    Write-Host "  ✅ Managed Identity '$managedIdentityName' is assigned" -ForegroundColor Green
} else {
    Write-Host "  ❌ Managed Identity '$managedIdentityName' is NOT assigned" -ForegroundColor Red
}
Write-Host ""

# Step 3: Check RBAC Role Assignments
Write-Host "[3/5] Checking RBAC role assignments..." -ForegroundColor Yellow
$subscriptionId = az account show --query id -o tsv
$storageScope = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Storage/storageAccounts/$storageAccountName"

$roles = az role assignment list `
    --assignee $managedIdentityClientId `
    --scope $storageScope `
    --query "[].{Role:roleDefinitionName}" `
    --output json | ConvertFrom-Json

$roleNames = $roles | ForEach-Object { $_.Role }

$requiredRoles = @(
    "Storage Blob Data Contributor",
    "Storage Blob Delegator"
)

$missingRoles = @()
foreach ($requiredRole in $requiredRoles) {
    if ($roleNames -contains $requiredRole) {
        Write-Host "  ✅ $requiredRole" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $requiredRole - MISSING" -ForegroundColor Red
        $missingRoles += $requiredRole
    }
}
Write-Host ""

# Step 4: Summary
Write-Host "[4/5] Diagnosis Summary" -ForegroundColor Yellow
$hasIssues = ($missingSettings.Count -gt 0) -or ($missingRoles.Count -gt 0) -or (-not $hasIdentity)

if (-not $hasIssues) {
    Write-Host "  ✅ All configuration looks correct!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  If you're still experiencing write errors, the issue may be:" -ForegroundColor Cyan
    Write-Host "  - Network connectivity to storage account" -ForegroundColor Cyan
    Write-Host "  - Storage account firewall rules blocking the function app" -ForegroundColor Cyan
    Write-Host "  - Code errors in the function implementation" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Run the test-write function to verify:" -ForegroundColor Cyan
    Write-Host "  curl https://func-mba-fresh.azurewebsites.net/api/test-write" -ForegroundColor White
} else {
    Write-Host "  ❌ Issues found:" -ForegroundColor Red
    if ($missingSettings.Count -gt 0) {
        Write-Host "    - Missing/incorrect app settings: $($missingSettings.Count)" -ForegroundColor Red
    }
    if ($missingRoles.Count -gt 0) {
        Write-Host "    - Missing RBAC roles: $($missingRoles.Count)" -ForegroundColor Red
    }
    if (-not $hasIdentity) {
        Write-Host "    - Managed identity not assigned to function app" -ForegroundColor Red
    }
}
Write-Host ""

# Step 5: Apply Fixes
if ($DiagnoseOnly) {
    Write-Host "[5/5] Diagnosis complete (run with -Apply to fix issues)" -ForegroundColor Yellow
    exit 0
}

if (-not $Apply) {
    Write-Host "[5/5] To apply fixes, run with -Apply flag" -ForegroundColor Yellow
    exit 0
}

if (-not $hasIssues) {
    Write-Host "[5/5] No fixes needed" -ForegroundColor Green
    exit 0
}

Write-Host "[5/5] Applying fixes..." -ForegroundColor Yellow

# Fix 1: Add missing app settings
if ($missingSettings.Count -gt 0) {
    Write-Host "  Adding missing app settings..." -ForegroundColor Cyan
    $settingsArray = $missingSettings -join " "
    az functionapp config appsettings set `
        --name $functionAppName `
        --resource-group $resourceGroup `
        --settings $settingsArray `
        --output none
    Write-Host "  ✅ App settings updated" -ForegroundColor Green
}

# Fix 2: Assign managed identity
if (-not $hasIdentity) {
    Write-Host "  Assigning managed identity..." -ForegroundColor Cyan
    az functionapp identity assign `
        --name $functionAppName `
        --resource-group $resourceGroup `
        --identities $identityKey `
        --output none
    Write-Host "  ✅ Managed identity assigned" -ForegroundColor Green

    # Wait for identity propagation
    Write-Host "  ⏳ Waiting 30 seconds for identity propagation..." -ForegroundColor Cyan
    Start-Sleep -Seconds 30
}

# Fix 3: Add missing RBAC roles
if ($missingRoles.Count -gt 0) {
    foreach ($role in $missingRoles) {
        Write-Host "  Assigning role: $role..." -ForegroundColor Cyan
        az role assignment create `
            --assignee $managedIdentityClientId `
            --role $role `
            --scope $storageScope `
            --output none
        Write-Host "  ✅ $role assigned" -ForegroundColor Green
    }

    # Wait for role propagation
    Write-Host "  ⏳ Waiting 60 seconds for role propagation..." -ForegroundColor Cyan
    Start-Sleep -Seconds 60
}

Write-Host ""
Write-Host "=== Fixes Applied Successfully ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Restart the function app:" -ForegroundColor White
Write-Host "   az functionapp restart --name $functionAppName --resource-group $resourceGroup" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Test write access:" -ForegroundColor White
Write-Host "   curl https://func-mba-fresh.azurewebsites.net/api/test-write" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Check function logs for any errors:" -ForegroundColor White
Write-Host "   az functionapp log tail --name $functionAppName --resource-group $resourceGroup" -ForegroundColor Gray
Write-Host ""
