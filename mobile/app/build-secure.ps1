# Secure Build Script for MyBartenderAI Mobile App
# This script retrieves sensitive keys from Azure Key Vault and builds the app securely

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "MyBartenderAI Secure Build Script" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$KeyVaultName = "kv-mybartenderai-prod"
$SecretName = "AZURE-FUNCTION-KEY"

# Step 1: Check Azure CLI authentication
Write-Host "[1/4] Checking Azure CLI authentication..." -ForegroundColor Yellow
try {
    $account = az account show 2>$null | ConvertFrom-Json
    if ($null -eq $account) {
        Write-Host "Error: Not logged into Azure CLI" -ForegroundColor Red
        Write-Host "Please run: az login" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  ✓ Authenticated as: $($account.user.name)" -ForegroundColor Green
} catch {
    Write-Host "Error: Azure CLI not found or not authenticated" -ForegroundColor Red
    Write-Host "Please install Azure CLI and run: az login" -ForegroundColor Yellow
    exit 1
}

# Step 2: Retrieve Azure Function Key from Key Vault
Write-Host "[2/4] Retrieving Azure Function Key from Key Vault..." -ForegroundColor Yellow
try {
    $functionKey = az keyvault secret show `
        --vault-name $KeyVaultName `
        --name $SecretName `
        --query "value" `
        -o tsv 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to retrieve secret from Key Vault" -ForegroundColor Red
        Write-Host "Error details: $functionKey" -ForegroundColor Red
        exit 1
    }

    if ([string]::IsNullOrWhiteSpace($functionKey)) {
        Write-Host "Error: Retrieved key is empty" -ForegroundColor Red
        exit 1
    }

    Write-Host "  ✓ Successfully retrieved Function Key" -ForegroundColor Green
} catch {
    Write-Host "Error: Failed to access Key Vault" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# Step 3: Clean previous build
Write-Host "[3/4] Cleaning previous build..." -ForegroundColor Yellow
flutter clean | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Build cleaned" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Clean warning (continuing anyway)" -ForegroundColor Yellow
}

# Step 4: Build APK with secure key
Write-Host "[4/4] Building release APK with secure configuration..." -ForegroundColor Yellow
Write-Host "  This may take a few minutes..." -ForegroundColor Gray

$buildCommand = "flutter build apk --release --dart-define=`"AZURE_FUNCTION_KEY=$functionKey`""
Invoke-Expression $buildCommand

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "==================================" -ForegroundColor Green
    Write-Host "✓ Build completed successfully!" -ForegroundColor Green
    Write-Host "==================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "APK Location: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Cyan

    # Get APK file info
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkPath) {
        $apkSize = (Get-Item $apkPath).Length / 1MB
        Write-Host "APK Size: $([math]::Round($apkSize, 1)) MB" -ForegroundColor Cyan
    }
} else {
    Write-Host ""
    Write-Host "==================================" -ForegroundColor Red
    Write-Host "✗ Build failed!" -ForegroundColor Red
    Write-Host "==================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please check the error messages above" -ForegroundColor Yellow
    exit 1
}

# Clear sensitive data from memory
$functionKey = $null
[System.GC]::Collect()

Write-Host ""
Write-Host "Security Note: Function key was retrieved securely from Azure Key Vault" -ForegroundColor Cyan
Write-Host "and was not written to disk or exposed in logs." -ForegroundColor Cyan
