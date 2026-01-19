import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../providers/inventory_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import 'add_ingredient_screen.dart';

class MyBarScreen extends ConsumerWidget {
  const MyBarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryProvider);
    final inventoryCount = ref.watch(inventoryCountProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('My Bar', style: AppTypography.heading2),
        actions: [
          // Scanner button (pink, matching home screen)
          IconButton(
            icon: Icon(Icons.camera_alt, color: AppColors.iconCirclePink),
            onPressed: () {
              context.push('/smart-scanner').then((_) {
                // Refresh inventory after scanning
                ref.invalidate(inventoryProvider);
              });
            },
          ),
          // Add button (purple, existing)
          IconButton(
            icon: Icon(Icons.add, color: AppColors.primaryPurple),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddIngredientScreen(),
                ),
              ).then((_) {
                // Refresh inventory after adding ingredient
                ref.invalidate(inventoryProvider);
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Stats Bar
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPaddingHorizontal,
                vertical: AppSpacing.md,
              ),
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
                children: [
                  Container(
                    width: AppSpacing.iconCircleSmall,
                    height: AppSpacing.iconCircleSmall,
                    decoration: BoxDecoration(
                      color: AppColors.iconCircleTeal,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.inventory_2,
                      color: AppColors.textPrimary,
                      size: AppSpacing.iconSizeSmall,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        inventoryCount.when(
                          data: (count) => Text(
                            '$count Ingredient${count != 1 ? 's' : ''}',
                            style: AppTypography.cardTitle,
                          ),
                          loading: () => Text(
                            'Loading...',
                            style: AppTypography.cardTitle,
                          ),
                          error: (_, __) => Text(
                            '0 Ingredients',
                            style: AppTypography.cardTitle,
                          ),
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          'Track what you have in your bar',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Inventory List
            Expanded(
              child: inventoryAsync.when(
                data: (inventory) {
                  if (inventory.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPaddingHorizontal,
                      vertical: AppSpacing.md,
                    ),
                    itemCount: inventory.length,
                    itemBuilder: (context, index) {
                      final ingredient = inventory[index];
                      return _buildIngredientCard(
                        context,
                        ref,
                        ingredient,
                      );
                    },
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryPurple,
                  ),
                ),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: AppSpacing.md),
                      Text(
                        'Error loading inventory',
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
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.cardBorder,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 40,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Your bar is empty',
              style: AppTypography.heading3,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Search to add ingredients, or snap a photo\nto let AI identify your bottles',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xl),
            // Two buttons side by side: Add manually or use Smart Scanner
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  // Add Manually button
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: AppSpacing.sm),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddIngredientScreen(),
                            ),
                          );
                        },
                        icon: Icon(Icons.add, size: 18),
                        label: Text('Add'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                          foregroundColor: AppColors.textPrimary,
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Smart Scanner button
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: AppSpacing.sm),
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/smart-scanner'),
                        icon: Icon(Icons.camera_alt, size: 18),
                        label: Text('Scanner'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.iconCirclePink,
                          foregroundColor: AppColors.textPrimary,
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientCard(
    BuildContext context,
    WidgetRef ref,
    UserIngredient ingredient,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppSpacing.borderWidthThin,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.iconCircleTeal,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.liquor,
            color: AppColors.textPrimary,
            size: 20,
          ),
        ),
        title: Text(
          ingredient.ingredientName,
          style: AppTypography.cardTitle,
        ),
        subtitle: ingredient.category != null || ingredient.notes != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ingredient.category != null) ...[
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      ingredient.category!,
                      style: AppTypography.caption,
                    ),
                  ],
                  if (ingredient.notes != null) ...[
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      ingredient.notes!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              )
            : null,
        trailing: IconButton(
          icon: Icon(
            Icons.delete_outline,
            color: AppColors.textSecondary,
          ),
          onPressed: () {
            _showDeleteConfirmation(
              context,
              ref,
              ingredient.ingredientName,
            );
          },
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    String ingredientName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Remove Ingredient?',
          style: AppTypography.heading3,
        ),
        content: Text(
          'Are you sure you want to remove "$ingredientName" from your bar?',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final notifier = ref.read(inventoryNotifierProvider.notifier);
              await notifier.removeIngredient(ingredientName);

              // Refresh inventory
              ref.invalidate(inventoryProvider);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Removed $ingredientName'),
                    backgroundColor: AppColors.cardBackground,
                  ),
                );
              }
            },
            child: Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
