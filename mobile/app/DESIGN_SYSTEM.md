# MyBartenderAI Design System

Complete design system for the MyBartenderAI Flutter mobile app, extracted from UI mockups and ready for implementation.

## Table of Contents
- [Overview](#overview)
- [Color Palette](#color-palette)
- [Typography](#typography)
- [Spacing & Sizing](#spacing--sizing)
- [Components](#components)
- [Usage Examples](#usage-examples)

---

## Overview

The MyBartenderAI design system provides a consistent, reusable set of design tokens and components that match the premium nighttime mixology aesthetic from the original mockups.

**Design Philosophy:**
- Dark theme with deep purple/navy backgrounds
- Vibrant accent colors for different feature categories
- Clean, modern typography with clear hierarchy
- Generous spacing for comfortable touch targets
- Pill-shaped elements and rounded corners throughout

---

## Color Palette

### Background Colors
```dart
AppColors.backgroundPrimary    // #0F0A1E - Deep navy purple (main background)
AppColors.backgroundSecondary  // #1A1333 - Slightly lighter purple (sections)
AppColors.cardBackground       // #1E1838 - Card background
AppColors.cardBorder           // #2D2548 - Subtle card borders
```

### Primary Brand Colors
```dart
AppColors.primaryPurple        // #7C3AED - Main purple accent
AppColors.primaryPurpleLight   // #9F7AEA - Lighter purple
AppColors.primaryPurpleDark    // #6D28D9 - Darker purple
```

### Accent Colors (Feature-Specific)
```dart
AppColors.accentCyan     // #06B6D4 - Teal/cyan (badges, scores)
AppColors.accentOrange   // #F59E0B - Orange/amber (Recipe Vault, Pro Tools)
AppColors.accentPink     // #EC4899 - Pink/magenta (Academy)
AppColors.accentTeal     // #14B8A6 - Teal (Premium Bar)
AppColors.accentBlue     // #3B82F6 - Blue (icons)
```

### Text Colors
```dart
AppColors.textPrimary    // #FFFFFF - White (headings)
AppColors.textSecondary  // #E5E7EB - Light gray (body text)
AppColors.textTertiary   // #9CA3AF - Medium gray (hints)
AppColors.textDisabled   // #6B7280 - Darker gray (disabled)
```

### Status Colors
```dart
AppColors.success  // #10B981 - Green
AppColors.warning  // #F59E0B - Orange
AppColors.error    // #EF4444 - Red
AppColors.info     // #3B82F6 - Blue
```

### Gradients
Pre-defined gradients for consistent styling:
- `AppColors.purpleGradient`
- `AppColors.cyanGradient`
- `AppColors.orangeGradient`
- `AppColors.pinkGradient`
- `AppColors.tealGradient`

---

## Typography

All typography follows the design mockups with clear hierarchy and consistent sizing.

### Headers
```dart
AppTypography.appTitle      // 32px, Bold - App brand title
AppTypography.heading1      // 28px, Bold - Main headings
AppTypography.heading2      // 24px, Bold - Section headings
AppTypography.heading3      // 20px, SemiBold - Subsection headings
AppTypography.sectionTitle  // 22px, Bold - Section titles ("Lounge Essentials")
```

### Body Text
```dart
AppTypography.bodyLarge   // 16px - Large body text
AppTypography.bodyMedium  // 14px - Standard body text
AppTypography.bodySmall   // 12px - Small body text
```

### Specialized Text
```dart
AppTypography.cardTitle        // 16px, SemiBold - Card titles
AppTypography.cardSubtitle     // 14px - Card subtitles
AppTypography.recipeName       // 18px, Bold - Recipe names
AppTypography.recipeDescription // 14px - Recipe descriptions
AppTypography.buttonLarge      // 16px, SemiBold - Button text
AppTypography.badge            // 12px, SemiBold - Badge text
AppTypography.pill             // 14px, Medium - Pill button text
```

---

## Spacing & Sizing

Consistent spacing scale based on 4px unit.

### Spacing Scale
```dart
AppSpacing.xs     // 4px
AppSpacing.sm     // 8px
AppSpacing.md     // 12px
AppSpacing.lg     // 16px
AppSpacing.xl     // 20px
AppSpacing.xxl    // 24px
AppSpacing.xxxl   // 32px
```

### Component Sizes
```dart
// Cards
AppSpacing.cardPadding           // 16px
AppSpacing.cardBorderRadius      // 12px
AppSpacing.cardLargeBorderRadius // 16px

// Buttons
AppSpacing.buttonHeight          // 48px
AppSpacing.buttonBorderRadius    // 24px (pill shape)

// Icons
AppSpacing.iconSizeSmall   // 16px
AppSpacing.iconSizeMedium  // 24px
AppSpacing.iconSizeLarge   // 32px

// Icon Circles
AppSpacing.iconCircleSmall  // 40px
AppSpacing.iconCircleMedium // 56px
AppSpacing.iconCircleLarge  // 64px

// Badges
AppSpacing.badgeBorderRadius // 16px (pill shape)
AppSpacing.matchBadgeSize    // 44px (circular match score)
```

---

## Components

### 1. FeatureCard

Large card with icon, title, and subtitle for main features.

**Variants:**
- `FeatureCard` - Full-size card with centered layout
- `CompactFeatureCard` - Horizontal layout with icon on left

**Usage:**
```dart
FeatureCard(
  icon: Icons.camera_alt,
  title: 'Smart Scanner',
  subtitle: 'Identify premium ingredients',
  iconColor: AppColors.iconCirclePurple,
  onTap: () => // Navigate to scanner
)
```

**Features:**
- Customizable icon and colors
- Optional background color or gradient
- Consistent rounded corners and padding
- Touch feedback

---

### 2. AppBadge

Pill-shaped badges for levels, counts, and tags.

**Factory Constructors:**
```dart
AppBadge.intermediate()           // Purple "Intermediate" badge
AppBadge.elite()                  // Orange "Elite" badge
AppBadge.spiritCount(count: 8)    // "8 spirits" badge
AppBadge.ingredient(name: "Vodka") // Purple ingredient tag
AppBadge.missingIngredient(name: "Mint") // Red missing ingredient
AppBadge.difficulty(level: "Easy")        // Color-coded difficulty
AppBadge.aiCreated()              // Cyan "AI" badge with sparkle icon
```

**Features:**
- Pre-styled variants for common use cases
- Optional icons
- Consistent padding and border radius
- Color-coded by context

---

### 3. MatchScoreBadge

Circular badge showing ingredient match score (e.g., "3/5").

**Usage:**
```dart
MatchScoreBadge(
  matchCount: 3,
  totalCount: 5,
)
```

**Features:**
- Automatic color-coding based on match percentage:
  - 100%: Green
  - 60%+: Cyan
  - <60%: Orange
- Circular design with centered text
- Consistent 44px size

---

### 4. PillButton

Rounded pill-shaped button for selections.

**Usage:**
```dart
PillButton(
  label: 'Bourbon',
  icon: Icons.add,
  selected: true,
  onTap: () => // Toggle selection
)
```

**Features:**
- Shows close icon when selected
- Color changes based on selection state
- Optional leading icon
- Pill shape with rounded ends

---

### 5. SectionHeader

Header for content sections with optional badge and "See All" button.

**Usage:**
```dart
SectionHeader(
  title: 'Lounge Essentials',
  badgeText: 'Elite',
  onSeeAllTap: () => // Navigate to full list
)
```

**Features:**
- Title with optional badge
- Optional "See All" button with arrow
- Consistent spacing above and below

---

### 6. RecipeCard

Card displaying cocktail recipe with full details.

**Variants:**
- `RecipeCard` - Full-size with all details
- `CompactRecipeCard` - Smaller card for horizontal scrolling

**Usage:**
```dart
RecipeCard(
  name: 'Mojito',
  description: 'Refreshing Cuban cocktail with mint and lime',
  matchCount: 3,
  totalIngredients: 5,
  difficulty: 'Medium',
  time: '5 min',
  servings: 1,
  missingIngredients: ['Mint', 'Club Soda'],
  isAiCreated: false,
  onTap: () => // View recipe details
)
```

**Features:**
- Match score badge in top-right
- AI-created indicator
- Recipe metadata (time, servings, difficulty)
- Missing ingredients display
- Compact variant with image support

---

## Usage Examples

### Importing the Design System

```dart
// Import everything
import 'package:app/src/theme/theme.dart';
import 'package:app/src/widgets/widgets.dart';

// Or import specific files
import 'package:app/src/theme/app_colors.dart';
import 'package:app/src/widgets/feature_card.dart';
```

### Example: Home Screen Section

```dart
Column(
  children: [
    // Section Header
    SectionHeader(
      title: 'Lounge Essentials',
    ),

    // Grid of Feature Cards
    GridView.count(
      crossAxisCount: 2,
      spacing: AppSpacing.gridSpacing,
      children: [
        FeatureCard(
          icon: Icons.camera_alt,
          title: 'Smart Scanner',
          subtitle: 'Identify premium ingredients',
          iconColor: AppColors.iconCirclePurple,
          onTap: () => navigateToScanner(),
        ),
        FeatureCard(
          icon: Icons.menu_book,
          title: 'Recipe Vault',
          subtitle: 'Curated cocktail collection',
          iconColor: AppColors.iconCircleOrange,
          onTap: () => navigateToRecipes(),
        ),
      ],
    ),
  ],
)
```

### Example: User Level Display

```dart
Row(
  children: [
    AppBadge.intermediate(),
    SizedBox(width: AppSpacing.sm),
    AppBadge.spiritCount(count: 8),
  ],
)
```

### Example: Recipe List

```dart
ListView.builder(
  itemCount: recipes.length,
  itemBuilder: (context, index) {
    final recipe = recipes[index];
    return RecipeCard(
      name: recipe.name,
      description: recipe.description,
      matchCount: recipe.matchCount,
      totalIngredients: recipe.ingredients.length,
      difficulty: recipe.difficulty,
      time: recipe.prepTime,
      servings: recipe.servings,
      missingIngredients: recipe.missingIngredients,
      isAiCreated: recipe.isAiGenerated,
      onTap: () => viewRecipeDetails(recipe),
    );
  },
)
```

---

## Applying the Theme

Update your `MaterialApp` to use the custom theme:

```dart
import 'package:app/src/theme/theme.dart';

MaterialApp(
  theme: AppTheme.darkTheme,
  // ... rest of your app
)
```

---

## Design Principles

1. **Consistency** - Use design tokens consistently across the app
2. **Accessibility** - Maintain WCAG contrast ratios for text
3. **Touch Targets** - Minimum 48px for interactive elements
4. **Feedback** - Provide visual feedback for all interactions
5. **Spacing** - Use the 4px grid system for all spacing
6. **Colors** - Use semantic colors (success, error, etc.) appropriately

---

## Next Steps

With this design system in place, you can now:

1. **Rebuild Home Screen** - Use the components to match your mockup
2. **Build Other Screens** - Apply the system to Voice Assistant, Recipe Vault, etc.
3. **Add Navigation** - Implement navigation between screens
4. **Connect Backend** - Integrate with your working Azure backend
5. **Add Authentication** - Implement Entra External ID login flows

---

## File Structure

```
lib/src/
├── theme/
│   ├── app_colors.dart       # Color palette
│   ├── app_typography.dart   # Text styles
│   ├── app_spacing.dart      # Spacing constants
│   ├── app_theme.dart        # Complete theme configuration
│   └── theme.dart           # Export file
├── widgets/
│   ├── feature_card.dart     # Feature card components
│   ├── app_badge.dart        # Badge components
│   ├── section_header.dart   # Section headers
│   ├── recipe_card.dart      # Recipe card components
│   └── widgets.dart         # Export file
```

All files are ready to use and match your design mockups!
