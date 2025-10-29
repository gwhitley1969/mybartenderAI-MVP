import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/cocktail_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../recipe_vault/cocktail_detail_screen.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);
    final countAsync = ref.watch(favoritesCountProvider);

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
          'My Favorites',
          style: AppTypography.appTitle,
        ),
      ),
      body: Column(
        children: [
          // Statistics section
          Padding(
            padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
            child: countAsync.when(
              data: (count) => _buildStatistics(count),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          // Favorites grid
          Expanded(
            child: favoritesAsync.when(
              data: (favorites) => _buildFavoritesGrid(context, ref, favorites),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: AppColors.textSecondary),
                      SizedBox(height: AppSpacing.md),
                      Text(
                        'Error loading favorites',
                        style: AppTypography.bodyMedium,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        error.toString(),
                        style: AppTypography.caption,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics(int count) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppSpacing.borderWidthThin,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite, color: AppColors.accentRed, size: 24),
          SizedBox(width: AppSpacing.md),
          Column(
            children: [
              Text('$count', style: AppTypography.heading2),
              SizedBox(height: AppSpacing.xs),
              Text('Favorite Cocktails', style: AppTypography.caption),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesGrid(
      BuildContext context, WidgetRef ref, List<FavoriteCocktail> favorites) {
    if (favorites.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border, size: 64, color: AppColors.textSecondary),
              SizedBox(height: AppSpacing.lg),
              Text(
                'No favorites yet',
                style: AppTypography.heading3,
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                'Tap the heart icon on any cocktail\nto add it to your favorites',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.gridSpacing,
        mainAxisSpacing: AppSpacing.gridSpacing,
        childAspectRatio: 0.75,
      ),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final favorite = favorites[index];
        // Fetch the cocktail data for this favorite
        final cocktailAsync = ref.watch(cocktailByIdProvider(favorite.cocktailId));

        return cocktailAsync.when(
          data: (cocktail) {
            if (cocktail == null) {
              return const SizedBox.shrink();
            }

            return Stack(
              children: [
                CompactRecipeCard(
                  name: cocktail.name,
                  imageUrl: cocktail.imageUrl,
                  matchCount: cocktail.ingredients.length,
                  totalIngredients: cocktail.ingredients.length,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CocktailDetailScreen(cocktailId: cocktail.id),
                      ),
                    );
                  },
                ),
                // Favorite indicator badge
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Container(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundPrimary.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite,
                      color: AppColors.accentRed,
                      size: 16,
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
              border: Border.all(
                color: AppColors.cardBorder,
                width: AppSpacing.borderWidthThin,
              ),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }
}
