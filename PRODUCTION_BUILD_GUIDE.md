# MyBartenderAI Production Build Guide

## Overview

This guide documents the secure production build process for MyBartenderAI mobile app. The app requires an APIM subscription key to communicate with Azure services, which must be injected at build time for security.

## Key Security Principles

1. **No Hardcoded Keys**: Subscription keys are NEVER hardcoded in source code
2. **Build-Time Injection**: Keys are retrieved from Azure Key Vault and injected during build
3. **No Default Values**: The app will not function without proper key injection
4. **Secure Storage**: All sensitive keys stored in Azure Key Vault

## Prerequisites

1. **Azure CLI** installed and authenticated
   ```powershell
   az login
   ```

2. **Access to Azure Key Vault** (`kv-mybartenderai-prod`)
   - You need at least "Key Vault Secrets User" role
   - Verify access:
   ```powershell
   az keyvault secret show --vault-name kv-mybartenderai-prod --name APIM-SUBSCRIPTION-KEY
   ```

3. **Flutter SDK** properly installed
   ```powershell
   flutter doctor
   ```

## Build Scripts

### 1. Production Build (`build-production.ps1`)

**Purpose**: Full production build with comprehensive security checks

```powershell
# Standard production build
.\build-production.ps1

# Skip clean for faster rebuilds (use with caution)
.\build-production.ps1 -SkipClean

# Test mode (continues despite warnings)
.\build-production.ps1 -TestMode
```

**What it does**:
- Verifies no hardcoded keys in source
- Checks proper environment variable configuration
- Retrieves APIM key from Key Vault
- Builds release APK with key injection
- Provides detailed security summary

### 2. Quick Secure Build (`build-secure.ps1`)

**Purpose**: Faster build for development/testing with Key Vault integration

```powershell
.\build-secure.ps1
```

**What it does**:
- Retrieves APIM key from Key Vault
- Cleans previous build
- Builds release APK with key injection

## Manual Build Process

If you need to build manually:

1. **Get the APIM subscription key**:
   ```powershell
   $key = az keyvault secret show `
     --vault-name kv-mybartenderai-prod `
     --name APIM-SUBSCRIPTION-KEY `
     --query value -o tsv
   ```

2. **Build with the key**:
   ```powershell
   flutter build apk --release --dart-define="APIM_SUBSCRIPTION_KEY=$key"
   ```

3. **Clear the key from memory**:
   ```powershell
   $key = $null
   ```

## Configuration Files

### `app_config.dart`
```dart
static const String? functionKey = String.fromEnvironment(
  'APIM_SUBSCRIPTION_KEY',
  defaultValue: null, // No default in production
);
```

### `main.dart`
```dart
config: const EnvConfig(
  apiBaseUrl: 'https://apim-mba-001.azure-api.net/api',
  functionKey: String.fromEnvironment('APIM_SUBSCRIPTION_KEY'),
),
```

## Verification Steps

After building, verify your APK:

1. **Check APK exists**:
   ```powershell
   ls mobile\app\build\app\outputs\flutter-apk\app-release.apk
   ```

2. **Install and test**:
   ```powershell
   adb install mobile\app\build\app\outputs\flutter-apk\app-release.apk
   ```

3. **Verify functionality**:
   - Launch the app
   - Test AI Chat feature
   - Test Recipe Vault download
   - Both should work without errors

## Troubleshooting

### Build fails with "APIM_SUBSCRIPTION_KEY not provided"
- Ensure you're using one of the build scripts
- Verify Key Vault access
- Check the key exists: `az keyvault secret list --vault-name kv-mybartenderai-prod`

### App shows "No subscription key available"
- The APK was built without proper key injection
- Rebuild using the production build script

### "Failed to retrieve secret from Key Vault"
1. Check Azure CLI authentication: `az account show`
2. Verify Key Vault permissions:
   ```powershell
   az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) `
     --scope /subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-mba-dev/providers/Microsoft.KeyVault/vaults/kv-mybartenderai-prod
   ```

### AI Chat or Recipe Vault not working
- Verify APIM service is running
- Check APIM subscription key is valid
- Test endpoint directly:
  ```powershell
  $key = az keyvault secret show --vault-name kv-mybartenderai-prod --name APIM-SUBSCRIPTION-KEY --query value -o tsv
  curl -H "Ocp-Apim-Subscription-Key: $key" https://apim-mba-001.azure-api.net/api/health
  ```

## CI/CD Integration

For automated builds (e.g., GitHub Actions):

1. Store the APIM key as a secret in your CI/CD platform
2. Pass it during build:
   ```yaml
   - run: flutter build apk --release --dart-define="APIM_SUBSCRIPTION_KEY=${{ secrets.APIM_KEY }}"
   ```

## Security Best Practices

1. **Never commit keys**: Even temporarily
2. **Use Key Vault**: All secrets should come from Azure Key Vault
3. **Rotate keys regularly**: Update in Key Vault, not code
4. **Audit access**: Regularly review who has Key Vault access
5. **Use managed identities**: For service-to-service communication

## Release Checklist

- [ ] No hardcoded keys in any source file
- [ ] Build script retrieves key from Key Vault
- [ ] APK built with production script
- [ ] AI Chat feature tested
- [ ] Recipe Vault feature tested
- [ ] No debug logging of sensitive data
- [ ] APK signed for Play Store

## Support

For issues with:
- **Azure Key Vault**: Check Azure Portal > Key Vault > Access Policies
- **APIM**: Check Azure Portal > API Management > Subscriptions
- **Build Process**: Review build script output for specific errors

---

*Last Updated: November 2025*
*Security Level: Production Ready*