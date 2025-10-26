# Disable OAuth Validation (Rollback to Phase 1)
# Use this if OAuth validation causes issues

Write-Host "`n========================================" -ForegroundColor Red
Write-Host "Disabling OAuth Validation (Rollback)" -ForegroundColor Red
Write-Host "========================================`n" -ForegroundColor Red

Write-Host "This will revert to Phase 1 configuration (OAuth disabled)`n" -ForegroundColor Yellow

$confirm = Read-Host "Are you sure you want to disable OAuth validation? (yes/no)"
if ($confirm -ne "yes" -and $confirm -ne "y") {
    Write-Host "`nRollback cancelled." -ForegroundColor Yellow
    exit
}

Write-Host "`n[Step 1/2] Disabling OAuth validation..." -ForegroundColor Yellow
az functionapp config appsettings set `
  --name func-mba-fresh `
  --resource-group rg-mba-prod `
  --settings "ENABLE_OAUTH_VALIDATION=false"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ OAuth validation disabled`n" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to disable OAuth validation" -ForegroundColor Red
    exit
}

Write-Host "[Step 2/2] Restarting function app..." -ForegroundColor Yellow
az functionapp restart `
  --name func-mba-fresh `
  --resource-group rg-mba-prod

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Function app restarted successfully`n" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to restart function app" -ForegroundColor Red
    exit
}

Write-Host "Waiting 30 seconds for function app to warm up..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Rollback Complete - OAuth Disabled" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Configuration reverted to Phase 1 (OAuth validation disabled)" -ForegroundColor White
Write-Host "You can now test signup again without OAuth validation.`n" -ForegroundColor White
