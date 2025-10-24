# Apply JWT Validation Policies to APIM Operations
# This script applies JWT validation to Premium/Pro tier operations

param(
    [string]$ResourceGroup = "rg-mba-prod",
    [string]$ApimServiceName = "apim-mba-001",
    [string]$ApiId = "mybartenderai-api",
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  JWT Policy Deployment Script" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Operations that require JWT authentication (Premium/Pro features)
$operationsRequiringJWT = @(
    "askBartender",
    "recommendCocktails",
    "getSpeechToken"
)

# Operations that should NOT have JWT (public/all tiers)
$publicOperations = @(
    "getLatestSnapshot",
    "getHealth",
    "getImageManifest",
    "triggerSync"  # Uses function key auth instead
)

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $ResourceGroup"
Write-Host "  APIM Service: $ApimServiceName"
Write-Host "  API: $ApiId"
Write-Host "  Dry Run: $DryRun"
Write-Host ""

Write-Host "JWT policy will be loaded from: policies/jwt-validation-entra-external-id.xml" -ForegroundColor Green
Write-Host ""

# Get subscription info
Write-Host "Getting Azure subscription information..." -ForegroundColor Yellow
$subscription = az account show | ConvertFrom-Json
$subscriptionId = $subscription.id
$tenantId = $subscription.tenantId

Write-Host "  Subscription ID: $subscriptionId"
Write-Host "  Tenant ID: $tenantId"
Write-Host ""

# Get access token for Azure REST API
Write-Host "Getting Azure access token..." -ForegroundColor Yellow
$token = az account get-access-token --query accessToken -o tsv
if (-not $token) {
    Write-Error "Failed to get access token"
    exit 1
}
Write-Host "Access token obtained" -ForegroundColor Green
Write-Host ""

# Function to get operation policy
function Get-OperationPolicy {
    param(
        [string]$OperationId
    )

    $url = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$ApimServiceName/apis/$ApiId/operations/$OperationId/policies/policy?api-version=2022-08-01"

    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }

    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        return $response
    }
    catch {
        Write-Host "    Warning: Could not get existing policy (may not exist yet)" -ForegroundColor Yellow
        return $null
    }
}

# Function to load JWT policy from file
function Get-JWTPolicyContent {
    $policyFilePath = Join-Path $PSScriptRoot "..\policies\jwt-validation-entra-external-id.xml"
    if (-not (Test-Path $policyFilePath)) {
        throw "JWT policy file not found: $policyFilePath"
    }

    $policyContent = Get-Content $policyFilePath -Raw
    return $policyContent
}

# Function to apply policy to operation
function Set-OperationPolicy {
    param(
        [string]$OperationId,
        [string]$PolicyXml
    )

    $url = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$ApimServiceName/apis/$ApiId/operations/$OperationId/policies/policy?api-version=2022-08-01"

    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }

    $body = @{
        properties = @{
            value = $PolicyXml
            format = "rawxml"
        }
    } | ConvertTo-Json -Depth 10

    if ($DryRun) {
        Write-Host "    [DRY RUN] Would apply policy to operation: $OperationId" -ForegroundColor Magenta
        return $true
    }

    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Put -Body $body
        return $true
    }
    catch {
        Write-Host "    Error applying policy: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Process each operation
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Processing Operations" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$successCount = 0
$skipCount = 0
$failCount = 0

foreach ($operation in $operationsRequiringJWT) {
    Write-Host "Processing operation: $operation" -ForegroundColor Yellow
    Write-Host "  Type: Premium/Pro (requires JWT)" -ForegroundColor Cyan

    # Get existing policy
    Write-Host "  Checking existing policy..." -ForegroundColor Gray
    $existingPolicy = Get-OperationPolicy -OperationId $operation

    if ($existingPolicy) {
        Write-Host "  Existing policy found" -ForegroundColor Gray
    } else {
        Write-Host "  No existing policy found" -ForegroundColor Gray
    }

    # Load JWT policy from file
    $newPolicy = Get-JWTPolicyContent

    # Apply policy
    Write-Host "  Applying JWT validation policy..." -ForegroundColor Green
    $result = Set-OperationPolicy -OperationId $operation -PolicyXml $newPolicy

    if ($result) {
        Write-Host "  ✓ Policy applied successfully" -ForegroundColor Green
        $successCount++
    } else {
        Write-Host "  ✗ Policy application failed" -ForegroundColor Red
        $failCount++
    }

    Write-Host ""
}

# Report on public operations
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Public Operations (No JWT Required)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

foreach ($operation in $publicOperations) {
    Write-Host "Skipping operation: $operation" -ForegroundColor Gray
    Write-Host "  Type: Public/All tiers (no JWT validation)" -ForegroundColor Gray
    Write-Host "  ✓ No changes needed" -ForegroundColor Green
    $skipCount++
    Write-Host ""
}

# Summary
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "JWT policies applied:  $successCount" -ForegroundColor Green
Write-Host "Operations skipped:    $skipCount" -ForegroundColor Gray
Write-Host "Failures:              $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY RUN MODE] No changes were made" -ForegroundColor Magenta
    Write-Host "Run without -DryRun to apply changes" -ForegroundColor Magenta
} else {
    Write-Host "Deployment complete!" -ForegroundColor Green
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Test JWT validation on Premium/Pro operations" -ForegroundColor White
Write-Host "2. Verify public operations still work without JWT" -ForegroundColor White
Write-Host "3. Update mobile app to include JWT tokens in requests" -ForegroundColor White
Write-Host ""

# Return success if no failures
if ($failCount -eq 0) {
    exit 0
} else {
    exit 1
}
