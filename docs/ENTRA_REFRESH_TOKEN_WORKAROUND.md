# Microsoft Entra External ID Refresh Token Workaround

**Last Updated:** December 2025
**Status:** Implemented and Tested
**Issue Type:** Known Microsoft Bug - No Official Fix Available

## Problem Summary

MyBartenderAI uses Microsoft Entra External ID (CIAM) for user authentication with Google, Facebook, and email sign-in options. Users were being forced to re-authenticate after approximately 12 hours of app inactivity, which is a poor user experience for a consumer mobile app.

## Root Cause Analysis

### The Error

When the app attempted to silently refresh tokens after 12 hours of inactivity, it received:

```
AADSTS700082: The refresh token has expired due to inactivity.
The token was issued on 2025-12-08T21:19:36.7279000Z and was
inactive for 12:00:00.
```

### Investigation Timeline

1. **Initial Report:** Users reported needing to re-login every ~24 hours
2. **Diagnostic Build:** Created APK with detailed `[AUTH-DIAG]` logging
3. **Root Cause Captured:** Test device captured the actual `AADSTS700082` error with "inactive for 12:00:00"
4. **Research:** Confirmed this is a known Microsoft bug with no portal-based fix

### Microsoft Bug Details

- **Affected Service:** Microsoft Entra External ID (CIAM) tenants only
- **Standard Behavior:** Regular Azure AD tenants have 90-day refresh token lifetime
- **Bug Behavior:** External ID tenants have a hardcoded 12-hour inactivity timeout
- **Configuration Options:** None available - the token lifetime settings visible in standard Entra ID are not available in Entra External ID tenants
- **Microsoft Status:** Acknowledged as a bug, no timeline for fix provided

### Sources Confirming the Bug

- Microsoft Q&A threads with CSA responses confirming it's a known issue
- Multiple developer reports of the same 12-hour timeout
- No workarounds provided by Microsoft

## Solution: Background Token Refresh

Since the 12-hour inactivity timeout cannot be configured, we implemented a workaround that prevents the refresh token from ever becoming "inactive."

### How It Works

1. **Background Task:** Using Android WorkManager, schedule a periodic background task
2. **Frequency:** Runs every 10 hours (2-hour safety margin before 12-hour timeout)
3. **Action:** Calls `acquireTokenSilent()` which uses the refresh token
4. **Result:** Using the refresh token resets the inactivity timer to zero

### Why 10 Hours?

- Microsoft's inactivity timeout: 12 hours
- Our refresh interval: 10 hours
- Safety margin: 2 hours
- This accounts for Android's WorkManager scheduling flexibility (it may delay tasks slightly based on battery optimization, device state, etc.)

## Implementation Details

### Files Modified/Created

| File                                                        | Purpose                                     |
| ----------------------------------------------------------- | ------------------------------------------- |
| `mobile/app/lib/src/services/background_token_service.dart` | **New** - Core WorkManager implementation   |
| `mobile/app/lib/src/services/auth_service.dart`             | Schedule refresh on login, cancel on logout |
| `mobile/app/lib/src/app/bootstrap.dart`                     | Initialize WorkManager on app startup       |
| `mobile/app/android/app/src/main/AndroidManifest.xml`       | Added required Android permissions          |
| `mobile/app/pubspec.yaml`                                   | Added `workmanager: ^0.9.0` dependency      |
| `mobile/app/lib/src/features/profile/profile_screen.dart`   | Added test button (Developer Tools)         |

### Key Code: Background Token Service

```dart
// background_token_service.dart

/// Callback dispatcher - MUST be a top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Perform token refresh
    return await _performTokenRefresh();
  });
}

/// Schedule periodic refresh every 10 hours
Future<void> scheduleTokenRefresh() async {
  await Workmanager().registerPeriodicTask(
    tokenRefreshTaskUniqueName,
    tokenRefreshTaskName,
    frequency: const Duration(hours: 10),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
  );
}
```

### Android Permissions Required

```xml
<!-- WorkManager permissions for background token refresh -->
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
```

### Lifecycle Integration

**On User Login (in `auth_service.dart`):**

```dart
// After successful authentication
await BackgroundTokenService.instance.scheduleTokenRefresh();
```

**On User Logout (in `auth_service.dart`):**

