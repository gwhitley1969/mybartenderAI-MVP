# My Bar Smart Scanner Integration

**Date**: January 2026
**Version**: 1.1.0
**Status**: Implemented

## Overview

My Bar provides users two ways to access the Smart Scanner:

1. **AppBar Scanner Button** (v1.1) - Always visible pink camera icon in the top-right, regardless of inventory state
2. **Empty State Buttons** (v1.0) - "Add" and "Scanner" buttons shown when inventory is empty

This ensures users can quickly scan bottles at any time without navigating back to the home screen.

## Feature Description

### Problem Solved

**Original Problem (v1.0)**: When users first access My Bar, their inventory is empty. Previously, the only option was to manually search and add ingredients one at a time.

**Additional Problem (v1.1)**: Once users had items in their inventory, the empty state buttons disappeared, forcing them to navigate back to the home screen to access the Scanner.

The Smart Scanner integration allows users to:
- Point their camera at bottles
- Let AI (Claude Haiku) identify the spirits/ingredients
- Quickly add multiple items to their inventory
- **Access Scanner from anywhere in My Bar** (v1.1)

---

## AppBar Scanner Button (v1.1)

### Overview

A persistent Scanner button in the My Bar AppBar ensures users can always scan bottles, regardless of whether their inventory is empty or populated.

### UI Layout

```
┌─────────────────────────────────────────────┐
│  ←    My Bar                      📷   +    │
│       Title                      Pink Purple│
│                                   ↑     ↑   │
│                              Scanner  Add   │
└─────────────────────────────────────────────┘
```

### Implementation

**File**: `mobile/app/lib/src/features/my_bar/my_bar_screen.dart`

**AppBar Actions**:
```dart
actions: [
  // Scanner button (pink, matching home screen)
  IconButton(
    icon: Icon(Icons.camera_alt, color: AppColors.iconCirclePink),
    onPressed: () {
      context.push('/smart-scanner').then((_) {
        // Refresh inventory after scanning
        ref.invalidate(inventoryProvider);
      });
    },
  ),
  // Add button (purple, existing)
  IconButton(
    icon: Icon(Icons.add, color: AppColors.primaryPurple),
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AddIngredientScreen(),
        ),
      ).then((_) {
        ref.invalidate(inventoryProvider);
      });
    },
  ),
],
```

### Key Details

