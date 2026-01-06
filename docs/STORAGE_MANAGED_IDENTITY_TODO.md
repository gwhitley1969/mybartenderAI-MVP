# Storage Managed Identity Configuration Required

## Manual Step Required
The Function App needs Storage Blob Data Contributor role to use Managed Identity for storage access. Please grant access manually:

### Azure Portal Steps:
1. Go to Azure Portal
2. Navigate to Storage Account: `mbacocktaildb3` (in resource group `rg-mba-prod`)
3. Click on "Access control (IAM)"
4. Click "+ Add" → "Add role assignment"
5. Select role: "Storage Blob Data Contributor"
6. Click "Next"
7. Select "Managed identity"
8. Click "+ Select members"
9. Under "Managed identity" dropdown, select "Function App"
10. Select `func-mba-fresh` from the list
11. Click "Select"
12. Click "Next"
13. Click "Review + assign"

## Function App Details
- **Function App Name**: func-mba-fresh
- **Managed Identity Object ID**: 0dd8c107-c598-4a4a-8029-532222e47b1b
- **Required Role**: Storage Blob Data Contributor
- **Storage Account**: mbacocktaildb3

## Alternative CLI Command (when subscription context is fixed):
```bash
az role assignment create \
  --assignee "0dd8c107-c598-4a4a-8029-532222e47b1b" \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/a30b74bc-d8dd-4564-8356-2269a68a9e18/resourceGroups/rg-mba-prod/providers/Microsoft.Storage/storageAccounts/mbacocktaildb3"
```

## After Role Assignment is Complete:
Once the role is granted, we can:
1. Update the Function App code to use DefaultAzureCredential
2. Remove the storage connection strings from configuration
3. Eliminate SAS token generation

## Benefits:
- No more storage keys in configuration
- No more SAS tokens to manage
- Better security with Managed Identity
- Works perfectly with Premium plan

Note: There's currently an issue with the Azure CLI subscription context that's preventing automatic role assignment.