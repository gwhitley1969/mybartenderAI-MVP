import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/cocktail_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../theme/theme.dart';

class CocktailDetailScreen extends ConsumerWidget {
  final String cocktailId;

  const CocktailDetailScreen({
    super.key,
    required this.cocktailId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cocktailAsync = ref.watch(cocktailByIdProvider(cocktailId));

    return cocktailAsync.when(
      data: (cocktail) {
        if (cocktail == null) {
          return Scaffold(
            backgroundColor: AppColors.backgroundPrimary,
            appBar: AppBar(
              backgroundColor: AppColors.backgroundPrimary,
              elevation: 0,
            ),
            body: Center(
              child: Text(
                'Cocktail not found',
                style: AppTypography.heading2,
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          body: CustomScrollView(
            slivers: [
              // App bar with image
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: AppColors.backgroundPrimary,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  // Favorite button
                  Consumer(
                    builder: (context, ref, child) {
                      final isFavoriteAsync = ref.watch(isFavoriteProvider(cocktailId));

                      return isFavoriteAsync.when(
                        data: (isFavorite) {
                          return IconButton(
                            icon: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite ? AppColors.accentRed : AppColors.textPrimary,
                            ),
                            onPressed: () async {
                              final notifier = ref.read(favoritesNotifierProvider.notifier);
                              await notifier.toggleFavorite(cocktailId);

                              // Show feedback
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isFavorite
                                          ? 'Removed from favorites'
                                          : 'Added to favorites',
                                    ),
                                    backgroundColor: AppColors.cardBackground,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          );
                        },
                        loading: () => IconButton(
                          icon: Icon(Icons.favorite_border, color: AppColors.textPrimary),
                          onPressed: null,
                        ),
                        error: (_, __) => IconButton(
                          icon: Icon(Icons.favorite_border, color: AppColors.textPrimary),
                          onPressed: null,
                        ),
                      );
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: cocktail.imageUrl != null
                      ? Image.network(
                          cocktail.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppColors.cardBackground,
                              child: Icon(
                                Icons.local_bar,
                                size: 100,
                                color: AppColors.iconCircleBlue,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: AppColors.cardBackground,
                          child: Icon(
                            Icons.local_bar,
                            size: 100,
                            color: AppColors.iconCircleBlue,
                          ),
                        ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and metadata
                      Text(
                        cocktail.name,
                        style: AppTypography.heading1,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      _buildMetadataRow(cocktail),
                      SizedBox(height: AppSpacing.xl),

                      // Ingredients section
                      _buildSectionHeader('Ingredients'),
                      SizedBox(height: AppSpacing.md),
                      _buildIngredientsCard(context, ref, cocktail.ingredients),
                      SizedBox(height: AppSpacing.xl),

                      // Instructions section
                      if (cocktail.instructions != null) ...[
                        _buildSectionHeader('Instructions'),
                        SizedBox(height: AppSpacing.md),
                        _buildInstructionsCard(cocktail.instructions!),
                        SizedBox(height: AppSpacing.xl),
                      ],

                      // Additional info
                      _buildAdditionalInfo(cocktail),
                      SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundPrimary,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundPrimary,
          elevation: 0,
        ),
        body: Center(
          child: Text(
            'Error loading cocktail',
            style: AppTypography.bodyMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataRow(Cocktail cocktail) {
    final items = <Widget>[];

    if (cocktail.category != null) {
      items.add(_buildBadge(cocktail.category!, AppColors.iconCircleOrange));
    }

    if (cocktail.alcoholic != null) {
      items.add(_buildBadge(
        cocktail.alcoholic!,
        cocktail.alcoholic == 'Alcoholic'
            ? AppColors.iconCirclePink
            : AppColors.iconCircleTeal,
      ));
    }

    if (cocktail.glass != null) {
      items.add(_buildBadge(cocktail.glass!, AppColors.iconCircleBlue));
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: items,
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppSpacing.badgeBorderRadius),
        border: Border.all(
          color: color,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(color: color),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTypography.heading2,
    );
  }

  Widget _buildIngredientsCard(
    BuildContext context,
    WidgetRef ref,
    List<DrinkIngredient> ingredients,
  ) {
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
        children: ingredients.map((ingredient) {
          final isInInventoryAsync =
              ref.watch(isInInventoryProvider(ingredient.ingredientName));

          return isInInventoryAsync.when(
            data: (isInInventory) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isInInventory
                            ? AppColors.iconCircleTeal
                            : AppColors.primaryPurple,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        ingredient.ingredientName,
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                    if (ingredient.measure != null) ...[
                      Text(
                        ingredient.measure!,
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      SizedBox(width: AppSpacing.sm),
                    ],
                    // Quick-add button
                    if (isInInventory)
                      Icon(
                        Icons.check_circle,
                        color: AppColors.iconCircleTeal,
                        size: 20,
                      )
                    else
                      IconButton(
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: AppColors.primaryPurple,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        onPressed: () async {
                          final notifier =
                              ref.read(inventoryNotifierProvider.notifier);
                          await notifier.addIngredient(
                            ingredient.ingredientName,
                          );

                          // Refresh inventory providers
                          ref.invalidate(inventoryProvider);
                          ref.invalidate(isInInventoryProvider);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Added ${ingredient.ingredientName} to your bar'),
                                backgroundColor: AppColors.cardBackground,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                  ],
                ),
              );
            },
            loading: () => Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      ingredient.ingredientName,
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                  if (ingredient.measure != null)
                    Text(
                      ingredient.measure!,
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            error: (_, __) => Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      ingredient.ingredientName,
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                  if (ingredient.measure != null)
                    Text(
                      ingredient.measure!,
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInstructionsCard(String instructions) {
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
      child: Text(
        instructions,
        style: AppTypography.bodyMedium,
      ),
    );
  }

  Widget _buildAdditionalInfo(Cocktail cocktail) {
    final items = <Widget>[];

    if (cocktail.iba != null) {
      items.add(_buildInfoRow('IBA Category', cocktail.iba!));
    }

    if (cocktail.tags.isNotEmpty) {
      items.add(_buildInfoRow('Tags', cocktail.tags.join(', ')));
    }

    if (cocktail.alternateName != null) {
      items.add(_buildInfoRow('Also known as', cocktail.alternateName!));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppSpacing.borderWidthThin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption,
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.bodyMedium,
          ),
        ],
      ),
    );
  }
}
