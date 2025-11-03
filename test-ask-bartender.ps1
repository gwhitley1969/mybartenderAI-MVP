# Test ask-bartender-test endpoint
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
    message = "How do I make a mojito?"
    context = @{
        conversationId = "test-123"
    }
} | ConvertTo-Json

$uri = 'https://func-mba-fresh.azurewebsites.net/api/v1/ask-bartender-test'

Write-Host "Testing ask-bartender-test endpoint..." -ForegroundColor Yellow
Write-Host "URL: $uri"
Write-Host "Body: $body"
Write-Host ""

try {
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
    Write-Host "SUCCESS! Response received:" -ForegroundColor Green
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "ERROR occurred:" -ForegroundColor Red
    Write-Host "Status Code:" $_.Exception.Response.StatusCode.value__
    Write-Host "Message:" $_.Exception.Message
    if ($_.ErrorDetails.Message) {
        Write-Host "`nError details:" -ForegroundColor Yellow
        try {
            $errorObj = $_.ErrorDetails.Message | ConvertFrom-Json
            $errorObj | ConvertTo-Json -Depth 10
        } catch {
            Write-Host $_.ErrorDetails.Message
        }
    }
}