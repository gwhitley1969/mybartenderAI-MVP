// Data models for the Academy feature.
//
// These models represent bartending lesson categories and individual lessons
// with YouTube video content.

/// Represents a category of bartending lessons (e.g., Fundamentals, Garnishes).
class AcademyCategory {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final int sortOrder;
  final List<AcademyLesson> lessons;

  const AcademyCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.sortOrder,
    required this.lessons,
  });

  factory AcademyCategory.fromJson(Map<String, dynamic> json) {
    return AcademyCategory(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      iconName: json['iconName'] as String,
      sortOrder: json['sortOrder'] as int,
      lessons: (json['lessons'] as List<dynamic>)
          .map((l) => AcademyLesson.fromJson(l as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    );
  }

  /// Number of lessons in this category.
  int get lessonCount => lessons.length;
}

/// Represents an individual bartending lesson with YouTube video content.
class AcademyLesson {
  final String id;
  final String title;
  final String description;
  final String duration;
  final String difficulty;
  final String youtubeVideoId;
  final List<String> tags;
  final int sortOrder;

  const AcademyLesson({
    required this.id,
    required this.title,
    required this.description,
    required this.duration,
    required this.difficulty,
    required this.youtubeVideoId,
    required this.tags,
    required this.sortOrder,
  });

  factory AcademyLesson.fromJson(Map<String, dynamic> json) {
    return AcademyLesson(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      duration: json['duration'] as String,
      difficulty: json['difficulty'] as String,
      youtubeVideoId: json['youtubeVideoId'] as String,
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      sortOrder: json['sortOrder'] as int,
    );
  }

  /// Generate YouTube thumbnail URL from video ID.
  /// Uses hqdefault (480x360) for good quality without excessive bandwidth.
  String get thumbnailUrl =>
      'https://img.youtube.com/vi/$youtubeVideoId/hqdefault.jpg';
}