| Property | Scanner Button | Add Button |
|----------|----------------|------------|
| Icon | `Icons.camera_alt` | `Icons.add` |
| Color | `AppColors.iconCirclePink` (#EC4899) | `AppColors.primaryPurple` (#7C3AED) |
| Navigation | `context.push('/smart-scanner')` | `Navigator.push()` |
| Post-nav | `ref.invalidate(inventoryProvider)` | `ref.invalidate(inventoryProvider)` |

### Benefits

1. **Always accessible** - Scanner available whether inventory is empty or full
2. **Consistent styling** - Pink color matches home screen Scanner button
3. **Auto-refresh** - Inventory updates automatically when returning from Scanner

---

## Empty State Buttons (v1.0)

### UI Changes

**Before:**
```
┌─────────────────────────────────────┐
│           ┌─────────┐               │
│           │   📦    │               │
│           └─────────┘               │
│                                     │
│       Your bar is empty             │
│                                     │
│   Add ingredients to track what     │
│   you have and discover cocktails   │
│   you can make                      │
│                                     │
│   [ + Add First Ingredient ]        │  ← Single button
│                                     │
└─────────────────────────────────────┘
```

**After:**
```
┌─────────────────────────────────────┐
│           ┌─────────┐               │
│           │   📦    │               │
│           └─────────┘               │
│                                     │
│       Your bar is empty             │
│                                     │
│   Search to add ingredients, or     │
│   snap a photo to let AI identify   │
│   your bottles                      │
│                                     │
│  [ + Add ]       [ 📷 Scanner ]     │  ← Two buttons
│   Purple             Pink           │
└─────────────────────────────────────┘
```

## Technical Implementation

### File Modified

`mobile/app/lib/src/features/my_bar/my_bar_screen.dart`

### Changes Made

#### 1. Added GoRouter Import

```dart
import 'package:go_router/go_router.dart';
```

#### 2. Updated `_buildEmptyState()` Method

Replaced the single `ElevatedButton` with a `Row` containing two `Expanded` buttons:

```dart
// Two buttons side by side: Add manually or use Smart Scanner
Padding(
  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
  child: Row(
    children: [
      // Add Manually button
      Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: AppSpacing.sm),
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddIngredientScreen(),
                ),
              );
            },
            icon: Icon(Icons.add, size: 18),
            label: Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: AppColors.textPrimary,
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
              ),
            ),
          ),
        ),
      ),
      // Smart Scanner button
      Expanded(
        child: Padding(
          padding: EdgeInsets.only(left: AppSpacing.sm),
          child: ElevatedButton.icon(
            onPressed: () => context.push('/smart-scanner'),
            icon: Icon(Icons.camera_alt, size: 18),
            label: Text('Scanner'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.iconCirclePink,
              foregroundColor: AppColors.textPrimary,
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
              ),
            ),
          ),
        ),
      ),
    ],
  ),
),
```

## Button Design

| Property | Add Button | Scanner Button |
|----------|------------|----------------|
| Background Color | `AppColors.primaryPurple` | `AppColors.iconCirclePink` |
| Icon | `Icons.add` | `Icons.camera_alt` |
| Label | "Add" | "Scanner" |
| Icon Size | 18 | 18 |
| Padding | `AppSpacing.md` vertical | `AppSpacing.md` vertical |

### Color Rationale

- **Purple for Add**: Maintains consistency with the original "Add First Ingredient" button color
- **Pink for Scanner**: Matches the Smart Scanner card color on the home screen, creating visual consistency across the app

## Navigation Behavior

| Button | Method | Destination | Back Behavior |
|--------|--------|-------------|---------------|
| Add | `Navigator.push()` | AddIngredientScreen | Returns to My Bar |
| Scanner | `context.push()` | SmartScannerScreen | Returns to My Bar |

### Why Different Navigation Methods?

- **Add button**: Uses `Navigator.push()` to maintain consistency with existing code in the file
- **Scanner button**: Uses GoRouter's `context.push()` because Smart Scanner is defined as a GoRouter route (`/smart-scanner`)

Both methods preserve the navigation stack, so pressing "Back" returns users to My Bar.

## User Flow

```
User opens My Bar (empty)
        │
        ▼
Sees empty state with two options
        │
        ├──► Taps [ + Add ]
        │         │
        │         ▼
        │    AddIngredientScreen
        │    - Search for ingredients
        │    - Add one at a time
        │    - Returns to My Bar
        │
        └──► Taps [ 📷 Scanner ]
                  │
                  ▼
             SmartScannerScreen
             - Point camera at bottles
             - AI identifies spirits
             - Add to inventory
             - Returns to My Bar
```

## Smart Scanner Details

The Smart Scanner feature uses:
- **AI Model**: Claude Haiku (via Azure)
- **Endpoint**: `/api/v1/vision/analyze`
- **Tier Restrictions**:
  - Free: 2 scans / 30 days
  - Premium: 15 scans / 30 days
  - Pro: 50 scans / 30 days

When users tap the Scanner button, they're taken to the same Smart Scanner screen accessible from the home screen's AI Concierge section.

## Related Files

| File | Purpose |
|------|---------|
| `mobile/app/lib/src/features/my_bar/my_bar_screen.dart` | My Bar screen with empty state |
| `mobile/app/lib/src/features/my_bar/add_ingredient_screen.dart` | Manual ingredient search/add |
| `mobile/app/lib/src/features/smart_scanner/smart_scanner_screen.dart` | AI-powered bottle scanner |
| `mobile/app/lib/main.dart` | GoRouter route definitions |
| `backend/functions/vision-analyze/index.js` | Backend vision analysis endpoint |

## Testing Checklist

### AppBar Scanner Button (v1.1)
- [x] AppBar shows Scanner (pink) and Add (purple) icons
- [x] Scanner icon visible when inventory is empty
- [x] Scanner icon visible when inventory has items
- [x] Scanner button opens SmartScannerScreen
- [x] Inventory refreshes after returning from Scanner
- [x] Pink color matches home screen Scanner button (#EC4899)

### Empty State (v1.0)
- [x] Empty state shows two buttons side by side
- [x] Buttons are evenly sized
- [x] "Add" button is purple
- [x] "Scanner" button is pink
- [x] "Add" button navigates to AddIngredientScreen
- [x] "Scanner" button navigates to SmartScannerScreen
- [x] Back from AddIngredient returns to My Bar
- [x] Back from Scanner returns to My Bar
- [x] Layout looks good on narrow screens
- [x] Clean release APK builds successfully

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.1.0 | January 2026 | Added AppBar Scanner button (always visible) |
| 1.0.0 | January 2026 | Initial empty state with Add/Scanner buttons |

## Future Enhancements

Potential improvements for future releases:

1. **Scanner results to inventory**: After scanning, automatically prompt to add identified bottles to My Bar
2. **Batch scanning**: Allow scanning multiple bottles in one session
3. **Scan history**: Show recently scanned items for quick re-adding

---

**Maintained By**: Claude Code
**Last Updated**: January 2026
