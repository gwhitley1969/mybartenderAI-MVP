# iOS Implementation Guide - My AI Bartender

## Overview

This document details the iOS-specific configuration and implementation for My AI Bartender. The Flutter app uses MSAL (Microsoft Authentication Library) for authentication with Microsoft Entra External ID (CIAM).

**Status**: Ready (January 2026)
**Tested**: Physical iPhone device with successful authentication flow

---

## Configuration Summary

### Key Values

| Configuration | Value |
|--------------|-------|
| Bundle Identifier | `ai.mybartender.mybartenderai` |
| Client ID | `f9f7f159-b847-4211-98c9-18e5b8193045` |
| Authority URL | `https://mybartenderai.ciamlogin.com/mybartenderai.onmicrosoft.com/` |
| iOS Redirect URI | `msauth.ai.mybartender.mybartenderai://auth` |
| Authority Type | `AuthorityType.b2c` (required for CIAM) |
| Deployment Target | iOS 13.0 |
| Development Team | `4ML27KY869` |

---

## Authentication Architecture

### MSAL Configuration for CIAM

Microsoft Entra External ID (CIAM) requires B2C-style authority configuration on iOS. The key insight is that CIAM uses a custom authority URL format (`*.ciamlogin.com`) which requires `MSALB2CAuthority` under the hood.

**Critical Configuration Points:**

1. **Authority Type**: Must be `AuthorityType.b2c` even though this is CIAM, not B2C
2. **Authority URL**: Must include the full tenant path: `https://{tenant}.ciamlogin.com/{tenant}.onmicrosoft.com/`
3. **Redirect URI**: MSAL iOS SDK automatically generates redirect URIs in the format `msauth.{bundleId}://auth`

### Redirect URI Registration

The iOS redirect URI `msauth.ai.mybartender.mybartenderai://auth` must be registered in Microsoft Entra ID:

1. Navigate to Azure Portal > Entra ID > App Registrations
2. Select the MyBartenderAI app registration
3. Go to **Authentication** > **Mobile and desktop applications**
4. Add the redirect URI: `msauth.ai.mybartender.mybartenderai://auth`
5. Ensure **Allow public client flows** is set to **Yes**

---

## Files Modified/Created

### Dart Code Changes

#### `lib/src/services/auth_service.dart` (lines ~110-115)

Added iOS AppleConfig to MSAL initialization:

```dart
_msalAuth = await SingleAccountPca.create(
  clientId: AuthConfig.clientId,
  androidConfig: AndroidConfig(
    configFilePath: 'assets/msal_config.json',
    redirectUri: 'msauth://ai.mybartender.mybartenderai/callback',
  ),
  appleConfig: AppleConfig(
    authority: 'https://mybartenderai.ciamlogin.com/mybartenderai.onmicrosoft.com/',
    authorityType: AuthorityType.b2c,  // Required for CIAM
  ),
);
```

#### `lib/src/services/background_token_service.dart` (lines ~73-78)

Same AppleConfig added for background token refresh:

```dart
appleConfig: AppleConfig(
  authority: 'https://mybartenderai.ciamlogin.com/mybartenderai.onmicrosoft.com/',
  authorityType: AuthorityType.b2c,
),
```

### iOS Project Files

#### `ios/Runner/Info.plist`

**URL Schemes** (for MSAL redirect handling):
```xml
<key>CFBundleURLTypes</key>
<array>
    <!-- Deep link scheme -->
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>mybartender</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>mybartender</string>
        </array>
    </dict>
    <!-- MSAL authentication scheme (bundle ID based) -->
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>msauth.$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        </array>
    </dict>
</array>
```

**App Queries Schemes** (for Microsoft Authenticator):
```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>msauthv2</string>
    <string>msauthv3</string>
</array>
```

**Background Modes** (for token refresh):
```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
</array>
```

#### `ios/Runner/Runner.entitlements`

Created for keychain access (required for MSAL token persistence):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.microsoft.adalcache</string>
    </array>
</dict>
</plist>
```

#### `ios/Runner/PrivacyInfo.xcprivacy`

Created for App Store compliance (iOS 17+):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

#### `ios/Runner.xcodeproj/project.pbxproj`

Added DEVELOPMENT_TEAM to Debug, Release, and Profile configurations:

```
DEVELOPMENT_TEAM = 4ML27KY869;
CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
```

---

## Build Instructions

### Prerequisites

- Xcode 15+ with Command Line Tools
- CocoaPods (`gem install cocoapods`)
- Valid Apple Developer account
- Developer Mode enabled on physical device (iOS 16+)

### Clean Build

```bash
cd mobile/app
flutter clean
flutter pub get
cd ios
pod install --repo-update
cd ..
flutter build ios --release
```

### Deploy to Simulator

```bash
flutter run -d "iPhone 16e"
```

### Deploy to Physical Device

**Important:** Debug builds crash when launched from home screen (require debugger). Use Release builds for standalone testing.

```bash
# Build Release
cd mobile/app/ios
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Runner.xcarchive \
  archive