```dart
// Cancel background task when user signs out
await BackgroundTokenService.instance.cancelTokenRefresh();
```

**On App Startup (in `bootstrap.dart`):**

```dart
// Initialize WorkManager
await BackgroundTokenService.instance.initialize();
```

## Testing

### Test Setup

1. Built debug APK with background token refresh enabled
2. Installed on test device
3. Signed in with test account
4. Used "Test Background Refresh" button in Profile > Developer Tools to verify immediate refresh works

### Test Execution

1. **Day 1:**
   
   - Installed APK with background refresh
   - Signed in successfully
   - Verified background task was scheduled (via logs)
   - Left device idle

2. **Day 2 (12+ hours later):**
   
   - Opened app
   - **Result:** App did NOT require re-authentication
   - User session remained active

### Before vs After

| Scenario                 | Before Fix      | After Fix        |
| ------------------------ | --------------- | ---------------- |
| App idle for 12+ hours   | Forced re-login | Session persists |
| Background token refresh | Not implemented | Every 10 hours   |
| User experience          | Frustrating     | Seamless         |

## Debugging

### Log Tags

All background token refresh logs use the prefix `[BG-TOKEN]`:

```
[BG-TOKEN] === TOKEN REFRESH KEEPALIVE STARTED ===
[BG-TOKEN] Time: 2025-12-10T03:30:00.000Z
[BG-TOKEN] User found: user@example.com
[BG-TOKEN] Initializing MSAL...
[BG-TOKEN] Attempting acquireTokenSilent...
[BG-TOKEN] SUCCESS! Token refreshed silently
[BG-TOKEN] === TOKEN REFRESH KEEPALIVE SUCCEEDED ===
```

### Testing the Background Task

In Profile screen (Developer Tools section), there's a "Test Background Refresh" button that triggers an immediate one-off refresh task. This is useful for verifying the implementation without waiting 10 hours.

### Viewing WorkManager Status

Use Android's adb to check scheduled work:

```bash
adb shell dumpsys jobscheduler | grep mybartenderai
```

## Limitations and Considerations

### Android-Specific

- WorkManager is Android-only; iOS implementation will need a different approach (iOS background fetch)
- Android may delay background tasks based on Doze mode and battery optimization
- The 10-hour interval provides buffer for these delays

### Network Dependency

- Background refresh requires network connectivity
- If no network is available, WorkManager will retry with backoff
- Constraint set: `networkType: NetworkType.connected`

### Not a "True" Fix

- This is a workaround, not a fix for the underlying Microsoft bug
- If Microsoft ever fixes the 12-hour timeout, this code could be removed
- Monitor Microsoft announcements for any updates to External ID token policies

## iOS Considerations

When porting to iOS, background task execution works differently than Android. This section documents what to expect and how to implement the workaround on iOS.

### iOS vs Android Background Tasks

| Aspect | Android (WorkManager) | iOS (BGTaskScheduler) |
|--------|----------------------|----------------------|
| Timing control | Developer specifies interval | System decides when to run |
| Guaranteed execution | High reliability | Not guaranteed |
| Minimum interval | 15 minutes | System controlled |
| Battery optimization | Can request exemption | Strict system control |
| User control | Per-app battery settings | Background App Refresh toggle |

### iOS Background Task APIs

iOS 13+ provides **BGTaskScheduler** with two task types:

1. **BGAppRefreshTask** - Short tasks for refreshing content (what we need)
2. **BGProcessingTask** - Longer tasks, runs when device is idle/charging

The `workmanager` Flutter package we're using already supports iOS via BGTaskScheduler, so the Dart code will work cross-platform.

### iOS-Specific Setup Required

When implementing for iOS, add these configurations:

**1. Info.plist - Register background task identifiers:**

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
  <string>com.mybartenderai.tokenRefreshKeepalive</string>
