# Monitor Front Door deployment and test endpoint
# This template demonstrates Azure CLI usage without embedded secrets

Write-Host ""
Write-Host "Monitoring Front Door deployment..." -ForegroundColor Cyan
Write-Host ""

for ($i = 1; $i -le 6; $i++) {
    Write-Host "Check $i/6 - Waiting 30 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30

    $status = az afd origin show `
        --resource-group rg-mba-prod `
        --profile-name fd-mba-share `
        --origin-group-name og-apim `
        --origin-name origin-apim `
        --query "deploymentStatus" `
        -o tsv

    Write-Host "Deployment Status: $status" -ForegroundColor White

    if ($status -ne "NotStarted") {
        Write-Host ""
        Write-Host "[UPDATE] Deployment status changed!" -ForegroundColor Green
        Write-Host "New status: $status" -ForegroundColor Cyan
        break
    }
}

Write-Host ""
Write-Host "Testing snapshots endpoint..." -ForegroundColor Cyan
Write-Host ""

try {
    $result = Invoke-WebRequest `
        -Uri "https://share.mybartenderai.com/api/v1/snapshots/latest" `
        -Method Get `
        -TimeoutSec 10

    Write-Host "[SUCCESS] Snapshots endpoint is now working!" -ForegroundColor Green
    Write-Host "Status Code: $($result.StatusCode)" -ForegroundColor White
} catch {
    Write-Host "[FAILED] Snapshots endpoint still returning 404" -ForegroundColor Red
    Write-Host "Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    Write-Host ""
    Write-Host "The deployment may need more time to propagate globally." -ForegroundColor Yellow
}
