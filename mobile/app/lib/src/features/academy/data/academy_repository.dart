import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/academy_models.dart';

/// Repository for loading and caching Academy content from local JSON.
///
/// Content is loaded once and cached in memory for the lifetime of the app.
/// This is appropriate since the content is static and doesn't change at runtime.
class AcademyRepository {
  static List<AcademyCategory>? _cachedCategories;

  /// Load all categories from the JSON asset.
  /// Results are cached after first load.
  static Future<List<AcademyCategory>> getCategories() async {
    if (_cachedCategories != null) {
      return _cachedCategories!;
    }

    final jsonString =
        await rootBundle.loadString('assets/data/academy_content.json');
    final json = jsonDecode(jsonString) as Map<String, dynamic>;

    final categories = (json['categories'] as List<dynamic>)
        .map((c) => AcademyCategory.fromJson(c as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    _cachedCategories = categories;
    return categories;
  }

  /// Get a specific category by ID.
  static Future<AcademyCategory?> getCategoryById(String id) async {
    final categories = await getCategories();
    try {
      return categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get a specific lesson by category ID and lesson ID.
  static Future<AcademyLesson?> getLessonById(
    String categoryId,
    String lessonId,
  ) async {
    final category = await getCategoryById(categoryId);
    if (category == null) return null;

    try {
      return category.lessons.firstWhere((l) => l.id == lessonId);
    } catch (_) {
      return null;
    }
  }

  /// Clear the cache (useful for testing or hot reload scenarios).
  static void clearCache() {
    _cachedCategories = null;
  }
}