# Or use Xcode: Product > Archive
```

---

## Troubleshooting

### Common Issues

#### 1. "Tenant not found" Error (AADSTS90002)

**Symptom:** Authentication fails with "Tenant 'v2.0' not found"

**Cause:** Authority URL missing tenant path

**Solution:** Ensure authority URL includes full path:
```dart
authority: 'https://mybartenderai.ciamlogin.com/mybartenderai.onmicrosoft.com/'
// NOT: 'https://mybartenderai.ciamlogin.com'
```

#### 2. App Crashes on Launch (Debug Build)

**Symptom:** White screen flashes, app exits immediately

**Cause:** Flutter debug builds require debugger attachment

**Solution:** Build and deploy Release configuration instead of Debug

#### 3. Device Not Detected in Xcode

**Symptom:** iPhone not appearing in Devices list

**Solutions:**
1. Reset Location & Privacy settings on iPhone (Settings > General > Transfer or Reset)
2. Enable Developer Mode (Settings > Privacy & Security > Developer Mode)
3. Trust the Mac when prompted on device
4. Reconnect USB cable

#### 4. Code Signing Errors

**Symptom:** "resource fork, Finder information, or similar detritus not allowed"

**Solution:** Clear extended attributes:
```bash
xattr -cr /path/to/project
```

#### 5. Redirect URI Mismatch

**Symptom:** Authentication fails with redirect URI error

**Cause:** Mismatch between registered URI and SDK-generated URI

**Note:** MSAL iOS SDK generates redirect URIs automatically in format `msauth.{bundleId}://auth`. Register this exact URI in Entra ID.

---

## Platform Differences

### iOS vs Android Authentication

| Aspect | iOS | Android |
|--------|-----|---------|
| Authority Type | `AuthorityType.b2c` | CIAM type in config file |
| Config Location | In-code `AppleConfig` | `assets/msal_config.json` |
| Redirect URI | `msauth.{bundleId}://auth` | `msauth://{bundleId}/callback` |
| Keychain | Requires entitlements | Automatic |

### Token Scopes

```dart
// Platform-specific scopes for CIAM
final scopes = Platform.isIOS
    ? ['User.Read']  // iOS: User.Read only (MSAL adds reserved scopes)
    : ['openid', 'offline_access'];  // Android: explicit reserved scopes
```

---

## Dependencies

### CocoaPods (Podfile.lock excerpt)

```
MSAL (2.2.0)
msal_auth (2.0.2):
  - Flutter
  - MSAL (~> 2.2.0)
workmanager_apple (0.0.1):
  - Flutter
```

---

## References

