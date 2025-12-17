# Accessibility Font Scaling Fix

## Issue Summary

Users who enable larger or bolder fonts in their Android device accessibility settings were experiencing layout issues throughout the app. Text would overflow its containers, get clipped, or break layouts entirely.

**Date Fixed**: December 17, 2025

## Problem Description

### Symptoms

When users enabled accessibility font settings on Android (Settings → Accessibility → Display → Font size / Bold text), the following issues occurred:

| Screen | Issue |
|--------|-------|
| Home Screen | "Track your" and "Saved" text overflowing on My Bar/Favorites cards |
| Home Screen | "Professional" and "Precision" text overflowing on Academy/Pro Tools cards |
| Home Screen | Section titles like "Lounge Essentials" getting cut off |
| Fundamentals | "Beginner" badges truncated to "Beginn..." |
| Fundamentals | "Intermediate" badge cut off showing "Interm...ate" |
| Various | Text overlapping, clipping, or breaking card layouts |

### Root Cause

Flutter respects the system-level `textScaleFactor` set by Android accessibility settings. When users enable larger fonts, Android applies a scale factor (e.g., 1.3x, 1.5x, or even 2.0x) to all text.

The app had:
1. **Fixed pixel sizes** for text containers
2. **Fixed aspect ratios** on GridView cards (`childAspectRatio: 0.9`)
3. **No text scale limits** - text grew unbounded
4. **Missing overflow handling** on some text widgets

When text scaled up 130-200%, it exceeded its container boundaries.

## Solution

A two-tier approach was implemented:

### Tier 1: App-Level Text Scale Limit

Added a global text scale cap in `main.dart` that limits the maximum text scaling to 1.3x (130%). This still respects accessibility needs while preventing layout breakage.

```dart
// In MaterialApp.router builder
builder: (context, child) {
  final mediaQuery = MediaQuery.of(context);
  final constrainedTextScaler = mediaQuery.textScaler.clamp(
    minScaleFactor: 1.0,
    maxScaleFactor: 1.3,
  );
  return MediaQuery(
    data: mediaQuery.copyWith(textScaler: constrainedTextScaler),
    child: child!,
  );
},
```

### Tier 2: Widget-Level Resilience

Individual widgets were updated to gracefully handle text overflow:

#### `FittedBox` for Scaling Down
Wraps text that must fit within a specific space, automatically scaling it down if needed:

```dart
FittedBox(
  fit: BoxFit.scaleDown,
  child: Text('Title', style: AppTypography.cardTitle),
)
```

#### `Flexible` for Shrinking
Allows widgets to shrink when space is constrained:

```dart
Flexible(
  child: Text(
    'Long subtitle text',
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  ),
)
```

#### `maxLines` + `overflow` for Graceful Truncation
Prevents text from expanding vertically and shows ellipsis when truncated:

```dart
Text(
  title,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
)
```

## Files Modified

| File | Change |
|------|--------|
| `mobile/app/lib/main.dart` | Added `textScaler.clamp(maxScaleFactor: 1.3)` in MaterialApp builder |
| `mobile/app/lib/src/widgets/feature_card.dart` | Added `FittedBox` to title, `Flexible` to subtitle |
| `mobile/app/lib/src/widgets/section_header.dart` | Wrapped title in `Flexible` with `maxLines: 1` and ellipsis |
| `mobile/app/lib/src/features/academy/widgets/difficulty_badge.dart` | Added `maxWidth` constraint and `FittedBox` |
| `mobile/app/lib/src/features/academy/widgets/lesson_card.dart` | Wrapped badge in `Flexible` to prevent Row overflow |

## Trade-offs

| Aspect | Before | After |
|--------|--------|-------|
| Max text scale | Unlimited (system default) | 1.3x (130%) |
| Layout stability | Broken at high scales | Stable |
| Accessibility | Full system scaling | Capped but still improved |

Users who set extremely large fonts (1.5x+) will see 1.3x instead. This is a reasonable compromise that:
- Still provides 30% larger text for readability
- Maintains UI integrity and usability
- Prevents broken layouts that make the app unusable

## Testing

To test the fix:

1. Build and install the APK
2. On Android device, go to **Settings → Accessibility → Display**
3. Enable **Bold text** and/or increase **Font size** to maximum
4. Launch the app and verify:
   - Home screen cards display correctly
   - Section headers are readable
   - Academy lesson badges show full text
   - No text overflow or clipping anywhere

## Best Practices for Future Development

When adding new UI components:

1. **Always use `maxLines` and `overflow`** on Text widgets in constrained spaces
2. **Use `Flexible` or `Expanded`** instead of fixed widths for text containers
3. **Consider `FittedBox`** for text that must fit exactly (badges, titles in cards)
4. **Test with accessibility fonts enabled** before merging UI changes
5. **Avoid fixed `childAspectRatio`** in GridViews with text content, or ensure text can adapt

## Related Documentation

- [Flutter Accessibility](https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility)
- [MediaQuery.textScaler](https://api.flutter.dev/flutter/widgets/MediaQuery/textScaler.html)
- [FittedBox class](https://api.flutter.dev/flutter/widgets/FittedBox-class.html)

---

**Author**: Claude Code
**Last Updated**: December 17, 2025
