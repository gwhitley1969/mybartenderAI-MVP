# Apply APIM Product Policies for MyBartenderAI
# This script applies the rate limiting and access control policies to each subscription tier

$resourceGroup = "rg-mba-prod"
$apimName = "apim-mba-001"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Applying APIM Product Policies" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to apply policy
function Apply-Policy {
    param(
        [string]$ProductId,
        [string]$PolicyFile,
        [string]$DisplayName
    )

    Write-Host "Applying policy for $DisplayName..." -ForegroundColor Yellow

    if (Test-Path $PolicyFile) {
        $policyContent = Get-Content -Path $PolicyFile -Raw

        # Save to temp file for Azure CLI
        $tempFile = "$env:TEMP\apim-policy-temp.xml"
        $policyContent | Out-File -FilePath $tempFile -Encoding UTF8

        # Apply the policy
        $result = az apim product policy set `
            --service-name $apimName `
            --resource-group $resourceGroup `
            --product-id $ProductId `
            --policy "@$tempFile" `
            --format "xml" 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ $DisplayName policy applied successfully" -ForegroundColor Green
        } else {
            Write-Host "✗ Failed to apply $DisplayName policy" -ForegroundColor Red
            Write-Host "  Error: $result" -ForegroundColor Red
        }

        # Clean up temp file
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "✗ Policy file not found: $PolicyFile" -ForegroundColor Red
    }
    Write-Host ""
}

# Apply policies for each tier
Apply-Policy -ProductId "free-tier" `
             -PolicyFile ".\infrastructure\apim\policies\free-tier-policy-fixed.xml" `
             -DisplayName "Free Tier"

Apply-Policy -ProductId "premium-tier" `
             -PolicyFile ".\infrastructure\apim\policies\premium-tier-policy-final.xml" `
             -DisplayName "Premium Tier"

Apply-Policy -ProductId "pro-tier" `
             -PolicyFile ".\infrastructure\apim\policies\pro-tier-policy-final.xml" `
             -DisplayName "Pro Tier"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Policy Application Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# List current products and their status
Write-Host "Current APIM Products:" -ForegroundColor Yellow
az apim product list --service-name $apimName --resource-group $resourceGroup --output table