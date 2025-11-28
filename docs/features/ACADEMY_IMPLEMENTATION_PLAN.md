# Academy Feature Implementation Plan

## Overview

This plan implements the Academy feature as specified in `ACADEMY_SPEC.md`. The Academy provides bite-sized bartending lessons organized by skill category, with curated YouTube content.

## Project Structure Analysis

Based on the existing codebase:
- **Navigation**: GoRouter with routes defined in `main.dart`, but detail screens use `Navigator.push()` (see Recipe Vault pattern)
- **State Management**: Riverpod (but not needed for static content)
- **Architecture**: Feature-first in `lib/src/features/`
- **Theme**: Custom theme system in `lib/src/theme/` (AppColors, AppTypography, AppSpacing)
- **Widgets**: Reusable components in `lib/src/widgets/` (FeatureCard, SectionHeader, etc.)
- **Home Integration**: Academy card already exists in `home_screen.dart` (lines 393-407) with "coming soon" placeholder

## Key Design Decisions

### 1. Navigation Pattern (Simplified)
The original plan used complex nested GoRouter routes. After analyzing the codebase:
- **Recipe Vault pattern**: Single GoRoute `/recipe-vault`, then `Navigator.push()` for CocktailDetailScreen
- **Academy should follow same pattern**: Single GoRoute `/academy`, then `Navigator.push()` for category and lesson screens

This is simpler and consistent with existing code.

### 2. State Management (Simplified)
For static JSON content that never changes:
- **No Riverpod providers needed** - overkill for read-only data
- Simple repository class with async method to load JSON once
- Data cached in memory after first load

### 3. Data Models (Simplified)
- Plain Dart classes with `factory fromJson()` constructors
- **No freezed** - unnecessary for immutable read-only data
- **Thumbnail URLs generated dynamically** from videoId: `https://img.youtube.com/vi/{videoId}/hqdefault.jpg`
  - Reduces JSON size
  - Always current
  - One less field to maintain

### 4. Video Player (Enhanced)
- Use `YoutubePlayerScaffold` (not just `YoutubePlayer`) for **fullscreen support**
- Users watching tutorials will want fullscreen capability
- Proper controller lifecycle management (create in initState, dispose in dispose)

---

## Implementation Steps

### Phase 1: Package & Asset Setup

**Step 1.1: Add YouTube player package to pubspec.yaml**

```yaml
dependencies:
  youtube_player_iframe: ^5.1.7
```

Why `youtube_player_iframe`:
- Actively maintained (updated Aug 2025)
- Uses webview_flutter under the hood (reliable on Android/iOS)
- No API key required
- Good fullscreen support via YoutubePlayerScaffold
- Same author as youtube_player_flutter (sarbagyastha)

**Step 1.2: Add asset reference**

```yaml
assets:
  - assets/msal_config.json
  - assets/data/academy_content.json
```

**Step 1.3: Create assets directory**

```
mkdir mobile/app/assets/data
```

---

### Phase 2: Data Layer

**Step 2.1: Create data models** (`lib/src/features/academy/models/academy_models.dart`)

```dart
class AcademyCategory {
  final String id;
  final String title;
  final String description;
  final String iconName;  // Material icon name as string
  final int sortOrder;
  final List<AcademyLesson> lessons;

  const AcademyCategory({...});

  factory AcademyCategory.fromJson(Map<String, dynamic> json) => ...;

  int get lessonCount => lessons.length;
}

class AcademyLesson {
  final String id;
  final String title;
  final String description;
  final String duration;  // "4:32" format
  final String difficulty;  // 'beginner', 'intermediate', 'advanced'
  final String youtubeVideoId;
  final List<String> tags;
  final int sortOrder;

  const AcademyLesson({...});

  factory AcademyLesson.fromJson(Map<String, dynamic> json) => ...;

  // Generate thumbnail URL dynamically
  String get thumbnailUrl =>
    'https://img.youtube.com/vi/$youtubeVideoId/hqdefault.jpg';
}
```

**Step 2.2: Create repository** (`lib/src/features/academy/data/academy_repository.dart`)

