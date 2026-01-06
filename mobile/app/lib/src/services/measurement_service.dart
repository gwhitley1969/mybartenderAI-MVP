import 'package:flutter/foundation.dart';

/// Service for parsing and converting cocktail measurements.
///
/// Handles conversion between imperial (oz) and metric (ml) units,
/// as well as bar-specific measurements like shots, jiggers, etc.
class MeasurementService {
  MeasurementService._internal();
  static final MeasurementService instance = MeasurementService._internal();

  // Standard conversions to milliliters
  static const double mlPerOz = 29.5735;
  static const double mlPerCl = 10.0;
  static const double mlPerShot = 44.36; // 1.5 oz US standard
  static const double mlPerJigger = 44.36; // Same as shot
  static const double mlPerPony = 29.57; // 1 oz
  static const double mlPerTbsp = 14.79;
  static const double mlPerTsp = 4.93;
  static const double mlPerCup = 236.59;
  static const double mlPerPint = 473.18;
  static const double mlPerDash = 0.92;
  static const double mlPerSplash = 14.79; // ~0.5 oz
  static const double mlPerDrop = 0.05;

  // Qualitative measure keywords (no numeric conversion possible)
  static const Set<String> _qualitativeKeywords = {
    'splash',
    'dash',
    'pinch',
    'fill',
    'top',
    'float',
    'twist',
    'wedge',
    'slice',
    'garnish',
    'to taste',
    'as needed',
    'optional',
    'drizzle',
    'rinse',
  };

  // Unit patterns for parsing
  static final Map<String, double> _unitConversions = {
    'oz': mlPerOz,
    'ounce': mlPerOz,
    'ounces': mlPerOz,
    'fl oz': mlPerOz,
    'fluid oz': mlPerOz,
    'ml': 1.0,
    'milliliter': 1.0,
    'milliliters': 1.0,
    'millilitre': 1.0,
    'millilitres': 1.0,
    'cl': mlPerCl,
    'centiliter': mlPerCl,
    'centiliters': mlPerCl,
    'centilitre': mlPerCl,
    'centilitres': mlPerCl,
    'shot': mlPerShot,
    'shots': mlPerShot,
    'jigger': mlPerJigger,
    'jiggers': mlPerJigger,
    'pony': mlPerPony,
    'ponies': mlPerPony,
    'tbsp': mlPerTbsp,
    'tblsp': mlPerTbsp,
    'tablespoon': mlPerTbsp,
    'tablespoons': mlPerTbsp,
    'tsp': mlPerTsp,
    'teaspoon': mlPerTsp,
    'teaspoons': mlPerTsp,
    'cup': mlPerCup,
    'cups': mlPerCup,
    'pint': mlPerPint,
    'pints': mlPerPint,
    'dash': mlPerDash,
    'dashes': mlPerDash,
    'drop': mlPerDrop,
    'drops': mlPerDrop,
    'part': 30.0, // Treat "part" as 1 oz for standardization
    'parts': 30.0,
  };

  /// Parse a measurement string into structured data.
  ///
  /// Examples:
  /// - "1.5 oz" → ParsedMeasurement(amountMl: 44.36, unitOriginal: "oz")
  /// - "45 ml" → ParsedMeasurement(amountMl: 45.0, unitOriginal: "ml")
  /// - "Splash of" → ParsedMeasurement(amountMl: null, unitOriginal: "splash", isQualitative: true)
  ParsedMeasurement parse(String? measure) {
    if (measure == null || measure.trim().isEmpty) {
      return ParsedMeasurement(
        amountMl: null,
        unitOriginal: null,
        originalText: '',
        isQualitative: true,
      );
    }

    final original = measure.trim();
    final normalized = original.toLowerCase();

    // Check for qualitative measures first
    for (final keyword in _qualitativeKeywords) {
      if (normalized.contains(keyword)) {
        return ParsedMeasurement(
          amountMl: null,
          unitOriginal: keyword,
          originalText: original,
          isQualitative: true,
        );
      }
    }

    // Try to extract numeric amount and unit
    // Patterns: "1.5 oz", "1 1/2 oz", "1/2 oz", "45ml", "2 cl"
    final parsed = _parseNumericMeasure(normalized, original);
    if (parsed != null) {
      return parsed;
    }

    // Fallback: couldn't parse, treat as qualitative
    return ParsedMeasurement(
      amountMl: null,
      unitOriginal: null,
      originalText: original,
      isQualitative: true,
    );
  }

