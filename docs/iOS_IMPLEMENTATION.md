# iOS Implementation Guide - My AI Bartender

## Overview

This document details the iOS-specific configuration and implementation for My AI Bartender. The Flutter app uses MSAL (Microsoft Authentication Library) for authentication with Microsoft Entra External ID (CIAM).

**Status**: Ready (January 2026)
**Tested**: Physical iPhone device with successful authentication flow
**Last Updated**: January 22, 2026

---

## Configuration Summary

### Key Values

| Configuration | Value |
|--------------|-------|
| Bundle Identifier | `com.mybartenderai.mybartenderai` |
| Client ID | `f9f7f159-b847-4211-98c9-18e5b8193045` |
| Authority URL | `https://mybartenderai.ciamlogin.com/mybartenderai.onmicrosoft.com/` |
| iOS Redirect URI | `msauth.com.mybartenderai.mybartenderai://auth` |
| Authority Type | `AuthorityType.b2c` (required for CIAM) |
| Deployment Target | iOS 13.0 |
| Development Team | `4ML27KY869` |

> **Note (Jan 22, 2026):** Bundle ID was changed from `ai.mybartender.mybartenderai` to `com.mybartenderai.mybartenderai` to match Apple Developer account configuration.

---

## Authentication Architecture

### MSAL Configuration for CIAM

Microsoft Entra External ID (CIAM) requires B2C-style authority configuration on iOS. The key insight is that CIAM uses a custom authority URL format (`*.ciamlogin.com`) which requires `MSALB2CAuthority` under the hood.

**Critical Configuration Points:**

1. **Authority Type**: Must be `AuthorityType.b2c` even though this is CIAM, not B2C
2. **Authority URL**: Must include the full tenant path: `https://{tenant}.ciamlogin.com/{tenant}.onmicrosoft.com/`
3. **Redirect URI**: MSAL iOS SDK automatically generates redirect URIs in the format `msauth.{bundleId}://auth`

### Redirect URI Registration

The iOS redirect URI `msauth.com.mybartenderai.mybartenderai://auth` must be registered in Microsoft Entra ID.

**Important:** The Azure Portal UI may reject this redirect URI format with validation error "Must start with HTTPS, HTTP, or 'customScheme://'". If this happens, use the **Manifest Editor** instead:

1. Navigate to Azure Portal > Entra ID > App Registrations
2. Select the MyBartenderAI app registration
3. Go to **Manifest** in the left menu
4. Find the `replyUrlsWithType` array
5. Add the following entry:
   ```json
   {
       "url": "msauth.com.mybartenderai.mybartenderai://auth",
       "type": "InstalledClient"
   }
   ```
6. Click **Save**

**Alternative (if Portal UI accepts it):**
1. Go to **Authentication** > **Mobile and desktop applications**
2. Add the redirect URI: `msauth.com.mybartenderai.mybartenderai://auth`
3. Ensure **Allow public client flows** is set to **Yes**

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

#### 2a. App Crashes on Restart (Release Build)

**Symptom:** App works after fresh install, but crashes with white screen when reopened after being terminated

**Cause:** Background services (NotificationService, WorkManager) initializing before Flutter engine is fully ready on iOS cold start

**Solution:** See "iOS Cold Start Crash Fix" section below for comprehensive fix

#### 2b. App Crashes After Adding WorkManager (Jan 22, 2026)

**Symptom:** White screen flash, immediate crash on cold start after adding WorkManager support

**Cause:** `WorkmanagerPlugin.registerPeriodicTask()` called BEFORE `GeneratedPluginRegistrant.register()` in AppDelegate.swift

