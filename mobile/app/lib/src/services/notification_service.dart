import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/cocktail.dart';

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

  // SharedPreferences keys for notification settings
  static const String _notificationEnabledKey = 'notification_enabled';
  static const String _notificationHourKey = 'notification_hour';
  static const String _notificationMinuteKey = 'notification_minute';

  // Default notification time: 5:00 PM
  static const int _defaultHour = 17;
  static const int _defaultMinute = 0;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _timeZoneInitialized = false;

  // Callback for when notification is tapped
  Function(String? cocktailId)? onNotificationTap;

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
    await _ensureTimeZoneInitialized();

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }
    // Call the callback with the cocktail ID
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

  /// Schedule the Today's Special notification
  Future<void> scheduleTodaysSpecialNotification(Cocktail cocktail) async {
    await initialize();

    // Check if notifications are enabled
    final enabled = await isNotificationEnabled();
    if (!enabled) {
      if (kDebugMode) {
        print('Notifications disabled, skipping schedule');
      }
      return;
    }

    await cancelTodaysSpecialNotification();

    final scheduledDate = await _nextNotificationTime();

    // Determine the best schedule mode for accuracy
    // Android 12+ requires SCHEDULE_EXACT_ALARM permission for exact timing
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    if (Platform.isAndroid) {
      final canUseExact = await canScheduleExactAlarms();
      if (canUseExact) {
        scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
        if (kDebugMode) {
          print('Using exact alarm scheduling for precise notification timing');
        }
      } else {
        // Try to request the permission
        final granted = await requestExactAlarmPermission();
        if (granted) {
          scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
          if (kDebugMode) {
            print('Exact alarm permission granted, using precise timing');
          }
        } else {
          if (kDebugMode) {
            print('Exact alarm permission not granted, using inexact scheduling (may be delayed)');
          }
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
      // Keep notification visible - user must manually dismiss
      autoCancel: false,
      ongoing: false,
      // Show on lock screen
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _plugin.zonedSchedule(
        _todaysSpecialNotificationId,
        "Today's Special: ${cocktail.name}",
        _buildNotificationBody(cocktail),
        scheduledDate,
        notificationDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
        payload: cocktail.id, // Used for deep linking to cocktail detail
      );

      if (kDebugMode) {
        final now = DateTime.now();
        print('=== Notification Scheduled ===');
        print('Current time: $now');
        print('Scheduled for: $scheduledDate');
        print('Cocktail: ${cocktail.name} (${cocktail.id})');
        print('Schedule mode: ${scheduleMode == AndroidScheduleMode.exactAllowWhileIdle ? "EXACT (on-time)" : "INEXACT (may be delayed)"}');
        print('Time until notification: ${scheduledDate.difference(tz.TZDateTime.now(tz.local))}');
        print('==============================');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling notification: $e');
      }
    }
  }

  /// Schedule notification for a specific number of seconds from now (for testing)
  Future<void> scheduleTestNotificationInSeconds(Cocktail cocktail, int seconds) async {
    await initialize();

    await _plugin.cancel(_todaysSpecialNotificationId + 2);

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
        _todaysSpecialNotificationId + 2,
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

  Future<void> cancelTodaysSpecialNotification() async {
    await initialize();
    await _plugin.cancel(_todaysSpecialNotificationId);
  }

  /// Calculate the next notification time based on user settings
  Future<tz.TZDateTime> _nextNotificationTime() async {
    final time = await getNotificationTime();
    final now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
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
      // Keep notification visible - user must manually dismiss
      autoCancel: false,
      ongoing: false,
      // Show on lock screen
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      _todaysSpecialNotificationId + 1, // Different ID for test
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
}
