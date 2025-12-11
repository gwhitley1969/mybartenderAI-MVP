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

-  `msalf9f7f159-b847-4211-98c9-18e5b8193045://auth` (MSAL only) - UNCHECKED
- ☐ `https://mybartenderai.b2clogin.com/oauth2/nativeclient` - UNCHECKED
- `msauth://ai.mybartender.mybartenderai/callback` - LISTED

**Other Settings**:

- Allow public client flows: **Yes**
- Supported account types: Accounts in any organizational directory (Multitenant)
- Implicit grant: Both unchecked (Access tokens and ID tokens)

### App Configuration

**File**: `mobile/app/lib/src/config/auth_config.dart`

```dart
// Authentication configuration for Entra External ID (Azure AD B2C)
class AuthConfig {
  // Entra External ID tenant configuration
  static const String tenantName = 'mybartenderai';
  static const String tenantId = 'a82813af-1054-4e2d-a8ec-c6b9c2908c91';

  // Mobile app registration (from Entra External ID tenant)
  static const String clientId = 'f9f7f159-b847-4211-98c9-18e5b8193045';

  // User flow (for sign-in/sign-up)
  static const String userFlowName = 'mba-signin-signup';

  // Authority URLs (Entra External ID / CIAM)
  static String get authority =>
      'https://$tenantName.ciamlogin.com/$tenantId';

  // Discovery URL for Entra External ID (CIAM) - use tenant ID, not policy path
  static String get discoveryUrl =>
      'https://$tenantName.ciamlogin.com/$tenantId/v2.0/.well-known/openid-configuration';

  // Explicit endpoints for Entra External ID (CIAM) - use tenant ID format
  // NOTE: Entra External ID uses tenant ID in path, NOT policy/user flow
  static String get authorizationEndpoint =>
      'https://$tenantName.ciamlogin.com/$tenantId/oauth2/v2.0/authorize';

  static String get tokenEndpoint =>
      'https://$tenantName.ciamlogin.com/$tenantId/oauth2/v2.0/token';

  static String get endSessionEndpoint =>
      'https://$tenantName.ciamlogin.com/$tenantId/oauth2/v2.0/logout';

  // Redirect URIs (must match Azure AD app registration EXACTLY)
  // Using standard custom scheme for flutter_appauth (NOT MSAL format)
  static const String redirectUrl = 'com.mybartenderai.app://oauth/redirect';
  static const String redirectUrlScheme = 'com.mybartenderai.app';

  // Scopes
  // Temporarily removing 'openid' to debug nonce duplication issue
  // OpenID Connect requires 'openid', but we're testing if this causes the nonce duplication
  static const List<String> scopes = [
    // 'openid', // TEMPORARILY REMOVED - this might trigger automatic nonce
    'profile',
    'email',
  ];

  // Additional parameters for Entra External ID
  // Note: In flutter_appauth 7.x, prompt is passed via promptValues parameter
  static const Map<String, String> additionalParameters = {
    // 'prompt': 'select_account', // Now handled via promptValues
    // Policy is now in URL path, not as parameter
    // REMOVED response_mode - let flutter_appauth use correct default for code+PKCE
  };

  // Token storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String idTokenKey = 'id_token';
  static const String expiresAtKey = 'expires_at';
  static const String userProfileKey = 'user_profile';
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
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Network permissions for API and OAuth -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <!-- Storage and camera permissions -->
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <!-- Notifications (Android 13+) -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <application
        android:label="My AI Bartender"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:networkSecurityConfig="@xml/network_security_config">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <!-- Specifies an Android theme to apply to this Activity as soon as
                 the Android process has started. This theme is visible to the user
                 while the Flutter UI initializes. After that, this theme continues
                 to determine the Window background behind the Flutter UI. -->
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <!-- MSAL BrowserTabActivity for Microsoft authentication -->
        <activity
            android:name="com.microsoft.identity.client.BrowserTabActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="msauth"
                      android:host="ai.mybartender.mybartenderai"
                      android:path="/callback" />
            </intent-filter>
        </activity>

        <!-- Don't delete the meta-data below.
             This is used by the Flutter tool to generate GeneratedPluginRegistrant.java -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <!-- Required to query activities that can process text, see:
         https://developer.android.com/training/package-visibility and
         https://developer.android.com/reference/android/content/Intent#ACTION_PROCESS_TEXT.

         In particular, this is used by the Flutter engine in io.flutter.plugin.text.ProcessTextPlugin. -->
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
        <!-- Query for browser apps to handle OAuth redirects -->
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <category android:name="android.intent.category.BROWSABLE"/>
            <data android:scheme="https"/>
        </intent>
        <!-- Query for MSAL authentication -->
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <category android:name="android.intent.category.BROWSABLE"/>
            <data android:scheme="msauth"/>
        </intent>
    </queries>
</manifest>

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

## ## Test Devices

- **Samsung Galaxy Z Flip 6**: Device ID `R5CX736BQWF`, ARM64 architecture
- **Android Emulator**: x86_64 architecture (has SSL trust issues)

## Latest APK Files

- `MyBartenderAI-TodaysSpecial-nov10.apk` - With msauth://ai.mybartender.mybartenderai/callback
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

**Last Updated**: November 11, 2025
**Status**: Blocked - Need external expertise
