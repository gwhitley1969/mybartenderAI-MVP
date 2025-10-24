# Test validate-age function with OAuth Bearer token

$url = "https://func-mba-fresh.azurewebsites.net/api/validate-age"

Write-Host "Testing validate-age function with OAuth authentication..." -ForegroundColor Cyan
Write-Host ""

# Test with Bearer token (simulating Entra External ID custom extension)
$headers = @{
    "Authorization" = "Bearer test-token-from-entra-12345"
    "Content-Type" = "application/json"
}

$body = @{
    birthdate = "1990-01-01"
    email = "test@example.com"
} | ConvertTo-Json

Write-Host "Sending request with OAuth Bearer token..." -ForegroundColor Yellow
Write-Host "URL: $url"
Write-Host "Authorization: Bearer test-token-from-entra-12345"
Write-Host "Body: $body"
Write-Host ""

try {
    $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body
    Write-Host "SUCCESS!" -ForegroundColor Green
    Write-Host "Response:" -ForegroundColor Green
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "ERROR!" -ForegroundColor Red
    Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    Write-Host "Error Message: $($_.Exception.Message)" -ForegroundColor Red

    if ($_.ErrorDetails.Message) {
        Write-Host "Error Details:" -ForegroundColor Red
        $_.ErrorDetails.Message
    }
}
