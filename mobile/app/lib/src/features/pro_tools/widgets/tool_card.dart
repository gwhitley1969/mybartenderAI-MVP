import 'package:flutter/material.dart';

import '../../../theme/theme.dart';
import '../models/pro_tools_models.dart';

/// Card widget for displaying a tool in the tier list.
///
/// Shows tool icon, name, subtitle, and a chevron for navigation.
class ToolCard extends StatelessWidget {
  final ProTool tool;
  final Color tierColor;
  final VoidCallback onTap;

  const ToolCard({
    required this.tool,
    required this.tierColor,
    required this.onTap,
    super.key,
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
        padding: EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Icon circle
            Container(
              width: AppSpacing.iconCircleMedium,
              height: AppSpacing.iconCircleMedium,
              decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIconData(tool.iconName),
                color: tierColor,
                size: AppSpacing.iconSizeMedium,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tool.name,
                    style: AppTypography.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    tool.subtitle,
                    style: AppTypography.cardSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Chevron
            Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  /// Map icon name strings to IconData.
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'straighten':
        return Icons.straighten;
      case 'sports_bar':
        return Icons.sports_bar;
      case 'sync':
        return Icons.sync;
      case 'filter_alt':
        return Icons.filter_alt;
      case 'vertical_align_bottom':
        return Icons.vertical_align_bottom;
      case 'compress':
        return Icons.compress;
      case 'local_bar':
        return Icons.local_bar;
      case 'filter_list':
        return Icons.filter_list;
      case 'content_cut':
        return Icons.content_cut;
      case 'filter_2':
        return Icons.filter_2;
      case 'water_drop':
        return Icons.water_drop;
      case 'ac_unit':
        return Icons.ac_unit;
      case 'tune':
        return Icons.tune;
      case 'gavel':
        return Icons.gavel;
      case 'smoking_rooms':
        return Icons.smoking_rooms;
      case 'air':
        return Icons.air;
      case 'scale':
        return Icons.scale;
      case 'thermostat':
        return Icons.thermostat;
      default:
        return Icons.build;
    }
  }
}
