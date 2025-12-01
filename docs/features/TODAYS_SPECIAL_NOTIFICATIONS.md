# Today's Special Daily Notifications

## Overview

This feature sends a daily push notification to users about the "Today's Special" cocktail. The notification is scheduled for a user-configurable time (default: 5:00 PM local time) and includes the cocktail name, category, and glass type.

## Implementation Date
December 2025

## User Experience

### Notification Behavior
- **Default State**: Enabled by default (opt-out model)
- **Default Time**: 5:00 PM local time
- **Frequency**: Daily, repeating at the configured time
- **Sound**: Default system notification sound
- **Persistence**: Notification stays in notification shade until user dismisses it

### Notification Content
```
Title: Today's Special: [Cocktail Name]
Body: Time to mix something special! · [Category] · Served in a [Glass Type]
```

### User Actions
- **Tap notification (app NOT running)**: Opens the app directly to the cocktail detail page
- **Tap notification (app IS running)**: Brings app to foreground (manual navigation required)
- **Configure in Profile**: Toggle on/off, change reminder time

## Settings UI

Located in **Profile > Notifications**:

1. **Toggle Switch**: Enable/disable daily reminders
2. **Time Picker**: Choose custom reminder time (only visible when enabled)
3. **Test Notification Button**: Send immediate test notification (debug builds)

## Technical Implementation

### Files Modified

| File | Changes |
|------|---------|
| `pubspec.yaml` | Added notification packages |
| `AndroidManifest.xml` | Added notification permissions and boot receiver |
| `notification_service.dart` | Complete rewrite with customizable time |
| `todays_special_provider.dart` | Added notification scheduling and settings provider |
| `main.dart` | Added `/cocktail/:id` route, notification initialization, global router for navigation |
| `profile_screen.dart` | Added notification settings UI with toggle, time picker, test button |

### Dependencies Added

```yaml
flutter_local_notifications: ^18.0.1
timezone: ^0.10.0
permission_handler: ^11.3.1
```

Note: `flutter_native_timezone` was initially considered but removed due to Gradle namespace compatibility issues. Timezone detection is handled via custom Dart implementation using `DateTime.now().timeZoneName` and offset mapping.

### Android Permissions Added

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.VIBRATE" />
```

### Boot Receiver Configuration

```xml
<!-- Scheduled notification receiver -->
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
    </intent-filter>
</receiver>
```

### Key Components

#### NotificationService (`notification_service.dart`)
- Singleton pattern for app-wide access
- Manages notification scheduling and cancellation
- Stores user preferences (enabled state, custom time)
- Handles timezone conversion for accurate local time scheduling
- Supports deep linking via notification payload
- Custom timezone detection with fallback mappings for common US/EU timezones

#### Providers (`todays_special_provider.dart`)
- `todaysSpecialProvider`: Schedules notification when cocktail is selected
- `notificationSettingsProvider`: Exposes current notification settings to UI

#### Routing (`main.dart`)
- Added `/cocktail/:id` route for deep linking from notifications
- Initialized notification service with tap callback on app start
- Global router reference (`_globalRouter`) for navigation attempts

### Notification Flow

```
1. App starts → NotificationService.initialize()
2. Home screen loads → todaysSpecialProvider fetches today's cocktail
3. Cocktail fetched → scheduleTodaysSpecialNotification() called
4. At configured time → Notification appears
5. User taps notification:
   - If app NOT running → App launches and navigates to cocktail detail
   - If app IS running → App brought to foreground
```

### Persistence

Notifications persist across:
- App restarts
- Device reboots (via `RECEIVE_BOOT_COMPLETED` permission)

User preferences stored in SharedPreferences:
- `notification_enabled`: Boolean
- `notification_hour`: Integer (0-23)
- `notification_minute`: Integer (0-59)

### Android Notification Details

```dart
AndroidNotificationDetails(
  channelId: 'todays_special_channel',
  channelName: 'Today\'s Special',
  importance: Importance.high,
  priority: Priority.high,
  autoCancel: false,        // Notification persists until dismissed
  ongoing: false,
  visibility: NotificationVisibility.public,
  category: AndroidNotificationCategory.reminder,
)
```

## Testing

### Manual Testing Steps

1. **Enable Notifications**:
   - Go to Profile > Notifications
   - Ensure toggle is ON
   - Set a time 2 minutes from now
   - Wait for notification to appear

2. **Tap Notification (App Closed)**:
   - Close the app completely
   - Wait for notification
   - Tap the notification
   - Verify cocktail detail page opens directly

3. **Tap Notification (App Open)**:
   - Leave app running (foreground or background)
   - Wait for notification
   - Tap the notification
   - App comes to foreground (expected behavior)

4. **Disable Notifications**:
   - Go to Profile > Notifications
   - Turn toggle OFF
   - Verify no notification appears at configured time

5. **Change Time**:
   - Enable notifications
   - Tap on "Reminder Time"
   - Select new time
   - Verify notification reschedules

### Debug Testing

The `NotificationService` includes:
- `showTestNotification()`: Immediate test notification
- `scheduleTestNotificationInSeconds()`: Schedule test for N seconds from now

## Known Limitations

1. **iOS Support**: Currently Android-only. iOS implementation pending.
2. **Background Limits**: Android 12+ may delay inexact alarms due to battery optimization.
3. **First Run**: Notification won't schedule until Today's Special loads (requires database sync).
4. **App Running**: When app is already running, tapping notification only brings app to foreground without navigating to cocktail detail. This is a limitation of how Android handles notification callbacks for backgrounded apps.
5. **Heads-up Banner**: Tapping the heads-up banner (notification that appears at top of screen) may not respond immediately. User should pull down notification shade and tap from there.

## Future Enhancements

- iOS notification support
- Multiple notification times per day
- Different notification content variations
- Rich notifications with cocktail image
- Quick actions (favorite, share) from notification
- Improved navigation when app is already running
