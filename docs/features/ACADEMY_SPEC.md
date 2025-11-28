# Feature Spec: Academy - Professional Techniques

## Overview

The Academy feature provides bite-sized bartending lessons organized by skill category. Each lesson consists of curated YouTube content with structured metadata. This is a read-only feature for beta — no user progress tracking yet.

## User Story

As a user, I want to learn professional bartending techniques through short video lessons so I can improve my home bartending skills.

## Data Structure

### Lesson Categories

```json
{
  "categories": [
    {
      "id": "fundamentals",
      "title": "Fundamentals",
      "description": "Master the basics every bartender needs",
      "icon": "school",
      "sortOrder": 1,
      "lessons": [...]
    }
  ]
}
```

### Individual Lesson

```json
{
  "id": "proper-pouring",
  "title": "Proper Pouring Technique",
  "description": "Learn consistent pours without a jigger",
  "duration": "4:32",
  "difficulty": "beginner",
  "youtubeVideoId": "abc123xyz",
  "thumbnailUrl": "https://img.youtube.com/vi/abc123xyz/hqdefault.jpg",
  "tags": ["pouring", "basics", "speed"],
  "sortOrder": 1
}
```

### Difficulty Levels

- `beginner` — No experience needed
- `intermediate` — Knows the basics
- `advanced` — Ready for pro techniques

## Content Structure

Implement these categories with 3-5 placeholder lessons each. Use real YouTube video IDs where possible, or placeholder IDs that can be swapped later.

### Categories to Implement

1. **Fundamentals**
   
   - Jigger basics
   - Pouring technique
   - Ice handling
   - Glassware selection

2. **Shaking & Stirring**
   
   - When to shake vs stir
   - The hard shake
   - Dry shake for egg whites
   - Proper stirring technique

3. **Garnishes**
   
   - Citrus twists and peels
   - Expressing oils
   - Flaming a peel
   - Herb garnishes

4. **Advanced Techniques**
   
   - Layering drinks
   - Fat washing
   - Clarified cocktails
   - Smoking cocktails

## UI Requirements

### Academy Main Screen

- Grid or list of category cards
- Each card shows: icon, title, lesson count
- Tapping a category opens the lesson list

### Category Lesson List

- Vertical list of lessons within that category
- Each lesson shows: thumbnail, title, duration, difficulty badge
- Tapping a lesson opens the video player

### Video Player Screen

- Embedded YouTube player (use `youtube_player_flutter` or similar package)
- Lesson title and description below video
- Difficulty badge
- Tags displayed as chips
- "Back to lessons" navigation

## Technical Implementation

### Data Storage

Store academy content in the existing snapshot mechanism if possible, or as a separate JSON file bundled with the app. For beta, this content is static — no API calls needed.

Suggested location: `assets/data/academy_content.json`

### Flutter Packages

- `youtube_player_flutter` or `youtube_player_iframe` for video playback
- Use existing app theme and components

### Files to Create/Modify

**New Files:**

- `lib/features/academy/` — Feature folder
  - `academy_screen.dart` — Main category grid
  - `academy_category_screen.dart` — Lesson list for a category
  - `academy_lesson_screen.dart` — Video player screen
  - `academy_models.dart` — Data models (Category, Lesson)
  - `academy_data.dart` — Static content or loader
- `assets/data/academy_content.json` — Lesson content

**Modify:**

- Main navigation to add Academy entry point
- `pubspec.yaml` to add YouTube player package and asset reference

## Constraints

- Follow existing app architecture patterns
- Use existing theme colors, typography, and spacing
- No backend API calls — all content is local for beta
- No user progress tracking for beta (future feature)
- Videos play within the app, not external YouTube app

## Out of Scope for Beta

- User progress tracking
- Bookmarking lessons
- Search within Academy
- User-submitted content
- Quizzes or assessments
- Certificates or badges

## Sample Content

Here are some real YouTube videos to consider (verify these exist and are appropriate):

**Fundamentals:**

- "How to Use a Jigger" — Educated Barfly
- "Basic Pouring Techniques" — Cocktail Chemistry

**Shaking:**

- "Japanese Hard Shake" — Cocktail Chemistry
- "How to Dry Shake" — Educated Barfly

**Garnishes:**

- "5 Citrus Garnishes Every Bartender Should Know" — Vlad SlickBartender

Search YouTube for "bartending techniques" and "cocktail tutorial" to find appropriate content. Prioritize channels like:

- Educated Barfly
- Cocktail Chemistry
- How to Drink
- Anders Erickson
- Vlad SlickBartender

## Acceptance Criteria

- [x] User can view list of lesson categories
- [x] User can tap a category to see lessons
- [x] User can tap a lesson to watch the video
- [x] Videos play embedded within the app
- [x] UI matches existing app theme
- [x] Content loads from local JSON (no network required)
- [x] Feature is accessible from main navigation

---

## Implementation Status: ✅ COMPLETE (November 2025)

See `ACADEMY_IMPLEMENTATION_PLAN.md` for full implementation details.

**Key Technical Note:** YouTube IFrame embedding requires `origin: 'https://www.youtube-nocookie.com'` in the YoutubePlayerParams to avoid Error 15/4 on mobile devices.

---

## Notes for Claude Code

- Check existing project structure before creating new folders
- Look at how other features are organized and follow that pattern
- Use existing navigation patterns (bottom nav, drawer, or however the app navigates)
- If a YouTube player package is already in pubspec.yaml, use that one
- Populate with real YouTube video IDs where possible
