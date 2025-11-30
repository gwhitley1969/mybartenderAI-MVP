# Create cocktail-preview operation on apim-mba-002
# Uses Azure REST API directly

# Get access token
$token = az account get-access-token --query accessToken -o tsv
Write-Host "Got access token"

# Get subscription ID
$subId = az account show --query id -o tsv
Write-Host "Subscription: $subId"

# Build the URI for apim-mba-002 (NOT apim-mba-001!)
$uri = "https://management.azure.com/subscriptions/$subId/resourceGroups/rg-mba-prod/providers/Microsoft.ApiManagement/service/apim-mba-002/apis/mybartenderai-api/operations/cocktail-preview?api-version=2024-05-01"
Write-Host "URI: $uri"

# Build the request body
$bodyObj = @{
    properties = @{
        displayName = "Get Cocktail Preview"
        method = "GET"
        urlTemplate = "/cocktail/{id}"
        description = "Generate HTML preview page with Open Graph tags for social sharing"
        templateParameters = @(
            @{
                name = "id"
                description = "Cocktail ID"
                type = "string"
                required = $true
            }
        )
    }
}
$body = $bodyObj | ConvertTo-Json -Depth 5
Write-Host "Body: $body"

# Headers
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

Write-Host "Making REST API call to create operation..."

try {
    $response = Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -Body $body
    Write-Host "SUCCESS!"
    Write-Host ($response | ConvertTo-Json -Depth 5)
} catch {
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)"

    if ($_.Exception.Response) {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $reader.BaseStream.Position = 0
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response Body: $responseBody"
    }
}

Write-Host "Done!"
