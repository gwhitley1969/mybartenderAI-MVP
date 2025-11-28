import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'models/pro_tools_models.dart';
import 'pro_tool_detail_screen.dart';
import 'widgets/tool_card.dart';

/// Screen showing the list of tools within a specific tier.
///
/// Users can tap a tool to see its full details.
class ProToolsTierScreen extends StatelessWidget {
  final ToolTier tier;

  const ProToolsTierScreen({
    required this.tier,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tierColor = _getTierColor(tier.id);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          tier.title,
          style: AppTypography.appTitle,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tier header
              Row(
                children: [
                  Container(
                    width: AppSpacing.iconCircleMedium,
                    height: AppSpacing.iconCircleMedium,
                    decoration: BoxDecoration(
                      color: tierColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIconData(tier.iconName),
                      color: AppColors.textPrimary,
                      size: AppSpacing.iconSizeMedium,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tier.subtitle,
                          style: AppTypography.bodySmall.copyWith(
                            color: tierColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          tier.description,
                          style: AppTypography.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.xl),
              // Tool count
              Text(
                '${tier.toolCount} Essential Tools',
                style: AppTypography.heading4,
              ),
              SizedBox(height: AppSpacing.md),
              // Tool list
              ...tier.tools.map((tool) => Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: ToolCard(
                      tool: tool,
                      tierColor: tierColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProToolDetailScreen(
                              tool: tool,
                              tierColor: tierColor,
                            ),
                          ),
                        );
                      },
                    ),
                  )),
              SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  /// Get a unique color for each tier.
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

  /// Map icon name strings to IconData.
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'star':
        return Icons.star;
      case 'trending_up':
        return Icons.trending_up;
      case 'workspace_premium':
        return Icons.workspace_premium;
      default:
        return Icons.build;
    }
  }
}
