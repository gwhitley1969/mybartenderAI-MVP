# Configure Azure API Management for MyBartenderAI
# This script sets up Products, APIs, and Policies for the three-tier subscription model

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup = "rg-mba-prod",

    [Parameter(Mandatory=$true)]
    [string]$ApimServiceName = "apim-mba-001",

    [Parameter(Mandatory=$false)]
    [string]$FunctionAppUrl = "https://func-mba-fresh.azurewebsites.net"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MyBartenderAI - APIM Configuration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if logged in to Azure
$context = Get-AzContext
if (-not $context) {
    Write-Host "Not logged in to Azure. Please run 'Connect-AzAccount'" -ForegroundColor Red
    exit 1
}

Write-Host "Using Azure subscription: $($context.Subscription.Name)" -ForegroundColor Green
Write-Host ""

# Get APIM service
Write-Host "Getting APIM service: $ApimServiceName..." -ForegroundColor Yellow
$apim = Get-AzApiManagement -ResourceGroupName $ResourceGroup -Name $ApimServiceName

if (-not $apim) {
    Write-Host "APIM service not found!" -ForegroundColor Red
    exit 1
}

Write-Host "APIM Gateway URL: $($apim.GatewayUrl)" -ForegroundColor Green
Write-Host ""

# Create APIM context
$apimContext = New-AzApiManagementContext -ResourceGroupName $ResourceGroup -ServiceName $ApimServiceName

# ====================
# STEP 1: Create Backend
# ====================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 1: Configure Backend" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "Creating backend for Function App: $FunctionAppUrl" -ForegroundColor Yellow

$backendId = "func-mba-fresh-backend"
$backend = Get-AzApiManagementBackend -Context $apimContext -BackendId $backendId -ErrorAction SilentlyContinue

if ($backend) {
    Write-Host "Backend already exists, updating..." -ForegroundColor Yellow
    Set-AzApiManagementBackend -Context $apimContext -BackendId $backendId -Url "$FunctionAppUrl/api" -Protocol "http"
} else {
    New-AzApiManagementBackend -Context $apimContext -BackendId $backendId -Url "$FunctionAppUrl/api" -Protocol "http" -Title "MyBartenderAI Function App"
}

Write-Host "✓ Backend configured" -ForegroundColor Green
Write-Host ""

# ====================
# STEP 2: Create Products (Subscription Tiers)
# ====================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 2: Create Products (Tiers)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Free Tier
Write-Host "Creating Free Tier product..." -ForegroundColor Yellow
$freeProduct = Get-AzApiManagementProduct -Context $apimContext -ProductId "free-tier" -ErrorAction SilentlyContinue
if (-not $freeProduct) {
    New-AzApiManagementProduct -Context $apimContext -ProductId "free-tier" -Title "Free Tier" `
        -Description "Free tier with offline database and limited AI (10 recommendations/month)" `
        -SubscriptionRequired $true -ApprovalRequired $false -State "Published"
}
Write-Host "✓ Free Tier created" -ForegroundColor Green

# Premium Tier
Write-Host "Creating Premium Tier product..." -ForegroundColor Yellow
$premiumProduct = Get-AzApiManagementProduct -Context $apimContext -ProductId "premium-tier" -ErrorAction SilentlyContinue
if (-not $premiumProduct) {
    New-AzApiManagementProduct -Context $apimContext -ProductId "premium-tier" -Title "Premium Tier ($4.99/month)" `
        -Description "Premium tier with AI (100/month), Voice (30 min/month), Vision (5 scans/month)" `
        -SubscriptionRequired $true -ApprovalRequired $false -State "Published"
}
Write-Host "✓ Premium Tier created" -ForegroundColor Green

# Pro Tier
Write-Host "Creating Pro Tier product..." -ForegroundColor Yellow
$proProduct = Get-AzApiManagementProduct -Context $apimContext -ProductId "pro-tier" -ErrorAction SilentlyContinue
if (-not $proProduct) {
    New-AzApiManagementProduct -Context $apimContext -ProductId "pro-tier" -Title "Pro Tier ($9.99/month)" `
        -Description "Pro tier with unlimited AI, extended Voice (5 hours/month), Vision (50 scans/month)" `
        -SubscriptionRequired $true -ApprovalRequired $false -State "Published"
}
Write-Host "✓ Pro Tier created" -ForegroundColor Green
Write-Host ""

