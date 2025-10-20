# Storage Write Access Fix for func-mba-fresh

## Problem
Azure Function App `func-mba-fresh` is experiencing errors when writing to storage account `mbacocktaildb3` using Managed Identity `func-cocktaildb2-uami`.

## Root Causes

The write errors are typically caused by one or more of these issues:

1. **Missing Environment Variables**: The function app needs specific configuration
2. **Missing RBAC Role Assignments**: The managed identity needs permissions
3. **Managed Identity Not Assigned**: The identity might not be assigned to the function app
4. **Network/Firewall Issues**: Storage account might be blocking the function app

## Quick Diagnosis

### Option 1: Run the Diagnostic Script
```powershell
# Diagnose only (no changes)
./fix-storage-write-access.ps1 -DiagnoseOnly

# Diagnose and fix automatically
./fix-storage-write-access.ps1 -Apply
```

### Option 2: Test Write Function
Call the test-write endpoint to see detailed diagnostics:
```bash
curl https://func-mba-fresh.azurewebsites.net/api/test-write
```

This will return:
- Current environment variable configuration
- Specific error details
- Actionable suggestions for fixing the issue

## Manual Fix Steps

### Step 1: Verify Environment Variables

Check that these settings exist in the Function App:

```powershell
az functionapp config appsettings list \
  --name func-mba-fresh \
  --resource-group rg-mba-prod \
  --query "[?name=='STORAGE_ACCOUNT_NAME' || name=='AZURE_CLIENT_ID' || name=='SNAPSHOT_CONTAINER_NAME']"
```

**Required settings:**
- `STORAGE_ACCOUNT_NAME=mbacocktaildb3`
- `AZURE_CLIENT_ID=94d9cf74-99a3-49d5-9be4-98ce2eae1d33`
- `SNAPSHOT_CONTAINER_NAME=snapshots`

**To add missing settings:**
```powershell
az functionapp config appsettings set \
  --name func-mba-fresh \
  --resource-group rg-mba-prod \
  --settings \
    STORAGE_ACCOUNT_NAME=mbacocktaildb3 \
    AZURE_CLIENT_ID=94d9cf74-99a3-49d5-9be4-98ce2eae1d33 \
    SNAPSHOT_CONTAINER_NAME=snapshots
```

### Step 2: Verify Managed Identity Assignment

Check if the managed identity is assigned to the function app:

```powershell
az functionapp identity show \
  --name func-mba-fresh \
  --resource-group rg-mba-prod
```

**To assign the managed identity:**
```powershell
$identityId = "/subscriptions/$(az account show --query id -o tsv)/resourcegroups/rg-mba-prod/providers/Microsoft.ManagedIdentity/userAssignedIdentities/func-cocktaildb2-uami"

az functionapp identity assign \
  --name func-mba-fresh \
  --resource-group rg-mba-prod \
  --identities $identityId
```

### Step 3: Verify RBAC Role Assignments

The managed identity needs these roles on the storage account:

```powershell
# Get subscription ID
$subscriptionId = az account show --query id -o tsv

# Check current roles
az role assignment list \
  --assignee 94d9cf74-99a3-49d5-9be4-98ce2eae1d33 \
  --scope "/subscriptions/$subscriptionId/resourceGroups/rg-mba-prod/providers/Microsoft.Storage/storageAccounts/mbacocktaildb3"
```

**Required roles:**
1. `Storage Blob Data Contributor` - For read/write access to blobs
2. `Storage Blob Delegator` - For generating User Delegation SAS tokens

**To assign missing roles:**
```powershell
$subscriptionId = az account show --query id -o tsv
$storageScope = "/subscriptions/$subscriptionId/resourceGroups/rg-mba-prod/providers/Microsoft.Storage/storageAccounts/mbacocktaildb3"

# Storage Blob Data Contributor
az role assignment create \
  --assignee 94d9cf74-99a3-49d5-9be4-98ce2eae1d33 \
  --role "Storage Blob Data Contributor" \
  --scope $storageScope

# Storage Blob Delegator
az role assignment create \
  --assignee 94d9cf74-99a3-49d5-9be4-98ce2eae1d33 \
  --role "Storage Blob Delegator" \
  --scope $storageScope
```