**Solution:** Always register Flutter plugins FIRST, then WorkManager:
```swift
// CORRECT ORDER:
GeneratedPluginRegistrant.register(with: self)  // FIRST
WorkmanagerPlugin.registerPeriodicTask(...)      // AFTER
```

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
| Redirect URI | `msauth.{bundleId}://auth` (note: dot separator) | `msauth://{bundleId}/callback` |
| Keychain | Requires entitlements | Automatic |
| Token Refresh Interval | 4 hours (less reliable background tasks) | 6 hours (AlarmManager reliable) |

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
xcrun devicectl device process launch --device <DEVICE_UDID> com.mybartenderai.mybartenderai
```

This bypasses Flutter's build script which can introduce extended attributes that cause code signing failures on macOS 15+.

---

## Local Notifications & Deep Linking

### Problem

iOS notifications for "Today's Special" display correctly, but tapping them only opens the app without navigating to the cocktail detail screen. This works correctly on Android.

### Root Cause

The `flutter_local_notifications` plugin's `getNotificationAppLaunchDetails()` method doesn't reliably capture notification tap data on iOS cold starts. By the time the Flutter engine initializes and checks for launch details, iOS has already "consumed" the notification response.

### Solution

Handle notification taps at the **native iOS level** in AppDelegate.swift, storing the payload in UserDefaults before Flutter even starts. Flutter then reads this on startup.

**Location**: `ios/Runner/AppDelegate.swift`

```swift
import Flutter
import UIKit
import UserNotifications
import workmanager_apple  // WorkManager plugin for iOS background tasks

@main
@objc class AppDelegate: FlutterAppDelegate {

  // Key must include "flutter." prefix to match SharedPreferences on iOS
  private let pendingNotificationKey = "flutter.pending_cocktail_navigation"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Set ourselves as notification delegate BEFORE plugin registration
    UNUserNotificationCenter.current().delegate = self

    // CRITICAL: Register Flutter plugins FIRST
    GeneratedPluginRegistrant.register(with: self)

