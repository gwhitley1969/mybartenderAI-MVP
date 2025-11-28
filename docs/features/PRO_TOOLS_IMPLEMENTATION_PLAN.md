# Pro Tools Implementation Plan

## Overview

This document outlines the step-by-step implementation plan for the Pro Tools feature - a curated guide to essential bar tools organized by priority tier.

**Based on**: `PRO_TOOLS_SPEC.md`
**Pattern Reference**: Academy feature implementation
**Target**: Beta release (read-only, local content)

---

## Architecture Decision: Multi-Screen Navigation

> **IMPORTANT**: After analyzing the spec's accordion suggestion against Flutter best practices and this app's established patterns, we are using **multi-screen navigation** instead of expandable panels.

### Rationale

| Consideration | Accordion | Multi-Screen (Chosen) |
|---------------|-----------|----------------------|
| Consistency with Academy | Different UX | Identical pattern |
| Nested scroll issues | Problematic | None |
| State management | Complex | Simple |
| Deep linking (future) | Difficult | Easy |
| Testing | More complex | Straightforward |

**Sources consulted:**
- [Mastering Expanded Lists in Flutter](https://medium.com/@ankitahuja007/mastering-expanded-lists-in-flutter-best-practices-common-pitfalls-200c52452346)
- [Flutter ExpansionTile API](https://api.flutter.dev/flutter/material/ExpansionTile-class.html)
- [Stack Overflow: Recommended approach to expandable lists](https://stackoverflow.com/questions/73291889/recommended-approach-to-lists-with-expandable-elements-in-flutter)

Key findings:
- ExpansionPanelList has padding issues that cannot be modified
- ExpansionTile loses animation when PageStorageKey is set (needed for scroll preservation)
- With only 3 tiers, the overhead of accordion is not justified

---

## Screen Flow

```
HomeScreen
    ↓ tap "Pro Tools" card
ProToolsScreen (3 tier cards - grid or list)
    ↓ tap a tier card
ProToolsTierScreen (list of tools for that tier)
    ↓ tap a tool
ProToolDetailScreen (full tool info with price ranges)
```

This mirrors Academy's: `AcademyScreen → AcademyCategoryScreen → AcademyLessonScreen`

---

## Implementation Summary

| Phase | Description | Files |
|-------|-------------|-------|
| 1 | Data Models | 1 file |
| 2 | Content JSON | 1 file |
| 3 | Repository | 1 file |
| 4 | UI Screens | 3 files |
| 5 | Widgets | 2 files |
| 6 | Navigation | 2 files (modify) |
| 7 | Assets | 1 file (modify) |

**Total**: 8 new files, 3 modified files

---

## Phase 1: Data Models

### File: `lib/src/features/pro_tools/models/pro_tools_models.dart`

Create three model classes with improved type safety:

```dart
/// PriceRange - Budget/Mid/Premium pricing info
/// Using List<PriceRange> instead of Map for better type safety and iteration
class PriceRange {
  final String tier;       // "budget", "mid", "premium"
  final String label;      // "Budget", "Mid-Range", "Premium"
  final String range;      // e.g., "$5-10"
  final String note;       // e.g., "Basic stainless steel"

  const PriceRange({
    required this.tier,
    required this.label,
    required this.range,
    required this.note,
  });

  factory PriceRange.fromJson(Map<String, dynamic> json) {
    return PriceRange(
      tier: json['tier'] as String,
      label: json['label'] as String,
      range: json['range'] as String,
      note: json['note'] as String,
    );
  }
}

/// ProTool - Individual tool with full details
class ProTool {
  final String id;
  final String name;
  final String subtitle;
  final String description;
  final String whyYouNeedIt;
  final List<String> whatToLookFor;
  final List<PriceRange> priceRanges;  // Changed from Map to List
  final String iconName;
  final int sortOrder;
  final List<String> tags;

  const ProTool({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.whyYouNeedIt,
    required this.whatToLookFor,
    required this.priceRanges,
    required this.iconName,
    required this.sortOrder,
    required this.tags,
  });

  factory ProTool.fromJson(Map<String, dynamic> json) {
    return ProTool(
      id: json['id'] as String,
      name: json['name'] as String,
      subtitle: json['subtitle'] as String,
      description: json['description'] as String,
      whyYouNeedIt: json['whyYouNeedIt'] as String,
      whatToLookFor: (json['whatToLookFor'] as List<dynamic>).cast<String>(),
      priceRanges: (json['priceRanges'] as List<dynamic>)
          .map((p) => PriceRange.fromJson(p as Map<String, dynamic>))
          .toList(),
      iconName: json['iconName'] as String,
      sortOrder: json['sortOrder'] as int,
      tags: (json['tags'] as List<dynamic>).cast<String>(),
    );
  }
}

/// ToolTier - Category grouping (Essential, Level Up, Pro Status)
class ToolTier {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String iconName;
  final int sortOrder;
  final List<ProTool> tools;

  const ToolTier({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.iconName,
    required this.sortOrder,
    required this.tools,
  });

  factory ToolTier.fromJson(Map<String, dynamic> json) {
    return ToolTier(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      description: json['description'] as String,
      iconName: json['iconName'] as String,
      sortOrder: json['sortOrder'] as int,
      tools: (json['tools'] as List<dynamic>)
          .map((t) => ProTool.fromJson(t as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    );
  }

  /// Number of tools in this tier.
  int get toolCount => tools.length;
}
```

### Key Design Decisions

1. **List instead of Map for priceRanges**: Better type safety, explicit ordering, easier iteration
2. **Explicit `label` field**: Display text separate from tier ID
3. **fromJson factories**: Consistent with Academy pattern

---

## Phase 2: Content JSON

### File: `assets/data/pro_tools_content.json`

**Updated structure with List-based priceRanges:**

```json
{
  "tiers": [
    {
      "id": "essential",
      "title": "Essential",
      "subtitle": "Start Here",
      "description": "The must-haves for any home bar",
      "iconName": "star",
      "sortOrder": 1,
      "tools": [
        {
          "id": "jigger",
          "name": "Jigger",
          "subtitle": "Japanese Style, 1oz/2oz",
          "description": "A jigger ensures consistent pours every time. The Japanese style has a sleek profile and internal measurement lines.",
          "whyYouNeedIt": "Eyeballing measurements leads to inconsistent drinks. A jigger is the difference between a balanced cocktail and a boozy mess.",
          "whatToLookFor": [
            "Internal measurement lines (½oz, ¾oz marks)",
            "Sturdy construction — thin metal dents easily",
            "Japanese style for precision, American style for speed"
          ],
          "priceRanges": [
            { "tier": "budget", "label": "Budget", "range": "$5-10", "note": "Basic stainless steel" },
            { "tier": "mid", "label": "Mid-Range", "range": "$15-25", "note": "Japanese style with lines" },
            { "tier": "premium", "label": "Premium", "range": "$30-50", "note": "Weighted, copper or gold finish" }
          ],
          "iconName": "straighten",
          "sortOrder": 1,
          "tags": ["measuring", "essential", "precision"]
        }
      ]
    }
  ]
}
```

### Content to Include:

**Tier 1: Essential (6 tools)**
1. Jigger - Japanese Style, 1oz/2oz
2. Boston Shaker - 18oz + 28oz tins
3. Bar Spoon - Twisted handle, 12 inch
4. Hawthorne Strainer - Spring-loaded
5. Muddler - Wooden or stainless steel
6. Citrus Juicer - Handheld press style

**Tier 2: Level Up (6 tools)**
1. Mixing Glass - Weighted base, 500-700ml
2. Fine Mesh Strainer - For double-straining
3. Channel Knife - For citrus twists
4. Julep Strainer - For stirred drinks
5. Pour Spouts - Speed pourers
6. Ice Cube Trays - Large format, 2 inch

**Tier 3: Pro Status (6 tools)**
1. Japanese Jigger Set - Multiple sizes
2. Lewis Bag & Mallet - For crushed ice
3. Smoking Gun - For smoked cocktails
4. Atomizer - For absinthe rinses
5. Fine Scale - 0.1g precision
6. Sous Vide - For rapid infusions

---

## Phase 3: Repository

### File: `lib/src/features/pro_tools/data/pro_tools_repository.dart`

Follow Academy pattern exactly:

```dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/pro_tools_models.dart';

/// Repository for loading and caching Pro Tools content from local JSON.
///
/// Content is loaded once and cached in memory for the lifetime of the app.
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

  /// Clear the cache (useful for testing or hot reload).
  static void clearCache() {
    _cachedTiers = null;
  }
}
```

---

## Phase 4: UI Screens

### File 1: `lib/src/features/pro_tools/pro_tools_screen.dart`

Main screen showing tier cards (like Academy's category grid).

**UI Components:**
- AppBar with "Pro Tools" title and back button
- Header text: "Precision Instruments" with subtitle
- List or grid of 3 tier cards
- Each card shows: icon, title, subtitle, tool count badge

**Layout Decision**: Use vertical list (not grid) since there are only 3 tiers. Full-width cards look better and provide more room for descriptions.

**Color Scheme (per tier):**
- Essential: `AppColors.iconCircleOrange`
- Level Up: `AppColors.iconCircleTeal`
- Pro Status: `AppColors.iconCirclePurple`

```dart
// Color mapping function (similar to Academy's _getCategoryColor)
Color _getTierColor(String tierId) {
  switch (tierId) {
    case 'essential':
      return AppColors.iconCircleOrange;
    case 'level-up':
      return AppColors.iconCircleTeal;
    case 'pro-status':
      return AppColors.iconCirclePurple;
    default:
      return AppColors.iconCircleBlue;
  }
}
```

### File 2: `lib/src/features/pro_tools/pro_tools_tier_screen.dart` (NEW)

Tool list screen for a specific tier (like Academy's category screen).

**UI Components:**
- AppBar with tier title
- Tier description at top
- Vertical list of tool cards
- Each tool card shows: icon, name, subtitle, chevron

**Tool Card Layout:**
```
┌─────────────────────────────────────┐
│ [Icon]  Tool Name           [>]    │
│         Subtitle text              │
└─────────────────────────────────────┘
```

### File 3: `lib/src/features/pro_tools/pro_tool_detail_screen.dart`

Detail view for individual tool.

**Layout (top to bottom):**
1. **Hero Section**: Large icon in colored circle, centered
2. **Title Section**: Tool name, subtitle
3. **Why You Need It**: Styled callout/quote box with icon
4. **What to Look For**: Bulleted list with checkmark icons
5. **Price Ranges**: Three horizontal cards (Budget | Mid | Premium)
6. **Tags**: Chips at bottom

**Price Range Card Visual Hierarchy:**
- Budget: Gray/muted styling
- Mid-Range: Subtle highlight or "Recommended" badge
- Premium: Gold/amber accent

---

## Phase 5: Widgets

### File 1: `lib/src/features/pro_tools/widgets/tool_card.dart`

Card for displaying a tool in the tier list.

```dart
class ToolCard extends StatelessWidget {
  final ProTool tool;
  final Color tierColor;
  final VoidCallback onTap;

  // Displays tool icon, name, subtitle with consistent styling
}
```

### File 2: `lib/src/features/pro_tools/widgets/price_range_card.dart`

Card displaying price range information.

```dart
class PriceRangeCard extends StatelessWidget {
  final PriceRange priceRange;
  final bool isRecommended; // true for "mid" tier

  // Visual treatment:
  // - Budget: subtle, gray tones
  // - Mid: highlighted border or "Recommended" badge
  // - Premium: gold/amber accent color
}
```

---

## Phase 6: Navigation Integration

### Modify: `lib/main.dart`

Add import and route:

```dart
import 'src/features/pro_tools/pro_tools_screen.dart';

// In routes array (as child of home route):
GoRoute(
  path: 'pro-tools',
  builder: (BuildContext context, GoRouterState state) {
    return const ProToolsScreen();
  },
),
```

### Modify: `lib/src/features/home/home_screen.dart`

Update Pro Tools card in `_buildMasterMixologist`:

```dart
FeatureCard(
  icon: Icons.calculate,
  title: 'Pro Tools',
  subtitle: 'Precision instruments',
  iconColor: AppColors.iconCircleOrange,
  onTap: () => context.go('/pro-tools'),  // Changed from snackbar
),
```

---

## Phase 7: Asset Registration

### Modify: `pubspec.yaml`

Ensure asset is registered:

```yaml
flutter:
  assets:
    - assets/data/academy_content.json
    - assets/data/pro_tools_content.json  # Add this line
```

---

## File Structure Summary

```
lib/src/features/pro_tools/
├── data/
│   └── pro_tools_repository.dart
├── models/
│   └── pro_tools_models.dart
├── widgets/
│   ├── tool_card.dart
│   └── price_range_card.dart
├── pro_tools_screen.dart           # Tier selection (main)
├── pro_tools_tier_screen.dart      # Tool list for a tier
└── pro_tool_detail_screen.dart     # Individual tool details

assets/data/
└── pro_tools_content.json
```

---

## Icon Mapping

Use Material Icons for tool placeholders.

> **Note**: These are beta placeholders. Production version should consider custom SVG icons for better visual identity.

| Tool | Icon | Notes |
|------|------|-------|
| Jigger | `straighten` | Measuring/ruler concept |
| Boston Shaker | `sports_bar` | Bar/drink themed |
| Bar Spoon | `sync` | Twisting/stirring motion |
| Hawthorne Strainer | `filter_alt` | Filtering concept |
| Muddler | `vertical_align_bottom` | Pressing down action |
| Citrus Juicer | `compress` | Squeezing action |
| Mixing Glass | `local_bar` | Cocktail glass |
| Fine Mesh Strainer | `filter_list` | Fine filtering |
| Channel Knife | `content_cut` | Cutting tool |
| Julep Strainer | `filter_2` | Alternative strainer |
| Pour Spouts | `water_drop` | Liquid flow |
| Ice Cube Trays | `ac_unit` | Cold/ice |
| Japanese Jigger Set | `tune` | Multiple sizes/precision |
| Lewis Bag & Mallet | `gavel` | Hitting/crushing |
| Smoking Gun | `smoking_rooms` | Smoke |
| Atomizer | `air` | Spray/mist |
| Fine Scale | `scale` | Weighing |
| Sous Vide | `thermostat` | Temperature control |

---

## Implementation Order

1. **Create models** (`pro_tools_models.dart`)
2. **Create JSON content** (`pro_tools_content.json`) - all 18 tools
3. **Create repository** (`pro_tools_repository.dart`)
4. **Register asset** in `pubspec.yaml`
5. **Create main screen** (`pro_tools_screen.dart`)
6. **Create tier screen** (`pro_tools_tier_screen.dart`)
7. **Create detail screen** (`pro_tool_detail_screen.dart`)
8. **Create widgets** (`tool_card.dart`, `price_range_card.dart`)
9. **Add route** to `main.dart`
10. **Update home screen** navigation
11. **Test and verify**

---

## Testing Checklist

- [x] JSON loads without errors
- [x] All three tiers display correctly on main screen
- [x] Tapping a tier navigates to tier screen
- [x] All tools display in tier screen
- [x] Tapping a tool navigates to detail screen
- [x] Detail screen shows all sections correctly
- [x] Price range cards render with proper styling
- [x] Tags display as chips
- [x] Back navigation works at all levels
- [x] Theme matches app style (colors, typography, spacing)
- [ ] Works in portrait and landscape (not tested)

---

## Acceptance Criteria (Updated)

- [x] User can view list of tool tiers
- [x] User can tap a tier to see its tools
- [x] User can tap a tool to see full details
- [x] Tool detail shows description, tips, and price ranges
- [x] UI matches existing app theme
- [x] Content loads from local JSON (no network required)
- [x] Feature is accessible from main navigation

---

## Implementation Status: COMPLETE (November 2025)

### Files Created

```
lib/src/features/pro_tools/
├── data/
│   └── pro_tools_repository.dart
├── models/
│   └── pro_tools_models.dart
├── widgets/
│   ├── tool_card.dart
│   └── price_range_card.dart
├── pro_tools_screen.dart
├── pro_tools_tier_screen.dart
└── pro_tool_detail_screen.dart

assets/data/
└── pro_tools_content.json
```

### Files Modified

- `pubspec.yaml` - Added asset reference
- `main.dart` - Added `/pro-tools` route and import
- `home_screen.dart` - Wired up Pro Tools card navigation

### Content Summary

| Tier | Tools | Color |
|------|-------|-------|
| Essential | 6 tools (Jigger, Boston Shaker, Bar Spoon, Hawthorne Strainer, Muddler, Citrus Juicer) | Orange |
| Level Up | 6 tools (Mixing Glass, Fine Mesh Strainer, Channel Knife, Julep Strainer, Pour Spouts, Ice Cube Trays) | Teal |
| Pro Status | 6 tools (Japanese Jigger Set, Lewis Bag & Mallet, Smoking Gun, Atomizer, Fine Scale, Sous Vide) | Purple |

**Total: 18 tools with full descriptions, "Why You Need It" sections, "What to Look For" checklists, and Budget/Mid-Range/Premium price ranges.**

---

## Notes

- **Followed Academy patterns exactly** - same navigation flow, same widget patterns
- Used existing theme constants (`AppColors`, `AppTypography`, `AppSpacing`)
- No product images for beta - using Material icons only
- No affiliate links (legal review needed first)
- Content is genuinely useful reference material
- Icons are beta placeholders; consider custom SVG icons for production

---

## Changes from Original Plan

| Original | Revised | Reason |
|----------|---------|--------|
| Accordion UI | Multi-screen navigation | Consistency with Academy, avoids nested scroll issues |
| 2 screens | 3 screens | Added tier screen to match Academy flow |
| Map for priceRanges | List for priceRanges | Better type safety, explicit ordering |
| tier_badge.dart widget | Removed | Inline color mapping sufficient |
| 6 new files | 8 new files | Added tier screen and tool card widget |

---

## Verified Working: November 28, 2025