  ParsedMeasurement? _parseNumericMeasure(String normalized, String original) {
    // Regex to match: optional number (decimal or fraction), then unit
    // Examples: "1.5 oz", "1 1/2 oz", "1/2 oz", "45ml", "2cl"
    final regexPatterns = [
      // Decimal: "1.5 oz", "0.5 ml"
      RegExp(r'^(\d+\.?\d*)\s*(.+)$'),
      // Mixed fraction: "1 1/2 oz"
      RegExp(r'^(\d+)\s+(\d+)/(\d+)\s*(.+)$'),
      // Simple fraction: "1/2 oz"
      RegExp(r'^(\d+)/(\d+)\s*(.+)$'),
    ];

    // Try decimal pattern first
    var match = regexPatterns[0].firstMatch(normalized);
    if (match != null) {
      final amountStr = match.group(1)!;
      final unitStr = match.group(2)!.trim();

      final amount = double.tryParse(amountStr);
      if (amount != null) {
        final unitInfo = _findUnit(unitStr);
        if (unitInfo != null) {
          return ParsedMeasurement(
            amountMl: amount * unitInfo.mlMultiplier,
            unitOriginal: unitInfo.unitName,
            originalText: original,
            isQualitative: false,
          );
        }
      }
    }

    // Try mixed fraction: "1 1/2 oz"
    match = regexPatterns[1].firstMatch(normalized);
    if (match != null) {
      final whole = int.tryParse(match.group(1)!) ?? 0;
      final numerator = int.tryParse(match.group(2)!) ?? 0;
      final denominator = int.tryParse(match.group(3)!) ?? 1;
      final unitStr = match.group(4)!.trim();

      if (denominator > 0) {
        final amount = whole + (numerator / denominator);
        final unitInfo = _findUnit(unitStr);
        if (unitInfo != null) {
          return ParsedMeasurement(
            amountMl: amount * unitInfo.mlMultiplier,
            unitOriginal: unitInfo.unitName,
            originalText: original,
            isQualitative: false,
          );
        }
      }
    }

    // Try simple fraction: "1/2 oz"
    match = regexPatterns[2].firstMatch(normalized);
    if (match != null) {
      final numerator = int.tryParse(match.group(1)!) ?? 0;
      final denominator = int.tryParse(match.group(2)!) ?? 1;
      final unitStr = match.group(3)!.trim();

      if (denominator > 0) {
        final amount = numerator / denominator;
        final unitInfo = _findUnit(unitStr);
        if (unitInfo != null) {
          return ParsedMeasurement(
            amountMl: amount * unitInfo.mlMultiplier,
            unitOriginal: unitInfo.unitName,
            originalText: original,
            isQualitative: false,
          );
        }
      }
    }

    return null;
  }

