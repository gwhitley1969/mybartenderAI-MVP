import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/cocktail.dart';

class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  static const int _todaysSpecialNotificationId = 1001;
  static const String _todaysSpecialChannelId = 'todays_special_channel';
  static const String _todaysSpecialChannelName = 'Today\'s Special';
  static const String _todaysSpecialChannelDescription =
      'Daily reminder featuring the bartender\'s special cocktail.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _timeZoneInitialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    final initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(initializationSettings);

    await _requestNotificationPermission();

    await _ensureTimeZoneInitialized();

    _initialized = true;
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
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    _timeZoneInitialized = true;
  }

  Future<void> scheduleTodaysSpecialNotification(Cocktail cocktail) async {
    await initialize();

    await cancelTodaysSpecialNotification();

    final tz.TZDateTime scheduledDate = _next5Pm();

    final androidDetails = AndroidNotificationDetails(
      _todaysSpecialChannelId,
      _todaysSpecialChannelName,
      channelDescription: _todaysSpecialChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: const DefaultStyleInformation(true, true),
      sound: const RawResourceAndroidNotificationSound('todays_special_chime'),
      playSound: true,
      channelAction: AndroidNotificationChannelAction.update,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    final subtitle = _buildSubtitle(cocktail);

    await _plugin.zonedSchedule(
      _todaysSpecialNotificationId,
      'Today\'s Special',
      subtitle != null
          ? '${cocktail.name} · $subtitle'
          : '${cocktail.name} is ready for you.',
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: cocktail.id,
    );
  }

  Future<void> cancelTodaysSpecialNotification() async {
    await initialize();
    await _plugin.cancel(_todaysSpecialNotificationId);
  }

  tz.TZDateTime _next5Pm() {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 17, 0);

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  String? _buildSubtitle(Cocktail cocktail) {
    if (cocktail.tags.isNotEmpty) {
      final tags = cocktail.tags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .map((tag) => tag[0].toUpperCase() + tag.substring(1).toLowerCase())
          .toList();
      if (tags.isNotEmpty) {
        return tags.take(2).join(' · ');
      }
    }

    final details = [
      if ((cocktail.category ?? '').isNotEmpty) cocktail.category,
      if ((cocktail.alcoholic ?? '').isNotEmpty) cocktail.alcoholic,
    ].whereType<String>().join(' · ');

    return details.isNotEmpty ? details : null;
  }
}