```dart
class AcademyRepository {
  static List<AcademyCategory>? _cachedCategories;

  static Future<List<AcademyCategory>> getCategories() async {
    if (_cachedCategories != null) return _cachedCategories!;

    final jsonString = await rootBundle.loadString('assets/data/academy_content.json');
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final categories = (json['categories'] as List)
        .map((c) => AcademyCategory.fromJson(c))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    _cachedCategories = categories;
    return categories;
  }

  static Future<AcademyCategory?> getCategoryById(String id) async {
    final categories = await getCategories();
    return categories.where((c) => c.id == id).firstOrNull;
  }

  static Future<AcademyLesson?> getLessonById(String categoryId, String lessonId) async {
    final category = await getCategoryById(categoryId);
    return category?.lessons.where((l) => l.id == lessonId).firstOrNull;
  }
}
```

**Step 2.3: Create JSON content** (`assets/data/academy_content.json`)

Structure:
```json
{
  "categories": [
    {
      "id": "fundamentals",
      "title": "Fundamentals",
      "description": "Master the basics every bartender needs",
      "iconName": "school",
      "sortOrder": 1,
      "lessons": [
        {
          "id": "jigger-basics",
          "title": "How to Use a Jigger",
          "description": "Learn proper measuring technique for consistent cocktails",
          "duration": "5:23",
          "difficulty": "beginner",
          "youtubeVideoId": "ACTUAL_VIDEO_ID",
          "tags": ["measuring", "basics", "tools"],
          "sortOrder": 1
        }
      ]
    }
  ]
}
```

Populate with real video IDs from: Educated Barfly, Cocktail Chemistry, How to Drink, Anders Erickson, Vlad SlickBartender.

---

### Phase 3: UI Screens

**Step 3.1: Academy main screen** (`lib/src/features/academy/academy_screen.dart`)

- AppBar with title "Academy" and back navigation
- FutureBuilder to load categories
- 2-column grid of category cards
- Each card: icon, title, lesson count badge, description
- Use `AppColors.iconCirclePink` as primary accent
- Tap navigates via `Navigator.push()` to category screen

**Step 3.2: Category screen** (`lib/src/features/academy/academy_category_screen.dart`)

- AppBar with category title
- Category description header
- ListView.builder of lesson cards
- Each lesson card: thumbnail, title, duration, difficulty badge
- Tap navigates via `Navigator.push()` to lesson screen

**Step 3.3: Lesson screen** (`lib/src/features/academy/academy_lesson_screen.dart`)

**Critical: Use YoutubePlayerScaffold for fullscreen support**

```dart
class AcademyLessonScreen extends StatefulWidget {
  final AcademyLesson lesson;
  const AcademyLessonScreen({required this.lesson, super.key});

  @override
  State<AcademyLessonScreen> createState() => _AcademyLessonScreenState();
}

class _AcademyLessonScreenState extends State<AcademyLessonScreen> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.lesson.youtubeVideoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        showControls: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerScaffold(
      controller: _controller,
      aspectRatio: 16 / 9,
      builder: (context, player) {
        return Scaffold(
          appBar: AppBar(title: Text(widget.lesson.title)),
          body: SingleChildScrollView(
            child: Column(
              children: [
                player,  // YouTube player with fullscreen support
                Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DifficultyBadge(difficulty: widget.lesson.difficulty),
                      SizedBox(height: AppSpacing.md),
                      Text(widget.lesson.description, style: AppTypography.bodyMedium),
                      SizedBox(height: AppSpacing.lg),
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: widget.lesson.tags
                            .map((tag) => Chip(label: Text(tag)))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

---

### Phase 4: Widgets

**Step 4.1: Difficulty badge** (`lib/src/features/academy/widgets/difficulty_badge.dart`)

```dart
class DifficultyBadge extends StatelessWidget {
  final String difficulty;

  const DifficultyBadge({required this.difficulty, super.key});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (difficulty) {
      'beginner' => (AppColors.success, 'Beginner'),
      'intermediate' => (AppColors.primaryPurple, 'Intermediate'),
      'advanced' => (AppColors.accentOrange, 'Advanced'),
      _ => (AppColors.textSecondary, difficulty),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        border: Border.all(color: color),
      ),
      child: Text(label, style: AppTypography.caption.copyWith(color: color)),
    );
  }
}
```

**Step 4.2: Lesson card** (`lib/src/features/academy/widgets/lesson_card.dart`)

```dart
class LessonCard extends StatelessWidget {
  final AcademyLesson lesson;
  final VoidCallback onTap;

