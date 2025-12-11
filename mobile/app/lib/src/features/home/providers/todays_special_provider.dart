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
  // Automatically refresh at the next local midnight
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final durationUntilMidnight = tomorrow.difference(now);

  Timer? refreshTimer;
  refreshTimer = Timer(durationUntilMidnight, () {
    if (refreshTimer?.isActive ?? false) {
      refreshTimer?.cancel();
    }
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
    cocktail = await db.getCocktailById(cachedId);
  }

  cocktail ??= await db.getRandomCocktail();

  if (cocktail != null) {
    await prefs.setString(_specialDateKey, todayKey);
    await prefs.setString(_specialIdKey, cocktail.id);

    // Schedule Today's Special notification
    try {
      await NotificationService.instance.scheduleTodaysSpecialNotification(cocktail);
      if (kDebugMode) {
        print("Today's Special notification scheduled for: ${cocktail.name}");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Failed to schedule notification: $e");
      }
    }
  } else {
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
