# MyBartenderAI Notification System

**Last Updated**: January 8, 2026

This document describes the notification architecture in the MyBartenderAI mobile app, including Today's Special daily notifications and background token refresh notifications.

---

## Overview

The app uses two types of local notifications:

| Type | Purpose | Frequency | User-Facing |
|------|---------|-----------|-------------|
| **Today's Special** | Daily cocktail recommendation | Once daily at configured time | Yes - featured content |
| **Session Keepalive** | Background token refresh | Every 6 hours | Yes - informative status |

Both are managed by `NotificationService` in `mobile/app/lib/src/services/notification_service.dart`.

---

## Notification Channels

Android 8.0+ requires notification channels. The app creates two channels:

### Today's Special Channel

```dart
Channel ID: todays_special_channel
Name: Today's Special
Description: Daily reminder featuring the bartender's special cocktail
Importance: HIGH
Sound: Yes
Vibration: Yes
```

**User Control**: Users can disable this channel in Android Settings → Apps → My AI Bartender → Notifications → Today's Special.

### Session Keepalive Channel

```dart
Channel ID: token_refresh_background
Name: Session Keepalive
Description: Periodic notification to keep you signed in automatically
Importance: LOW
Sound: No
Vibration: No
```

**User Control**: Users can disable this channel in Android Settings → Apps → My AI Bartender → Notifications → Session Keepalive.

---

## Today's Special Notifications

### Purpose

Delivers a daily cocktail recommendation to users at their preferred time, driving app engagement and showcasing the cocktail database.

### Implementation

**Location**: `notification_service.dart`, `scheduleTodaysSpecialNotification()`

**Features**:
- Schedules 7 days of notifications ahead (not repeating alarms - more reliable)
- Configurable notification time (default: 5:00 PM)
- Deep links to cocktail detail when tapped
- Idempotent scheduling (30-minute cooldown prevents infinite loops)
- Battery optimization exemption for reliable delivery
- Exact alarm scheduling when permission granted

### Notification Content

```
Title: Today's Special: [Cocktail Name]
Body: Time to mix something special! · [Category] · Served in a [Glass]
```

### Deep Linking

When tapped, the notification navigates to the cocktail detail screen:

1. Notification payload contains `cocktailId`
2. `main.dart` receives tap callback
3. Router navigates to `/cocktail/{id}`
4. `CocktailDetailScreen` displays the featured cocktail

**Note**: See `TODAYS_SPECIAL_FEATURE.md` for deep linking implementation details and Issue #5 fix.

---

## Session Keepalive Notifications

### Purpose

Keeps the Microsoft Entra External ID refresh token active by triggering a background token refresh every 6 hours. This prevents users from being logged out after 12 hours of inactivity.

### The 12-Hour Problem

Microsoft Entra External ID has a **12-hour inactivity timeout** on refresh tokens. Without periodic refresh:

```
User logs in → Closes app → 12 hours pass → Opens app → Token expired → Must re-login
```

### Solution: Multi-Layer Token Refresh

The app uses three layers of protection:

| Layer | Mechanism | Interval | Reliability |
|-------|-----------|----------|-------------|
| 1 | **AppLifecycleService** | On app resume | High when app is used |
| 2 | **AlarmManager** (Session Keepalive) | 6 hours | High - fires in Doze mode |
| 3 | **WorkManager** | 8 hours | Moderate backup |

### Implementation

**Location**: `notification_service.dart`, `scheduleTokenRefreshAlarm()`

**Flow**:
1. User logs in
2. `AuthService` schedules token refresh alarm for 6 hours
3. When alarm fires, notification appears
4. `_onNotificationTap()` detects `TOKEN_REFRESH_TRIGGER` payload
5. Calls registered `onTokenRefreshNeeded` callback
6. `AuthService.refreshToken()` silently refreshes the token
7. Alarm reschedules for next 6 hours

### Notification Content

```
Title: Session Active
Body: Keeping you signed in automatically
```

**Why visible instead of hidden?**

Android's notification system is designed to prevent apps from showing truly invisible notifications (security/privacy concern). Attempts to hide the notification (empty title, empty body, minimum importance, secret visibility) still resulted in Android displaying the app name.

Instead of confusing users with an empty notification, we make it informative:
- Users understand what's happening
- Builds trust ("the app is taking care of me")
- Users can still disable it if desired

