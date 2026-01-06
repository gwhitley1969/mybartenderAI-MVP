# Recipe Vault AI Concierge Integration

**Date**: January 2026
**Version**: 1.0.0
**Status**: Implemented

## Overview

The Recipe Vault screen now includes an AI Concierge prompt card that helps users discover cocktails beyond the local database. When users can't find what they're looking for through search or filters, they can quickly access the AI Chat or Voice AI features directly from within Recipe Vault.

## Feature Description

### Problem Solved

Users browsing the Recipe Vault (621+ cocktails) might search for something that:
- Isn't in the local database
- Requires a custom variation
- Needs ingredient substitutions
- Is described vaguely ("something tropical and refreshing")

Previously, users would need to navigate back to the home screen to access AI features. Now they have direct access.

### UI Changes

**Before:**
```
┌─────────────────────────────────────┐
│ 621 Cocktails │ 11 Categories │12/18│  ← Stats box
├─────────────────────────────────────┤
│ 🔍 Search cocktails...              │
├─────────────────────────────────────┤
│ [Can Make] [Favorites] [Categories] │
└─────────────────────────────────────┘
```

**After:**
```
┌─────────────────────────────────────┐
│ 🔍 Search cocktails...              │  ← Search now at top
├─────────────────────────────────────┤
│ 💡 Can't find what you're looking   │  ← New AI prompt card
│    for?                             │
│    Ask our AI Cocktail Concierge!   │
│                                     │
│  [💬 Chat]         [🎤 Voice]       │  ← Direct navigation
├─────────────────────────────────────┤
│ [Can Make] [Favorites] [Categories] │
└─────────────────────────────────────┘
```

### Navigation Behavior

| Button | Destination | Back Behavior |
|--------|-------------|---------------|
| Chat | `/ask-bartender` | Returns to Recipe Vault |
| Voice | `/voice-ai` | Returns to Recipe Vault |

Uses `context.push()` (not `context.go()`) to maintain navigation stack, allowing users to return to Recipe Vault after their AI session.

## Technical Implementation

### File Modified

`mobile/app/lib/src/features/recipe_vault/recipe_vault_screen.dart`

### Changes Made

1. **Added GoRouter import** for navigation
2. **Removed statistics provider watch** (`snapshotStatisticsProvider`)
3. **Removed statistics UI section** from build method
4. **Removed helper methods**:
   - `_formatVersion()` - formatted snapshot version as MM/DD
   - `_buildStatistics()` - built the stats container
   - `_buildStatItem()` - built individual stat columns
5. **Added `_buildAIConciergePrompt()`** - new card with Chat/Voice buttons

### New Method: `_buildAIConciergePrompt()`

```dart
Widget _buildAIConciergePrompt(BuildContext context) {
  return Container(
    padding: EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
      border: Border.all(
        color: AppColors.cardBorder,
        width: AppSpacing.borderWidthThin,
      ),
    ),
    child: Column(
      children: [
        // Icon + text header
        Row(...),
        // Chat and Voice buttons
        Row(
          children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: () => context.push('/ask-bartender'),
              icon: Icon(Icons.chat_bubble_outline),
              label: Text('Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.iconCircleBlue,
                ...
              ),
            )),
            Expanded(child: ElevatedButton.icon(
              onPressed: () => context.push('/voice-ai'),
              icon: Icon(Icons.mic),
              label: Text('Voice'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.iconCircleTeal,
                ...
              ),
            )),
          ],
        ),
      ],
    ),
  );
}
```

### Design Consistency

The card styling matches the home screen's AI Concierge section:

| Property | Value |
|----------|-------|
| Background | `AppColors.cardBackground` |
| Border | `AppColors.cardBorder` with `AppSpacing.borderWidthThin` |
| Border radius | `AppSpacing.cardBorderRadius` |
| Icon circle | `AppColors.accentBlue` |
| Chat button | `AppColors.iconCircleBlue` |
| Voice button | `AppColors.iconCircleTeal` |
| Typography | `AppTypography.cardTitle`, `AppTypography.cardSubtitle` |

## User Experience Flow

```
User opens Recipe Vault
        │
        ▼
Searches for "spicy mango cocktail"
        │
        ▼
No results found in local database
        │
        ▼
Sees AI Concierge card: "Can't find what you're looking for?"
        │
        ├──► Taps [Chat] ──► Opens AI Chat ──► Types request
        │                          │
        │                          ▼
        │                    Gets AI recommendation
        │                          │
        │                          ▼
        │                    Taps Back ──► Returns to Recipe Vault
        │
        └──► Taps [Voice] ──► Opens Voice AI ──► Speaks request
                                   │
                                   ▼
                             Gets spoken recommendation
                                   │
                                   ▼
                             Taps Back ──► Returns to Recipe Vault
```

## Tier Considerations

Both buttons are visible to all users regardless of subscription tier:

| Tier | Chat | Voice |
|------|------|-------|
| Free | Available (limited tokens) | Shows upgrade prompt |
| Premium | Available (300k tokens) | Available via purchase ($4.99/10 min) |
| Pro | Available (1M tokens) | Available (45 min included + top-up) |

Tier restrictions are handled by the destination screens, not the Recipe Vault buttons.

## What Was Removed

### Statistics Box

The stats box showing "621 Cocktails | 11 Categories | 12/18 Updated" was removed because:

1. **Low value**: Users rarely need to know exact counts
2. **Takes space**: Vertical space is valuable on mobile
3. **Static info**: Rarely changes, doesn't drive user action
4. **AI is more useful**: The AI prompt provides actionable next steps

### Where Stats Info Went

If users need database sync information:
- **Profile screen**: Shows sync status and last update
- **Sync button**: Still available in Recipe Vault app bar (🔄 icon)

## Related Files

| File | Purpose |
|------|---------|
| `mobile/app/lib/src/features/recipe_vault/recipe_vault_screen.dart` | Main implementation |
| `mobile/app/lib/src/features/home/home_screen.dart` | Design reference for card styling |
| `mobile/app/lib/src/features/ask_bartender/chat_screen.dart` | Chat destination |
| `mobile/app/lib/src/features/voice_ai/voice_ai_screen.dart` | Voice destination |
| `mobile/app/lib/main.dart` | Route definitions |

## Testing Checklist

- [x] Stats box removed from Recipe Vault
- [x] Search bar appears at top of content area
- [x] AI Concierge card displays below search bar
- [x] Card styling matches app design language
- [x] Chat button navigates to `/ask-bartender`
- [x] Voice button navigates to `/voice-ai`
- [x] Back button from Chat returns to Recipe Vault
- [x] Back button from Voice returns to Recipe Vault
- [x] Filter chips still work correctly
- [x] Clean debug APK builds successfully

---

**Maintained By**: Claude Code
**Last Updated**: January 2026
