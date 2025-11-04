# Authentication Diagnostics and Solution - RESOLVED

## Issues Identified and Fixed

### 1. OAuth Flow Configuration Issues
**Problem**: Wrong OAuth endpoints initially, incorrect client ID, wrong redirect URI format
**Solution**:
- Corrected OAuth endpoints to use Entra External ID (ciamlogin.com)
- Updated client ID to: `f9f7f159-b847-4211-98c9-18e5b8193045`
- Fixed redirect URI to: `mybartenderai://auth`

### 2. flutter_appauth v7.x Compatibility
**Problem**: `prompt` parameter must use `promptValues` array instead of `additionalParameters`
**Solution**: Updated auth_service.dart to use `promptValues: ['select_account']`

### 3. Missing Android Permissions
**Problem**: Missing INTERNET and ACCESS_NETWORK_STATE permissions
**Solution**: Added to AndroidManifest.xml

### 4. Missing Browser Query Intents
**Problem**: Android 11+ requires explicit query declarations for Custom Tabs
**Solution**: Added browser and custom scheme query intents to AndroidManifest.xml

### 5. SSL Certificate Trust (Emulator)
**Problem**: Emulator doesn't trust SSL certificates for Microsoft domains
**Solution**: Added network_security_config.xml with trust anchors for Microsoft domains

### 6. Wrong APK Architecture
**Problem**: APK built for x86_64 (emulator) instead of ARM64 (physical devices)
**Solution**: Rebuilt APK targeting the physical device specifically with `-d <device-id>`

### 7. Google OAuth Redirect URI Mismatch
**Problem**: Redirect URI not registered in Azure app registration for Google identity provider
**Solution**: Add `mybartenderai://auth` to Mobile and desktop applications redirect URIs in Azure portal

## Complete Solution

### 1. Authentication Service Updates

**File**: `lib/src/services/auth_service.dart`

Key changes:
- Added `preferEphemeralSession: false` to force Custom Tabs instead of WebView
- Added comprehensive logging for debugging
- Added specific error handling for network issues

### 2. Android Manifest Updates

**File**: `android/app/src/main/AndroidManifest.xml`

Added:
```xml
<!-- Network permissions for API and OAuth -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Query intents for browser handling -->
<queries>
    <intent>
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="https"/>
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="mybartenderai"/>
    </intent>
</queries>
```

### 3. Configuration Verification

**Correct OAuth URLs**:
- Authorization: `https://mybartenderai.ciamlogin.com/a82813af-1054-4e2d-a8ec-c6b9c2908c91/oauth2/v2.0/authorize`
- Token: `https://mybartenderai.ciamlogin.com/a82813af-1054-4e2d-a8ec-c6b9c2908c91/oauth2/v2.0/token`
- Logout: `https://mybartenderai.ciamlogin.com/a82813af-1054-4e2d-a8ec-c6b9c2908c91/oauth2/v2.0/logout`

**Correct App Configuration**:
- Client ID: `f9f7f159-b847-4211-98c9-18e5b8193045`
- Redirect URI: `mybartenderai://auth`
- Redirect Scheme: `mybartenderai`

## Troubleshooting Steps

### For Emulator Issues

1. **Check emulator network**:
   ```bash
   adb shell ping google.com
   ```

2. **Configure emulator DNS** (if needed):
   ```bash
   adb shell setprop net.dns1 8.8.8.8
   adb shell setprop net.dns2 8.8.4.4
   ```

3. **Use physical device for testing** if emulator continues to have issues

### For Physical Device Issues

1. **Ensure device has internet connection**
2. **Check if Chrome/browser is installed and updated**
3. **Clear browser cache and cookies**
4. **Try disabling any VPN or proxy**

## Alternative Solutions

### Option 1: Use System Browser Instead of Custom Tabs

Modify `auth_service.dart`:
```dart
final request = AuthorizationTokenRequest(
  // ... existing config
  preferEphemeralSession: true, // Forces system browser
);
```

