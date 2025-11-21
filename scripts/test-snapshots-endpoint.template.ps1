# Test snapshots endpoint via Front Door
# This template demonstrates secure secret retrieval from Azure Key Vault

# Import Key Vault helper
. "$PSScriptRoot\Get-AzureSecrets.ps1"

Write-Host ""
Write-Host "Testing snapshots endpoint via Front Door..." -ForegroundColor Cyan
Write-Host ""

try {
    $result = Invoke-WebRequest `
        -Uri "https://share.mybartenderai.com/api/v1/snapshots/latest" `
        -Method Get `
        -TimeoutSec 10

    Write-Host "[SUCCESS] Snapshots endpoint is reachable!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Status Code: $($result.StatusCode)" -ForegroundColor White
    Write-Host "Content-Type: $($result.Headers['Content-Type'])" -ForegroundColor White
    Write-Host "Content-Length: $($result.Headers['Content-Length']) bytes" -ForegroundColor White

    # Check if we got JSON
    if ($result.Headers['Content-Type'] -like '*application/json*') {
        $json = $result.Content | ConvertFrom-Json
        Write-Host ""
        Write-Host "Response preview:" -ForegroundColor Yellow
        Write-Host "Timestamp: $($json.timestamp)" -ForegroundColor Cyan
        Write-Host "Cocktail count: $($json.cocktails.Count)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "[FAILED] Snapshots endpoint error" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

    if ($_.Exception.Response) {
        Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    }
}
