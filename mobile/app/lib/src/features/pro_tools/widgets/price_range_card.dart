import 'package:flutter/material.dart';

import '../../../theme/theme.dart';
import '../models/pro_tools_models.dart';

/// Card widget for displaying a price range option.
///
/// Shows the tier label, price range, and a note.
/// The "mid" tier is highlighted as the recommended option.
class PriceRangeCard extends StatelessWidget {
  final PriceRange priceRange;
  final bool isRecommended;

  const PriceRangeCard({
    required this.priceRange,
    this.isRecommended = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Visual styling based on tier
    final Color backgroundColor;
    final Color borderColor;
    final Color labelColor;

    switch (priceRange.tier) {
      case 'budget':
        backgroundColor = AppColors.backgroundSecondary;
        borderColor = AppColors.cardBorder;
        labelColor = AppColors.textSecondary;
        break;
      case 'mid':
        backgroundColor = AppColors.iconCircleTeal.withValues(alpha: 0.1);
        borderColor = AppColors.iconCircleTeal.withValues(alpha: 0.5);
        labelColor = AppColors.iconCircleTeal;
        break;
      case 'premium':
        backgroundColor = AppColors.iconCircleOrange.withValues(alpha: 0.1);
        borderColor = AppColors.iconCircleOrange.withValues(alpha: 0.5);
        labelColor = AppColors.iconCircleOrange;
        break;
      default:
        backgroundColor = AppColors.backgroundSecondary;
        borderColor = AppColors.cardBorder;
        labelColor = AppColors.textSecondary;
    }

    return Container(
      padding: EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        border: Border.all(
          color: borderColor,
          width: isRecommended ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Recommended badge (only for mid tier)
          if (isRecommended) ...[
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.iconCircleTeal,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'BEST VALUE',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(height: AppSpacing.xs),
          ],
          // Label
          Text(
            priceRange.label,
            style: AppTypography.bodySmall.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xs),
          // Price range
          Text(
            priceRange.range,
            style: AppTypography.cardTitle.copyWith(
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xs),
          // Note
          Text(
            priceRange.note,
            style: AppTypography.caption.copyWith(
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