### Option 2: Implement Fallback for Network Issues

Add network check before authentication:
```dart
Future<bool> checkNetworkConnectivity() async {
  try {
    final result = await http.get(Uri.parse('https://www.google.com'));
    return result.statusCode == 200;
  } catch (e) {
    return false;
  }
}
```

## Testing Authentication

### Debug Logging

When testing, check logs using:
```bash
adb logcat | grep -E "AuthService|AuthNotifier"
```

### Expected Flow

1. User taps "Sign In / Sign Up"
2. Browser/Custom Tab opens with Microsoft login page
3. User authenticates (Email/Google/Facebook)
4. Browser redirects to `mybartenderai://auth`
5. App receives tokens and saves them
6. User is redirected to home screen

## Known Issues and Workarounds

### Issue: "gstatic.com connection failed"
**Cause**: Emulator network configuration
**Workaround**: Use physical device or fix emulator DNS

### Issue: "authorize_and_exchange_code_failed"
**Cause**: Incorrect client ID or redirect URI
**Solution**: Verify Azure app registration matches code configuration

### Issue: Browser doesn't open
**Cause**: Missing browser or query permissions
**Solution**: Ensure Chrome is installed and manifest has query intents

## Next Steps

1. Test on physical device to confirm emulator-specific issue
2. Consider implementing offline development mode for testing
3. Add retry mechanism for transient network failures
4. Implement token refresh logic for expired sessions

## Building for Physical Devices

### Important: Target Device Architecture

When building for physical Android devices, you MUST build targeting the specific device to ensure correct architecture (ARM64 vs x86_64):

```bash
# List connected devices
flutter devices

# Build targeting specific device ID
flutter build apk --release -d <DEVICE_ID>

# Example for Samsung Flip 6
flutter build apk --release -d R5CX736BQWF

# Install on device
adb -s <DEVICE_ID> install -r build/app/outputs/flutter-apk/app-release.apk
```

**Why This Matters**:
- Emulators typically use x86_64 architecture
- Physical devices (especially Samsung, Google Pixel) use ARM64 (arm64-v8a)
- Installing wrong architecture APK will cause immediate crash: "Could not find 'libflutter.so'"
- Using `-d <DEVICE_ID>` ensures Flutter builds for the correct target architecture

### Building for Emulator

```bash
flutter build apk --release -d emulator-5554
```

## Current Status (2025-11-04)

### ✅ Working
- OAuth flow correctly navigates to Microsoft Entra External ID login
- App launches successfully on Samsung Flip 6 (ARM64)
- Browser/Custom Tabs integration working
- SSL certificate trust configured
- Android permissions and query intents properly set
- flutter_appauth v7.x compatibility implemented

### ⏳ Pending User Action
- **Google OAuth Redirect URI**: Add `mybartenderai://auth` to Azure app registration
  - Navigate to: Azure Portal → App Registrations → MyBartenderAI → Authentication
  - Under "Mobile and desktop applications", click "Add URI"
  - Enter: `mybartenderai://auth`
  - Click "Save" at top of page
  - Test authentication again

### 📝 Lessons Learned
1. **Entra External ID vs Azure AD B2C**: Use `ciamlogin.com` endpoints, not `b2clogin.com`
2. **flutter_appauth v7.x**: Breaking changes - use `promptValues` array instead of `prompt` in `additionalParameters`
3. **Android Query Intents**: Required for Android 11+ to enable Custom Tabs
4. **Device Architecture**: Always build targeting specific device ID for physical devices
5. **Emulator Limitations**: SSL trust and network issues - prefer physical device testing
6. **OAuth Redirect URIs**: Must be exactly registered in Azure portal for each identity provider

## Contact Support

If issues persist after following these steps:
1. Check Azure portal for app registration status
2. Verify Entra External ID tenant is active
3. Review redirect URI configuration in Azure
4. Check for any service outages at https://status.azure.com/

---

**Last Updated**: November 4, 2025
**Status**: Authentication flow working, pending final Azure redirect URI configuration