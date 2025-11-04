# Authentication Diagnostics - UNRESOLVED

**Last Updated**: November 4, 2025 (Opus Session)
**Status**: Authentication still failing across ALL methods (Email, Google, Facebook)

## Summary of the Problem

The MyBartenderAI mobile app cannot complete authentication with Microsoft Entra External ID. ALL authentication methods fail at the redirect stage - the browser successfully authenticates but cannot redirect back to the app.

## Current Symptoms

1. User initiates sign-in (any method: Email/Google/Facebook)
2. Browser opens and navigates to Microsoft Entra External ID
3. User successfully authenticates
4. Consent screen appears: "Are you trying to sign in to MyBartenderAI Mobile?"
5. User clicks "Continue"
6. **FAILURE**: Browser hangs and never redirects back to app
7. If user closes browser, app shows "User cancelled flow" error

## Configuration Details

### Azure Entra External ID Configuration
- **Tenant Name**: mybartenderai
- **Tenant ID**: a82813af-1054-4e2d-a8ec-c6b9c2908c91
- **Client ID**: f9f7f159-b847-4211-98c9-18e5b8193045
- **User Flow**: mba-signin-signup (tested and working in Azure Portal)
- **Identity Providers**: Google, Facebook, Microsoft (all configured)

### OAuth Endpoints
- **Authorization**: `https://mybartenderai.ciamlogin.com/a82813af-1054-4e2d-a8ec-c6b9c2908c91/oauth2/v2.0/authorize`
- **Token**: `https://mybartenderai.ciamlogin.com/a82813af-1054-4e2d-a8ec-c6b9c2908c91/oauth2/v2.0/token`
- **Logout**: `https://mybartenderai.ciamlogin.com/a82813af-1054-4e2d-a8ec-c6b9c2908c91/oauth2/v2.0/logout`

## All Attempted Solutions (November 4, 2025)

### Session 1 (Sonnet) - Initial Fixes

1. **Fixed Client ID**
   - Changed from: `0a9decfb-ba92-400d-8d8d-8d86f0f86a0b`
   - Changed to: `f9f7f159-b847-4211-98c9-18e5b8193045`
   - Result: ✅ Resolved initial authorization errors

2. **Fixed OAuth Endpoints**
   - Corrected to use Entra External ID endpoints (ciamlogin.com)
   - Not Azure AD B2C endpoints (b2clogin.com)
   - Result: ✅ Proper authentication flow initiated

3. **Updated flutter_appauth v7.x Compatibility**
   - Changed from `additionalParameters: {'prompt': 'select_account'}`
   - To `promptValues: ['select_account']`
   - Result: ✅ Resolved prompt parameter errors

4. **Added Android Permissions**
   - Added INTERNET and ACCESS_NETWORK_STATE permissions
   - Result: ✅ Network connectivity established

5. **Added Browser Query Intents**
   - Added query intents for Android 11+ Custom Tabs support
   - Result: ✅ Browser launches correctly

6. **Fixed APK Architecture**
   - Built specifically for ARM64 (Samsung Flip 6)
   - Result: ✅ App launches without crashes

7. **Changed Custom Tabs to System Browser**
   - Set `preferEphemeralSession: true`
   - Result: ❌ Still hangs after consent

### Session 2 (Opus) - Deep Dive Analysis

8. **Added response_mode Parameter**
   - Added `response_mode: 'query'` to force query parameters
   - Added dynamic `nonce` for security
   - Result: ❌ Still hangs after consent

9. **Changed to MSAL Redirect URI Format**
   - Changed from: `mybartenderai://auth`
   - Changed to: `msalf9f7f159-b847-4211-98c9-18e5b8193045://auth`
   - Updated all Android configurations to match
   - Result: ✅ Progress - reached permissions consent screen
   - But: ❌ Stuck at "Permissions requested" screen

10. **Granted Admin Consent**
    - Granted admin consent for User.Read permission in Azure Portal
    - Result: ❌ Still stuck at permissions screen

11. **Tested Deep Links Directly**
    - Command: `adb shell am start -d "msalf9f7f159-b847-4211-98c9-18e5b8193045://auth?code=test"`
    - Result: ✅ App receives deep links correctly
    - Conclusion: App CAN receive redirects, but Azure isn't sending them

## Azure Portal Configuration Verified

### ✅ Redirect URIs Registered
- `msalf9f7f159-b847-4211-98c9-18e5b8193045://auth` (MSAL only) - CHECKED
- `https://mybartenderai.b2clogin.com/oauth2/nativeclient` - CHECKED
- `mybartenderai://auth` - LISTED

