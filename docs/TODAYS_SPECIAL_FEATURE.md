# Today's Special Feature

**Date**: January 2026
**Version**: 1.4.0
**Status**: Implemented with Notifications & Bug Fixes

## Overview

The Today's Special feature displays a randomly selected cocktail on the home screen that changes once per day at midnight. Users receive a daily notification at a configurable time (default 5:00 PM) reminding them of the day's special cocktail. Tapping the notification navigates directly to the cocktail detail screen.

## Feature Specifications

### Core Functionality

1. **Random Selection**: Each day, a random cocktail is selected from the local SQLite database
2. **Daily Persistence**: The selection remains consistent throughout the entire calendar day
3. **Automatic Refresh**: At local midnight, the selection automatically refreshes to a new random cocktail
4. **Caching**: SharedPreferences stores the current day's selection to prevent re-randomization on app restarts
5. **Daily Notifications**: Scheduled notifications at user-configurable time (default 5:00 PM)
6. **Deep Linking**: Tapping notification opens cocktail detail screen directly

### User Experience

- **Display**: Prominent card on home screen showing:
  - "Today's Special" header
  - Cocktail name (e.g., "Margarita", "Mojito")
  - Flavor profile or category info
- **Interaction**: Tapping the card navigates to full cocktail details via GoRouter
- **Notifications**: Daily reminder with cocktail name, category, and glass type
- **Settings**: Configurable notification time in Profile > Notifications

## Technical Implementation

### File Structure

```
mobile/app/lib/src/
├── features/home/
│   ├── providers/
│   │   └── todays_special_provider.dart     # Core business logic + notification scheduling
│   └── home_screen.dart                     # UI display + GoRouter navigation
├── services/
│   ├── notification_service.dart            # Notification scheduling & deep linking
│   └── battery_optimization_service.dart    # Battery exemption for reliable alarms
└── main.dart                                # Route definitions + notification callbacks
```

### Core Provider (`todays_special_provider.dart`)

**Type**: `FutureProvider<Cocktail?>`

**Key Features**:

- Automatic midnight refresh using `Timer`
- Date-based cache key formatting (`YYYY-MM-DD`)
- Integration with local SQLite database
- SharedPreferences for persistence
- Notification scheduling on cocktail selection
- Diagnostic logging with `[TODAYS-SPECIAL]` tag

**Logic Flow**:

1. Calculate time until next midnight
2. Set timer to invalidate provider at midnight
3. Check SharedPreferences for today's cached selection
4. If cache miss or date mismatch, fetch random cocktail from database
5. Store new selection with today's date key
6. Schedule 7 days of notifications via `NotificationService`

### Notification Service (`notification_service.dart`)

**Key Features**:

- Schedules 7 individual one-time notifications (more reliable than repeating)
- Uses `exactAllowWhileIdle` for precise timing on Android 12+
- Integrates with `BatteryOptimizationService` for reliable delivery on OEM devices
- **Idempotency check**: Prevents re-scheduling within 30 minutes to avoid loops
- **Force parameter**: Allows bypassing idempotency when user changes settings
- Deep link payload contains cocktail ID for navigation
- Diagnostic logging with `[NOTIFICATION]` tag

**Notification Details**:

```dart
AndroidNotificationDetails(
  channelId: 'todays_special_channel',
  channelName: 'Today\'s Special',
  importance: Importance.high,
  priority: Priority.high,
  autoCancel: false,        // Stays until user dismisses
  visibility: NotificationVisibility.public,
  category: AndroidNotificationCategory.reminder,
)
```

### Navigation & Deep Linking (`main.dart`)

**Route Definition**:

```dart
GoRoute(
  path: '/cocktail/:id',
  builder: (context, state) {
    final cocktailId = state.pathParameters['id']!;
    return CocktailDetailScreen(cocktailId: cocktailId);
  },
),
```

**Notification Tap Handling**:

