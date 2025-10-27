import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import 'app_badge.dart';

/// Recipe Card Widget
/// Card displaying cocktail recipe with match score and details
/// Matches the design from "Recipe Suggestions" screen mockup
class RecipeCard extends StatelessWidget {
  final String name;
  final String description;
  final int matchCount;
  final int totalIngredients;
  final String difficulty;
  final String time;
  final int servings;
  final List<String> missingIngredients;
  final bool isAiCreated;
  final VoidCallback onTap;

  const RecipeCard({
    super.key,
    required this.name,
    required this.description,
    required this.matchCount,
    required this.totalIngredients,
    required this.difficulty,
    required this.time,
    required this.servings,
    required this.missingIngredients,
    this.isAiCreated = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
          border: Border.all(
            color: AppColors.cardBorder,
            width: AppSpacing.borderWidthThin,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Name + Match Badge
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: AppTypography.recipeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isAiCreated) ...[
                          const SizedBox(width: AppSpacing.sm),
                          AppBadge.aiCreated(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  MatchScoreBadge(
                    matchCount: matchCount,
                    totalCount: totalIngredients,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Description
              Text(
                description,
                style: AppTypography.recipeDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.md),
              // Metadata Row: Time, Servings, Difficulty
              Row(
                children: [
                  _MetadataItem(
                    icon: Icons.access_time,
                    text: time,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _MetadataItem(
                    icon: Icons.person_outline,
                    text: '$servings serving${servings > 1 ? 's' : ''}',
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AppBadge.difficulty(level: difficulty),
                ],
              ),
              // Missing Ingredients (if any)
              if (missingIngredients.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Missing ingredients:',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: missingIngredients.map((ingredient) {
                    return AppBadge.missingIngredient(name: ingredient);
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Metadata Item
/// Small icon + text combo for recipe metadata
class _MetadataItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetadataItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: AppSpacing.iconSizeSmall,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          text,
          style: AppTypography.recipeMetadata,
        ),
      ],
    );
  }
}

/// Compact Recipe Card
/// Smaller version for horizontal scrolling lists
class CompactRecipeCard extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final int matchCount;
  final int totalIngredients;
  final VoidCallback onTap;

  const CompactRecipeCard({
    super.key,
    required this.name,
    this.imageUrl,
    required this.matchCount,
    required this.totalIngredients,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
          border: Border.all(
            color: AppColors.cardBorder,
            width: AppSpacing.borderWidthThin,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image or placeholder
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.buttonSecondary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppSpacing.cardBorderRadius),
                  topRight: Radius.circular(AppSpacing.cardBorderRadius),
                ),
              ),
              child: Stack(
                children: [
                  if (imageUrl != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppSpacing.cardBorderRadius),
                        topRight: Radius.circular(AppSpacing.cardBorderRadius),
                      ),
                      child: Image.network(
                        imageUrl!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.local_bar,
                              size: 48,
                              color: AppColors.textTertiary,
                            ),
                          );
                        },
                      ),
                    )
                  else
                    const Center(
                      child: Icon(
                        Icons.local_bar,
                        size: 48,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  // Match badge overlay
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: MatchScoreBadge(
                      matchCount: matchCount,
                      totalCount: totalIngredients,
                    ),
                  ),
                ],
              ),
            ),
            // Name
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                name,
                style: AppTypography.cardTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
