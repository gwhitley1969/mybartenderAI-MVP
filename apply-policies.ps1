# Apply APIM Policies Script

$resourceGroup = "rg-mba-prod"
$apimName = "apim-mba-001"

# Apply Free Tier Policy
Write-Host "Applying Free Tier Policy..." -ForegroundColor Green
$freeTierPolicy = Get-Content -Path ".\infrastructure\apim\policies\free-tier-policy-fixed.xml" -Raw
az apim product policy set `
    --service-name $apimName `
    --resource-group $resourceGroup `
    --product-id "free-tier" `
    --policy $freeTierPolicy `
    --format "xml"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Free Tier policy applied successfully" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to apply Free Tier policy" -ForegroundColor Red
}

# Apply Premium Tier Policy
Write-Host "Applying Premium Tier Policy..." -ForegroundColor Green
$premiumTierPolicy = Get-Content -Path ".\infrastructure\apim\policies\premium-tier-policy-final.xml" -Raw
az apim product policy set `
    --service-name $apimName `
    --resource-group $resourceGroup `
    --product-id "premium-tier" `
    --policy $premiumTierPolicy `
    --format "xml"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Premium Tier policy applied successfully" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to apply Premium Tier policy" -ForegroundColor Red
}

# Apply Pro Tier Policy
Write-Host "Applying Pro Tier Policy..." -ForegroundColor Green
$proTierPolicy = Get-Content -Path ".\infrastructure\apim\policies\pro-tier-policy-final.xml" -Raw
az apim product policy set `
    --service-name $apimName `
    --resource-group $resourceGroup `
    --product-id "pro-tier" `
    --policy $proTierPolicy `
    --format "xml"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Pro Tier policy applied successfully" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to apply Pro Tier policy" -ForegroundColor Red
}

Write-Host ""
Write-Host "Policy application complete!" -ForegroundColor Cyan

# Verify policies are applied
Write-Host ""
Write-Host "Verifying applied policies..." -ForegroundColor Yellow
Write-Host "Free Tier: " -NoNewline
az apim product policy show --service-name $apimName --resource-group $resourceGroup --product-id "free-tier" --query "format" -o tsv

Write-Host "Premium Tier: " -NoNewline
az apim product policy show --service-name $apimName --resource-group $resourceGroup --product-id "premium-tier" --query "format" -o tsv

Write-Host "Pro Tier: " -NoNewline
az apim product policy show --service-name $apimName --resource-group $resourceGroup --product-id "pro-tier" --query "format" -o tsv