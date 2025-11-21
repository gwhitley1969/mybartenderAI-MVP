$subscriptionId = az account show --query id -o tsv

$policyJson = @{
  properties = @{
    format = 'rawxml'
    value = '<policies><inbound><base /><rewrite-uri template="/vision-analyze" copy-unmatched-params="true" /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
  }
} | ConvertTo-Json -Depth 10

# Write JSON to file with UTF-8 encoding WITHOUT BOM
$tempFile = "temp-policy.json"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($tempFile, $policyJson, $utf8NoBom)

$url = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/rg-mba-prod/providers/Microsoft.ApiManagement/service/apim-mba-002/apis/mybartenderai-api/operations/a366ba59a02243e69233d598b095ab86/policies/policy?api-version=2021-08-01"

Write-Host "Applying path rewrite policy to vision-analyze operation..." -ForegroundColor Cyan
Write-Host "Temp file: $tempFile" -ForegroundColor Yellow
Write-Host "File contents:" -ForegroundColor Yellow
Get-Content $tempFile | Write-Host

$result = az rest --method put --url $url --body "@$tempFile" --headers "Content-Type=application/json" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] Policy applied successfully!" -ForegroundColor Green
    Write-Host "APIM will now rewrite /v1/vision/analyze to /vision-analyze" -ForegroundColor Cyan
    Remove-Item $tempFile -ErrorAction SilentlyContinue
} else {
    Write-Host "[FAILED] Failed to apply policy - Exit code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host "Error output:" -ForegroundColor Red
    $result | Write-Host
    Write-Host "Temp file left for inspection: $tempFile" -ForegroundColor Yellow
}
