import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/cocktail.dart';
import 'battery_optimization_service.dart';

/// Callback for handling notification taps - must be top-level function
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // This is called when app is in background/terminated
  // The payload contains the cocktail ID
  if (kDebugMode) {
    print('Notification tapped in background: ${notificationResponse.payload}');
  }
}

class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  static const int _todaysSpecialNotificationId = 1001;
  static const String _todaysSpecialChannelId = 'todays_special_channel';
  static const String _todaysSpecialChannelName = 'Today\'s Special';
  static const String _todaysSpecialChannelDescription =
      'Daily reminder featuring the bartender\'s special cocktail.';

  // Token refresh alarm constants
  // This provides a more reliable mechanism than WorkManager for time-critical background tasks
  static const int _tokenRefreshNotificationId = 9000;
  static const String _tokenRefreshChannelId = 'token_refresh_background';
  static const String _tokenRefreshChannelName = 'Background Sync';
  static const String _tokenRefreshChannelDescription =
      'Silent background task for session management.';
  static const String _tokenRefreshPayload = 'TOKEN_REFRESH_TRIGGER';

  // Number of days ahead to schedule notifications
  // This ensures notifications fire even if user doesn't open app for a week
  static const int _daysToScheduleAhead = 7;

  // SharedPreferences keys for notification settings
  static const String _notificationEnabledKey = 'notification_enabled';
  static const String _notificationHourKey = 'notification_hour';
  static const String _notificationMinuteKey = 'notification_minute';

  // Idempotency: Track last scheduling to prevent rapid re-scheduling loops
  static const String _lastScheduledKey = 'notification_last_scheduled';
  static const int _minScheduleIntervalMinutes = 30;

  // Default notification time: 5:00 PM
  static const int _defaultHour = 17;
  static const int _defaultMinute = 0;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _timeZoneInitialized = false;

  // Callback for when notification is tapped
  Function(String? cocktailId)? onNotificationTap;

  // Callback for when token refresh alarm fires
  // This is called when the alarm triggers, allowing the auth service to perform a silent refresh
  Future<void> Function()? onTokenRefreshNeeded;

  Future<void> initialize({Function(String? cocktailId)? onTap}) async {
    if (_initialized) {
      onNotificationTap = onTap;
      return;
    }

    onNotificationTap = onTap;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _requestNotificationPermission();
    await _createNotificationChannels();
    await _ensureTimeZoneInitialized();

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }

    // Handle token refresh trigger (silent alarm)
    if (response.payload == _tokenRefreshPayload) {
      if (kDebugMode) {
        print('[TOKEN-ALARM] Token refresh alarm triggered');
      }
      // Call the token refresh callback asynchronously
      if (onTokenRefreshNeeded != null) {
        onTokenRefreshNeeded!().then((_) {
          if (kDebugMode) {
            print('[TOKEN-ALARM] Token refresh completed, rescheduling alarm');
          }
          // Reschedule the alarm for the next interval
          scheduleTokenRefreshAlarm();
        }).catchError((e) {
          if (kDebugMode) {
            print('[TOKEN-ALARM] Token refresh failed: $e');
          }
          // Still reschedule even on error
          scheduleTokenRefreshAlarm();
        });
      } else {
        if (kDebugMode) {
          print('[TOKEN-ALARM] No token refresh callback registered');
        }
      }
      return; // Don't call the regular notification tap handler
    }

    // Call the callback with the cocktail ID for regular notifications
    onNotificationTap?.call(response.payload);
  }

  Future<void> _requestNotificationPermission() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    final status = await Permission.notification.status;
    if (status.isGranted || status.isLimited) {
      if (kDebugMode) {
        print('Notification permission already granted: $status');
      }
      return;
    }

    final result = await Permission.notification.request();
    if (kDebugMode) {
      print('Notification permission result: $result');
    }
  }

  /// Create notification channels during initialization.
  ///
  /// On Android 8.0+ (API 26+), notification channels must be created before
  /// notifications can be displayed. This method ensures channels exist in
  /// Android system settings immediately after permission is granted,
  /// before any notifications are scheduled or shown.
  ///
  /// Without this, channels only appear in system settings after the first
  /// notification is actually displayed (not just scheduled), which causes
  /// the app to not appear in "App notifications" until a test notification
  /// is triggered.
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

    if (kDebugMode) {
      print('[NOTIFICATION] Notification channels created');
    }
  }

  Future<void> _ensureTimeZoneInitialized() async {
    if (_timeZoneInitialized) return;

    tz.initializeTimeZones();

    // Get the device's timezone offset and find a matching timezone
    final now = DateTime.now();
    final localOffset = now.timeZoneOffset;

    // Try to find timezone by name from the device
    String timezoneName = now.timeZoneName;

    // Common timezone mappings for Android/iOS timezone abbreviations
    final timezoneMap = <String, String>{
      'EST': 'America/New_York',
      'EDT': 'America/New_York',
      'CST': 'America/Chicago',
      'CDT': 'America/Chicago',
      'MST': 'America/Denver',
      'MDT': 'America/Denver',
      'PST': 'America/Los_Angeles',
      'PDT': 'America/Los_Angeles',
      'GMT': 'Europe/London',
      'BST': 'Europe/London',
      'CET': 'Europe/Paris',
      'CEST': 'Europe/Paris',
    };

    // Try mapped name first, then try direct lookup
    String? resolvedTimezone = timezoneMap[timezoneName];

    if (resolvedTimezone != null) {
      try {
        tz.setLocalLocation(tz.getLocation(resolvedTimezone));
        _timeZoneInitialized = true;
        if (kDebugMode) {
          print('Timezone initialized: $resolvedTimezone (from $timezoneName)');
        }
        return;
      } catch (e) {
        if (kDebugMode) {
          print('Failed to set mapped timezone: $e');
        }
      }
    }

    // Fallback: find timezone by offset
    final offsetHours = localOffset.inHours;
    final offsetMinutes = localOffset.inMinutes % 60;

    // Common US timezones by offset
    final offsetToTimezone = <int, String>{
      -5: 'America/New_York',
      -6: 'America/Chicago',
      -7: 'America/Denver',
      -8: 'America/Los_Angeles',
      0: 'Europe/London',
      1: 'Europe/Paris',
    };

    final fallbackTimezone = offsetToTimezone[offsetHours] ?? 'America/New_York';

    try {
      tz.setLocalLocation(tz.getLocation(fallbackTimezone));
    } catch (e) {
      // Ultimate fallback
      tz.setLocalLocation(tz.getLocation('America/New_York'));
    }

    _timeZoneInitialized = true;

    if (kDebugMode) {
      print('Timezone initialized: $fallbackTimezone (offset: ${offsetHours}h ${offsetMinutes}m)');
    }
  }

  /// Check if notifications are enabled
  Future<bool> isNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to true (enabled by default as per requirement)
    return prefs.getBool(_notificationEnabledKey) ?? true;
  }

  /// Set notification enabled/disabled
  Future<void> setNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationEnabledKey, enabled);

    if (!enabled) {
      await cancelTodaysSpecialNotification();
    }
  }

  /// Get the configured notification time
  Future<({int hour, int minute})> getNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_notificationHourKey) ?? _defaultHour;
    final minute = prefs.getInt(_notificationMinuteKey) ?? _defaultMinute;
    return (hour: hour, minute: minute);
  }

  /// Set the notification time
  Future<void> setNotificationTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_notificationHourKey, hour);
    await prefs.setInt(_notificationMinuteKey, minute);
  }

  /// Schedule the Today's Special notification for the next 7 days
  ///
  /// Instead of using unreliable repeating notifications, we schedule
  /// individual one-time notifications for each of the next 7 days.
  /// This ensures notifications fire reliably even if the app is killed
  /// or the user doesn't open the app for a week.
  ///
  /// Set [force] to true to bypass idempotency check (e.g., when user changes settings).
  Future<void> scheduleTodaysSpecialNotification(Cocktail cocktail, {bool force = false}) async {
    // FIX 6: Enhanced diagnostic logging
    print('[NOTIFICATION] === Scheduling Today\'s Special ===');
    print('[NOTIFICATION] Cocktail: ${cocktail.name} (ID: ${cocktail.id})');
    print('[NOTIFICATION] Force: $force');

    await initialize();

    // Idempotency check: Skip if we've scheduled within the last 30 minutes
    // This prevents infinite loops when provider re-evaluates
    if (!force) {
      final prefs = await SharedPreferences.getInstance();
      final lastScheduled = prefs.getInt(_lastScheduledKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final minutesSinceLastSchedule = (now - lastScheduled) / (1000 * 60);

      if (minutesSinceLastSchedule < _minScheduleIntervalMinutes) {
        print('[NOTIFICATION] SKIPPED - Already scheduled ${minutesSinceLastSchedule.toInt()} minutes ago');
        print('[NOTIFICATION] =============================');
        return;
      }
    }

    // FIX 6: Check and log notification permission status
    final hasPermission = await Permission.notification.isGranted;
    print('[NOTIFICATION] System permission granted: $hasPermission');
    if (!hasPermission) {
      print('[NOTIFICATION] SKIPPED - No system notification permission');
      return;
    }

    // Check if notifications are enabled in app settings
    final enabled = await isNotificationEnabled();
    print('[NOTIFICATION] App notifications enabled: $enabled');
    if (!enabled) {
      print('[NOTIFICATION] SKIPPED - Notifications disabled by user in app settings');
      return;
    }

    // FIX 4: Request battery optimization exemption for reliable alarm delivery
    if (Platform.isAndroid) {
      try {
        final batteryOptimized = await BatteryOptimizationService.instance.isOptimizationDisabled();
        print('[NOTIFICATION] Battery optimization disabled: $batteryOptimized');
        if (!batteryOptimized) {
          // Request exemption silently (dialog already shown on home screen)
          await BatteryOptimizationService.instance.requestOptimizationExemption();
        }
      } catch (e) {
        print('[NOTIFICATION] Battery optimization check failed: $e');
      }
    }

    // Cancel all existing scheduled notifications first
    await cancelTodaysSpecialNotification();

    // Determine the best schedule mode for accuracy
    // Android 12+ requires SCHEDULE_EXACT_ALARM permission for exact timing
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    if (Platform.isAndroid) {
      final canUseExact = await canScheduleExactAlarms();
      if (canUseExact) {
        scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
        print('[NOTIFICATION] Using EXACT alarm scheduling');
      } else {
        // Try to request the permission
        final granted = await requestExactAlarmPermission();
        if (granted) {
          scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
          print('[NOTIFICATION] Exact alarm permission granted');
        } else {
          print('[NOTIFICATION] Using INEXACT scheduling (may be delayed by hours)');
        }
      }
    }

    final androidDetails = AndroidNotificationDetails(
      _todaysSpecialChannelId,
      _todaysSpecialChannelName,
      channelDescription: _todaysSpecialChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(
        _buildNotificationBody(cocktail),
        contentTitle: "Today's Special: ${cocktail.name}",
        summaryText: 'Tap to see the recipe',
      ),
      // Use default sound for reliability
      playSound: true,
      channelAction: AndroidNotificationChannelAction.update,
      icon: '@mipmap/ic_launcher',
      // Dismiss notification when user taps it (standard Android behavior)
      autoCancel: true,
      ongoing: false,
      // Show on lock screen
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    // Get the notification time settings
    final time = await getNotificationTime();
    final now = tz.TZDateTime.now(tz.local);

    print('[NOTIFICATION] Configured time: ${formatTime(time.hour, time.minute)}');
    print('[NOTIFICATION] Current time: ${now.hour}:${now.minute.toString().padLeft(2, '0')}');

    int scheduledCount = 0;

    // Schedule notifications for the next 7 days
    for (int dayOffset = 0; dayOffset < _daysToScheduleAhead; dayOffset++) {
      // Calculate the scheduled date for this day
      tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + dayOffset,
        time.hour,
        time.minute,
      );

      // If scheduled time is in the past, skip it (no catch-up to prevent loops)
      if (scheduledDate.isBefore(now)) {
        if (dayOffset == 0) {
          print('[NOTIFICATION] Today\'s time already passed - skipping day 0 (tomorrow will fire)');
        }
        continue;
      }

      // Unique notification ID for each day (base ID + day offset)
      final notificationId = _todaysSpecialNotificationId + dayOffset;

      try {
        await _plugin.zonedSchedule(
          notificationId,
          "Today's Special: ${cocktail.name}",
          _buildNotificationBody(cocktail),
          scheduledDate,
          notificationDetails,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          // NO matchDateTimeComponents - each is a one-time exact alarm
          payload: cocktail.id, // Used for deep linking to cocktail detail
        );
        scheduledCount++;

        print('[NOTIFICATION] Scheduled #$notificationId for: $scheduledDate');
      } catch (e) {
        print('[NOTIFICATION] ERROR scheduling #$notificationId: $e');
      }
    }

    // Save scheduling timestamp for idempotency check
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastScheduledKey, DateTime.now().millisecondsSinceEpoch);

    print('[NOTIFICATION] === Scheduling Complete ===');
    print('[NOTIFICATION] Total scheduled: $scheduledCount notifications');
    print('[NOTIFICATION] Schedule mode: ${scheduleMode == AndroidScheduleMode.exactAllowWhileIdle ? "EXACT" : "INEXACT"}');
    print('[NOTIFICATION] =============================');
  }

  // Offset for test notification IDs (outside the multi-day range)
  static const int _testNotificationIdOffset = 100;

  /// Schedule notification for a specific number of seconds from now (for testing)
  Future<void> scheduleTestNotificationInSeconds(Cocktail cocktail, int seconds) async {
    await initialize();

    await _plugin.cancel(_todaysSpecialNotificationId + _testNotificationIdOffset);

    final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));

    // Use exact scheduling for test notifications to verify timing accuracy
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    if (Platform.isAndroid) {
      final canUseExact = await canScheduleExactAlarms();
      if (canUseExact) {
        scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      }
    }

    final androidDetails = AndroidNotificationDetails(
      _todaysSpecialChannelId,
      _todaysSpecialChannelName,
      channelDescription: _todaysSpecialChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _plugin.zonedSchedule(
        _todaysSpecialNotificationId + _testNotificationIdOffset,
        "Today's Special: ${cocktail.name}",
        'Scheduled test - this should appear in $seconds seconds!',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: cocktail.id,
      );

      if (kDebugMode) {
        print('Test notification scheduled for: $scheduledDate ($seconds seconds from now)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling test notification: $e');
      }
      rethrow;
    }
  }

  /// Cancel all scheduled Today's Special notifications
  ///
  /// Cancels all notification IDs in the range used for multi-day scheduling.
  Future<void> cancelTodaysSpecialNotification() async {
    await initialize();

    // Cancel all notification IDs used for multi-day scheduling
    for (int dayOffset = 0; dayOffset < _daysToScheduleAhead; dayOffset++) {
      final notificationId = _todaysSpecialNotificationId + dayOffset;
      await _plugin.cancel(notificationId);
    }

    if (kDebugMode) {
      print('Cancelled $_daysToScheduleAhead scheduled notifications');
    }
  }

  String _buildNotificationBody(Cocktail cocktail) {
    final parts = <String>[];

    // Add a fun tagline
    parts.add('Time to mix something special!');

    // Add category info if available
    if (cocktail.category != null && cocktail.category!.isNotEmpty) {
      parts.add(cocktail.category!);
    }

    // Add glass type if available
    if (cocktail.glass != null && cocktail.glass!.isNotEmpty) {
      parts.add('Served in a ${cocktail.glass}');
    }

    return parts.join(' · ');
  }

  /// Show an immediate test notification (for debugging)
  Future<void> showTestNotification(Cocktail cocktail) async {
    await initialize();

    final androidDetails = AndroidNotificationDetails(
      _todaysSpecialChannelId,
      _todaysSpecialChannelName,
      channelDescription: _todaysSpecialChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(
        _buildNotificationBody(cocktail),
        contentTitle: "Today's Special: ${cocktail.name}",
        summaryText: 'Tap to see the recipe',
      ),
      playSound: true,
      icon: '@mipmap/ic_launcher',
      // Dismiss notification when user taps it (standard Android behavior)
      autoCancel: true,
      ongoing: false,
      // Show on lock screen
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      _todaysSpecialNotificationId + _testNotificationIdOffset + 1, // Different ID for immediate test
      "Today's Special: ${cocktail.name}",
      _buildNotificationBody(cocktail),
      notificationDetails,
      payload: cocktail.id,
    );

    if (kDebugMode) {
      print('Test notification shown for: ${cocktail.name}');
    }
  }

  /// Check if exact alarms are permitted (Android 12+)
  Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;

    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        return await androidPlugin.canScheduleExactNotifications() ?? false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking exact alarm permission: $e');
      }
    }
    return false;
  }

  /// Request exact alarm permission (Android 12+)
  Future<bool> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        return await androidPlugin.requestExactAlarmsPermission() ?? false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting exact alarm permission: $e');
      }
    }
    return false;
  }

  /// Format time for display (e.g., "5:00 PM")
  String formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  /// Get details about the notification that launched the app (if any)
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async {
    try {
      return await _plugin.getNotificationAppLaunchDetails();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting notification launch details: $e');
      }
      return null;
    }
  }

  // ============================================================================
  // Token Refresh Alarm Methods
  // ============================================================================

  /// Schedule a silent alarm to trigger token refresh.
  ///
  /// Uses AlarmManager with exact alarms, which is more reliable than WorkManager
  /// for time-critical tasks. The alarm fires even in Doze mode.
  ///
  /// Default interval: 6 hours (provides 2 opportunities before 12-hour timeout)
  Future<void> scheduleTokenRefreshAlarm({Duration delay = const Duration(hours: 6)}) async {
    await initialize();

    // Cancel any existing token refresh alarm
    await _plugin.cancel(_tokenRefreshNotificationId);

    final scheduledTime = tz.TZDateTime.now(tz.local).add(delay);

    // Determine the best schedule mode for accuracy
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    if (Platform.isAndroid) {
      final canUseExact = await canScheduleExactAlarms();
      if (canUseExact) {
        scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      }
    }

    // Use minimal notification settings - we'll cancel it immediately after scheduling
    // The alarm is registered with AlarmManager, but the notification is dismissed
    // before the user ever sees it
    final androidDetails = AndroidNotificationDetails(
      _tokenRefreshChannelId,
      _tokenRefreshChannelName,
      channelDescription: _tokenRefreshChannelDescription,
      importance: Importance.min, // Minimum importance
      priority: Priority.min,
      playSound: false,
      enableVibration: false,
      showWhen: false,
      ongoing: false,
      autoCancel: true,
      visibility: NotificationVisibility.secret, // Hidden from lock screen
      silent: true,
    );

    try {
      await _plugin.zonedSchedule(
        _tokenRefreshNotificationId,
        '', // Empty - notification will be canceled immediately
        '',
        scheduledTime,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: _tokenRefreshPayload,
      );

      // KEY FIX: Cancel the notification immediately after scheduling
      // The alarm is already registered with Android's AlarmManager system.
      // Canceling the notification does NOT cancel the alarm callback -
      // the alarm will still fire and trigger _onNotificationTap() with our payload.
      // This makes the notification invisible to users while keeping the refresh mechanism.
      await _plugin.cancel(_tokenRefreshNotificationId);

      if (kDebugMode) {
        print('[TOKEN-ALARM] Token refresh alarm scheduled for: $scheduledTime');
        print('[TOKEN-ALARM] Notification canceled immediately (invisible to user)');
        print('[TOKEN-ALARM] Schedule mode: ${scheduleMode == AndroidScheduleMode.exactAllowWhileIdle ? "EXACT" : "INEXACT"}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[TOKEN-ALARM] Error scheduling token refresh alarm: $e');
      }
    }
  }

  /// Cancel the token refresh alarm.
  ///
  /// Call this when the user logs out.
  Future<void> cancelTokenRefreshAlarm() async {
    await _plugin.cancel(_tokenRefreshNotificationId);

    if (kDebugMode) {
      print('[TOKEN-ALARM] Token refresh alarm cancelled');
    }
  }

  /// Schedule an immediate token refresh alarm (for testing).
  Future<void> scheduleImmediateTokenRefresh() async {
    await scheduleTokenRefreshAlarm(delay: const Duration(seconds: 5));
  }
}