- [msal_auth Flutter Package](https://pub.dev/packages/msal_auth)
- [Microsoft MSAL iOS Documentation](https://learn.microsoft.com/en-us/entra/msal/objc/)
- [Entra External ID (CIAM) Documentation](https://learn.microsoft.com/en-us/entra/external-id/)
- [Apple Privacy Manifest Requirements](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)

---

## Voice AI Audio Routing

### Problem

On iOS, WebRTC audio defaults to the **earpiece** (receiver) instead of the **speaker**, making AI voice responses whisper-quiet even at maximum volume.

### Root Cause

1. **Timing Issue**: Calling speaker settings BEFORE WebRTC peer connection causes iOS to override them when the connection is established
2. **Guard Check Bug**: flutter_webrtc's `setSpeakerphoneOn()` silently fails if audio session isn't in `PlayAndRecord` mode
3. **Missing Option**: `ensureAudioSession()` doesn't include the `defaultToSpeaker` category option

### Solution

Configure iOS audio routing **AFTER** the WebRTC peer connection is fully established, using `setAppleAudioConfiguration()` with explicit `defaultToSpeaker` option.

**Location**: `lib/src/services/voice_ai_service.dart` (lines ~416-436)

```dart
// iOS-specific: Force speaker output AFTER peer connection is established
if (Platform.isIOS) {
  await Helper.setAppleAudioConfiguration(AppleAudioConfiguration(
    appleAudioCategory: AppleAudioCategory.playAndRecord,
    appleAudioCategoryOptions: {
      AppleAudioCategoryOption.defaultToSpeaker,  // Forces speaker!
      AppleAudioCategoryOption.allowBluetooth,
      AppleAudioCategoryOption.allowBluetoothA2DP,
      AppleAudioCategoryOption.allowAirPlay,
    },
    appleAudioMode: AppleAudioMode.voiceChat,
  ));
  await Helper.setSpeakerphoneOn(true);
}
```

### Key Imports Required

```dart
import 'dart:io' show Platform;
import 'package:flutter_webrtc/src/native/ios/audio_configuration.dart';
```

### Why This Works

| Factor | Explanation |
|--------|-------------|
| Timing | Calling after peer connection ensures iOS doesn't override settings |
| Explicit Configuration | `setAppleAudioConfiguration()` bypasses guard check bugs |
| defaultToSpeaker | This iOS category option explicitly routes audio to speaker |
| voiceChat Mode | Optimized for two-way voice communication |

---

## Microphone Permission (permission_handler)

### Problem

iOS requires explicit Podfile configuration for `permission_handler` package. Without it, microphone permission always returns "denied".

### Solution

Add `GCC_PREPROCESSOR_DEFINITIONS` to the Podfile's `post_install` block:

**Location**: `ios/Podfile`

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)

    # Enable permissions for permission_handler package
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_MICROPHONE=1',
        'PERMISSION_CAMERA=1',
        'PERMISSION_PHOTOS=1',
        'PERMISSION_NOTIFICATIONS=1',
      ]
    end
  end
end
```

Without these macros, the permission code is not compiled into the iOS binary.

---

## Social Sharing (share_plus)

### Problem

On iOS, tapping the share button on cocktail detail screen shows "Unable to share recipe. Please try again." error. This works correctly on Android.

### Root Cause

The `share_plus` package uses iOS `UIActivityViewController` which requires a `sharePositionOrigin` parameter to anchor the share sheet popover. Without it, iOS throws a `PlatformException`.

### Solution

1. Wrap the share `IconButton` in a `Builder` widget to get the correct context
2. Calculate the `sharePositionOrigin` from the button's `RenderBox`
3. Pass the position to `Share.shareWithResult()`

**Location**: `lib/src/features/recipe_vault/cocktail_detail_screen.dart`

```dart
// Share button - wrapped in Builder for iOS sharePositionOrigin
Builder(
  builder: (shareContext) => IconButton(
    icon: Icon(Icons.share, color: AppColors.textPrimary),
    onPressed: () => _shareRecipe(shareContext, cocktail),
  ),
),
```

In `_shareRecipe()` method:

```dart
// Calculate share position origin for iOS
// Required for iPad and recommended for all iOS devices
Rect? sharePositionOrigin;
if (Platform.isIOS) {
  final renderBox = context.findRenderObject() as RenderBox?;
  if (renderBox != null) {
    final position = renderBox.localToGlobal(Offset.zero);
    sharePositionOrigin = position & renderBox.size;
  }
}

final result = await Share.shareWithResult(
  '$shareText\n$shareUrl',
  subject: '${cocktail.name} - My AI Bartender Recipe',
  sharePositionOrigin: sharePositionOrigin,
);
```

### Key Import Required

```dart
import 'dart:io' show Platform;
```

### Why This Works

| Factor | Explanation |
|--------|-------------|
| `Builder` widget | Provides context specific to the button's position in widget tree |
| `sharePositionOrigin` | iOS uses this to anchor the share sheet popover |
| `Platform.isIOS` check | Only calculates position for iOS - Android doesn't need it |

---

## Build & Deploy to Physical Device

### Recommended Method: xcodebuild

When `flutter run --release` fails with code signing errors (especially "resource fork, Finder information, or similar detritus not allowed"), use xcodebuild directly:

```bash
# Build and deploy to connected iPhone
cd mobile/app/ios
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -destination 'id=<DEVICE_UDID>' \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=4ML27KY869

# Install to device
xcrun devicectl device install app --device <DEVICE_UDID> \
  ~/Library/Developer/Xcode/DerivedData/Runner-*/Build/Products/Release-iphoneos/Runner.app

# Launch the app
xcrun devicectl device process launch --device <DEVICE_UDID> ai.mybartender.mybartenderai
```

This bypasses Flutter's build script which can introduce extended attributes that cause code signing failures on macOS 15+.

---

**Last Updated**: January 16, 2026
**Implementation Status**: Complete and Tested
