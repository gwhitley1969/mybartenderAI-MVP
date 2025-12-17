import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

/// Feature Card Widget
/// Large card with icon, title, and subtitle used on home screen
/// Matches the design from mockups (Smart Scanner, Recipe Vault, etc.)
class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Gradient? gradient;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
    this.backgroundColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.cardBackground,
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppSpacing.cardLargeBorderRadius),
          border: Border.all(
            color: AppColors.cardBorder,
            width: AppSpacing.borderWidthThin,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon Circle
            Container(
              width: AppSpacing.iconCircleLarge,
              height: AppSpacing.iconCircleLarge,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.textPrimary,
                size: AppSpacing.iconSizeLarge,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Title - use FittedBox to scale down if needed
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: AppTypography.cardTitle,
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Subtitle - flexible with ellipsis for overflow
            Flexible(
              child: Text(
                subtitle,
                style: AppTypography.cardSubtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact Feature Card Widget
/// Smaller horizontal card with icon and text side-by-side
/// Used for "Ask the Bartender" and "Create" sections
class CompactFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  const CompactFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
          border: Border.all(
            color: AppColors.cardBorder,
            width: AppSpacing.borderWidthThin,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          children: [
            // Icon Circle
            Container(
              width: AppSpacing.iconCircleMedium,
              height: AppSpacing.iconCircleMedium,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.textPrimary,
                size: AppSpacing.iconSizeMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.cardTitle,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTypography.cardSubtitle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
