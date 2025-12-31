import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/cocktail.dart';
import '../../../providers/cocktail_provider.dart';
import '../../../services/notification_service.dart';

const _specialDateKey = 'todays_special_date';
const _specialIdKey = 'todays_special_id';

String _formatDateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// Provides the featured cocktail of the day, rotating once every calendar day.
final todaysSpecialProvider = FutureProvider<Cocktail?>((ref) async {
  // FIX 7: Enhanced diagnostic logging
  print('[TODAYS-SPECIAL] Provider evaluating...');

  // Automatically refresh at the next local midnight
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final durationUntilMidnight = tomorrow.difference(now);

  print('[TODAYS-SPECIAL] Will auto-refresh at midnight in ${durationUntilMidnight.inHours}h ${durationUntilMidnight.inMinutes % 60}m');

  Timer? refreshTimer;
  refreshTimer = Timer(durationUntilMidnight, () {
    if (refreshTimer?.isActive ?? false) {
      refreshTimer?.cancel();
    }
    print('[TODAYS-SPECIAL] Midnight refresh triggered');
    ref.invalidateSelf();
  });
  ref.onDispose(() {
    refreshTimer?.cancel();
  });

  final db = ref.watch(databaseServiceProvider);
  final prefs = await SharedPreferences.getInstance();

  final todayKey = _formatDateKey(now);
  final cachedDate = prefs.getString(_specialDateKey);
  final cachedId = prefs.getString(_specialIdKey);

  Cocktail? cocktail;

  if (cachedDate == todayKey && cachedId != null) {
    print('[TODAYS-SPECIAL] Using cached cocktail ID: $cachedId');
    cocktail = await db.getCocktailById(cachedId);
    if (cocktail == null) {
      print('[TODAYS-SPECIAL] Cached cocktail not found in database, will select new one');
    }
  } else {
    print('[TODAYS-SPECIAL] No cache for today ($todayKey), selecting random cocktail');
  }

  cocktail ??= await db.getRandomCocktail();

  if (cocktail != null) {
    print('[TODAYS-SPECIAL] Selected: ${cocktail.name} (ID: ${cocktail.id})');
    await prefs.setString(_specialDateKey, todayKey);
    await prefs.setString(_specialIdKey, cocktail.id);

    // Schedule Today's Special notification
    try {
      await NotificationService.instance.scheduleTodaysSpecialNotification(cocktail);
    } catch (e) {
      print('[TODAYS-SPECIAL] ERROR scheduling notification: $e');
    }
  } else {
    // FIX 7: Log when database is empty - this is a critical issue
    print('[TODAYS-SPECIAL] WARNING: No cocktail available - database may be empty!');
    print('[TODAYS-SPECIAL] User needs to complete initial sync to populate database.');
    print('[TODAYS-SPECIAL] Notification NOT scheduled.');
    await prefs.remove(_specialDateKey);
    await prefs.remove(_specialIdKey);
  }

  return cocktail;
});

/// Provider for notification settings state
final notificationSettingsProvider = FutureProvider<NotificationSettings>((ref) async {
  final notificationService = NotificationService.instance;
  final enabled = await notificationService.isNotificationEnabled();
  final time = await notificationService.getNotificationTime();
  return NotificationSettings(
    enabled: enabled,
    hour: time.hour,
    minute: time.minute,
  );
});

/// Data class for notification settings
class NotificationSettings {
  final bool enabled;
  final int hour;
  final int minute;

  const NotificationSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  String get formattedTime {
    return NotificationService.instance.formatTime(hour, minute);
  }
}