### Notification Settings

```dart
Importance: LOW (visible but non-intrusive)
Priority: LOW
Sound: false
Vibration: false
Silent: true
ShowWhen: true (shows timestamp)
Visibility: PRIVATE (shows on lock screen, hides content)
AutoCancel: true (dismisses on tap)
```

### Payload Filtering

In `main.dart`, the notification tap handler filters out token refresh notifications:

```dart
if (cocktailId != null && cocktailId != 'TOKEN_REFRESH_TRIGGER') {
  // Navigate to cocktail detail
}
```

This prevents accidental navigation when users tap the Session Keepalive notification.

---

## Android Permissions

The app requires these permissions for notifications:

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
```

| Permission | Purpose |
|------------|---------|
| `POST_NOTIFICATIONS` | Required on Android 13+ to show any notifications |
| `SCHEDULE_EXACT_ALARM` | Ensures notifications fire at exact times |
| `RECEIVE_BOOT_COMPLETED` | Reschedules notifications after device restart |
| `WAKE_LOCK` | Allows notification processing when device is asleep |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Prevents notification delays from Doze mode |

---

## Boot Persistence

Scheduled notifications survive device reboots via boot receivers:

```xml
<receiver android:exported="false"
          android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
</receiver>
```

---

## Battery Optimization

Android's Doze mode can delay notifications. The app:

1. Requests battery optimization exemption via `BatteryOptimizationService`
2. Uses `exactAllowWhileIdle` alarm scheduling mode
3. Shows a one-time prompt to users explaining why exemption helps

---

## User Settings

### Today's Special

**Location**: Profile Screen → Today's Special Reminder

- **Toggle**: Enable/disable notifications entirely
- **Time Picker**: Choose notification time (default: 5:00 PM)

Settings stored in `SharedPreferences`:
- `notification_enabled`: Boolean
- `notification_hour`: Int (0-23)
- `notification_minute`: Int (0-59)

### Session Keepalive

No in-app setting. Users can disable via Android system settings:
1. Settings → Apps → My AI Bartender
2. Notifications → Session Keepalive → Toggle off

---

## Troubleshooting

### Notifications Not Appearing

1. **Check system permission**: Settings → Apps → My AI Bartender → Notifications → Enabled?
2. **Check channel enabled**: Settings → Apps → My AI Bartender → Notifications → [Channel Name] → Enabled?
3. **Check battery optimization**: Settings → Apps → My AI Bartender → Battery → Unrestricted?
4. **Check exact alarm permission** (Android 12+): Settings → Apps → My AI Bartender → Alarms & Reminders → Allowed?

### Deep Links Not Working

See `TODAYS_SPECIAL_FEATURE.md` Issue #5 for the `refreshListenable` pattern fix.

### Token Refresh Failing

Check logs for `[TOKEN-ALARM]` entries:
```
[TOKEN-ALARM] Token refresh alarm triggered
[TOKEN-ALARM] Token refresh completed, rescheduling alarm
```

If refresh fails, user will be prompted to re-login next time they open the app.

---

## Code References

| File | Purpose |
|------|---------|
| `notification_service.dart` | All notification logic |
| `auth_service.dart` | Token refresh scheduling after login |
| `app_lifecycle_service.dart` | Foreground token refresh |
| `background_token_service.dart` | WorkManager backup refresh |
| `main.dart` | Notification tap handling and routing |
| `todays_special_provider.dart` | Today's Special selection and scheduling |
| `profile_screen.dart` | Notification settings UI |

---

## History

### January 8, 2026 - Session Keepalive UX Fix

**Problem**: Users saw a mysterious notification with just "My AI Bartender" and no content every ~6 hours.

**Root Cause**: The token refresh alarm was configured to be "silent" with empty title/body, but Android still displayed the app name.

**Solution**: Changed from attempting to hide the notification to making it informative:
- Title: "Session Active"
- Body: "Keeping you signed in automatically"

**Rationale**: Transparency is better than confusion. Users now understand what the notification means and can disable it if desired via Android settings.

---

**Related Documents**:
- `TODAYS_SPECIAL_FEATURE.md` - Today's Special implementation details
- `DEPLOYMENT_STATUS.md` - Overall app status
- `AUTHENTICATION_IMPLEMENTATION.md` - Auth flow details