1. `NotificationService.initialize(onTap: callback)` registers tap handler
2. On tap, callback receives cocktail ID from payload
3. `_navigateToCocktail()` uses global router to push `/cocktail/:id` route
4. Route is protected from redirects to ensure detail screen stays visible

### Data Storage

**SharedPreferences Keys**:

- `todays_special_date`: Date string (format: `YYYY-MM-DD`)
- `todays_special_id`: Cocktail ID from database
- `notification_enabled`: Boolean (default: true)
- `notification_hour`: Integer 0-23 (default: 17)
- `notification_minute`: Integer 0-59 (default: 0)
- `notification_last_scheduled`: Timestamp in milliseconds (for idempotency)

## Bug Fixes (December 2025 - January 2026)

### Issue #1: Card Flashes and Closes

**Problem**: When tapping the notification, the cocktail detail card appeared briefly then disappeared.

**Root Cause**: Router redirect logic in `main.dart` didn't exempt `/cocktail/:id` route. When redirect conditions triggered (sync needed, auth check, etc.), the detail screen got immediately redirected away.

**Fixes Applied**:

1. **Protected `/cocktail/:id` from redirects** (`main.dart`):
   ```dart
   final isCocktailRoute = state.matchedLocation.startsWith('/cocktail/');
   if (isCocktailRoute) {
     return null; // Allow through without redirect
   }
   ```

2. **Added pending navigation retry** (`main.dart`):
   - Stores pending cocktail ID if router not ready
   - Retries navigation after router becomes available in build()

3. **Unified navigation to GoRouter** (`home_screen.dart`):
   - Changed from `Navigator.push(MaterialPageRoute(...))` to `context.push('/cocktail/${cocktail.id}')`
   - Ensures consistent navigation stack with notification deep links

### Issue #2: Notifications Not Firing

**Problem**: On some installs, the daily notification never appeared.

**Root Causes**:
- Battery optimization killing scheduled alarms on Samsung/Xiaomi/Huawei
- Permissions not granted

**Fixes Applied**:

1. **Battery optimization exemption** (`notification_service.dart`):
   ```dart
   if (Platform.isAndroid) {
     await BatteryOptimizationService.instance.requestOptimizationExemption();
   }
   ```

2. **Enhanced diagnostic logging**:
   - `[NOTIFICATION]` logs show permission status, scheduling details, errors
   - `[TODAYS-SPECIAL]` logs show cocktail selection, cache status, database state

### Issue #3: Infinite Notification Loop (January 2026)

**Problem**: After tapping a Today's Special notification, the app fired another notification every 1-2 minutes in an infinite loop until notifications were disabled.

