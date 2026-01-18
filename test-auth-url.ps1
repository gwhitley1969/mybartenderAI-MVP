$authUrl = 'https://mybartenderai.ciamlogin.com/a82813af-1054-4e2d-a8ec-c6b9c2908c91/oauth2/v2.0/authorize'
$params = @{
    'client_id' = 'f9f7f159-b847-4211-98c9-18e5b8193045'
    'response_type' = 'code'
    'redirect_uri' = 'mybartenderai://auth'
    'response_mode' = 'query'
    'scope' = 'openid profile email'
    'state' = 'test123'
    'nonce' = 'test456'
    'prompt' = 'select_account'
}
$queryString = ($params.GetEnumerator() | ForEach-Object { "$($_.Key)=$([System.Uri]::EscapeDataString($_.Value))" }) -join '&'
$fullUrl = "$authUrl`?$queryString"
Write-Host "Test this URL in Chrome on your phone:" -ForegroundColor Green
Write-Host ""
Write-Host $fullUrl -ForegroundColor Cyan
Write-Host ""
Write-Host "Copy this URL and open it in Chrome on your Samsung Flip 6"
Write-Host "Tell me what happens after you click Continue on the consent screen"