import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

/// Section Header Widget
/// Header for sections like "The Lounge", "Back Bar"
/// Includes title and optional badge
class SectionHeader extends StatelessWidget {
  final String title;
  final String? badgeText;
  final VoidCallback? onSeeAllTap;

  const SectionHeader({
    super.key,
    required this.title,
    this.badgeText,
    this.onSeeAllTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sectionTitleSpacing,
      ),
      child: Row(
        children: [
          // Title - use Flexible to prevent overflow
          Flexible(
            child: Text(
              title,
              style: AppTypography.sectionTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Badge (if provided)
          if (badgeText != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.accentCyan,
                borderRadius: BorderRadius.circular(AppSpacing.badgeBorderRadius),
              ),
              child: Text(
                badgeText!,
                style: AppTypography.badge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
          const Spacer(),
          // See All Button (if onTap provided)
          if (onSeeAllTap != null)
            TextButton(
              onPressed: onSeeAllTap,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See All',
                    style: AppTypography.buttonSmall.copyWith(
                      color: AppColors.accentCyan,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.arrow_forward,
                    size: AppSpacing.iconSizeSmall,
                    color: AppColors.accentCyan,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// SubHeader Widget
/// Smaller header for subsections
class SubHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SubHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.heading4,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: AppTypography.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}
