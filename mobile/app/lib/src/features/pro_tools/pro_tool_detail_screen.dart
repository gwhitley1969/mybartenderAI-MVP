import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'models/pro_tools_models.dart';
import 'widgets/price_range_card.dart';

/// Detail screen for an individual bar tool.
///
/// Shows full description, why you need it, what to look for,
/// price ranges, and tags.
class ProToolDetailScreen extends StatelessWidget {
  final ProTool tool;
  final Color tierColor;

  const ProToolDetailScreen({
    required this.tool,
    required this.tierColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
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
          tool.name,
          style: AppTypography.cardTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero icon section
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: tierColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconData(tool.iconName),
                    color: AppColors.textPrimary,
                    size: 48,
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              // Title and subtitle
              Center(
                child: Column(
                  children: [
                    Text(
                      tool.name,
                      style: AppTypography.heading2,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      tool.subtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: tierColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.xl),
              // Description
              Text(
                tool.description,
                style: AppTypography.bodyLarge,
              ),
              SizedBox(height: AppSpacing.xxl),
              // Why You Need It section
              _buildSectionHeader(
                icon: Icons.lightbulb_outline,
                title: 'Why You Need It',
                color: tierColor,
              ),
              SizedBox(height: AppSpacing.md),
              Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                  border: Border.all(
                    color: tierColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.format_quote,
                      color: tierColor,
                      size: 24,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        tool.whyYouNeedIt,
                        style: AppTypography.bodyMedium.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.xxl),
              // What to Look For section
              _buildSectionHeader(
                icon: Icons.checklist,
                title: 'What to Look For',
                color: tierColor,
              ),
              SizedBox(height: AppSpacing.md),
              ...tool.whatToLookFor.map((item) => Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: tierColor,
                          size: 20,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            item,
                            style: AppTypography.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )),
              SizedBox(height: AppSpacing.xxl),
              // Price Ranges section
              _buildSectionHeader(
                icon: Icons.attach_money,
                title: 'Price Ranges',
                color: tierColor,
              ),
              SizedBox(height: AppSpacing.md),
              // Price range cards in a row
              Row(
                children: tool.priceRanges.map((priceRange) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: PriceRangeCard(
                        priceRange: priceRange,
                        isRecommended: priceRange.tier == 'mid',
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: AppSpacing.xxl),
              // Tags section
              if (tool.tags.isNotEmpty) ...[
                _buildSectionHeader(
                  icon: Icons.label_outline,
                  title: 'Tags',
                  color: tierColor,
                ),
                SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: tool.tags.map((tag) {
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.badgeBorderRadius,
                        ),
                        border: Border.all(
                          color: AppColors.cardBorder,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              // Bottom padding
              SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 22,
        ),
        SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: AppTypography.heading4,
        ),
      ],
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
