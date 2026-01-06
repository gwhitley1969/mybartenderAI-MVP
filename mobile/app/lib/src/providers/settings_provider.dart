import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/user_settings_service.dart';

/// Provider for the user's measurement unit preference.
///
/// Returns 'imperial' or 'metric'.
/// Use `ref.invalidate(measurementUnitProvider)` after changing the setting
/// to refresh all consumers.
final measurementUnitProvider = FutureProvider<String>((ref) async {
  return await UserSettingsService.instance.getMeasurementUnit();
});

/// User settings data class for potential future expansion
class UserSettings {
  final String measurementUnit;

  const UserSettings({
    required this.measurementUnit,
  });

  bool get isImperial => measurementUnit == UserSettingsService.imperial;
  bool get isMetric => measurementUnit == UserSettingsService.metric;

  /// Display label for the current measurement unit
  String get measurementUnitLabel => isImperial ? 'Imperial (oz)' : 'Metric (ml)';
}

/// Provider for all user settings (for future expansion)
final userSettingsProvider = FutureProvider<UserSettings>((ref) async {
  final measurementUnit = await ref.watch(measurementUnitProvider.future);
  return UserSettings(measurementUnit: measurementUnit);
});
