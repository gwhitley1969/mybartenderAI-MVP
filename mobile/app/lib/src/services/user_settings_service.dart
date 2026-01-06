import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing user preferences using SharedPreferences.
///
/// Currently handles:
/// - Measurement unit preference (imperial/metric)
///
/// Future settings can be added here as needed.
class UserSettingsService {
  UserSettingsService._internal();
  static final UserSettingsService instance = UserSettingsService._internal();

  // SharedPreferences keys
  static const String _measurementUnitKey = 'measurement_unit';

  // Default values
  static const String defaultMeasurementUnit = 'imperial'; // US market default

  /// Valid measurement unit values
  static const String imperial = 'imperial';
  static const String metric = 'metric';

  /// Get the user's preferred measurement unit.
  /// Returns 'imperial' or 'metric'.
  Future<String> getMeasurementUnit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_measurementUnitKey) ?? defaultMeasurementUnit;
  }

  /// Set the user's preferred measurement unit.
  /// [unit] should be 'imperial' or 'metric'.
  Future<void> setMeasurementUnit(String unit) async {
    if (unit != imperial && unit != metric) {
      throw ArgumentError('Invalid measurement unit: $unit. Must be "$imperial" or "$metric".');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_measurementUnitKey, unit);
  }

  /// Check if measurement unit is imperial
  Future<bool> isImperial() async {
    final unit = await getMeasurementUnit();
    return unit == imperial;
  }

  /// Check if measurement unit is metric
  Future<bool> isMetric() async {
    final unit = await getMeasurementUnit();
    return unit == metric;
  }

  /// Toggle between imperial and metric
  Future<String> toggleMeasurementUnit() async {
    final current = await getMeasurementUnit();
    final newUnit = current == imperial ? metric : imperial;
    await setMeasurementUnit(newUnit);
    return newUnit;
  }

  /// Clear all user settings (useful for logout/reset)
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_measurementUnitKey);
  }
}
