# Security Best Practices

## Never Commit Secrets

**IMPORTANT**: This repository uses Azure Key Vault for all secrets management. Never hardcode secrets in:
- Test scripts
- Configuration files
- Policy files
- Source code

## Using Secrets from Key Vault

### PowerShell Scripts

All PowerShell scripts should use the secure helper module:

```powershell
# Import the Key Vault helper
. .\scripts\Get-AzureSecrets.ps1

# Retrieve secrets at runtime
$functionKey = Get-FunctionKey
$apimKey = Get-ApimSubscriptionKey

# Use secrets in your script
Invoke-WebRequest -Uri "https://func-mba-fresh.azurewebsites.net/api/test" `
    -Headers @{"x-functions-key" = $functionKey}
```

### Available Helper Functions

- `Get-FunctionKey()` - Azure Function host key
- `Get-ApimSubscriptionKey()` - APIM subscription key
- `Get-StorageConnectionString()` - Storage account connection string
- `Get-PostgresConnectionString()` - PostgreSQL connection string
- `Get-OpenAIKey()` - Azure OpenAI API key
- `Get-OpenAIEndpoint()` - Azure OpenAI endpoint URL
- `Get-AzureSecret -SecretName "SECRET-NAME"` - Any secret by name

### Prerequisites

1. **Azure CLI**: Install from https://aka.ms/azure-cli
2. **Azure Login**: Run `az login` before using scripts
3. **Key Vault Access**: Ensure you have "Key Vault Secrets User" role on `kv-mybartenderai-prod`

### Creating Test Scripts

Create template files (committed to Git):

**File**: `test-example.template.ps1`
```powershell
# Import Key Vault helper
. .\scripts\Get-AzureSecrets.ps1

# Retrieve secrets securely
$functionKey = Get-FunctionKey

# Your test logic here
Write-Host "Testing endpoint..."
$result = Invoke-WebRequest -Uri "https://func-mba-fresh.azurewebsites.net/api/health" `
    -Headers @{"x-functions-key" = $functionKey}

Write-Host "Status: $($result.StatusCode)"
```

To use:
```powershell
# Copy template to working script (ignored by Git)
cp test-example.template.ps1 test-example.ps1

# Run the script
.\test-example.ps1
```

## Files Excluded from Git

The following patterns are in `.gitignore` to prevent secret leakage:

```gitignore
# Settings with secrets
current-settings.json
staging-settings.txt
apim-subscription-key.txt

# Test scripts (use templates)
test-*.ps1
!test-*.template.ps1

# Policy files (deploy programmatically)
*-policy.xml
!*-policy.template.xml

# Backup folders
migration-backup-*/
migration-scripts/

# Key files
*.key
*.secret
```

## Deployment Scripts

For policy deployment and configuration, use programmatic approaches:

```powershell
# Bad - Hardcoded secret
$policy = @"
<policies>
  <inbound>
    <set-backend-service backend-id="backend-apim" />
    <authentication-managed-identity resource="https://management.azure.com"
        output-token-variable-name="token" />
    <set-header name="x-functions-key" exists-action="override">
      <value>HARDCODED_SECRET_HERE</value>
    </set-header>
  </inbound>
</policies>
"@

# Good - Retrieve at deployment time
. .\scripts\Get-AzureSecrets.ps1
$functionKey = Get-FunctionKey

$policy = @"
<policies>
  <inbound>
    <set-backend-service backend-id="backend-apim" />
    <authentication-managed-identity resource="https://management.azure.com"
        output-token-variable-name="token" />
    <set-header name="x-functions-key" exists-action="override">
      <value>$functionKey</value>
    </set-header>
  </inbound>
</policies>
"@

# Deploy policy with secret injected
az apim api operation policy create --policy $policy ...
```

## Azure Key Vault Secrets

Current secrets in `kv-mybartenderai-prod`:

- `AZURE-FUNCTION-KEY` - Function App host key
- `APIM-SUBSCRIPTION-KEY` - API Management subscription key
- `AZURE-OPENAI-API-KEY` - Azure OpenAI API key
- `AZURE-OPENAI-ENDPOINT` - Azure OpenAI endpoint URL
- `POSTGRES-CONNECTION-STRING` - PostgreSQL connection string
- `STORAGE-CONNECTION-STRING` - Storage account connection string
- `COCKTAILDB-API-KEY` - TheCocktailDB API key
- `AZURE-SPEECH-KEY` - Azure Speech Services key
- `AZURE-CV-KEY` - Azure Computer Vision key

## Security Checklist

Before committing:
- [ ] No hardcoded secrets in any files
- [ ] Test scripts use `Get-AzureSecrets.ps1`
- [ ] Configuration files are in `.gitignore` or use templates
- [ ] Policy files with secrets are excluded from Git
- [ ] Deployment scripts inject secrets at runtime
- [ ] Run `git diff` to verify no secrets are staged

## GitHub Push Protection

GitHub will block pushes containing detected secrets. If this happens:

1. **Never bypass** using the "allow secret" URL
2. Reset the commit: `git reset HEAD~1`
3. Add secret-containing files to `.gitignore`
4. Use the secure helper module instead
5. Commit again without secrets

## Incident Response

If a secret is accidentally committed:

1. **Immediately rotate the secret** in Azure Key Vault
2. Update the secret in Key Vault with a new value
3. Remove the secret from Git history:
   ```bash
   # Use BFG Repo-Cleaner or git filter-branch
   ```
4. Force push the cleaned history (coordinate with team)
5. Verify all deployed systems still function with new secret

## Questions?

See the Key Vault helper script: `scripts/Get-AzureSecrets.ps1`
