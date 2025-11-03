# Test ask-bartender-simple endpoint
# Read function key from environment variable
# Set this before running: $env:AZURE_FUNCTION_KEY = "your-function-key-here"
$functionKey = $env:AZURE_FUNCTION_KEY
if (-not $functionKey) {
    Write-Error "AZURE_FUNCTION_KEY environment variable not set"
    exit 1
}
$headers = @{
    'x-functions-key' = $functionKey
    'Content-Type' = 'application/json'
}

$body = @{
    message = "test"
} | ConvertTo-Json

$uri = 'https://func-mba-fresh.azurewebsites.net/api/v1/ask-bartender-simple'

Write-Host "Testing ask-bartender-simple endpoint..." -ForegroundColor Yellow
Write-Host "URL: $uri"
Write-Host ""

try {
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -ErrorAction Stop
    Write-Host "SUCCESS!" -ForegroundColor Green
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "ERROR occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    if ($_.ErrorDetails.Message) {
        Write-Host "Error details:" -ForegroundColor Yellow
        Write-Host $_.ErrorDetails.Message
    }
}
