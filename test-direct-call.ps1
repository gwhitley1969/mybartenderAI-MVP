# Test validate-age function directly
$url = "https://func-mba-fresh.azurewebsites.net/api/validate-age"
$headers = @{
    "Authorization" = "Bearer test-token-12345"
    "Content-Type" = "application/json"
}

$body = @{
    data = @{
        userSignUpInfo = @{
            attributes = @{
                birthdate = "01051990"
                email = "test@example.com"
            }
        }
    }
} | ConvertTo-Json -Depth 10

Write-Host "Testing validate-age function directly..." -ForegroundColor Cyan
Write-Host "URL: $url"
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