    // Register WorkManager periodic task for token refresh AFTER plugins are registered
    // This enables iOS BGTaskScheduler to run our Dart background code
    // Frequency: 4 hours - iOS may adjust this based on user patterns
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.mybartenderai.tokenRefreshKeepalive",
      frequency: NSNumber(value: 4 * 60 * 60) // 4 hours in seconds
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle notification tap when app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .badge, .sound])
  }

  // Handle notification tap - called when user taps a notification
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo

    // Extract payload (flutter_local_notifications stores it in userInfo)
    if let payload = userInfo["payload"] as? String {
      // Store in UserDefaults for Flutter to read via SharedPreferences
      UserDefaults.standard.set(payload, forKey: pendingNotificationKey)
    }

    // Call super to let flutter_local_notifications handle it too
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}
```

### Flutter Side Implementation

**Location**: `lib/src/app/bootstrap.dart`

The notification service is initialized **before** `runApp()` to capture launch details early:

```dart
Future<void> bootstrap(...) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check for notification launch details BEFORE runApp()
  await _checkNotificationLaunchDetails();

  runApp(...);
}
```

**Location**: `lib/main.dart`

The app checks SharedPreferences on startup and retries navigation multiple times:

```dart
Future<void> _checkPendingNavigation() async {
  final prefs = await SharedPreferences.getInstance();
  final pendingId = prefs.getString('pending_cocktail_navigation');
  if (pendingId != null && pendingId.isNotEmpty) {
    _pendingCocktailId = pendingId;
    await prefs.remove('pending_cocktail_navigation');
    _scheduleNavigationRetry(pendingId, delayMs: 1500);
  }
}
```

### Key Insights

| Factor | Explanation |
|--------|-------------|
| Native Handling | iOS notification taps must be captured in AppDelegate.swift before Flutter starts |
| UserDefaults Key | Must use `flutter.` prefix to match SharedPreferences on iOS |
| Delegate Timing | Set `UNUserNotificationCenter.delegate` BEFORE plugin registration |
| Retry Logic | Multiple navigation attempts with increasing delays handles timing issues |

### DarwinInitializationSettings

The notification plugin must request iOS permissions during initialization:

```dart
final darwinSettings = DarwinInitializationSettings(
  requestAlertPermission: true,   // Must be true for iOS
  requestBadgePermission: true,
  requestSoundPermission: true,
  notificationCategories: [
    DarwinNotificationCategory(
      'todays_special',
      actions: [
        DarwinNotificationAction.plain('view', 'View Recipe'),
      ],
    ),
  ],
);
```

**Critical**: Setting these to `false` will prevent iOS from ever requesting notification permissions, causing all local notifications to be silently blocked.

---

## iOS Cold Start Crash Fix

### Problem

After installing the app fresh, it works correctly. However, if the user closes the app completely (swipe up to terminate) and then reopens it, the app crashes immediately - white screen flashes and returns to the iOS home screen. This issue does not occur on Android.

### Root Cause

**Multiple factors combined to cause this crash:**

1. **Early Background Service Initialization**: `NotificationService` and `BackgroundTokenService` (WorkManager) were initialized in `bootstrap.dart` BEFORE `runApp()`. On iOS cold start from terminated state, this causes crashes because the Flutter engine isn't fully attached to the iOS view hierarchy yet.

2. **Background Notification Handler**: The `onDidReceiveBackgroundNotificationResponse: notificationTapBackground` callback in `flutter_local_notifications` is a known crash source on iOS (Issue #2025). When iOS launches from terminated state, this handler can be invoked before Flutter is ready.

3. **Keychain Data Corruption**: iOS Keychain can occasionally return corrupted data on cold start. Without try-catch handling around `DateTime.parse()` and `jsonDecode()` calls in `TokenStorageService`, this causes unhandled exceptions that crash the app before the UI renders.

### Solution

#### 1. Defer Background Initialization on iOS (`bootstrap.dart`)

Skip early notification/background initialization on iOS. These services initialize AFTER `runApp()` instead.

```dart
if (!Platform.isIOS) {
  // CRITICAL: Check for notification launch details BEFORE runApp()
  // This is required for Android to properly capture the notification that launched the app
  await _checkNotificationLaunchDetails();

  // Initialize background token refresh service
  try {
    await BackgroundTokenService.instance.initialize();
    debugPrint('BackgroundTokenService initialized');
  } catch (e) {
    debugPrint('Failed to initialize BackgroundTokenService: $e');
  }
} else {
  debugPrint('[iOS] Skipping early background service initialization to prevent cold start crash');
}
```

#### 2. Initialize BackgroundTokenService After App Starts (`main.dart`)

For iOS, initialize the background service in `initState()` after the app is running:

```dart
@override
void initState() {
  super.initState();
  _initializeNotifications();
  _checkPendingNavigation();
  // iOS-specific: Initialize BackgroundTokenService here (after app is running)
  if (Platform.isIOS) {
    _initializeBackgroundServicesIOS();
  }
}

