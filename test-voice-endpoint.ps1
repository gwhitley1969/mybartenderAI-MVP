$body = @{
    audioData = 'dGVzdA=='
    voicePreference = 'en-US-JennyNeural'
    context = @{}
} | ConvertTo-Json

$headers = @{
    'Content-Type' = 'application/json'
    'x-functions-key' = $env:AZURE_FUNCTION_KEY  # Set this environment variable with your key
}

try {
    $response = Invoke-RestMethod -Uri 'https://func-mba-fresh.azurewebsites.net/api/v1/voice-bartender' -Method Post -Body $body -Headers $headers -ErrorAction Stop
    Write-Host "Success:"
    $response | ConvertTo-Json -Depth 5
} catch {
    Write-Host "Error occurred:"
    Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)"
    Write-Host "Status Description: $($_.Exception.Response.StatusDescription)"
    $_.Exception.Response.GetResponseStream() | ForEach-Object {
        $reader = New-Object System.IO.StreamReader($_)
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response Body: $responseBody"
    }
}
