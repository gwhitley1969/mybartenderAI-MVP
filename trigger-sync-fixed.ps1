# Read function key from environment variable
# Set this before running: $env:AZURE_FUNCTION_ADMIN_KEY = "your-admin-key-here"
$functionKey = $env:AZURE_FUNCTION_ADMIN_KEY
if (-not $functionKey) {
    Write-Error "AZURE_FUNCTION_ADMIN_KEY environment variable not set"
    exit 1
}
$uri = "https://func-mba-fresh.azurewebsites.net/admin/functions/sync-cocktaildb?code=$functionKey"
$body = @{
    input = ""
} | ConvertTo-Json

try {
    $response = Invoke-WebRequest -Uri $uri -Method Post -Body $body -ContentType "application/json"
    Write-Host "Status Code: $($response.StatusCode)"
    Write-Host "Status Description: $($response.StatusDescription)"
    Write-Host "Response:"
    Write-Host $response.Content
} catch {
    Write-Host "Error: $_"
    if ($_.Exception.Response) {
        Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)"
    }
}
