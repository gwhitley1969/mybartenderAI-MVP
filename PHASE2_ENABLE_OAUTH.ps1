# Phase 2: Enable OAuth Validation
# Run this script AFTER Phase 1 testing succeeds

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Phase 2: Enabling OAuth Validation" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Your Tenant Information:" -ForegroundColor Yellow
Write-Host "  Tenant Name: mybartenderai" -ForegroundColor White
Write-Host "  Tenant ID: a82813af-1054-4e2d-a8ec-c6b9c2908c91" -ForegroundColor White
Write-Host "  Domain: mybartenderai.onmicrosoft.com`n" -ForegroundColor White

# Confirm before proceeding
$confirm = Read-Host "Have you completed Phase 1 testing successfully? (yes/no)"
if ($confirm -ne "yes" -and $confirm -ne "y") {
    Write-Host "`nPlease complete Phase 1 testing first. See READY_TO_TEST.md for instructions." -ForegroundColor Red
    exit
}

Write-Host "`n[Step 1/3] Configuring environment variables..." -ForegroundColor Green
az functionapp config appsettings set `
  --name func-mba-fresh `
  --resource-group rg-mba-prod `
  --settings `
    "ENTRA_TENANT_ID=a82813af-1054-4e2d-a8ec-c6b9c2908c91" `
    "ENABLE_OAUTH_VALIDATION=true"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Environment variables configured successfully`n" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to configure environment variables" -ForegroundColor Red
    exit
}

Write-Host "[Step 2/3] Restarting function app..." -ForegroundColor Green
az functionapp restart `
  --name func-mba-fresh `
  --resource-group rg-mba-prod

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Function app restarted successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to restart function app" -ForegroundColor Red
    exit
}

Write-Host "`nWaiting 30 seconds for function app to warm up..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host "`n[Step 3/3] Verifying configuration..." -ForegroundColor Green
az functionapp config appsettings list `
  --name func-mba-fresh `
  --resource-group rg-mba-prod `
  --query "[?name=='ENABLE_OAUTH_VALIDATION' || name=='ENTRA_TENANT_ID'].{Name:name, Value:value}" `
  --output table

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "OAuth Validation Enabled!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Test signup again with the same tests" -ForegroundColor White
Write-Host "2. Check function logs to verify OAuth validation" -ForegroundColor White
Write-Host "3. Look for: '[OAuth] Token validated successfully'`n" -ForegroundColor White

Write-Host "Function Logs Location:" -ForegroundColor Yellow
Write-Host "Azure Portal → func-mba-fresh → validate-age → Invocations`n" -ForegroundColor White

Write-Host "If signup fails after enabling OAuth:" -ForegroundColor Red
Write-Host "Run: .\PHASE2_DISABLE_OAUTH.ps1`n" -ForegroundColor White
