# Today's Special Feature

**Date**: December 2025
**Version**: 1.1.0
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
- Supports catch-up notifications when scheduled time has passed
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

## Bug Fixes (December 2025)

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
- Time already passed when app opened (skipped that day)
- Permissions not granted

**Fixes Applied**:

1. **Battery optimization exemption** (`notification_service.dart`):
   ```dart
   if (Platform.isAndroid) {
     await BatteryOptimizationService.instance.requestOptimizationExemption();
   }
   ```

2. **Catch-up notification** (`notification_service.dart`):
   ```dart
   if (scheduledDate.isBefore(now) && dayOffset == 0) {
     // Today's time passed - schedule catch-up in 1 minute
     scheduledDate = now.add(const Duration(minutes: 1));
   }
   ```

3. **Enhanced diagnostic logging**:
   - `[NOTIFICATION]` logs show permission status, scheduling details, errors
   - `[TODAYS-SPECIAL]` logs show cocktail selection, cache status, database state

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

3. **Catch-up Notification**:
   - [ ] Set notification time to an hour ago
   - [ ] Open app after that time
   - [ ] Verify notification appears within 1 minute

4. **Diagnostic Logs**:
   - [ ] Run `adb logcat | grep -E "\[NOTIFICATION\]|\[TODAYS-SPECIAL\]"`
   - [ ] Verify logs show scheduling status and any errors

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

### December 2025 (v1.1.0)

- Fixed: Card flashing and closing when tapping notification
- Fixed: Notifications not firing on some devices (battery optimization)
- Added: Catch-up notification when scheduled time has passed
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
**Last Updated**: December 2025
