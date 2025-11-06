# Test OAuth URLs to understand the redirect flow

$tenantName = "mybartenderai"
$tenantId = "a82813af-1054-4e2d-a8ec-c6b9c2908c91"
$clientId = "f9f7f159-b847-4211-98c9-18e5b8193045"
$redirectUri = [System.Web.HttpUtility]::UrlEncode("com.mybartenderai.app://oauth/redirect")
$userFlow = "mba-signin-signup"

Write-Host "Testing different OAuth URL patterns for Entra External ID:" -ForegroundColor Green
Write-Host ""

Write-Host "1. WITH policy in path (Azure AD B2C style):" -ForegroundColor Yellow
$url1 = "https://$tenantName.ciamlogin.com/$tenantId/$userFlow/oauth2/v2.0/authorize?client_id=$clientId&redirect_uri=$redirectUri&response_type=code&scope=openid%20profile&response_mode=query&p=$userFlow"
Write-Host $url1
Write-Host ""

Write-Host "2. WITHOUT policy in path (Standard OAuth):" -ForegroundColor Yellow
$url2 = "https://$tenantName.ciamlogin.com/$tenantId/oauth2/v2.0/authorize?client_id=$clientId&redirect_uri=$redirectUri&response_type=code&scope=openid%20profile&response_mode=query&p=$userFlow"
Write-Host $url2
Write-Host ""

Write-Host "3. Check if the redirect URI needs to be in a different format:" -ForegroundColor Cyan
Write-Host "  Current: com.mybartenderai.app://oauth/redirect"
Write-Host "  MSAL format: msalf9f7f159-b847-4211-98c9-18e5b8193045://auth"
Write-Host ""

Write-Host "CRITICAL:" -ForegroundColor Red
Write-Host "The redirect URI in Azure Portal MUST match EXACTLY what we send."
Write-Host "Even a trailing slash difference will cause the GET error."
Write-Host ""
Write-Host "Please verify in Azure Portal:"
Write-Host "1. Go to App registrations -> MyBartenderAI Mobile -> Authentication"
Write-Host "2. Check EXACTLY what redirect URIs are registered"
Write-Host "3. Make sure one of them is: com.mybartenderai.app://oauth/redirect"