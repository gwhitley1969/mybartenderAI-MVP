import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/cocktail.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../favorites/favorites_screen.dart';
import '../my_bar/my_bar_screen.dart';
import '../recipe_vault/cocktail_detail_screen.dart';
import '../recipe_vault/recipe_vault_screen.dart';
import 'providers/todays_special_provider.dart';

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
              _buildAppHeader(context),
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

              // Today's Special
              _buildTodaysSpecial(context, ref),
              SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppHeader(BuildContext context) {
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
                    'My AI Bartender',
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
            // Profile Button
            IconButton(
              onPressed: () => context.go('/profile'),
              icon: Icon(
                Icons.person_outline,
                color: AppColors.textSecondary,
                size: 28,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        // Backend Connectivity Status
        Center(
          child: BackendStatus(),
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
          // Action Buttons - Row 1
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context: context,
                  icon: Icons.chat_bubble_outline,
                  title: 'Chat',
                  subtitle: 'Text conversation',
                  color: AppColors.iconCircleBlue,
                  onTap: () => context.go('/ask-bartender'),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildActionButton(
                  context: context,
                  icon: Icons.camera_alt,
                  title: 'Scanner',
                  subtitle: 'Identify bottles',
                  color: AppColors.iconCirclePink,
                  onTap: () => context.go('/smart-scanner'),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildActionButton(
                  context: context,
                  icon: Icons.auto_fix_high,
                  title: 'Create',
                  subtitle: 'Design cocktails',
                  color: AppColors.iconCirclePurple,
                  onTap: () => context.go('/create-studio'),
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
        // Recipe Vault - Full Width Card
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RecipeVaultScreen(),
              ),
            );
          },
          child: Container(
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
                    color: AppColors.iconCircleOrange,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.menu_book,
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
                        'Recipe Vault',
                        style: AppTypography.cardTitle.copyWith(
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        'Curated cocktail collection',
                        style: AppTypography.cardSubtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: AppSpacing.gridSpacing),
        // My Bar and Favorites - 2 Column Grid
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.gridSpacing,
          mainAxisSpacing: AppSpacing.gridSpacing,
          childAspectRatio: 0.9,
          children: [
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
              icon: Icons.favorite,
              title: 'Favorites',
              subtitle: 'Saved cocktails',
              iconColor: AppColors.accentRed,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FavoritesScreen(),
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
              onTap: () => context.go('/academy'),
            ),
            FeatureCard(
              icon: Icons.build,
              title: 'Pro Tools',
              subtitle: 'Precision instruments',
              iconColor: AppColors.iconCircleOrange,
              onTap: () => context.go('/pro-tools'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTodaysSpecial(BuildContext context, WidgetRef ref) {
    final specialAsync = ref.watch(todaysSpecialProvider);

    return specialAsync.when(
      data: (cocktail) => _buildSpecialCard(
        context: context,
        cocktail: cocktail,
        onTap: cocktail != null
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CocktailDetailScreen(cocktailId: cocktail.id),
                  ),
                );
              }
            : null,
        contentBuilder: () => _buildSpecialDetails(cocktail),
      ),
      loading: () => _buildSpecialCard(
        context: context,
        cocktail: null,
        contentBuilder: _buildSpecialLoading,
      ),
      error: (error, stackTrace) => _buildSpecialCard(
        context: context,
        cocktail: null,
        contentBuilder: _buildSpecialError,
      ),
    );
  }

  Widget _buildSpecialCard({
    required BuildContext context,
    required Widget Function() contentBuilder,
    Cocktail? cocktail,
    VoidCallback? onTap,
  }) {
    final card = Container(
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
              color: AppColors.iconCirclePurple,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.wb_sunny_outlined,
              color: AppColors.textPrimary,
              size: AppSpacing.iconSizeMedium,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(child: contentBuilder()),
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }

    return GestureDetector(
      onTap: onTap,
      child: card,
    );
  }

  Widget _buildSpecialDetails(Cocktail? cocktail) {
    final titleStyle = AppTypography.cardTitle.copyWith(fontSize: 18);

    if (cocktail == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Special',
            style: titleStyle,
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Check back soon for a bartender-curated pick.',
            style: AppTypography.cardSubtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    final subtitle = _buildSpecialSubtitle(cocktail);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Special',
          style: titleStyle,
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          cocktail.name,
          style: AppTypography.cardTitle.copyWith(
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle.isNotEmpty) ...[
          SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: AppTypography.cardSubtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildSpecialLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Special',
          style: AppTypography.cardTitle.copyWith(fontSize: 18),
        ),
        SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.textSecondary),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Shaking up something special...',
                style: AppTypography.cardSubtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpecialError() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Special',
          style: AppTypography.cardTitle.copyWith(fontSize: 18),
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          'We\'re restocking the bar. Please check back shortly.',
          style: AppTypography.cardSubtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _buildSpecialSubtitle(Cocktail cocktail) {
    final tagLine = _buildTagLineFromTags(cocktail.tags);
    if (tagLine != null) {
      return 'Flavor profile: $tagLine';
    }

    final category = cocktail.category?.trim();
    final alcoholic = cocktail.alcoholic?.trim();

    if (category != null && category.isNotEmpty && alcoholic != null && alcoholic.isNotEmpty) {
      return '$category · $alcoholic';
    }

    if (category != null && category.isNotEmpty) {
      return category;
    }

    if (alcoholic != null && alcoholic.isNotEmpty) {
      return alcoholic;
    }

    return 'A bartender-curated favorite for today.';
  }

  String? _buildTagLineFromTags(List<String> tags) {
    final formattedTags = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .map(_capitalizeWords)
        .toList();

    if (formattedTags.isEmpty) {
      return null;
    }

    return formattedTags.take(2).join(' + ');
  }

  String _capitalizeWords(String input) {
    final words = input.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    return words
        .map(
          (word) => word.length == 1
              ? word.toUpperCase()
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }
}
