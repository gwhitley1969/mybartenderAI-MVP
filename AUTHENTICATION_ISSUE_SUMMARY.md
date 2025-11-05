# Authentication Issue Summary for External Review

## The Core Problem

**Error**: `AADSTS900561: The endpoint only accepts POST requests. Received a GET request.`

**What's Happening**:
- User completes authentication and consent screen
- After clicking "Continue", browser hangs at mybartenderai.ciamlogin.com
- When refreshed, shows the AADSTS900561 error
- Error indicates a GET request is being sent to the token endpoint
- This happens with both Chrome and Microsoft Edge

## Expected OAuth Flow

1. App initiates authorization → Opens browser
2. User authenticates → Consent screen
3. User clicks "Continue" → **Browser redirects to app** with authorization code
4. **App makes POST request** to token endpoint to exchange code for tokens

## What's Actually Happening

1. App initiates authorization → Opens browser ✅
2. User authenticates → Consent screen ✅
3. User clicks "Continue" → **Browser redirects to token endpoint** ❌
4. **Browser makes GET request** to token endpoint ❌
5. Error: Token endpoint only accepts POST

## Current Configuration

### Azure Portal Settings

**App Registration**: MyBartenderAI Mobile
- **Client ID**: `f9f7f159-b847-4211-98c9-18e5b8193045`
- **Tenant Name**: mybartenderai
- **Tenant ID**: `a82813af-1054-4e2d-a8ec-c6b9c2908c91`
- **User Flow**: mba-signin-signup
- **Platform**: Mobile and desktop applications

**Redirect URIs Registered**:
- ☑ `msalf9f7f159-b847-4211-98c9-18e5b8193045://auth` (MSAL only) - CHECKED
- ☐ `https://mybartenderai.b2clogin.com/oauth2/nativeclient` - UNCHECKED
- `com.mybartenderai.app://oauth/redirect` - LISTED
- `mybartenderai://auth` - LISTED

**Other Settings**:
- Allow public client flows: **Yes**
- Supported account types: Accounts in any organizational directory (Multitenant)
- Implicit grant: Both unchecked (Access tokens and ID tokens)

### App Configuration

**File**: `mobile/app/lib/src/config/auth_config.dart`
```dart
clientId: 'f9f7f159-b847-4211-98c9-18e5b8193045'
redirectUrl: 'msalf9f7f159-b847-4211-98c9-18e5b8193045://auth'
authorizationEndpoint: 'https://mybartenderai.ciamlogin.com/mybartenderai.onmicrosoft.com/mba-signin-signup/oauth2/v2.0/authorize'
tokenEndpoint: 'https://mybartenderai.ciamlogin.com/mybartenderai.onmicrosoft.com/mba-signin-signup/oauth2/v2.0/token'
scopes: ['openid', 'profile', 'email', 'offline_access']
additionalParameters: {
  'response_mode': 'query'
}
```

**File**: `mobile/app/lib/src/services/auth_service.dart`
- Using `flutter_appauth` package (v7.x)
- Split authorization and token exchange into separate calls
- Using `AuthorizationRequest` → `authorize()` → then `TokenRequest` → `token()`
- PKCE automatically handled by flutter_appauth

**Android Configuration**:
```xml
<!-- AndroidManifest.xml -->
<data android:scheme="msalf9f7f159-b847-4211-98c9-18e5b8193045"
      android:host="auth" />
```

## What We've Tried

1. ✅ Fixed client ID and redirect URI
2. ✅ Updated for flutter_appauth v7.x compatibility
3. ✅ Added Android permissions and query intents
4. ✅ Fixed APK architecture for physical device
5. ✅ Switched between Custom Tabs and system browser
6. ✅ Added explicit `response_mode=query` parameter
7. ✅ Split authorization and token exchange into separate calls
8. ✅ Changed redirect URI between MSAL and standard formats
9. ✅ Tried policy in URL path vs. query parameter
10. ✅ Enabled "Allow public client flows" in Azure
11. ✅ Checked redirect URI checkbox in Azure portal
12. ✅ Tested on both emulator and physical device (Samsung Flip 6)
13. ✅ Verified third-party cookies are enabled

## The Mystery

**Why is the browser being redirected to the token endpoint instead of to the app?**

This behavior suggests:
- Azure doesn't recognize the redirect URI as valid for a mobile app
- OR Azure is configured to use a different OAuth flow (implicit/hybrid)
- OR There's something about Entra External ID's behavior that's different from standard Azure AD B2C

## Test Devices

- **Samsung Galaxy Z Flip 6**: Device ID `R5CX736BQWF`, ARM64 architecture
- **Android Emulator**: x86_64 architecture (has SSL trust issues)

## Latest APK Files

- `URGENT-AUTH-FIX.apk` - With MSAL redirect URI matching Azure
- `mybartenderai-b2c-endpoints.apk` - With B2C-specific endpoint format

## Key Observations

1. **Account is created**: Azure successfully creates user accounts during the flow
2. **Authentication succeeds**: Users can log in with Google, Email, Facebook
3. **Consent screen appears**: The permissions request shows correctly
4. **Redirect fails**: After clicking "Continue", browser doesn't redirect to app
5. **Browser hangs**: At mybartenderai.ciamlogin.com
6. **Refresh shows error**: GET request to token endpoint

## Questions for External Reviewer

1. Is there a configuration in Entra External ID that forces browser-based token delivery?
2. Should we be using a different OAuth flow for Entra External ID?
3. Is the MSAL redirect URI format (`msalXXX://auth`) incompatible with flutter_appauth?
4. Is there an Azure setting that forces implicit flow even when we request authorization code flow?
5. Should we abandon flutter_appauth and use Microsoft's MSAL library instead?

## Repository Information

- **GitHub**: https://github.com/gwhitley1969/mybartenderAI-MVP
- **Branch**: main
- **Key Files**:
  - `/mobile/app/lib/src/config/auth_config.dart`
  - `/mobile/app/lib/src/services/auth_service.dart`
  - `/mobile/app/android/app/src/main/AndroidManifest.xml`
  - `/AUTHENTICATION_DIAGNOSTICS.md`
  - `/AUTHENTICATION_CURRENT_STATE.md`

## Contact

Project owner available through GitHub issues.

---

**Last Updated**: November 5, 2025
**Status**: Blocked - Need external expertise