  _UnitInfo? _findUnit(String unitStr) {
    // Clean up the unit string
    final cleaned = unitStr
        .replaceAll(RegExp(r'[.,]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Direct match
    if (_unitConversions.containsKey(cleaned)) {
      return _UnitInfo(
        unitName: _normalizeUnitName(cleaned),
        mlMultiplier: _unitConversions[cleaned]!,
      );
    }

    // Try matching the beginning of the string (e.g., "oz vodka" → "oz")
    for (final entry in _unitConversions.entries) {
      if (cleaned.startsWith(entry.key)) {
        return _UnitInfo(
          unitName: _normalizeUnitName(entry.key),
          mlMultiplier: entry.value,
        );
      }
    }

    return null;
  }

  String _normalizeUnitName(String unit) {
    // Map various forms to canonical unit names
    switch (unit) {
      case 'ounce':
      case 'ounces':
      case 'fl oz':
      case 'fluid oz':
        return 'oz';
      case 'milliliter':
      case 'milliliters':
      case 'millilitre':
      case 'millilitres':
        return 'ml';
      case 'centiliter':
      case 'centiliters':
      case 'centilitre':
      case 'centilitres':
        return 'cl';
      case 'shots':
        return 'shot';
      case 'jiggers':
        return 'jigger';
      case 'tablespoon':
      case 'tablespoons':
      case 'tblsp':
        return 'tbsp';
      case 'teaspoon':
      case 'teaspoons':
        return 'tsp';
      case 'cups':
        return 'cup';
      case 'pints':
        return 'pint';
      case 'dashes':
        return 'dash';
      case 'drops':
        return 'drop';
      case 'parts':
        return 'part';
      case 'ponies':
        return 'pony';
      default:
        return unit;
    }
  }

  /// Format a measurement for display based on user preference.
  ///
  /// [amountMl] - The canonical amount in milliliters (null for qualitative)
  /// [unitOriginal] - The original unit type (for qualitative display)
  /// [preference] - "imperial" or "metric"
  /// [originalText] - Fallback text if formatting fails
  String format({
    required double? amountMl,
    required String? unitOriginal,
    required String preference,
    String? originalText,
  }) {
    // Qualitative measures - return formatted original
    if (amountMl == null) {
      return _formatQualitative(unitOriginal, originalText);
    }

    // Convert and format based on preference
    if (preference == 'imperial') {
      return _formatImperial(amountMl);
    } else {
      return _formatMetric(amountMl);
    }
  }

  String _formatImperial(double amountMl) {
    final oz = amountMl / mlPerOz;

    // Handle very small amounts
    if (oz < 0.1) {
      final tsp = amountMl / mlPerTsp;
      if (tsp < 1) {
        return '${tsp.toStringAsFixed(1)} tsp';
      }
      return '${tsp.toStringAsFixed(1)} tsp';
    }

    // Format with appropriate precision
    if (oz >= 1) {
      // Show 1 decimal place for amounts >= 1 oz
      final formatted = oz.toStringAsFixed(1);
      // Remove trailing .0
      final display =
          formatted.endsWith('.0') ? formatted.substring(0, formatted.length - 2) : formatted;
      return '$display oz';
    } else {
      // Show 1 decimal place for amounts < 1 oz
      return '${oz.toStringAsFixed(1)} oz';
    }
  }

  String _formatMetric(double amountMl) {
    // For small amounts, show ml with precision
    if (amountMl < 10) {
      return '${amountMl.toStringAsFixed(1)} ml';
    }

    // For larger amounts, round to whole ml
    return '${amountMl.round()} ml';
  }

  String _formatQualitative(String? unitOriginal, String? originalText) {
    // If we have the original text, clean it up and return
    if (originalText != null && originalText.isNotEmpty) {
      // Capitalize first letter
      final trimmed = originalText.trim();
      if (trimmed.isEmpty) return '';
      return trimmed[0].toUpperCase() + trimmed.substring(1);
    }

    // Format based on unit keyword
    if (unitOriginal == null) return '';

    switch (unitOriginal) {
      case 'splash':
        return 'Splash';
      case 'dash':
        return 'Dash';
      case 'pinch':
        return 'Pinch';
      case 'fill':
        return 'Fill';
      case 'top':
        return 'Top up';
      case 'float':
        return 'Float';
      case 'twist':
        return 'Twist';
      case 'wedge':
        return 'Wedge';
      case 'slice':
        return 'Slice';
      case 'garnish':
        return 'Garnish';
      case 'to taste':
        return 'To taste';
      case 'as needed':
        return 'As needed';
      case 'drizzle':
        return 'Drizzle';
      case 'rinse':
        return 'Rinse';
      default:
        return unitOriginal[0].toUpperCase() + unitOriginal.substring(1);
    }
  }

  /// Debug method to test parsing
  @visibleForTesting
  void debugParse(String measure) {
    final result = parse(measure);
    debugPrint('Parse "$measure": '
        'amountMl=${result.amountMl}, '
        'unit=${result.unitOriginal}, '
        'qualitative=${result.isQualitative}');
  }
}

/// Result of parsing a measurement string
class ParsedMeasurement {
  /// Amount in milliliters (null for qualitative measures like "splash")
  final double? amountMl;

  /// The original unit type detected ("oz", "ml", "shot", "splash", etc.)
  final String? unitOriginal;

  /// The original measurement text, preserved
  final String originalText;

  /// True if this is a qualitative measure (splash, dash, etc.)
  final bool isQualitative;

  const ParsedMeasurement({
    required this.amountMl,
    required this.unitOriginal,
    required this.originalText,
    required this.isQualitative,
  });

  @override
  String toString() {
    return 'ParsedMeasurement(amountMl: $amountMl, '
        'unitOriginal: $unitOriginal, '
        'originalText: $originalText, '
        'isQualitative: $isQualitative)';
  }
}

/// Internal helper for unit lookup
class _UnitInfo {
  final String unitName;
  final double mlMultiplier;

  const _UnitInfo({
    required this.unitName,
    required this.mlMultiplier,
  });
}
