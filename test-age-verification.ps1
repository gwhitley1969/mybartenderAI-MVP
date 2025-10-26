# Test Age Verification Function
# Tests the validate-age endpoint with different scenarios

$endpoint = "https://func-mba-fresh.azurewebsites.net/api/validate-age"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Testing Age Verification Function" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Test 1: Under-21 User (Should Block)
Write-Host "[TEST 1] Under-21 User (Birthdate: 01/05/2010)" -ForegroundColor Yellow
$body1 = @{
    type = "microsoft.graph.authenticationEvent.attributeCollectionSubmit"
    data = @{
        userSignUpInfo = @{
            attributes = @{
                birthdate = @{ value = "01/05/2010" }
                email = @{ value = "test-under21@example.com" }
            }
        }
    }
} | ConvertTo-Json -Depth 10

try {
    $response1 = Invoke-WebRequest -Uri $endpoint -Method POST -Body $body1 -ContentType "application/json" -Headers @{ "Authorization" = "Bearer test-token" } -UseBasicParsing
    Write-Host "Status Code: $($response1.StatusCode)" -ForegroundColor Green
    Write-Host "Content-Type: $($response1.Headers['Content-Type'])" -ForegroundColor Green
    $jsonResponse1 = $response1.Content | ConvertFrom-Json
    Write-Host "Response Message: $($jsonResponse1.data.actions[0].message)" -ForegroundColor Cyan
    Write-Host "Expected: Should BLOCK (under 21)" -ForegroundColor Magenta
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host "`n----------------------------------------`n"

# Test 2: 21+ User (Should Allow)
Write-Host "[TEST 2] 21+ User (Birthdate: 01/05/1990)" -ForegroundColor Yellow
$body2 = @{
    type = "microsoft.graph.authenticationEvent.attributeCollectionSubmit"
    data = @{
        userSignUpInfo = @{
            attributes = @{
                birthdate = @{ value = "01/05/1990" }
                email = @{ value = "test-over21@example.com" }
            }
        }
    }
} | ConvertTo-Json -Depth 10

try {
    $response2 = Invoke-WebRequest -Uri $endpoint -Method POST -Body $body2 -ContentType "application/json" -Headers @{ "Authorization" = "Bearer test-token" } -UseBasicParsing
    Write-Host "Status Code: $($response2.StatusCode)" -ForegroundColor Green
    Write-Host "Content-Type: $($response2.Headers['Content-Type'])" -ForegroundColor Green
    $jsonResponse2 = $response2.Content | ConvertFrom-Json
    Write-Host "Action Type: $($jsonResponse2.data.actions[0].'@odata.type')" -ForegroundColor Cyan
    Write-Host "Expected: Should ALLOW (continueWithDefaultBehavior)" -ForegroundColor Magenta
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host "`n----------------------------------------`n"

# Test 3: Extension Attribute with GUID (Simulates Entra format)
Write-Host "[TEST 3] Extension Attribute with GUID (Birthdate: 05/15/1985)" -ForegroundColor Yellow
$body3 = @{
    type = "microsoft.graph.authenticationEvent.attributeCollectionSubmit"
    data = @{
        userSignUpInfo = @{
            attributes = @{
                "extension_df9fd4be0b514fb38b2b3bedc47318a1_DateofBirth" = @{ value = "05/15/1985" }
                email = @{ value = "test-extension@example.com" }
            }
        }
    }
} | ConvertTo-Json -Depth 10

try {
    $response3 = Invoke-WebRequest -Uri $endpoint -Method POST -Body $body3 -ContentType "application/json" -Headers @{ "Authorization" = "Bearer test-token" } -UseBasicParsing
    Write-Host "Status Code: $($response3.StatusCode)" -ForegroundColor Green
    Write-Host "Content-Type: $($response3.Headers['Content-Type'])" -ForegroundColor Green
    $jsonResponse3 = $response3.Content | ConvertFrom-Json
    Write-Host "Action Type: $($jsonResponse3.data.actions[0].'@odata.type')" -ForegroundColor Cyan
    Write-Host "Expected: Should ALLOW (continueWithDefaultBehavior)" -ForegroundColor Magenta
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host "`n----------------------------------------`n"

# Test 4: Invalid Date Format
Write-Host "[TEST 4] Invalid Date Format (Birthdate: invalid-date)" -ForegroundColor Yellow
$body4 = @{
    type = "microsoft.graph.authenticationEvent.attributeCollectionSubmit"
    data = @{
        userSignUpInfo = @{
            attributes = @{
                birthdate = @{ value = "invalid-date" }
                email = @{ value = "test-invalid@example.com" }
            }
        }
    }
} | ConvertTo-Json -Depth 10

try {
    $response4 = Invoke-WebRequest -Uri $endpoint -Method POST -Body $body4 -ContentType "application/json" -Headers @{ "Authorization" = "Bearer test-token" } -UseBasicParsing
    Write-Host "Status Code: $($response4.StatusCode)" -ForegroundColor Green
    Write-Host "Content-Type: $($response4.Headers['Content-Type'])" -ForegroundColor Green
    $jsonResponse4 = $response4.Content | ConvertFrom-Json
    Write-Host "Response Message: $($jsonResponse4.data.actions[0].message)" -ForegroundColor Cyan
    Write-Host "Expected: Should BLOCK (invalid format)" -ForegroundColor Magenta
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Testing Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "`nKey Points to Verify:" -ForegroundColor Yellow
Write-Host "1. All responses should return HTTP 200 status" -ForegroundColor White
Write-Host "2. All responses should have Content-Type: application/json" -ForegroundColor White
Write-Host "3. Under-21 should be blocked with showBlockPage" -ForegroundColor White
Write-Host "4. 21+ should be allowed with continueWithDefaultBehavior" -ForegroundColor White
Write-Host "5. Extension attributes with GUID prefix should be handled correctly`n" -ForegroundColor White