# ====================
# STEP 3: Import OpenAPI Spec
# ====================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 3: Import OpenAPI Specification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$openApiPath = "../../spec/openapi-complete.yaml"
if (Test-Path $openApiPath) {
    Write-Host "Importing OpenAPI spec from: $openApiPath" -ForegroundColor Yellow

    # Check if API already exists
    $apiId = "mybartenderai-api"
    $existingApi = Get-AzApiManagementApi -Context $apimContext -ApiId $apiId -ErrorAction SilentlyContinue

    if ($existingApi) {
        Write-Host "API already exists, updating..." -ForegroundColor Yellow
        # Use Import-AzApiManagementApi to update existing
        Import-AzApiManagementApi -Context $apimContext -ApiId $apiId -SpecificationFormat "OpenApi" `
            -SpecificationPath $openApiPath -Path "api"
    } else {
        Import-AzApiManagementApi -Context $apimContext -SpecificationFormat "OpenApi" `
            -SpecificationPath $openApiPath -Path "api" -ApiId $apiId
    }

    Write-Host "✓ OpenAPI spec imported" -ForegroundColor Green
} else {
    Write-Host "⚠ OpenAPI spec not found at: $openApiPath" -ForegroundColor Yellow
    Write-Host "Skipping API import. Please import manually via Azure Portal." -ForegroundColor Yellow
}
Write-Host ""

# ====================
# STEP 4: Add API to Products
# ====================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 4: Add API to Products" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$apiId = "mybartenderai-api"

Write-Host "Adding API to Free Tier..." -ForegroundColor Yellow
Add-AzApiManagementApiToProduct -Context $apimContext -ProductId "free-tier" -ApiId $apiId -ErrorAction SilentlyContinue
Write-Host "✓ API added to Free Tier" -ForegroundColor Green

Write-Host "Adding API to Premium Tier..." -ForegroundColor Yellow
Add-AzApiManagementApiToProduct -Context $apimContext -ProductId "premium-tier" -ApiId $apiId -ErrorAction SilentlyContinue
Write-Host "✓ API added to Premium Tier" -ForegroundColor Green

Write-Host "Adding API to Pro Tier..." -ForegroundColor Yellow
Add-AzApiManagementApiToProduct -Context $apimContext -ProductId "pro-tier" -ApiId $apiId -ErrorAction SilentlyContinue
Write-Host "✓ API added to Pro Tier" -ForegroundColor Green
Write-Host ""

# ====================
# STEP 5: Apply Policies
# ====================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 5: Apply Product Policies" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "NOTE: Policies must be applied manually via Azure Portal or using policy XML files" -ForegroundColor Yellow
Write-Host "Policy files are located in: infrastructure/apim/policies/" -ForegroundColor Yellow
Write-Host ""
Write-Host "Free Tier Policy: policies/free-tier-policy.xml" -ForegroundColor Cyan
Write-Host "Premium Tier Policy: policies/premium-tier-policy.xml" -ForegroundColor Cyan
Write-Host "Pro Tier Policy: policies/pro-tier-policy.xml" -ForegroundColor Cyan
Write-Host ""

# ====================
# Summary
# ====================
Write-Host "========================================" -ForegroundColor Green
Write-Host "Configuration Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Apply rate limiting policies via Azure Portal" -ForegroundColor White
Write-Host "2. Configure JWT validation policy" -ForegroundColor White
Write-Host "3. Test endpoints with subscription keys" -ForegroundColor White
Write-Host "4. Set up Developer Portal for API key management" -ForegroundColor White
Write-Host ""
Write-Host "APIM Gateway URL: $($apim.GatewayUrl)" -ForegroundColor Green
Write-Host "Developer Portal: https://$ApimServiceName.developer.azure-api.net" -ForegroundColor Green
Write-Host ""
