# Secure Key Management for MyBartenderAI

**Last Updated**: November 6, 2025
**Status**: PRODUCTION-READY (Key Rotated & Secure Build Implemented)
**Security Level**: Enhanced

## Overview

This document describes the secure key management strategy for MyBartenderAI, specifically how to handle Azure Function keys without exposing them in the mobile app.

## ⚠️ IMPORTANT: Key Rotation History

### November 6, 2025 - Key Rotation Event
- **Reason**: Previous key was exposed in background bash process logs
- **Action**: Generated new Function key and updated Key Vault
- **Old Key**: `wKFSvp***` (REDACTED - REVOKED)
- **New Key**: `PjJ95C***` (REDACTED - Stored in Key Vault)
- **Key Vault Version**: f73c6ce903954cb49483693045e2a4fe
- **Status**: ✅ Active and secure
- **Security Note**: Actual keys never stored in git - retrieve from Azure Key Vault

## Current Implementation

### Key Storage
- **Location**: Azure Key Vault (`kv-mybartenderai-prod`)
- **Secret Name**: `AZURE-FUNCTION-KEY`
- **Value**: Stored securely (not displayed in logs or git)
- **Access**: RBAC with "Key Vault Secrets User" role

### Mobile App Configuration
**File**: `mobile/app/lib/src/config/app_config.dart`

```dart
// Function key retrieved from Azure Key Vault at build time via --dart-define
static const String? functionKey = String.fromEnvironment(
  'AZURE_FUNCTION_KEY',
  defaultValue: '', // Empty for development (uses JWT auth instead)
);
```

- **No hardcoded keys**: Uses `String.fromEnvironment()` for compile-time constant
- **Build-time injection**: Keys provided via --dart-define during Flutter build
- **Fallback**: Empty string allows JWT-only authentication for development
- **Security**: Key embedded as compile-time constant, not accessible via reflection

## Building the App Securely

### 🔐 Method 1: Secure Build Script (RECOMMENDED)
**File**: `mobile/app/build-secure.ps1`

```powershell
# Automated secure build - retrieves key from Key Vault automatically
cd mobile/app
.\build-secure.ps1
```

**Features**:
- Validates Azure CLI authentication
- Retrieves key directly from Key Vault (never writes to disk)
- Passes key securely via --dart-define
- Clears sensitive data from memory after build
- No key exposure in logs or command history

### Development Builds
```bash
# For local testing (no key needed for JWT-only auth)
flutter run

# With function key for testing function-key-auth endpoints
flutter run --dart-define=AZURE_FUNCTION_KEY=<your_key>

# For debug APK
flutter build apk --debug --dart-define=AZURE_FUNCTION_KEY=<your_key>
```

### Manual Production Builds (Advanced)
```powershell
# Windows PowerShell
$key = az keyvault secret show --vault-name kv-mybartenderai-prod --name AZURE-FUNCTION-KEY --query value -o tsv
flutter build apk --release --dart-define="AZURE_FUNCTION_KEY=$key"
$key = $null  # Clear from memory
```

```bash
# Linux/Mac
KEY=$(az keyvault secret show --vault-name kv-mybartenderai-prod --name AZURE-FUNCTION-KEY --query value -o tsv)
flutter build apk --release --dart-define=AZURE_FUNCTION_KEY=$KEY
unset KEY  # Clear from memory
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