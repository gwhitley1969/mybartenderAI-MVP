# Apply APIM Policies using Azure REST API
$subscriptionId = az account show --query id -o tsv
$resourceGroup = "rg-mba-prod"
$apimName = "apim-mba-001"
$apiVersion = "2022-08-01"

# Get Azure access token
$token = az account get-access-token --query accessToken -o tsv

function Apply-ProductPolicy {
    param($productId, $policyFile)

    $policyContent = Get-Content $policyFile -Raw
    $policyContent = $policyContent -replace '"', '\"' -replace "`r`n", "\n"

    $body = @{
        properties = @{
            value = $policyContent
            format = "xml"
        }
    } | ConvertTo-Json -Depth 10

    $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.ApiManagement/service/$apimName/products/$productId/policies/policy?api-version=$apiVersion"

    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }

    Write-Host "Applying policy for $productId..." -ForegroundColor Yellow

    try {
        $response = Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -Body $body
        Write-Host "✓ $productId policy applied successfully" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to apply $productId policy: $_" -ForegroundColor Red
    }
}

# Apply all policies
Apply-ProductPolicy "free-tier" ".\infrastructure\apim\policies\free-tier-policy-fixed.xml"
Apply-ProductPolicy "premium-tier" ".\infrastructure\apim\policies\premium-tier-policy-final.xml"
Apply-ProductPolicy "pro-tier" ".\infrastructure\apim\policies\pro-tier-policy-final.xml"

Write-Host "`nPolicy application complete!" -ForegroundColor Cyan