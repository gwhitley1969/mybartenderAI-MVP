# Secure Key Management for MyBartenderAI

**Last Updated**: November 6, 2025
**Status**: Implemented

## Overview

This document describes the secure key management strategy for MyBartenderAI, specifically how to handle Azure Function keys without exposing them in the mobile app.

## Current Implementation

### Key Storage
- **Location**: Azure Key Vault (`kv-mybartenderai-prod`)
- **Secret Name**: `AZURE-FUNCTION-KEY`
- **Value**: Stored securely (not displayed in documentation)

### Mobile App Configuration
- **No hardcoded keys**: Default value is empty string
- **Build-time injection**: Keys must be provided during build
- **Validation**: App will fail to start without a valid key

## Building the App Securely

### Development Builds
```bash
# For local testing
flutter run --dart-define=AZURE_FUNCTION_KEY=<your_key>

# For debug APK
flutter build apk --debug --dart-define=AZURE_FUNCTION_KEY=<your_key>
```

### Production Builds
```bash
# Retrieve key from Key Vault
$key = az keyvault secret show --vault-name kv-mybartenderai-prod --name AZURE-FUNCTION-KEY --query value -o tsv

# Build release APK with key
flutter build apk --release --dart-define=AZURE_FUNCTION_KEY=$key

# For Windows PowerShell
$key = az keyvault secret show --vault-name kv-mybartenderai-prod --name AZURE-FUNCTION-KEY --query value -o tsv
flutter build apk --release --dart-define="AZURE_FUNCTION_KEY=$key"
```

### CI/CD Pipeline (Recommended)
```yaml
# Azure DevOps Pipeline Example
steps:
- task: AzureKeyVault@2
  inputs:
    azureSubscription: 'Your-Azure-Subscription'
    KeyVaultName: 'kv-mybartenderai-prod'
    SecretsFilter: 'AZURE-FUNCTION-KEY'

- script: |
    flutter build apk --release --dart-define=AZURE_FUNCTION_KEY=$(AZURE-FUNCTION-KEY)
  displayName: 'Build Release APK'
```

## Security Architecture

### Current State (MVP)
```
Mobile App → Azure Functions (with Function Key)
```
- Function key stored in Key Vault
- Key injected at build time
- Not perfect but acceptable for MVP

### Recommended Production Architecture
```
Mobile App → API Management → Azure Functions
```

#### Implementation Steps:
1. **Configure APIM Backend**
   - APIM retrieves Function key from Key Vault using Managed Identity
   - APIM adds Function key to backend requests

2. **Issue APIM Subscription Keys**
   - Each app installation gets unique APIM subscription key
   - Keys can be revoked/rotated per user
   - Rate limiting per subscription

3. **Mobile App Uses APIM Keys**
   - Replace Function key with APIM subscription key
   - Better security and control

## Key Rotation Process

### Manual Rotation
1. **Generate new Function key**
   ```bash
   az functionapp keys set --name func-mba-fresh --resource-group rg-mba-prod --key-name default --key-value <new_key>
   ```

2. **Update Key Vault**
   ```bash
   az keyvault secret set --vault-name kv-mybartenderai-prod --name AZURE-FUNCTION-KEY --value <new_key>
   ```

3. **Rebuild and redistribute app**

### Automated Rotation (Future)
- Use Azure Key Vault key rotation policies
- Implement APIM for seamless rotation
- No app updates required

## Security Best Practices

### DO:
✅ Store keys in Azure Key Vault
✅ Use build-time injection for keys
✅ Validate key presence at app startup
✅ Use APIM for production deployments
✅ Implement key rotation policies
✅ Use unique keys per environment (dev/staging/prod)

### DON'T:
❌ Hardcode keys in source code
❌ Commit keys to version control
❌ Use same keys across environments
❌ Share keys in documentation
❌ Log keys in application logs

## Monitoring and Auditing

### Key Vault Access Logs
```bash
# View Key Vault access logs
az monitor activity-log list --resource-id /subscriptions/<sub-id>/resourceGroups/rg-mba-dev/providers/Microsoft.KeyVault/vaults/kv-mybartenderai-prod
```

### Function App Authentication Failures
```bash
# Monitor 401 errors
az monitor metrics list --resource func-mba-fresh --resource-group rg-mba-prod --metric "Http401"
```

## Troubleshooting

### App Won't Start
**Error**: `StateError: AZURE_FUNCTION_KEY must be set`
**Solution**: Provide key during build:
```bash
flutter build apk --dart-define=AZURE_FUNCTION_KEY=<your_key>
```

### 401 Unauthorized Errors
**Possible Causes**:
1. Key not provided during build
2. Key expired or rotated
3. Wrong key used

**Debug Steps**:
1. Verify key in Key Vault matches Function App
2. Check build command included `--dart-define`
3. Rebuild app with correct key

### Key Vault Access Denied
**Error**: `Forbidden` when accessing Key Vault
**Solution**: Grant access to your identity:
```bash
az keyvault set-policy --name kv-mybartenderai-prod --upn <your-email> --secret-permissions get list
```

## Migration Path to APIM

### Phase 1: Current (Function Keys)
- Direct Function App access
- Function keys in Key Vault
- Build-time injection

### Phase 2: APIM Integration (Next Sprint)
1. Configure APIM backend for Function App
2. Create subscription products (Free/Premium/Pro)
3. Implement subscription key management
4. Update mobile app to use APIM endpoint

### Phase 3: Full Security (Production)
1. Disable direct Function App access
2. All traffic through APIM
3. Per-user subscription keys
4. Advanced rate limiting and analytics

## Related Documentation

- [Azure Key Vault Documentation](https://docs.microsoft.com/azure/key-vault/)
- [Azure API Management](https://docs.microsoft.com/azure/api-management/)
- [Flutter Build Configuration](https://docs.flutter.dev/deployment/flavors)

## Contacts

- **Key Vault**: `kv-mybartenderai-prod`
- **Function App**: `func-mba-fresh`
- **API Management**: `apim-mba-001`
- **Resource Group**: `rg-mba-prod`

---

**Security Note**: Never share actual keys in documentation, logs, or commit messages. Always use Azure Key Vault references or environment variables.