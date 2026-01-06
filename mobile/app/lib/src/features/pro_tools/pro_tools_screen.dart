import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme.dart';
import 'data/pro_tools_repository.dart';
import 'models/pro_tools_models.dart';
import 'pro_tools_tier_screen.dart';

/// Main Pro Tools screen showing a list of tool tiers.
///
/// Users can tap a tier to see its tools.
class ProToolsScreen extends StatefulWidget {
  const ProToolsScreen({super.key});

  @override
  State<ProToolsScreen> createState() => _ProToolsScreenState();
}

class _ProToolsScreenState extends State<ProToolsScreen> {
  late Future<List<ToolTier>> _tiersFuture;

  @override
  void initState() {
    super.initState();
    _tiersFuture = ProToolsRepository.getTiers();
  }

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
          'Pro Tools',
          style: AppTypography.appTitle,
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<ToolTier>>(
          future: _tiersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoading();
            }

            if (snapshot.hasError) {
              return _buildError(snapshot.error.toString());
            }

            final tiers = snapshot.data ?? [];
            if (tiers.isEmpty) {
              return _buildEmpty();
            }

            return _buildTierList(tiers);
          },
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.iconCircleOrange,
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'Loading tools...',
            style: AppTypography.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Failed to load tools',
              style: AppTypography.heading4,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  ProToolsRepository.clearCache();
                  _tiersFuture = ProToolsRepository.getTiers();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.iconCircleOrange,
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.build_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'No tools available',
            style: AppTypography.heading4,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Check back later for new content',
            style: AppTypography.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildTierList(List<ToolTier> tiers) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header text
          Text(
            'Precision Instruments',
            style: AppTypography.heading3,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Build your home bar with the right tools for every technique',
            style: AppTypography.bodyMedium,
          ),
          SizedBox(height: AppSpacing.xl),
          // Tier cards
          ...tiers.map((tier) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.gridSpacing),
                child: _buildTierCard(tier),
              )),
          SizedBox(height: AppSpacing.md),
          // AI Concierge prompt card
          _buildConciergeCTA(),
          SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildTierCard(ToolTier tier) {
    final tierColor = _getTierColor(tier.id);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProToolsTierScreen(tier: tier),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.cardLargeBorderRadius),
          border: Border.all(
            color: AppColors.cardBorder,
            width: AppSpacing.borderWidthThin,
          ),
        ),
        padding: EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          children: [
            // Icon circle
            Container(
              width: AppSpacing.iconCircleLarge,
              height: AppSpacing.iconCircleLarge,
              decoration: BoxDecoration(
                color: tierColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIconData(tier.iconName),
                color: AppColors.textPrimary,
                size: AppSpacing.iconSizeLarge,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row with badge
                  Row(
                    children: [
                      Text(
                        tier.title,
                        style: AppTypography.cardTitle.copyWith(fontSize: 18),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: tierColor.withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.badgeBorderRadius),
                        ),
                        child: Text(
                          '${tier.toolCount} tools',
                          style: AppTypography.caption.copyWith(
                            color: tierColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.xs),
                  // Subtitle
                  Text(
                    tier.subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: tierColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  // Description
                  Text(
                    tier.description,
                    style: AppTypography.cardSubtitle,
                    maxLines: 2,
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

  /// Build the AI Concierge call-to-action card.
  Widget _buildConciergeCTA() {
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
          // Icon
          Icon(
            Icons.chat_bubble_outline,
            size: 32,
            color: AppColors.iconCircleBlue,
          ),
          SizedBox(height: AppSpacing.sm),
          // Text
          Text(
            'Have questions? Your AI Concierge\nis here to help',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.lg),
          // Buttons row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/ask-bartender'),
                  icon: Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text('Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.iconCircleBlue,
                    foregroundColor: AppColors.textPrimary,
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.cardBorderRadius),
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/voice-ai'),
                  icon: Icon(Icons.mic, size: 18),
                  label: Text('Voice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.iconCircleTeal,
                    foregroundColor: AppColors.textPrimary,
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.cardBorderRadius),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
