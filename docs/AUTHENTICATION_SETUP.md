# MyBartenderAI Authentication Setup

## Current Status

The backend functions are deployed and working, but the authenticated endpoints (`ask-bartender`, `recommend`, `realtime-token`) require Azure AD B2C (Entra External ID) configuration.

## Temporary Solution

We've created a test endpoint `/v1/ask-bartender-test` that bypasses JWT authentication for testing purposes.

## Azure AD B2C Setup Required

To enable proper authentication, you need to:

### 1. Configure Azure Functions with B2C Settings

Add these environment variables to your Function App (`func-mba-fresh`):

```bash
# Your B2C tenant name (e.g., "mybartenderai")
ENTRA_TENANT_ID=<your-b2c-tenant-name>.onmicrosoft.com

# The Application (client) ID from your B2C app registration
ENTRA_EXPECTED_AUDIENCE=<your-b2c-app-client-id>

# The B2C issuer URL
ENTRA_ISSUER=https://<your-b2c-tenant-name>.b2clogin.com/<your-b2c-tenant-name>.onmicrosoft.com/<your-sign-in-policy>/v2.0
```

Example:
```bash
az functionapp config appsettings set \
  -n func-mba-fresh \
  -g rg-mba-prod \
  --settings \
    "ENTRA_TENANT_ID=mybartenderai.onmicrosoft.com" \
    "ENTRA_EXPECTED_AUDIENCE=12345678-1234-1234-1234-123456789012" \
    "ENTRA_ISSUER=https://mybartenderai.b2clogin.com/mybartenderai.onmicrosoft.com/B2C_1_signupsignin/v2.0"
```

### 2. Flutter App Authentication Flow

The Flutter app needs to:

1. **Add B2C authentication package**:
   ```yaml
   dependencies:
     flutter_appauth: ^6.0.2
   ```

2. **Configure B2C settings**:
   ```dart
   const b2cConfig = {
     'tenant': 'mybartenderai',
     'clientId': '<your-b2c-app-client-id>',
     'redirectUri': 'com.mybartenderai.app://auth',
     'signInPolicy': 'B2C_1_signupsignin',
   };
   ```

3. **Implement authentication flow**:
   - Login with Microsoft/Google
   - Get ID token
   - Include token in API requests as `Authorization: Bearer <token>`

### 3. Update API Calls

Once authentication is set up, the Flutter app should include the JWT token:

```dart
dio.options.headers['Authorization'] = 'Bearer $idToken';
```

## Testing Without Authentication

For now, the Flutter app is configured to use:
- Base URL: `https://func-mba-fresh.azurewebsites.net/api`
- Function Key: Included in headers
- Test endpoint: `/v1/ask-bartender-test` (no JWT required)

## Next Steps

1. Get your B2C configuration details:
   - Tenant name
   - Client ID
   - Sign-in policy name

2. Configure the Function App with B2C settings

3. Implement authentication in the Flutter app

4. Switch back to the authenticated endpoints
