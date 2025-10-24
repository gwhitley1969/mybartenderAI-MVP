# Test Age Validation Function
#
# Usage:
#   .\test-age-validation.ps1 -FunctionKey "your-function-key-here"
#
# To get the function key:
#   az functionapp function keys list --name func-mba-fresh --resource-group rg-mba-prod --function-name validate-age --query "default" -o tsv

param(
    [Parameter(Mandatory=$false)]
    [string]$FunctionKey
)

$functionUrl = "https://func-mba-fresh.azurewebsites.net/api/validate-age"

# If no key provided, try to get it from Azure CLI
if ([string]::IsNullOrEmpty($FunctionKey)) {
    Write-Host "No function key provided. Attempting to retrieve from Azure CLI..." -ForegroundColor Yellow
    try {
        $FunctionKey = az functionapp function keys list --name func-mba-fresh --resource-group rg-mba-prod --function-name validate-age --query "default" -o tsv 2>$null
        if ([string]::IsNullOrEmpty($FunctionKey)) {
            Write-Host "Error: Could not retrieve function key from Azure. Please provide it as a parameter:" -ForegroundColor Red
            Write-Host "  .\test-age-validation.ps1 -FunctionKey 'your-key-here'" -ForegroundColor Yellow
            exit 1
        }
        Write-Host "Successfully retrieved function key from Azure" -ForegroundColor Green
    } catch {
        Write-Host "Error: Could not retrieve function key from Azure. Please provide it as a parameter:" -ForegroundColor Red
        Write-Host "  .\test-age-validation.ps1 -FunctionKey 'your-key-here'" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""
Write-Host "Testing Age Validation Function..." -ForegroundColor Cyan
Write-Host ""

# Test 1: Under 21 (should block)
Write-Host "Test 1: User under 21 (birthdate: 2010-01-01)" -ForegroundColor Yellow
$body1 = @{
    birthdate = "2010-01-01"
    email = "under21@example.com"
} | ConvertTo-Json

try {
    $response1 = Invoke-RestMethod -Uri "$functionUrl`?code=$functionKey" -Method Post -Body $body1 -ContentType "application/json"
    Write-Host "Response:" -ForegroundColor Green
    $response1 | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "-----------------------------------" -ForegroundColor Gray
Write-Host ""

# Test 2: Exactly 21 (should allow)
Write-Host "Test 2: User exactly 21 years old (birthdate: 2003-10-24)" -ForegroundColor Yellow
$body2 = @{
    birthdate = "2003-10-24"
    email = "exactly21@example.com"
} | ConvertTo-Json

try {
    $response2 = Invoke-RestMethod -Uri "$functionUrl`?code=$functionKey" -Method Post -Body $body2 -ContentType "application/json"
    Write-Host "Response:" -ForegroundColor Green
    $response2 | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "-----------------------------------" -ForegroundColor Gray
Write-Host ""

# Test 3: Over 21 (should allow)
Write-Host "Test 3: User over 21 (birthdate: 1990-01-01)" -ForegroundColor Yellow
$body3 = @{
    birthdate = "1990-01-01"
    email = "over21@example.com"
} | ConvertTo-Json

try {
    $response3 = Invoke-RestMethod -Uri "$functionUrl`?code=$functionKey" -Method Post -Body $body3 -ContentType "application/json"
    Write-Host "Response:" -ForegroundColor Green
    $response3 | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Testing complete!" -ForegroundColor Cyan
