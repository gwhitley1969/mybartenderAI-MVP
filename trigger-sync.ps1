$headers = @{
    'x-functions-key' = 'YOUR_FUNCTION_MASTER_KEY_HERE'
    'Content-Type' = 'application/json'
}

$response = Invoke-WebRequest -Uri 'https://func-mba-fresh.azurewebsites.net/admin/functions/sync-cocktaildb' `
    -Method POST `
    -Headers $headers `
    -Body '{}' `
    -UseBasicParsing

Write-Host "Status Code: $($response.StatusCode)"
Write-Host "Status Description: $($response.StatusDescription)"
Write-Host "Response: $($response.Content)"
