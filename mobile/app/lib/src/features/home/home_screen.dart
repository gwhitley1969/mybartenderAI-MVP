import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../ask_bartender/voice_chat_screen.dart';
import '../my_bar/my_bar_screen.dart';
import '../recipe_vault/recipe_vault_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingHorizontal,
            vertical: AppSpacing.screenPaddingTop,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App Header
              _buildAppHeader(),
              SizedBox(height: AppSpacing.xxl),

              // AI Cocktail Concierge Section
              _buildConciergeSection(context),
              SizedBox(height: AppSpacing.sectionSpacing),

              // Lounge Essentials Section
              _buildLoungeEssentials(context),
              SizedBox(height: AppSpacing.sectionSpacing),

              // Master Mixologist Section
              _buildMasterMixologist(context),
              SizedBox(height: AppSpacing.sectionSpacing),

              // Tonight's Special
              _buildTonightsSpecial(context),
              SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // App Logo Icon (optional - can add circular icon here)
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.cardBorder,
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.local_bar,
                color: AppColors.iconCircleBlue,
                size: 32,
              ),
            ),
            SizedBox(width: AppSpacing.lg),
            // Title and Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MyBartenderAI',
                    style: AppTypography.appTitle,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'Premium mixology experience',
                    style: AppTypography.appSubtitle,
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        // User Level Badges
        Row(
          children: [
            AppBadge.intermediate(),
            SizedBox(width: AppSpacing.sm),
            AppBadge.spiritCount(count: 8),
            SizedBox(width: AppSpacing.sm),
            BackendStatus(),
          ],
        ),
      ],
    );
  }

  Widget _buildConciergeSection(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.cardLargeBorderRadius),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppSpacing.borderWidthThin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Concierge Header
          Row(
            children: [
              Container(
                width: AppSpacing.iconCircleMedium,
                height: AppSpacing.iconCircleMedium,
                decoration: BoxDecoration(
                  color: AppColors.accentBlue,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
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
                      'AI Cocktail Concierge',
                      style: AppTypography.cardTitle.copyWith(
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      'Sophisticated cocktail intelligence for the evening',
                      style: AppTypography.cardSubtitle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context: context,
                  icon: Icons.mic,
                  title: 'Ask the Bartender',
                  subtitle: 'Speak naturally',
                  color: AppColors.iconCircleBlue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VoiceChatScreen(),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildActionButton(
                  context: context,
                  icon: Icons.auto_fix_high,
                  title: 'Create',
                  subtitle: 'Signature cocktails',
                  color: AppColors.primaryPurple,
                  onTap: () {
                    // TODO: Navigate to create screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Create Studio coming soon!'),
                        backgroundColor: AppColors.cardBackground,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
          border: Border.all(
            color: AppColors.cardBorder,
            width: AppSpacing.borderWidthThin,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: AppSpacing.iconCircleSmall,
              height: AppSpacing.iconCircleSmall,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.textPrimary,
                size: AppSpacing.iconSizeSmall,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: AppTypography.buttonSmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: AppTypography.caption,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildLoungeEssentials(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Lounge Essentials'),
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.gridSpacing,
          mainAxisSpacing: AppSpacing.gridSpacing,
          childAspectRatio: 0.9,
          children: [
            FeatureCard(
              icon: Icons.camera_alt,
              title: 'Smart Scanner',
              subtitle: 'Identify premium ingredients',
              iconColor: AppColors.iconCirclePurple,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Smart Scanner coming soon!'),
                    backgroundColor: AppColors.cardBackground,
                  ),
                );
              },
            ),
            FeatureCard(
              icon: Icons.menu_book,
              title: 'Recipe Vault',
              subtitle: 'Curated cocktail collection',
              iconColor: AppColors.iconCircleOrange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RecipeVaultScreen(),
                  ),
                );
              },
            ),
            FeatureCard(
              icon: Icons.inventory_2,
              title: 'My Bar',
              subtitle: 'Track your collection',
              iconColor: AppColors.iconCircleTeal,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyBarScreen(),
                  ),
                );
              },
            ),
            FeatureCard(
              icon: Icons.person,
              title: 'Taste Profile',
              subtitle: 'Personal preferences',
              iconColor: AppColors.accentBlue,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Taste Profile coming soon!'),
                    backgroundColor: AppColors.cardBackground,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMasterMixologist(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Master Mixologist',
          badgeText: 'Elite',
        ),
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.gridSpacing,
          mainAxisSpacing: AppSpacing.gridSpacing,
          childAspectRatio: 0.9,
          children: [
            FeatureCard(
              icon: Icons.school,
              title: 'Academy',
              subtitle: 'Professional techniques',
              iconColor: AppColors.iconCirclePink,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Academy coming soon!'),
                    backgroundColor: AppColors.cardBackground,
                  ),
                );
              },
            ),
            FeatureCard(
              icon: Icons.calculate,
              title: 'Pro Tools',
              subtitle: 'Precision instruments',
              iconColor: AppColors.iconCircleOrange,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Pro Tools coming soon!'),
                    backgroundColor: AppColors.cardBackground,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTonightsSpecial(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.cardLargeBorderRadius),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppSpacing.borderWidthThin,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: AppSpacing.iconCircleMedium,
            height: AppSpacing.iconCircleMedium,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.nightlight_round,
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
                  'Tonight\'s Special',
                  style: AppTypography.cardTitle.copyWith(
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'Perfectly crafted for your palate: Sweet + Citrusy',
                  style: AppTypography.cardSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