**Root Cause**: The catch-up notification logic (from Issue #2 fix) combined with provider re-evaluation created a loop:
1. `todaysSpecialProvider` called `scheduleTodaysSpecialNotification()` on every evaluation
2. If today's time had passed, a catch-up notification was scheduled for 1 minute later
3. When notification fired, app foregrounded, provider re-evaluated
4. Re-evaluation cancelled all notifications and scheduled new catch-up in 1 minute
5. Loop repeated indefinitely

**Fixes Applied**:

1. **Added idempotency check** (`notification_service.dart`):
   ```dart
   static const String _lastScheduledKey = 'notification_last_scheduled';
   static const int _minScheduleIntervalMinutes = 30;

   // Skip if we've scheduled within the last 30 minutes
   if (!force) {
     final lastScheduled = prefs.getInt(_lastScheduledKey) ?? 0;
     final minutesSinceLastSchedule = (now - lastScheduled) / (1000 * 60);
     if (minutesSinceLastSchedule < _minScheduleIntervalMinutes) {
       return; // Skip - already scheduled recently
     }
   }
   ```

2. **Removed 1-minute catch-up logic** (`notification_service.dart`):
   ```dart
   // If scheduled time is in the past, skip it (no catch-up to prevent loops)
   if (scheduledDate.isBefore(now)) {
     continue; // Tomorrow's notification will fire correctly
   }
   ```

3. **Added force parameter** (`notification_service.dart`):
   ```dart
   Future<void> scheduleTodaysSpecialNotification(Cocktail cocktail, {bool force = false})
   ```
   - `force: true` bypasses idempotency check
   - Used in `profile_screen.dart` when user changes notification settings

### Issue #4: App Not in "App Notifications" Until Test (January 2026)

**Problem**: After fresh install and granting notification permission, the app didn't appear in Settings → Notifications → App notifications. Today's Special notifications never fired unless user tapped "Test Notification" in profile settings.

**Root Cause**: Android 8.0+ (API 26+) requires notification channels to be explicitly created before notifications work. The `NotificationService.initialize()` method only initialized the plugin but didn't create channels. Channels were created implicitly when the first notification was shown (via `show()`), but `zonedSchedule()` only scheduled future notifications without triggering channel registration in Android system settings.

**Why "Test Notification" Fixed It**: The test notification called `show()` which immediately displays a notification, which creates and registers the channel visibly in Android settings.

**Fixes Applied**:

1. **Added explicit channel creation** (`notification_service.dart`):
   ```dart
   Future<void> _createNotificationChannels() async {
     if (!Platform.isAndroid) return;

     final androidPlugin = _plugin
         .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

     if (androidPlugin == null) return;

     // Create Today's Special channel
     const todaysSpecialChannel = AndroidNotificationChannel(
       _todaysSpecialChannelId,
       _todaysSpecialChannelName,
       description: _todaysSpecialChannelDescription,
       importance: Importance.high,
       playSound: true,
       enableVibration: true,
     );
     await androidPlugin.createNotificationChannel(todaysSpecialChannel);

     // Create Token Refresh channel (silent/hidden)
     const tokenRefreshChannel = AndroidNotificationChannel(
       _tokenRefreshChannelId,
       _tokenRefreshChannelName,
       description: _tokenRefreshChannelDescription,
       importance: Importance.min,
       playSound: false,
       enableVibration: false,
     );
     await androidPlugin.createNotificationChannel(tokenRefreshChannel);
   }
   ```

2. **Called from initialize()** (`notification_service.dart`):
   ```dart
   await _requestNotificationPermission();
   await _createNotificationChannels();  // Ensures channels exist immediately
   await _ensureTimeZoneInitialized();
   ```

**Why This Fix Works**:
- `createNotificationChannel()` is the official Android API for registering channels
- Channels appear in system settings immediately, without waiting for first notification
- App now appears in "App notifications" right after installation
- Scheduled notifications work because the channel already exists when they fire

### Issue #5: Card Flashes & Notification Doesn't Clear (January 2026)

**Problems**:
1. When tapping notification, cocktail detail card flashes briefly then redirects to home screen
2. After tapping notification, it remains in the notification tray instead of being dismissed

**Root Cause #1 - Card Flash (Initial Fix)**: The router's `initialSyncStatus` check could redirect away from the cocktail route. While an early exemption existed at lines 191-195, the initial sync check at lines 217-222 didn't include this protection, creating a potential race condition when provider state changed.

**Root Cause #2 - Notification Not Clearing**: `autoCancel: false` was explicitly set in the notification configuration, preventing automatic dismissal on tap.

**Initial Fixes Applied**:

1. **Added cocktail route protection to initial sync check** (`main.dart`):
   ```dart
   // Before
   if (isAuthenticated && !isInitialSyncRoute && !initialSyncStatus.isChecking) {

   // After
   if (isAuthenticated && !isInitialSyncRoute && !isCocktailRoute && !initialSyncStatus.isChecking) {
   ```

2. **Changed autoCancel to true** (`notification_service.dart`):
   ```dart
   // Before (lines 409 and 595)
   autoCancel: false,  // Keep notification visible

   // After
   autoCancel: true,   // Dismiss on tap (standard Android behavior)
   ```

### Issue #5 REGRESSION: Card Flash Returns (January 2026)

**Problem**: The card flash issue returned despite the previous fixes. During cold start, tapping notification would:
1. Show cocktail detail briefly ✓
2. Card disappears, redirects to home ✗

**TRUE ROOT CAUSE - Router Recreation via ref.watch()**:

The `routerProvider` in `main.dart` used `ref.watch()` on three state providers:
```dart
// BEFORE (Broken)
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);        // ← PROBLEM!
  final isAgeVerified = ref.watch(ageVerificationProvider); // ← PROBLEM!
  final initialSyncStatus = ref.watch(initialSyncStatusProvider); // ← PROBLEM!

  return GoRouter(
    initialLocation: '/',  // ← New router starts HERE!
    ...
  );
});
```

When any of these providers changed state (which happens asynchronously during cold start), Riverpod **recreated the entire routerProvider**, which created a **NEW GoRouter instance** with `initialLocation: '/'`. This reset the navigation stack, losing the cocktail detail route.

**Timeline of What Happened**:
```
T=0ms:   App launches from notification tap
T=50ms:  routerProvider created (authState = AuthStateInitial)
T=100ms: Router navigates to /cocktail/123 ✓ (user sees card!)
T=200ms: Auth finishes loading (authState = AuthStateAuthenticated)
T=210ms: ref.watch() detects change → triggers provider rebuild
T=220ms: NEW GoRouter created with initialLocation: '/'
T=230ms: Navigation resets to '/' ✗ (card disappears!)
```

**Why Previous Fixes Didn't Work**: The `isCocktailRoute` guards in the redirect function were inside the GoRouter that got **replaced**. When a new router was created, the navigation stack was already lost before redirect even ran.

**PERMANENT FIX - GoRouter refreshListenable Pattern** (`main.dart`):

1. **Created RouterRefreshNotifier class** that uses `ref.listen()` instead of `ref.watch()`:
   ```dart
   class RouterRefreshNotifier extends ChangeNotifier {
     RouterRefreshNotifier(Ref ref) {
       ref.listen(authNotifierProvider, (_, __) => notifyListeners());
       ref.listen(ageVerificationProvider, (_, __) => notifyListeners());
       ref.listen(initialSyncStatusProvider, (_, __) => notifyListeners());
     }
   }
   ```

2. **Modified routerProvider** to use `refreshListenable`:
   ```dart
   // AFTER (Fixed)
   final routerProvider = Provider<GoRouter>((ref) {
     final refreshNotifier = ref.watch(routerRefreshNotifierProvider);

     return GoRouter(
       refreshListenable: refreshNotifier,  // ← Re-evaluates redirects, keeps nav stack
       redirect: (context, state) {
         final authState = ref.read(authNotifierProvider);  // ← No rebuild, just reads
         // ... rest of redirect logic unchanged
       },
     );
   });
   ```

**Why This Fix Works**:
- `refreshListenable` makes GoRouter **re-evaluate its redirects** WITHOUT creating a new router instance
- The navigation stack is preserved because the same router instance handles the redirect re-evaluation
- `ref.read()` inside redirect reads current state without subscribing to changes
- This is the official GoRouter best practice for Riverpod integration

## Android Permissions

```xml
<!-- Notifications -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.VIBRATE" />

<!-- Battery optimization exemption for reliable alarms -->
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
```

## Dependencies

```yaml
# Notifications
flutter_local_notifications: ^18.0.1
timezone: ^0.10.0
permission_handler: ^11.3.1

# State Management
flutter_riverpod: ^2.6.1

# Local Storage
shared_preferences: ^2.2.3

# Database
sqflite: ^2.4.1

# Routing
go_router: ^14.8.1
```

## Testing

### Manual Test Scenarios

1. **Notification Deep Link (App Closed)**:
   - [ ] Schedule notification for 1 minute from now
   - [ ] Close app completely
   - [ ] Tap notification when it appears
   - [ ] Verify cocktail detail screen opens and STAYS visible
   - [ ] Tap back button - should return to home

2. **Notification Deep Link (App Running)**:
   - [ ] Leave app running in background
   - [ ] Wait for notification
   - [ ] Tap notification
   - [ ] App comes to foreground with cocktail detail

3. **No Infinite Loop (Issue #3 Regression Test)**:
   - [ ] Enable notifications with time in the past
   - [ ] Verify NO notification fires immediately (time passed, skip day 0)
   - [ ] Navigate around app, close and reopen
   - [ ] Verify NO repeated notifications fire
   - [ ] Tomorrow's notification should fire correctly at scheduled time

4. **User Settings Change**:
   - [ ] Change notification time in Profile > Notifications
   - [ ] Verify notifications reschedule immediately (force: true bypasses idempotency)
   - [ ] Check logs show "Force: true" in scheduling output

5. **Diagnostic Logs**:
   - [ ] Run `adb logcat | grep -E "\[NOTIFICATION\]|\[TODAYS-SPECIAL\]"`
   - [ ] Verify logs show scheduling status and any errors
   - [ ] Look for "SKIPPED - Already scheduled X minutes ago" on app resume

### Test Commands

```bash
# View diagnostic logs
adb logcat | grep -E "\[NOTIFICATION\]|\[TODAYS-SPECIAL\]"

# Check scheduled alarms
adb shell dumpsys alarm | grep mybartenderai
```

## Known Limitations

1. **iOS Support**: Currently Android-only. iOS implementation pending.
2. **Background Limits**: Android 12+ may delay inexact alarms due to battery optimization.
3. **First Run**: Notification won't schedule until Today's Special loads (requires database sync).

## Changelog

### January 2026 (v1.5.0)

- **PERMANENT FIX**: Resolved root cause of notification deep link card flash regression
- Root Cause: `routerProvider` using `ref.watch()` caused router recreation on state changes
- Added: `RouterRefreshNotifier` class using `ref.listen()` pattern
- Added: `routerRefreshNotifierProvider` for stable router refresh handling
- Changed: `routerProvider` now uses GoRouter's `refreshListenable` pattern
- Changed: Redirect function uses `ref.read()` instead of closure-captured watched state
- Result: Router stays as single instance, navigation stack preserved during auth state changes

### January 2026 (v1.4.0)

- Fixed: Cocktail detail card flashing then redirecting to home on notification tap
- Fixed: Notification not clearing from tray after user taps it
- Added: `!isCocktailRoute` protection to initial sync redirect check
- Changed: `autoCancel: false` → `autoCancel: true` for standard Android dismiss-on-tap behavior

### January 2026 (v1.3.0)

- Fixed: App not appearing in "App notifications" until test notification triggered
- Added: Explicit notification channel creation during `initialize()`
- Added: `_createNotificationChannels()` method for Android 8.0+ compatibility
- Changed: Channels now registered immediately on app startup, not on first notification

### January 2026 (v1.2.0)

- Fixed: Infinite notification loop caused by catch-up + provider re-evaluation
- Added: Idempotency check (30-minute cooldown) to prevent rapid re-scheduling
- Added: `force` parameter to bypass idempotency for user settings changes
- Removed: 1-minute catch-up notification (was causing infinite loop)
- Changed: If today's time passed, skip day 0 instead of catch-up (tomorrow will fire)

### December 2025 (v1.1.0)

- Fixed: Card flashing and closing when tapping notification
- Fixed: Notifications not firing on some devices (battery optimization)
- Added: Battery optimization exemption request
- Added: Diagnostic logging (`[NOTIFICATION]`, `[TODAYS-SPECIAL]`)
- Changed: Navigation from Navigator.push to GoRouter for consistency
- Changed: Protected `/cocktail/:id` route from redirects

### November 2025 (v1.0.0)

- Implemented core Today's Special feature
- Added random daily cocktail selection
- Implemented midnight refresh timer
- Added SharedPreferences caching
- Created UI display in home screen
- Added notification scheduling (7-day lookahead)
- Added notification settings in Profile screen

---

**Maintained By**: Claude Code
**Last Updated**: January 2026
