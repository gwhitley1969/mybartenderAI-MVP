# This script will help us understand what Azure is doing after consent

Write-Host "CRITICAL DIAGNOSTIC TEST" -ForegroundColor Red
Write-Host "========================" -ForegroundColor Red
Write-Host ""
Write-Host "When you reach the consent screen and it hangs after clicking Continue:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. BEFORE closing the browser, look at the URL bar" -ForegroundColor Cyan
Write-Host "2. Take a screenshot of the ENTIRE browser window showing the URL" -ForegroundColor Cyan
Write-Host "3. Try these in the browser's address bar while it's hung:" -ForegroundColor Cyan
Write-Host ""
Write-Host "   - Press F12 to open Developer Tools" -ForegroundColor Green
Write-Host "   - Go to Network tab" -ForegroundColor Green
Write-Host "   - Look for any redirect attempts" -ForegroundColor Green
Write-Host ""
Write-Host "4. Also try long-pressing the browser back button to see navigation history" -ForegroundColor Cyan
Write-Host ""
Write-Host "The URL after clicking Continue will tell us if Azure is:" -ForegroundColor Yellow
Write-Host "  - Not redirecting at all (URL stays on ciamlogin.com)" -ForegroundColor White
Write-Host "  - Trying to redirect but failing (URL changes to mybartenderai://auth)" -ForegroundColor White
Write-Host "  - Redirecting to wrong URL (URL shows something unexpected)" -ForegroundColor White