### Step 4: Wait for Propagation

After making changes, wait for Azure AD propagation:
- **Identity assignment**: Wait 30-60 seconds
- **Role assignments**: Wait 60-120 seconds

### Step 5: Restart Function App

```powershell
az functionapp restart \
  --name func-mba-fresh \
  --resource-group rg-mba-prod
```

## Verification

### Test Write Access
```bash
curl https://func-mba-fresh.azurewebsites.net/api/test-write
```

**Expected success response:**
```json
{
  "success": true,
  "message": "Successfully wrote to blob storage using Managed Identity",
  "storageAccount": "mbacocktaildb3",
  "container": "test-writes",
  "blob": "test-1729437600000.json",
  "authMethod": "managed-identity",
  "clientId": "94d9cf74-99a3-49d5-9be4-98ce2eae1d33"
}
```

### Check Function Logs
```powershell
# Real-time logs
az functionapp log tail \
  --name func-mba-fresh \
  --resource-group rg-mba-prod

# Or use Application Insights
az monitor app-insights query \
  --app func-mba-fresh \
  --analytics-query "traces | where message contains 'test-write' | order by timestamp desc | take 50"
```

## Common Error Messages and Solutions

### Error: "STORAGE_ACCOUNT_NAME environment variable is required"
**Solution**: Add the environment variable as shown in Step 1

### Error: "DefaultAzureCredential failed to retrieve token"
**Cause**: Managed identity is not assigned to the function app
**Solution**: Follow Step 2 to assign the managed identity

### Error: "403 Forbidden" or "Access denied"
**Cause**: Missing RBAC role assignments
**Solution**: Follow Step 3 to assign required roles

### Error: "404 Not Found"
**Cause**: Wrong storage account name or storage account doesn't exist
**Solution**: Verify the storage account name is `mbacocktaildb3`

## Network/Firewall Issues

If all configuration is correct but writes still fail, check:

1. **Storage Account Firewall**:
```powershell
az storage account show \
  --name mbacocktaildb3 \
  --resource-group rg-mba-prod \
  --query "networkRuleSet"
```

If firewall is enabled, add the function app to allowed networks:
```powershell
# Get function app outbound IPs
az functionapp show \
  --name func-mba-fresh \
  --resource-group rg-mba-prod \
  --query "outboundIpAddresses" -o tsv

# Add to storage firewall
az storage account network-rule add \
  --account-name mbacocktaildb3 \
  --resource-group rg-mba-prod \
  --ip-address <FUNCTION_APP_IP>
```

2. **Virtual Network**: If the storage account is in a VNet, ensure the function app has access

## Configuration Summary

**Function App**: func-mba-fresh
**Resource Group**: rg-mba-prod
**Storage Account**: mbacocktaildb3
**Managed Identity**: func-cocktaildb2-uami
**Client ID**: 94d9cf74-99a3-49d5-9be4-98ce2eae1d33

**Required App Settings**:
- STORAGE_ACCOUNT_NAME=mbacocktaildb3
- AZURE_CLIENT_ID=94d9cf74-99a3-49d5-9be4-98ce2eae1d33
- SNAPSHOT_CONTAINER_NAME=snapshots

**Required RBAC Roles** (on mbacocktaildb3):
- Storage Blob Data Contributor
- Storage Blob Delegator

## Related Files

- `/fix-storage-write-access.ps1` - Automated diagnostic and fix script
- `/apps/backend/v3-deploy/test-write/index.js` - Enhanced diagnostic function
- `/apps/backend/v3-deploy/services/snapshotStorageServiceMI.js` - MI-enabled storage service
- `/docs/MANAGED_IDENTITY_MIGRATION.md` - Migration documentation