Future<void> _initializeBackgroundServicesIOS() async {
  try {
    debugPrint('[iOS] Initializing BackgroundTokenService after app started...');
    await BackgroundTokenService.instance.initialize();
    debugPrint('[iOS] BackgroundTokenService initialized successfully');
  } catch (e) {
    debugPrint('[iOS] Failed to initialize BackgroundTokenService: $e');
  }
}
```

#### 3. Disable Background Notification Handler on iOS (`notification_service.dart`)

The `onDidReceiveBackgroundNotificationResponse` callback causes iOS crashes. On iOS, use `getNotificationAppLaunchDetails()` to capture launch notifications instead.

```dart
await _plugin.initialize(
  initializationSettings,
  onDidReceiveNotificationResponse: _onNotificationTap,
  // Only register background handler on Android - iOS uses launch details instead
  onDidReceiveBackgroundNotificationResponse: Platform.isIOS ? null : notificationTapBackground,
);
```

#### 4. Error Handling in TokenStorageService (`token_storage_service.dart`)

Add try-catch blocks around all parsing operations to handle corrupted Keychain data gracefully:

```dart
Future<DateTime?> getExpiresAt() async {
  final value = await _storage.read(key: AuthConfig.expiresAtKey);
  if (value == null) return null;
  try {
    return DateTime.parse(value);
  } catch (e) {
    // Corrupted data - clear it and return null to prevent crash on iOS restart
    await _storage.delete(key: AuthConfig.expiresAtKey);
    return null;
  }
}
```

Apply the same pattern to `getLastRefreshTime()` and `getUserProfile()`.

### Files Modified

| File | Changes |
|------|---------|
| `lib/src/app/bootstrap.dart` | Skip early init on iOS, add Platform import |
| `lib/main.dart` | Add iOS-specific `_initializeBackgroundServicesIOS()` |
| `lib/src/services/notification_service.dart` | Conditionally disable background handler on iOS |
| `lib/src/services/token_storage_service.dart` | Add try-catch error handling, iOS Keychain options |

### Why This Works

| Factor | Explanation |
|--------|-------------|
| Deferred Initialization | iOS gets time to fully initialize Flutter engine before background services start |
| No Background Handler | Avoids flutter_local_notifications Issue #2025 crash on iOS |
| Error Handling | Corrupted Keychain data triggers graceful logout instead of crash |
| Platform-Specific | Changes only affect iOS - Android behavior unchanged |

### Related Issues

- [flutter_local_notifications #2025](https://github.com/MaikuB/flutter_local_notifications/issues/2025) - iOS crash from terminated state
- [flutter_secure_storage #794](https://github.com/juliansteenbakker/flutter_secure_storage/issues/794) - iOS 18/Xcode 16 startup crashes
- [Flutter #66422](https://github.com/flutter/flutter/issues/66422) - Flutter crashing after app kill/restart on iOS

---

## iOS Token Refresh Workaround (Entra External ID)

### Problem

Microsoft Entra External ID (CIAM) has a hardcoded 12-hour inactivity timeout for refresh tokens. After 12 hours without token activity, users must re-authenticate. This is a known Microsoft limitation with no official fix.

### iOS-Specific Challenges

Unlike Android (which has reliable AlarmManager), iOS has stricter background execution limits:
- **No AlarmManager equivalent**: iOS doesn't allow apps to schedule guaranteed wake-ups
- **BGTaskScheduler limitations**: iOS controls timing, not the app (may delay hours or skip)
- **30-second execution window**: Maximum background task duration before iOS suspends

### Solution: 4-Layer Defense for iOS

| Layer | Mechanism | Interval | Reliability |
|-------|-----------|----------|-------------|
| 1 | Foreground Refresh (AppLifecycleService) | 4 hours | High (when app opens) |
| 2 | WorkManager One-Off Tasks | 4 hours | Medium (iOS controls timing) |
| 3 | Notification Alarms | 4 hours | Medium (needs permission) |
| 4 | Welcome Back Dialog | N/A | Fallback (graceful re-login) |

### Key Implementation Details

**Shorter Intervals than Android:** iOS uses 4-hour intervals (vs 6 hours on Android) because background tasks are less reliable. This provides 8 hours of safety margin before the 12-hour timeout.

**Chain Scheduling:** iOS one-off tasks are more reliable than periodic tasks. After each successful refresh, the next task is re-scheduled (chain scheduling pattern).

**Native WorkManager Registration:** Required in `AppDelegate.swift` for iOS BGTaskScheduler to recognize the task:

```swift
WorkmanagerPlugin.registerPeriodicTask(
  withIdentifier: "com.mybartenderai.tokenRefreshKeepalive",
  frequency: NSNumber(value: 4 * 60 * 60) // 4 hours
)
```

**Info.plist Configuration:** Required entries for background task support:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
</array>
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.mybartenderai.tokenRefreshKeepalive</string>
</array>
```

### Files Modified

| File | Change |
|------|--------|
| `AppDelegate.swift` | Native WorkManager registration |
| `app_lifecycle_service.dart` | Platform-aware 4-hour threshold |
| `background_token_service.dart` | iOS one-off tasks with chain scheduling |
| `notification_service.dart` | Platform-aware 4-hour alarm interval |

See `ENTRA_REFRESH_TOKEN_WORKAROUND.md` for complete documentation.

---

**Last Updated**: January 22, 2026
**Implementation Status**: Complete and Tested
