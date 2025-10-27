import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

/// App Badge Widget
/// Pill-shaped badge used for user levels, counts, and tags
/// Matches the "Intermediate", "8 spirits", "Elite" badges from mockups
class AppBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final bool outlined;

  const AppBadge({
    super.key,
    required this.label,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.outlined = false,
  });

  /// Intermediate level badge (purple)
  factory AppBadge.intermediate({String label = 'Intermediate'}) {
    return AppBadge(
      label: label,
      icon: Icons.star,
      backgroundColor: AppColors.badgeIntermediate.withOpacity(0.2),
      textColor: AppColors.textPrimary,
    );
  }

  /// Elite level badge (orange)
  factory AppBadge.elite({String label = 'Elite'}) {
    return AppBadge(
      label: label,
      icon: Icons.stars,
      backgroundColor: AppColors.badgeElite.withOpacity(0.2),
      textColor: AppColors.badgeElite,
    );
  }

  /// Spirit count badge (with icon)
  factory AppBadge.spiritCount({required int count}) {
    return AppBadge(
      label: '$count spirits',
      icon: Icons.local_bar,
      backgroundColor: AppColors.badgeBackground,
      textColor: AppColors.textSecondary,
    );
  }

  /// Ingredient tag (for selected ingredients)
  factory AppBadge.ingredient({required String name, VoidCallback? onRemove}) {
    return AppBadge(
      label: name,
      backgroundColor: AppColors.primaryPurple,
      textColor: AppColors.textPrimary,
    );
  }

  /// Missing ingredient tag (red)
  factory AppBadge.missingIngredient({required String name}) {
    return AppBadge(
      label: name,
      backgroundColor: AppColors.error,
      textColor: AppColors.textPrimary,
    );
  }

  /// Difficulty badge
  factory AppBadge.difficulty({required String level}) {
    Color color;
    switch (level.toLowerCase()) {
      case 'easy':
        color = AppColors.success;
        break;
      case 'medium':
        color = AppColors.warning;
        break;
      case 'hard':
        color = AppColors.error;
        break;
      default:
        color = AppColors.textTertiary;
    }
    return AppBadge(
      label: level,
      backgroundColor: color.withOpacity(0.2),
      textColor: color,
    );
  }

  /// AI Created badge (with sparkles icon)
  factory AppBadge.aiCreated() {
    return const AppBadge(
      label: 'AI',
      icon: Icons.auto_awesome,
      backgroundColor: AppColors.accentCyan,
      textColor: AppColors.textPrimary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.badgePaddingHorizontal,
        vertical: AppSpacing.badgePaddingVertical,
      ),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : (backgroundColor ?? AppColors.badgeBackground),
        borderRadius: BorderRadius.circular(AppSpacing.badgeBorderRadius),
        border: outlined
            ? Border.all(
                color: textColor ?? AppColors.textSecondary,
                width: AppSpacing.borderWidthThin,
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: AppSpacing.iconSizeSmall,
              color: textColor ?? AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTypography.badge.copyWith(
              color: textColor ?? AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Match Score Badge
/// Circular badge showing ingredient match (e.g., "3/5")
/// Used on recipe cards to show how many ingredients user has
class MatchScoreBadge extends StatelessWidget {
  final int matchCount;
  final int totalCount;
  final Color? backgroundColor;

  const MatchScoreBadge({
    super.key,
    required this.matchCount,
    required this.totalCount,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate match percentage for color
    final percentage = matchCount / totalCount;
    Color scoreColor;
    if (percentage == 1.0) {
      scoreColor = AppColors.success;
    } else if (percentage >= 0.6) {
      scoreColor = AppColors.accentCyan;
    } else {
      scoreColor = AppColors.warning;
    }

    return Container(
      width: AppSpacing.matchBadgeSize,
      height: AppSpacing.matchBadgeSize,
      decoration: BoxDecoration(
        color: backgroundColor ?? scoreColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$matchCount/$totalCount',
          style: AppTypography.matchScore.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Pill Button Widget
/// Rounded pill-shaped button used for selections
/// Like "Bourbon", "Brandy", etc. in the bar inventory
class PillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const PillButton({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pillPaddingHorizontal,
          vertical: AppSpacing.pillPaddingVertical,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryPurple : AppColors.buttonSecondary,
          borderRadius: BorderRadius.circular(AppSpacing.pillBorderRadius),
          border: Border.all(
            color: selected ? AppColors.primaryPurple : AppColors.cardBorder,
            width: AppSpacing.borderWidthThin,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: AppSpacing.iconSizeSmall,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(
              label,
              style: AppTypography.pill,
            ),
            if (selected) ...[
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.close,
                size: AppSpacing.iconSizeSmall,
                color: AppColors.textPrimary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
