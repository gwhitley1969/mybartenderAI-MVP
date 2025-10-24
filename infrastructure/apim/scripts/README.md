# APIM Policy Deployment Scripts

This directory contains scripts for deploying and managing APIM policies.

## apply-jwt-policies.ps1

Automatically applies JWT validation policies to Premium/Pro tier operations in Azure API Management.

### Prerequisites

- Azure CLI installed and authenticated (`az login`)
- PowerShell 5.1 or PowerShell Core 7+
- Appropriate permissions on the APIM instance

### Usage

**Dry run (test without making changes):**
```powershell
cd infrastructure/apim/scripts
.\apply-jwt-policies.ps1 -DryRun
```

**Apply policies:**
```powershell
.\apply-jwt-policies.ps1
```

**Custom resource group/APIM:**
```powershell
.\apply-jwt-policies.ps1 -ResourceGroup "rg-mba-prod" -ApimServiceName "apim-mba-001" -ApiId "mybartenderai-api"
```

### What It Does

1. **Applies JWT validation to Premium/Pro operations:**
   - `askBartender` (POST /v1/ask-bartender)
   - `recommendCocktails` (POST /v1/recommend)
   - `getSpeechToken` (GET /v1/speech/token)

2. **Skips public operations (no JWT needed):**
   - `getLatestSnapshot` (GET /v1/snapshots/latest)
   - `getHealth` (GET /health)
   - `getImageManifest` (GET /v1/images/manifest)
   - `triggerSync` (POST /v1/admin/sync - uses function key)

3. **JWT Policy Features:**
   - Validates tokens from Entra External ID
   - Checks token signature, expiration, audience, issuer
   - Extracts user info to headers (X-User-Id, X-User-Email, X-User-Name)
   - Returns 401 with JSON error for auth failures

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-ResourceGroup` | string | `rg-mba-prod` | Azure resource group name |
| `-ApimServiceName` | string | `apim-mba-001` | APIM service name |
| `-ApiId` | string | `mybartenderai-api` | API identifier in APIM |
| `-DryRun` | switch | `false` | Test mode - shows what would be done without making changes |

### Output

The script provides detailed output:
- Lists each operation being processed
- Shows whether JWT policy is applied or skipped
- Displays summary of successes, skips, and failures
- Suggests next steps

Example output:
```
================================================
  JWT Policy Deployment Script
================================================

Configuration:
  Resource Group: rg-mba-prod
  APIM Service: apim-mba-001
  API: mybartenderai-api
  Dry Run: False

Processing operation: askBartender
  Type: Premium/Pro (requires JWT)
  Applying JWT validation policy...
  ✓ Policy applied successfully

...

Summary:
JWT policies applied:  3
Operations skipped:    4
Failures:              0

Deployment complete!
```

### Troubleshooting

**Error: "Failed to get access token"**
- Run `az login` to authenticate
- Verify you have access to the subscription

**Error: "Policy application failed"**
- Check you have Contributor or API Management Service Contributor role
- Verify resource group and APIM service name are correct
- Check Azure CLI is up to date: `az upgrade`

**Warning: "Could not get existing policy"**
- Normal if operation has no policy yet
- Policy will be created from template

### Testing After Deployment

**Test JWT validation (should fail without token):**
```powershell
curl -X POST https://apim-mba-001.azure-api.net/api/v1/ask-bartender `
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY" `
  -H "Content-Type: application/json" `
  -d '{"query": "How do I make a Negroni?"}'
```

Expected: `401 Unauthorized`

**Test public endpoint (should work without JWT):**
```powershell
curl https://apim-mba-001.azure-api.net/api/v1/snapshots/latest `
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY"
```

Expected: `200 OK` with snapshot data

### Rollback

To remove JWT validation from an operation:

1. Go to Azure Portal → APIM → APIs → MyBartenderAI API
2. Select the operation
3. Click **</>** in Inbound processing
4. Remove the `<validate-jwt>` section
5. Save

Or re-run the script with a policy file containing only `<base />`.

---

## Related Documentation

- [JWT Policy Template](../policies/jwt-validation-entra-external-id.xml)
- [Deployment Guide](../JWT_POLICY_DEPLOYMENT_GUIDE.md)
- [Entra External ID Configuration](../../docs/authentication-setup-corrected.md)