  const LessonCard({required this.lesson, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.horizontal(left: Radius.circular(AppSpacing.cardBorderRadius)),
              child: Image.network(
                lesson.thumbnailUrl,
                width: 120,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 120, height: 90,
                  color: AppColors.backgroundSecondary,
                  child: Icon(Icons.play_circle_outline, color: AppColors.textSecondary),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.title, style: AppTypography.cardTitle, maxLines: 2),
                    SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                        SizedBox(width: AppSpacing.xs),
                        Text(lesson.duration, style: AppTypography.caption),
                        SizedBox(width: AppSpacing.md),
                        DifficultyBadge(difficulty: lesson.difficulty),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### Phase 5: Navigation Integration

**Step 5.1: Add single route to main.dart**

```dart
GoRoute(
  path: 'academy',
  builder: (BuildContext context, GoRouterState state) {
    return const AcademyScreen();
  },
),
```

**Step 5.2: Update home_screen.dart (line ~398)**

Replace:
```dart
onTap: () {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Academy coming soon!'), ...),
  );
},
```

With:
```dart
onTap: () => context.go('/academy'),
```

---

## File Structure Summary

```
mobile/app/
├── assets/
│   └── data/
│       └── academy_content.json          # NEW: Static lesson content
├── lib/
│   └── src/
│       └── features/
│           └── academy/                   # NEW: Feature folder
│               ├── academy_screen.dart
│               ├── academy_category_screen.dart
│               ├── academy_lesson_screen.dart
│               ├── models/
│               │   └── academy_models.dart
│               ├── data/
│               │   └── academy_repository.dart
│               └── widgets/
│                   ├── lesson_card.dart
│                   └── difficulty_badge.dart
├── pubspec.yaml                           # MODIFY: Add package and asset
└── lib/main.dart                          # MODIFY: Add route
```

**Files to create**: 8 new files
**Files to modify**: 3 files (pubspec.yaml, main.dart, home_screen.dart)

---

## Platform Configuration

### Android (if needed)
The `youtube_player_iframe` package uses `webview_flutter`. Check AndroidManifest.xml for:
- `<uses-permission android:name="android.permission.INTERNET"/>` (likely present)
- May need `android:usesCleartextTraffic="true"` in application tag

### iOS (if needed)
May need to add to Info.plist:
```xml
<key>io.flutter.embedded_views_preview</key>
<true/>
```

---

## Error Handling Considerations

1. **No internet for video playback**: Show friendly message, metadata still loads from local JSON
2. **Invalid video ID**: YouTube player shows error state automatically
3. **JSON loading failure**: Show error state with retry option

---

## Acceptance Criteria

- [ ] User can view list of lesson categories from home screen
- [ ] User can tap a category to see its lessons
- [ ] User can tap a lesson to watch the embedded video
- [ ] Videos support fullscreen playback
- [ ] UI matches existing app theme (colors, typography, spacing)
- [ ] Content metadata loads offline (only videos need internet)
- [ ] Back navigation works correctly at all levels

---

## What Changed from Original Plan

| Aspect | Original | Revised | Why |
|--------|----------|---------|-----|
| Navigation | 3 nested GoRouter routes | 1 route + Navigator.push | Matches existing patterns (Recipe Vault) |
| State Management | Riverpod providers | Simple repository class | Static data doesn't need reactive state |
| Models | Consider freezed | Plain Dart classes | Overkill for read-only data |
| Thumbnails | Stored in JSON | Generated from videoId | Smaller JSON, always current |
| Video player | YoutubePlayer | YoutubePlayerScaffold | Fullscreen support |
| Complexity | Higher | Lower | KISS principle |

---

## Implementation Status (November 2025)

**Status: ✅ COMPLETE**

### Completed Items

- [x] User can view list of lesson categories from home screen
- [x] User can tap a category to see its lessons
- [x] User can tap a lesson to watch the embedded video
- [x] Videos support fullscreen playback
- [x] UI matches existing app theme (colors, typography, spacing)
- [x] Content metadata loads offline (only videos need internet)
- [x] Back navigation works correctly at all levels
- [x] Category cards display varied icon colors (blue, teal, orange, pink)

### Files Created

```
mobile/app/
├── assets/
│   └── data/
│       └── academy_content.json           # 16 curated YouTube lessons
├── lib/
│   └── src/
│       └── features/
│           └── academy/
│               ├── academy_screen.dart           # Main category grid
│               ├── academy_category_screen.dart  # Lesson list
│               ├── academy_lesson_screen.dart    # Video player
│               ├── models/
│               │   └── academy_models.dart       # Data models
│               ├── data/
│               │   └── academy_repository.dart   # Content loader
│               └── widgets/
│                   ├── lesson_card.dart          # Lesson list item
│                   └── difficulty_badge.dart     # Difficulty indicator
```

### Critical Implementation Detail: YouTube Origin Fix

The YouTube IFrame player requires a trusted origin to allow embedded playback. Without this, videos fail with **Error 15** or **Error 4**.

**Solution in `academy_lesson_screen.dart`:**

```dart
_controller = YoutubePlayerController.fromVideoId(
  videoId: widget.lesson.youtubeVideoId,
  autoPlay: false,
  params: const YoutubePlayerParams(
    showFullscreenButton: true,
    showControls: true,
    mute: false,
    enableCaption: true,
    playsInline: true,
    origin: 'https://www.youtube-nocookie.com',  // CRITICAL for mobile
  ),
);
```

**Why `youtube-nocookie.com`:**
- YouTube's IFrame API requires a valid trusted origin for embedded playback
- Using `youtube.com` alone doesn't work in mobile WebView contexts
- The `youtube-nocookie.com` domain is a privacy-enhanced embedding domain that YouTube trusts
- This resolves Error 15/153 (origin mismatch) and Error 4 (playback incompatibility)

**References:**
- [Stack Overflow: YouTube Error 15/153 Fix](https://stackoverflow.com/questions/79804589/youtube-video-shows-video-unavailable-error-15-153-using-youtube-player-if)
- [GitHub Issue: Working App Broke](https://github.com/sarbagyastha/youtube_player_flutter/issues/1084)

### Curated Video Content

The 16 lessons use curated YouTube videos from professional bartending channels:

**Fundamentals (4 lessons):**
- How to Use a Jigger - Vu2CkQwA19M
- Pouring Techniques - w-ylhJS_iUo
- Ice Handling Basics - uHu7iOzuFdU
- Glassware Guide - CODeSo8ePtM

**Shaking & Stirring (4 lessons):**
- Shake vs Stir - MAAQkLSetcE
- Japanese Hard Shake - pi8yL8A0G60
- Dry Shake Technique - GcjBDxzfF9s
- Proper Stirring - ueo3gKWPNO4

**Garnishes (4 lessons):**
- Citrus Twists - 640aJL2zmww
- Expressing Oils - lYnvd_oqzXE
- Flaming a Peel - w-vJpeIwVwk
- Herb Garnishes - liHlEbfgDug

**Advanced Techniques (4 lessons):**
- Layering Drinks - QENCJN9Z6vY
- Fat Washing - 9M4mBhJg6C4
- Clarified Cocktails - EyToyAVim2k
- Smoking Cocktails - 0pJtGs3bma4

### Category Icon Colors

Each category card displays a unique icon color for visual variety:

```dart
Color _getCategoryColor(String categoryId) {
  switch (categoryId) {
    case 'fundamentals':
      return AppColors.iconCircleBlue;
    case 'shaking-stirring':
      return AppColors.iconCircleTeal;
    case 'garnishes':
      return AppColors.iconCircleOrange;
    case 'advanced-techniques':
      return AppColors.iconCirclePink;
    default:
      return AppColors.iconCirclePurple;
  }
}
```

---

## References

- [youtube_player_iframe on pub.dev](https://pub.dev/packages/youtube_player_iframe)
- [youtube_player_flutter GitHub](https://github.com/sarbagyastha/youtube_player_flutter)
- [YouTube IFrame API Error Codes](https://developers.google.com/youtube/iframe_api_reference)