### ✅ API Permissions
- Microsoft Graph: User.Read
- Admin consent: Granted
- Status: Still fails

### ✅ Identity Providers
- Google: Configured with correct redirect URIs in Google Cloud Console
- Facebook: Configured
- Microsoft: Configured

### ✅ User Flow
- mba-signin-signup: Tested and working in Azure Portal test feature

## Current Code State

### auth_config.dart
```dart
static const String redirectUrl = 'msalf9f7f159-b847-4211-98c9-18e5b8193045://auth';
static const String redirectUrlScheme = 'msalf9f7f159-b847-4211-98c9-18e5b8193045';
static const Map<String, String> additionalParameters = {
  'response_mode': 'query',
};
```

### auth_service.dart
```dart
final nonce = DateTime.now().millisecondsSinceEpoch.toString();
final additionalParams = {
  ...AuthConfig.additionalParameters,
  'nonce': nonce,
};

final request = AuthorizationTokenRequest(
  AuthConfig.clientId,
  AuthConfig.redirectUrl,
  serviceConfiguration: AuthorizationServiceConfiguration(
    authorizationEndpoint: AuthConfig.authorizationEndpoint,
    tokenEndpoint: AuthConfig.tokenEndpoint,
    endSessionEndpoint: AuthConfig.endSessionEndpoint,
  ),
  scopes: AuthConfig.scopes,
  promptValues: ['select_account'],
  additionalParameters: additionalParams,
  preferEphemeralSession: true, // Using system browser
);
```

### AndroidManifest.xml
```xml
<activity
    android:name="net.openid.appauth.RedirectUriReceiverActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="msalf9f7f159-b847-4211-98c9-18e5b8193045" />
    </intent-filter>
</activity>
```

## What Works vs What Doesn't

### ✅ What Works:
- OAuth flow initiates correctly
- Browser opens and navigates to Microsoft Entra External ID
- User can authenticate with Google/Email/Facebook
- Deep links work when tested directly with adb
- App is properly configured to receive redirects

### ❌ What Doesn't Work:
- After consent screen, browser doesn't redirect to app
- Stuck at "Permissions requested" screen
- All authentication methods fail at the same point
- Azure is not completing the redirect after consent

## Possible Root Causes

1. **Azure Entra External ID Redirect Issue**
   - Azure may require additional configuration for mobile redirects
   - Post-consent redirect might need different handling

2. **Unverified App Status**
   - App shows as "unverified" in consent screen
   - May be blocking the redirect flow

3. **Missing Configuration**
   - May need additional redirect URIs
   - May need specific Azure configuration for mobile apps

4. **Library Incompatibility**
   - flutter_appauth may not fully support Entra External ID
   - May need to use Microsoft's MSAL library instead

## Next Steps for Resolution

1. **Try MSAL Flutter Library**
   - Replace flutter_appauth with Microsoft's official MSAL library
   - Package: `msal_flutter`

2. **Verify with Microsoft Support**
   - Open support ticket with Azure
   - Specifically ask about mobile app redirects in Entra External ID

3. **Test with Different OAuth Flow**
   - Try implicit flow instead of authorization code flow
   - Try hybrid flow

4. **Check Entra External ID Logs**
   - Review sign-in logs in Azure Portal
   - Look for redirect errors or blocks

5. **Alternative Architecture**
   - Consider web-based authentication with webview
   - Consider using a backend service to handle OAuth

## Files Modified During Troubleshooting

- `/mobile/app/lib/src/config/auth_config.dart`
- `/mobile/app/lib/src/services/auth_service.dart`
- `/mobile/app/android/app/src/main/AndroidManifest.xml`
- `/mobile/app/android/app/build.gradle.kts`
- `/mobile/app/android/app/src/main/res/xml/network_security_config.xml`

## Test Devices

- **Samsung Flip 6**: Device ID `R5CX736BQWF` (ARM64)
- **Android Emulator**: Device ID `emulator-5554` (x86_64)

## Relevant Azure Documentation

- [Entra External ID Mobile App Integration](https://learn.microsoft.com/en-us/azure/active-directory/external-identities/)
- [OAuth 2.0 Authorization Code Flow](https://learn.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-auth-code-flow)

---

**For Next Developer**: The core issue is that Azure Entra External ID successfully authenticates the user but fails to redirect back to the mobile app after the consent screen. The app is configured to receive the redirect (verified with adb tests), but Azure isn't sending it. Consider using Microsoft's MSAL library or opening a support ticket with Microsoft.