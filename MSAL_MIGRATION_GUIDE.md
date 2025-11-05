# MSAL Migration Guide - From flutter_appauth to msal_auth

## Overview

This guide documents the migration from `flutter_appauth` to `msal_auth` for Microsoft Entra External ID (CIAM) authentication.

---

## Why Migrate?

### Problems with flutter_appauth
- ❌ Duplicate nonce errors (AADSTS9000411)
- ❌ POST/GET request mismatches (AADSTS900561)
- ❌ Generic OAuth library not optimized for Microsoft
- ❌ Complex configuration for Entra External ID

### Benefits of msal_auth
- ✅ Native Microsoft authentication support
- ✅ Automatic nonce handling
- ✅ Built-in token refresh management
- ✅ Designed for Azure AD/Entra ID
- ✅ Simpler configuration for CIAM

---

## Migration Steps

### 1. Update Dependencies

**Remove**:
```yaml
# pubspec.yaml
flutter_appauth: ^7.0.0  # REMOVE THIS
```

**Add**:
```yaml
# pubspec.yaml
msal_auth: ^3.3.0  # ADD THIS
```

Run:
```bash
flutter pub get
```

### 2. Create MSAL Configuration Files

**Create** `/mobile/app/assets/msal_config.json`:
```json
{
  "client_id": "YOUR_CLIENT_ID",
  "authorization_user_agent": "DEFAULT",
  "redirect_uri": "msauth://YOUR.PACKAGE.NAME/callback",
  "account_mode": "SINGLE",
  "broker_redirect_uri_registered": false,
  "authorities": [
    {
      "type": "CIAM",
      "authority_url": "https://YOUR_TENANT.ciamlogin.com/YOUR_TENANT.onmicrosoft.com/",
      "default": true
    }
  ],
  "logging": {
    "pii_enabled": false,
    "log_level": "INFO",
    "logcat_enabled": true
  }
}
```

**Copy** to Android resources:
```bash
cp assets/msal_config.json android/app/src/main/res/raw/msal_config.json
```

### 3. Update pubspec.yaml Assets

```yaml
flutter:
  assets:
    - assets/msal_config.json
```

### 4. Update Android Manifest

**Remove** old flutter_appauth configuration:
```xml
<!-- REMOVE THIS -->
<activity
    android:name="net.openid.appauth.RedirectUriReceiverActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="YOUR_OLD_SCHEME" />
    </intent-filter>
</activity>
```

**Add** MSAL configuration:
```xml
<!-- ADD THIS -->
<activity
    android:name="com.microsoft.identity.client.BrowserTabActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="msauth"
              android:host="YOUR.PACKAGE.NAME"
              android:path="/callback" />
    </intent-filter>
</activity>
```

### 5. Update build.gradle.kts

**Remove**:
```kotlin
// REMOVE THIS
manifestPlaceholders["appAuthRedirectScheme"] = "YOUR_OLD_SCHEME"
```

### 6. Rewrite Authentication Service

**Old** (flutter_appauth):
```dart
import 'package:flutter_appauth/flutter_appauth.dart';

class AuthService {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  Future<User?> signIn() async {
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        clientId,
        redirectUrl,
        serviceConfiguration: AuthorizationServiceConfiguration(
          authorizationEndpoint: authEndpoint,
          tokenEndpoint: tokenEndpoint,
        ),
        scopes: scopes,
      ),
    );
    // Handle result...
  }
}
```

**New** (msal_auth):
```dart
import 'package:msal_auth/msal_auth.dart';

class AuthService {
  SingleAccountPca? _msalAuth;

  Future<void> initialize() async {
    _msalAuth = await SingleAccountPca.create(
      clientId: clientId,
      androidConfig: AndroidConfig(
        configFilePath: 'assets/msal_config.json',
        redirectUri: 'msauth://YOUR.PACKAGE.NAME/callback',
      ),
    );
  }

  Future<User?> signIn() async {
    if (_msalAuth == null) await initialize();

    final result = await _msalAuth!.acquireToken(
      scopes: [
        'https://graph.microsoft.com/User.Read',
        'openid',
        'profile',
        'email',
      ],
      prompt: Prompt.login,
    );
    // Handle result...
  }
}
```

---

## Key Differences

### Redirect URI Format
- **flutter_appauth**: `com.example.app://oauth/redirect`
- **msal_auth**: `msauth://com.example.app/callback`

### Scope Handling
- **flutter_appauth**: Manually manage all scopes including `offline_access`
- **msal_auth**: Handles refresh tokens internally, don't request `offline_access`

### Token Management
- **flutter_appauth**: Manual token refresh with `TokenRequest`
- **msal_auth**: Use `acquireTokenSilent()` for automatic refresh

### Configuration
- **flutter_appauth**: In-code configuration
- **msal_auth**: JSON configuration file

---

## Azure Portal Changes

### Update Redirect URI
1. Go to **Azure Portal** → **App registrations** → Your App → **Authentication**
2. Under **Mobile and desktop applications**, add:
   - `msauth://YOUR.PACKAGE.NAME/callback`
3. Remove old redirect URIs
4. Click **Save**

### Verify Settings
- Allow public client flows: **Yes**
- Implicit grant: Both **unchecked**

---

## Common Issues and Solutions

### Issue: MissingPluginException
**Solution**: Ensure complete migration - no references to flutter_appauth remain

### Issue: Declined Scopes
**Solution**: Remove `offline_access` - MSAL handles this internally

### Issue: Configuration Not Found
**Solution**: Verify msal_config.json is in both assets/ and android/app/src/main/res/raw/

### Issue: Redirect Not Working
**Solution**: Ensure redirect URI in Azure matches exactly: `msauth://package.name/callback`

---

## Testing Checklist

- [ ] Uninstall old app completely
- [ ] Clean Flutter build: `flutter clean`
- [ ] Get dependencies: `flutter pub get`
- [ ] Build release APK: `flutter build apk --release`
- [ ] Install and test authentication
- [ ] Verify token refresh works
- [ ] Check all authentication providers (Email, Google, Facebook)

---

## Benefits After Migration

✅ **No more duplicate nonce errors**
✅ **No more POST/GET mismatches**
✅ **Simpler configuration**
✅ **Better Microsoft service integration**
✅ **Automatic token management**
✅ **Native CIAM support**

---

**Migration Date**: November 5, 2025
**Time to Complete**: ~2 hours (including troubleshooting)
**Result**: ✅ Fully working authentication