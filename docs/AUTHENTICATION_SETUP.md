# MyBartenderAI Authentication Setup

## Current Status

✅ **Authentication System: FULLY OPERATIONAL** (December 2025)

### Supported Authentication Methods

1. **Email + Password** ✅ Working
   - Native Entra External ID authentication
   - Password-based signup and signin

2. **Google Sign-In** ✅ Working
   - OAuth 2.0 federation with Google
   - One-click signup/signin
   - Seamless age verification integration

3. **Apple Sign-In** ✅ Working
   - OAuth 2.0 federation with Apple
   - One-click signup/signin via Apple ID
   - Seamless age verification integration

4. **Facebook Sign-In** ❌ Removed (February 2026)
   - Removed due to persistent OAuth configuration issues (redirect URI errors for testers, "App not active" for public users)
   - Facebook App Review process was not pursued
   - Existing Facebook users can sign in using the same email via Email + Password

5. **Age Verification (21+)** ✅ Working
   - Custom Authentication Extension
   - OAuth 2.0 secured endpoint
   - Works with all authentication methods
   - Privacy-focused (birthdate not stored)

### What's Configured

- ✅ Entra External ID tenant (mybartenderai)
- ✅ User flows (mba-signin-signup)
- ✅ Identity providers (Email, Google, Apple)
- ✅ Custom user attributes (Date of Birth, Age Verified)
- ✅ Custom Authentication Extension (validate-age)
- ✅ OAuth 2.0 token validation
- ✅ Social login redirect URIs

## Backend Authentication Status

All backend functions are deployed and fully operational. Authentication flow:

1. Mobile app authenticates with Entra External ID
2. JWT token included in API requests (`Authorization: Bearer <token>`)
3. APIM validates JWT via `validate-jwt` policy on **all protected operations** (30 total: 13 newly protected Feb 11, 2026 + 12 previously protected + 5 intentionally public)
4. APIM extracts JWT claims and forwards as headers:
   - `X-User-Id` (from `sub` claim) — user identifier
   - `X-User-Email` (from `email` / `preferred_username` claim) — user email
   - `X-User-Name` (from `name` claim) — user display name
5. Backend functions store email and display name in PostgreSQL `users` table via `getOrCreateUser()`
6. Functions check user tier in PostgreSQL database

See `ENTRA_EXTERNAL_ID_AUTH_FLOW.md` for full APIM policy details and backend consumption patterns.

### API Gateway

- **Gateway URL**: `https://apim-mba-002.azure-api.net`
- **Authentication**: JWT-only (no subscription keys on client)
- **JWT Validation**: APIM `validate-jwt` policy on all protected operations (audience: `f9f7f159-b847-4211-98c9-18e5b8193045`)

### Mobile App Auth Integration

All mobile API providers use authenticated Dio from `BackendService` (via `backendServiceProvider`), which adds `Authorization: Bearer <ID token>` to every request. Fixed Feb 11, 2026 — previously 4 providers used a bare Dio with no auth interceptor. See `BUG_FIXES.md` (BUG-008).

## Age Verification (21+ Requirement)

### Custom Authentication Extension

The app implements server-side age verification during signup using Entra External ID Custom Authentication Extensions.

**Function**: `validate-age`
- **URL**: https://func-mba-fresh.azurewebsites.net/api/validate-age
- **Purpose**: Validates users are 21+ during signup
- **Event Type**: OnAttributeCollectionSubmit
- **Authentication**: ✅ OAuth 2.0 Bearer tokens ENABLED AND WORKING
- **Status**: ✅ Deployed, Tested, and FULLY OPERATIONAL
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

## Social Identity Providers

### Status: ✅ Google Working | ✅ Apple Working | ❌ Facebook Removed

Google and Apple are configured as social identity providers, allowing users to sign up and sign in with their existing accounts. Age verification works seamlessly with both providers.

**Facebook was removed in February 2026** due to persistent OAuth configuration issues (redirect URI errors for testers, "App not active" errors for public users because the app was in development mode). The Facebook App Review process was not pursued. Configuration details are preserved below for reference.

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

### Facebook Sign-In Configuration (REMOVED — February 2026)

> **Note:** Facebook was removed as an identity provider due to persistent OAuth issues. This section is preserved for historical reference only. The Facebook app and Entra configuration have been deactivated.

**Facebook Developer Console Setup (Historical):**

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

**Entra External ID Configuration (Historical):**

1. Navigate to: **External Identities → All identity providers**
2. Facebook was configured with:
   - App ID from Facebook Developer Console
   - App Secret from Facebook Developer Console
   - Status: ❌ Removed (February 2026)

3. Facebook was removed from user flow:
   - User flow: mba-signin-signup
   - "Continue with Facebook" button no longer appears

### User Experience Flow

**Google/Apple Sign-Up Process:**

1. User navigates to MyBartenderAI signup page
2. Clicks "Continue with Google" or "Continue with Apple"
3. Authenticates with their Google or Apple account
4. Redirected back to Entra signup page
5. Prompted for **Date of Birth** (required for age verification)
6. Age verification validates (21+ requirement)
7. If 21+: Account created with `age_verified: true` claim
8. If under 21: Account creation blocked with appropriate message

**Key Features:**
- One-click signup/signin for existing Google and Apple users
- Age verification seamlessly integrated into social login flow
- All authentication methods (Email, Google, Apple) require age verification
- Consistent user experience across all providers

### Testing Social Login

**Test Google Sign-In:**
1. Navigate to signup page
2. Click "Continue with Google"
3. Select Google account
4. Enter birthdate (21+ to test success)
5. Verify account created in Entra External ID

**Test Apple Sign-In:**
1. Navigate to signup page
2. Click "Continue with Apple"
3. Authenticate with Apple ID
4. Enter birthdate (21+ to test success)
5. Verify account created in Entra External ID

### Troubleshooting Social Login

See `docs/TROUBLESHOOTING.md` for detailed troubleshooting of social login issues, including:
- Redirect URI mismatch errors
- Invalid scopes errors
- Domain not whitelisted errors
- Permission configuration issues

---

**Last Updated**: February 2026
