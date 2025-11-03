# Test Azure OpenAI directly
$apiKey = "a5ffbf42d3be4a3896d8b6a99a0b9564"
$endpoint = "https://mybartenderai-scus.openai.azure.com"
$deployment = "gpt-4o-mini"
$apiVersion = "2024-10-21"

$uri = "$endpoint/openai/deployments/$deployment/chat/completions?api-version=$apiVersion"

$headers = @{
    'api-key' = $apiKey
    'Content-Type' = 'application/json'
}

$body = @{
    messages = @(
        @{
            role = "system"
            content = "You are a helpful assistant."
        },
        @{
            role = "user"
            content = "Say hello in one short sentence."
        }
    )
    temperature = 0.7
    max_tokens = 50
} | ConvertTo-Json -Depth 10

Write-Host "Testing Azure OpenAI endpoint directly..." -ForegroundColor Yellow
Write-Host "URL: $uri"
Write-Host ""

try {
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
    Write-Host "SUCCESS! Azure OpenAI is working:" -ForegroundColor Green
    Write-Host "Response: $($response.choices[0].message.content)"
    Write-Host "Tokens used: $($response.usage.total_tokens)"
} catch {
    Write-Host "ERROR occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    if ($_.ErrorDetails.Message) {
        Write-Host "Error details:" -ForegroundColor Red
        Write-Host $_.ErrorDetails.Message
    }
}