</array>
```

**2. Info.plist - Enable background modes:**

```xml
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>processing</string>
</array>
```

**3. AppDelegate.swift - Register task handler:**

```swift
import BackgroundTasks

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Register background task
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: "com.mybartenderai.tokenRefreshKeepalive",
      using: nil
    ) { task in
      self.handleTokenRefresh(task: task as! BGAppRefreshTask)
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func handleTokenRefresh(task: BGAppRefreshTask) {
    // WorkManager plugin handles this internally
    task.setTaskCompleted(success: true)
  }
}
```

### iOS Timing Limitations

**Critical:** iOS does NOT guarantee when background tasks will run. The system considers:

- User's typical app usage patterns
- Device battery level
- Whether device is charging
- Network connectivity
- System resources

This means:
- A 10-hour interval request might actually run at 8, 12, or 15+ hours
- Tasks may be skipped entirely if conditions aren't favorable
- Users who rarely open the app may see fewer background executions

### Mitigation Strategies for iOS

To improve reliability on iOS, implement these additional measures:

**1. Foreground Token Refresh (Recommended)**

Always refresh tokens when app comes to foreground:

```dart
// In app lifecycle observer
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    // Refresh token when app comes to foreground
    _refreshTokenIfNeeded();
  }
}
```

**2. Shorter Requested Interval**

Request 6-hour intervals on iOS, hoping the system runs it within 12 hours:

```dart
final interval = Platform.isIOS
    ? const Duration(hours: 6)   // More aggressive for iOS
    : const Duration(hours: 10); // Standard for Android
```

**3. User Education**

Prompt users to enable Background App Refresh:

```dart
if (Platform.isIOS) {
  // Check if background refresh is enabled
  // Show prompt if disabled
  showDialog(
    // "Enable Background App Refresh in Settings > MyBartenderAI
    //  to stay signed in"
  );
}
```

**4. Silent Push Notifications (Advanced)**

Server can send silent push to wake app:

```json
{
  "aps": {
    "content-available": 1
  },
  "refresh-token": true
}
```

This requires:
- Apple Push Notification service (APNs) setup
- Backend service to send periodic pushes
- More infrastructure complexity

### Expected iOS Behavior

| Scenario | Expected Outcome |
|----------|-----------------|
| User opens app daily | Background refresh likely runs, no re-login |
| User opens app every few days | May occasionally need to re-login |
| Background App Refresh disabled | Will need to re-login after 12 hours |
| Device in Low Power Mode | Background tasks deprioritized |

### iOS Testing

To test background tasks on iOS simulator:

```bash
# Trigger background task manually
xcrun simctl spawn booted e -b com.mybartenderai.app -- \
  com.apple.backgroundtaskassertionqueue
```

Or in Xcode:
1. Run app in debug mode
2. Pause debugger
3. Execute: `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.mybartenderai.tokenRefreshKeepalive"]`

### iOS Summary

The workaround will work on iOS but with reduced reliability compared to Android. Expect:
- **Best case:** Background refresh runs regularly, seamless experience
- **Typical case:** Occasional re-logins for infrequent users
- **Worst case:** Users with Background App Refresh disabled will need to re-login

The foreground token refresh (checking on app resume) is the most reliable iOS strategy and should be implemented as a safety net.

## Future Considerations

1. **iOS Implementation:** Implement the iOS-specific setup documented above
2. **Foreground Refresh:** Add token refresh on app resume as iOS safety net
3. **Monitoring:** Consider adding telemetry to track background refresh success/failure rates
4. **User Notification:** If background refresh fails repeatedly, consider notifying the user to open the app
5. **Production:** Set `isInDebugMode: false` in WorkManager initialization for release builds
6. **Silent Push:** Evaluate if server-side silent push notifications are worth the infrastructure investment

## Related Documentation

- [AUTHENTICATION_SETUP.md](./AUTHENTICATION_SETUP.md) - Entra External ID configuration
- [AUTHENTICATION_IMPLEMENTATION.md](./AUTHENTICATION_IMPLEMENTATION.md) - MSAL Flutter implementation
- [Microsoft Entra External ID Docs](https://learn.microsoft.com/en-us/entra/external-id/)

## Appendix: Full Error Log

Captured from test device showing the exact error before the fix:

```
[AUTH-DIAG] ==================================================
[AUTH-DIAG] MSAL acquireTokenSilent Exception:
[AUTH-DIAG] Type: MsalException
[AUTH-DIAG] Message: AADSTS700082: The refresh token has expired
due to inactivity. The token was issued on
2025-12-08T21:19:36.7279000Z and was inactive for 12:00:00.
[AUTH-DIAG] ==================================================
```
