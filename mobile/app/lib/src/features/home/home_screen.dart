import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/cocktail.dart';
import '../../providers/auth_provider.dart';
import '../../providers/backend_provider.dart';
import '../../services/battery_optimization_service.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../favorites/favorites_screen.dart';
import '../my_bar/my_bar_screen.dart';
import '../recipe_vault/cocktail_detail_screen.dart';
import '../recipe_vault/recipe_vault_screen.dart';
import 'providers/todays_special_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasCheckedBatteryOptimization = false;

  @override
  void initState() {
    super.initState();
    // Schedule battery optimization check after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBatteryOptimization();
    });
  }

  Future<void> _checkBatteryOptimization() async {
    if (_hasCheckedBatteryOptimization) return;
    _hasCheckedBatteryOptimization = true;

    // Only show if user is authenticated
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    if (!isAuthenticated) return;

    // Show the battery optimization dialog if needed
    if (mounted) {
      await BatteryOptimizationService.instance.showExemptionDialogIfNeeded(context);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              _buildAppHeader(context, ref),
              SizedBox(height: AppSpacing.xxl),

              // AI Cocktail Concierge Section
              _buildConciergeSection(context),
              SizedBox(height: AppSpacing.sectionSpacing),

              // The Lounge Section
              _buildLoungeEssentials(context),
              SizedBox(height: AppSpacing.sectionSpacing),

              // Back Bar Section
              _buildMasterMixologist(context),
              SizedBox(height: AppSpacing.sectionSpacing),

              // Today's Special
              _buildTodaysSpecial(context, ref),
              SizedBox(height: AppSpacing.xl),
              // Responsible drinking message and version
              Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    children: [
                      Text(
                        '21+ | Drink Responsibly',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        'Version: 1.0.0',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppHeader(BuildContext context, WidgetRef ref) {
    // Watch backend health status for profile icon indicator
    final healthCheck = ref.watch(healthCheckProvider);

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/icon/icon.png',
            fit: BoxFit.cover,
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
        // Profile Button with connection status indicator
        _buildProfileButtonWithStatus(context, healthCheck),
      ],
    );
  }

  /// Build profile button with backend connection status indicator
  Widget _buildProfileButtonWithStatus(
    BuildContext context,
    AsyncValue<bool> healthCheck,
  ) {
    // Determine indicator color based on backend status
    Color indicatorColor = healthCheck.when(
      data: (isHealthy) => isHealthy ? AppColors.success : AppColors.error,
      loading: () => AppColors.textTertiary,
      error: (_, __) => AppColors.error,
    );

    return GestureDetector(
      onTap: () => context.go('/profile'),
      child: Stack(
        children: [
          // Profile icon with colored border
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: indicatorColor,
                width: 2.5,
              ),
            ),
            child: Icon(
              Icons.person_outline,
              color: AppColors.textSecondary,
              size: 24,
            ),
          ),
          // Small status dot in bottom-right corner
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: indicatorColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.backgroundPrimary,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
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
                  color: AppColors.iconCircleTeal,
                  onTap: () => context.go('/ask-bartender'),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildActionButton(
                  context: context,
                  icon: Icons.mic,
                  title: 'Voice',
                  subtitle: 'Talk to AI',
                  color: AppColors.iconCircleBlue,
                  onTap: () => context.go('/voice-ai'),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          // Action Buttons - Row 2
          Row(
            children: [
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
              width: AppSpacing.iconCircleAction,
              height: AppSpacing.iconCircleAction,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.textPrimary,
                size: AppSpacing.iconSizeAction,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: AppTypography.cardTitle,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: AppTypography.cardSubtitle.copyWith(
                color: AppColors.textPrimary,
              ),
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
        SectionHeader(title: 'The Lounge'),
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
          title: 'Back Bar',
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
                // FIX: Use GoRouter for consistent navigation with notification deep links
                context.push('/cocktail/${cocktail.id}');
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
