import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/pro_tools_models.dart';

/// Repository for loading and caching Pro Tools content from local JSON.
///
/// Content is loaded once and cached in memory for the lifetime of the app.
/// This is appropriate since the content is static and doesn't change at runtime.
class ProToolsRepository {
  static List<ToolTier>? _cachedTiers;

  /// Load all tiers from the JSON asset.
  /// Results are cached after first load.
  static Future<List<ToolTier>> getTiers() async {
    if (_cachedTiers != null) {
      return _cachedTiers!;
    }

    final jsonString =
        await rootBundle.loadString('assets/data/pro_tools_content.json');
    final json = jsonDecode(jsonString) as Map<String, dynamic>;

    final tiers = (json['tiers'] as List<dynamic>)
        .map((t) => ToolTier.fromJson(t as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    _cachedTiers = tiers;
    return tiers;
  }

  /// Get a specific tier by ID.
  static Future<ToolTier?> getTierById(String id) async {
    final tiers = await getTiers();
    try {
      return tiers.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get a specific tool by tier ID and tool ID.
  static Future<ProTool?> getToolById(String tierId, String toolId) async {
    final tier = await getTierById(tierId);
    if (tier == null) return null;

    try {
      return tier.tools.firstWhere((t) => t.id == toolId);
    } catch (_) {
      return null;
    }
  }

  /// Clear the cache (useful for testing or hot reload scenarios).
  static void clearCache() {
    _cachedTiers = null;
  }
}
