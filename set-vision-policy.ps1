# Set APIM operation policy for vision-analyze using PowerShell cmdlets
Write-Host "Setting up APIM policy for vision-analyze operation..." -ForegroundColor Cyan

# Create APIM context
$apimContext = New-AzApiManagementContext -ResourceGroupName "rg-mba-prod" -ServiceName "apim-mba-002"

# Define the policy XML
$policyXml = @'
<policies>
  <inbound>
    <base />
    <rewrite-uri template="/vision-analyze" copy-unmatched-params="true" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
'@

# Set the operation policy
Write-Host "Applying path rewrite policy..." -ForegroundColor Yellow
Set-AzApiManagementPolicy -Context $apimContext -ApiId "mybartenderai-api" -OperationId "a366ba59a02243e69233d598b095ab86" -Policy $policyXml

Write-Host "[SUCCESS] Policy applied successfully!" -ForegroundColor Green
Write-Host "APIM will now rewrite /v1/vision/analyze to /vision-analyze when calling the backend" -ForegroundColor Cyan
