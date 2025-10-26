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

## Age Verification (21+ Requirement)

### Custom Authentication Extension

The app implements server-side age verification during signup using Entra External ID Custom Authentication Extensions.

**Function**: `validate-age`
- **URL**: https://func-mba-fresh.azurewebsites.net/api/validate-age
- **Purpose**: Validates users are 21+ during signup
- **Event Type**: OnAttributeCollectionSubmit
- **Authentication**: OAuth 2.0 Bearer tokens (configurable)
- **Status**: ✅ Deployed, Tested, and WORKING (as of 2025-10-26)
- **Test Results**:
  - Under-21 users successfully BLOCKED
  - 21+ users successfully ALLOWED
  - Accounts created in Entra tenant

**Key Features**:
- Content-Type: application/json headers (Entra requirement)
- Extension attribute handling (GUID-prefixed custom attributes like `extension_<GUID>_DateofBirth`)
- Multiple date format support (MM/DD/YYYY, MMDDYYYY, YYYY-MM-DD)
- Privacy-focused (birthdate NOT stored, only `age_verified: true` boolean)
- Microsoft Graph API response format for Entra integration
- Configurable OAuth validation (currently disabled for testing)

### Entra External ID Configuration Required

1. **Create Custom User Attributes**:
   - Navigate to: **Entra External ID → Custom user attributes**
   - Create `birthdate` attribute (String type)
   - Create `age_verified` attribute (Boolean type)

2. **Update User Flow**:
   - Add `birthdate` to signup form (required field)
   - Position after First name, Last name, Email

3. **Create Custom Authentication Extension**:
   - Navigate to: **External Identities → Custom authentication extensions**
   - Click **+ Create a custom extension**
   - Configure:
     - **Name**: Age Verification
     - **Event type**: OnAttributeCollectionSubmit ⚠️ (CRITICAL)
     - **Target URL**: https://func-mba-fresh.azurewebsites.net/api/validate-age
     - **Authentication**: Create new app registration (OAuth 2.0)
     - **Claims**: birthdate

4. **Add Extension to User Flow**:
   - Navigate to: **User flows → mba-signin-signup**
   - Click **Custom authentication extensions**
   - Select event: OnAttributeCollectionSubmit
   - Choose extension: Age Verification

5. **Update JWT Token Configuration**:
   - Navigate to: **App registrations → MyBartenderAI Mobile**
   - Click **Token configuration**
   - Add optional claim: `extension_age_verified` (Access token)

### Testing Age Verification

**Under-21 Test** (Should Block):
```
Birthdate: 01/05/2010 (under 21)
Expected: Account creation blocked with message:
"You must be 21 years or older to use MyBartenderAI."
```

**21+ Test** (Should Allow):
```
Birthdate: 01/05/1990 (21+)
Expected: Account created successfully
JWT token includes: "age_verified": true
```

### Documentation

For detailed setup instructions, see:
- `infrastructure/apim/ENTRA_EXTERNAL_ID_API_CONNECTOR_SETUP.md` - Step-by-step portal configuration
- `docs/AGE_VERIFICATION_IMPLEMENTATION.md` - Complete implementation guide
- `docs/TROUBLESHOOTING.md` - Age verification issues and fixes

## Next Steps

1. Get your B2C configuration details:
   - Tenant name
   - Client ID
   - Sign-in policy name

2. Configure the Function App with B2C settings

3. **Configure Age Verification**:
   - Create custom user attributes (birthdate, age_verified)
   - Create Custom Authentication Extension
   - Add extension to user flow
   - Update JWT token configuration
   - Test signup flow with under-21 and 21+ users

4. Implement authentication in the Flutter app

5. Switch back to the authenticated endpoints
