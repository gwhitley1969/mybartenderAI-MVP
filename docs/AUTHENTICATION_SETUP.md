# MyBartenderAI Authentication Setup

## Current Status

✅ **Authentication System: FULLY OPERATIONAL** (as of 2025-10-27)

### Supported Authentication Methods

1. **Email + Password** ✅ Working
   - Native Entra External ID authentication
   - Password-based signup and signin

2. **Google Sign-In** ✅ Working
   - OAuth 2.0 federation with Google
   - One-click signup/signin
   - Seamless age verification integration

3. **Facebook Sign-In** ✅ Working
   - OAuth 2.0 federation with Facebook
   - One-click signup/signin
   - Seamless age verification integration

4. **Age Verification (21+)** ✅ Working
   - Custom Authentication Extension
   - OAuth 2.0 secured endpoint
   - Works with all authentication methods
   - Privacy-focused (birthdate not stored)

### What's Configured

- ✅ Entra External ID tenant (mybartenderai)
- ✅ User flows (mba-signin-signup)
- ✅ Identity providers (Email, Google, Facebook)
- ✅ Custom user attributes (Date of Birth, Age Verified)
- ✅ Custom Authentication Extension (validate-age)
- ✅ OAuth 2.0 token validation
- ✅ Social login redirect URIs

## Backend Authentication Status

The backend functions are deployed and working, but the authenticated endpoints (`ask-bartender`, `recommend`, `realtime-token`) require JWT tokens from Entra External ID.

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
- **Authentication**: ✅ OAuth 2.0 Bearer tokens ENABLED AND WORKING
- **Status**: ✅ Deployed, Tested, and FULLY OPERATIONAL (as of 2025-10-26)
- **Test Results**:
  - ✅ OAuth token validation successful (ciamlogin.com JWKS)
  - ✅ Under-21 users successfully BLOCKED
  - ✅ 21+ users successfully ALLOWED
  - ✅ Accounts created in Entra tenant
  - ✅ Security hardening complete

**Key Features**:
- OAuth 2.0 token validation using Entra External ID ciamlogin.com domain
- Cryptographic token verification (no secrets stored, uses Microsoft's public JWKS)
- JWKS caching (10-minute TTL for performance)
- Content-Type: application/json headers (Entra requirement)
- Extension attribute handling (GUID-prefixed custom attributes like `extension_<GUID>_DateofBirth`)
- Multiple date format support (MM/DD/YYYY, MMDDYYYY, YYYY-MM-DD)
- Privacy-focused (birthdate NOT stored, only `age_verified: true` boolean)
- Microsoft Graph API response format for Entra integration
- Comprehensive logging for debugging and monitoring

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

## Social Identity Providers (Google & Facebook)

### Status: ✅ Configured and Working (as of 2025-10-27)

Both Google and Facebook are configured as identity providers, allowing users to sign up and sign in with their existing social accounts. Age verification works seamlessly with both providers.

### Google Sign-In Configuration

**Google Cloud Console Setup:**

1. **Project**: MyBartenderAI-auth
2. **OAuth 2.0 Client**:
   - Name: EntraExternalID-Google
   - Type: Web application
   - Client ID: `469059267896-qaan4dcbmp2ejgbm1jh17kgjioaciddg.apps.googleusercontent.com`

3. **Authorized Redirect URIs** (Both Required):
   ```
   https://a82813af-1054-4e2d-a8ec-c6b9c2908c91.ciamlogin.com/a82813af-1054-4e2d-a8ec-c6b9c2908c91/federation/oidc/accounts.google.com
   https://mybartenderai.ciamlogin.com/mybartenderai.onmicrosoft.com/federation/oauth2
   ```

**Why Two Redirect URIs?**
- First URI uses tenant ID format (OIDC federation endpoint)
- Second URI uses tenant name format (OAuth2 endpoint)
- Entra External ID may use either depending on configuration

**Entra External ID Configuration:**

1. Navigate to: **External Identities → All identity providers**
2. Google is configured with:
   - Client ID from Google Cloud Console
   - Client Secret from Google Cloud Console
   - Status: ✅ Configured

3. Google is added to user flow:
   - User flow: mba-signin-signup
   - Users see "Continue with Google" button

### Facebook Sign-In Configuration

**Facebook Developer Console Setup:**

1. **App**: MyBartenderAI
   - App ID: `1833559960622020`
   - Mode: In development

2. **App Domains** (Settings → Basic):
   ```
   bluebuildapps.com
   ciamlogin.com
   ```

3. **Facebook Login Settings** (Use cases → Facebook Login → Settings):

   **Valid OAuth Redirect URIs** (Both Required):
   ```
   https://a82813af-1054-4e2d-a8ec-c6b9c2908c91.ciamlogin.com/a82813af-1054-4e2d-a8ec-c6b9c2908c91/federation/oidc/www.facebook.com
   https://mybartenderai.ciamlogin.com/mybartenderai.onmicrosoft.com/federation/oauth2
   ```

   **Allowed Domains for JavaScript SDK**:
   ```
   https://ciamlogin.com/
   ```
   (Facebook auto-formats with https:// protocol)

4. **Permissions** (Use cases → Facebook Login → Permissions and features):
   - ✅ email (Required - must be added manually)
   - ✅ public_profile (Default)

**Entra External ID Configuration:**

1. Navigate to: **External Identities → All identity providers**
2. Facebook is configured with:
   - App ID from Facebook Developer Console
   - App Secret from Facebook Developer Console
   - Status: ✅ Configured

3. Facebook is added to user flow:
   - User flow: mba-signin-signup
   - Users see "Continue with Facebook" button

### User Experience Flow

**Google/Facebook Sign-Up Process:**

1. User navigates to MyBartenderAI signup page
2. Clicks "Continue with Google" or "Continue with Facebook"
3. Authenticates with their Google/Facebook account
4. Redirected back to Entra signup page
5. Prompted for **Date of Birth** (required for age verification)
6. Age verification validates (21+ requirement)
7. If 21+: Account created with `age_verified: true` claim
8. If under 21: Account creation blocked with appropriate message

**Key Features:**
- One-click signup/signin for existing Google/Facebook users
- Age verification seamlessly integrated into social login flow
- All authentication methods (email, Google, Facebook) require age verification
- Consistent user experience across all providers

### Testing Social Login

**Test Google Sign-In:**
1. Navigate to signup page
2. Click "Continue with Google"
3. Select Google account
4. Enter birthdate (21+ to test success)
5. Verify account created in Entra External ID

**Test Facebook Sign-In:**
1. Navigate to signup page
2. Click "Continue with Facebook"
3. Log in to Facebook
4. Enter birthdate (21+ to test success)
5. Verify account created in Entra External ID

### Troubleshooting Social Login

See `docs/TROUBLESHOOTING.md` for detailed troubleshooting of social login issues, including:
- Redirect URI mismatch errors
- Invalid scopes errors
- Domain not whitelisted errors
- Permission configuration issues

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
