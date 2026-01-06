# Key Vault Access Configuration Required

## Manual Step Required
The staging Function App needs access to Key Vault. Please grant access manually:

1. Go to Azure Portal
2. Navigate to Key Vault: `kv-mybartenderai-prod` (in resource group `rg-mba-dev`)
3. Click on "Access control (IAM)"
4. Click "+ Add" → "Add role assignment"
5. Select role: "Key Vault Secrets User"
6. Click "Next"
7. Select "Managed identity"
8. Click "+ Select members"
9. Under "Managed identity" dropdown, select "Function App"
10. Select `func-mba-premium-staging` from the list
11. Click "Select"
12. Click "Next"
13. Click "Review + assign"

## Function App Details
- **Staging App Name**: func-mba-premium-staging
- **Managed Identity Object ID**: 4f2793eb-96c6-4bb5-98ae-91e4a7e5e844
- **Required Role**: Key Vault Secrets User
- **Key Vault**: kv-mybartenderai-prod

## Alternative CLI Command (if subscription context is fixed):
```bash
az role assignment create \
  --assignee "4f2793eb-96c6-4bb5-98ae-91e4a7e5e844" \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/a30b74bc-d8dd-4564-8356-2269a68a9e18/resourceGroups/rg-mba-dev/providers/Microsoft.KeyVault/vaults/kv-mybartenderai-prod"
```

Note: There's currently an issue with the Azure CLI subscription context that's preventing this from being executed automatically.