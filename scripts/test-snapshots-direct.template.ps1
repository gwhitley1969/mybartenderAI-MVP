# Test snapshots function directly (bypassing APIM and Front Door)
# This template demonstrates secure secret retrieval from Azure Key Vault

# Import Key Vault helper
. "$PSScriptRoot\Get-AzureSecrets.ps1"

Write-Host ""
Write-Host "Testing snapshots function directly..." -ForegroundColor Cyan
Write-Host ""

# Retrieve Function Key from Key Vault
Write-Host "Retrieving Function Key from Key Vault..." -ForegroundColor Yellow
$functionKey = Get-FunctionKey

if ([string]::IsNullOrWhiteSpace($functionKey)) {
    Write-Host "[ERROR] Failed to retrieve Function Key from Key Vault" -ForegroundColor Red
    exit 1
}

try {
    $result = Invoke-WebRequest `
        -Uri "https://func-mba-fresh.azurewebsites.net/api/v1/snapshots/latest" `
        -Method Get `
        -Headers @{
            "x-functions-key" = $functionKey
        } `
        -TimeoutSec 15

    Write-Host "[SUCCESS] Direct function call works!" -ForegroundColor Green
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
    Write-Host "[FAILED] Direct function call failed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

    if ($_.Exception.Response) {
        Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    }
}
