import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/cocktail_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../theme/theme.dart';

class AddIngredientScreen extends ConsumerStatefulWidget {
  const AddIngredientScreen({super.key});

  @override
  ConsumerState<AddIngredientScreen> createState() =>
      _AddIngredientScreenState();
}

class _AddIngredientScreenState extends ConsumerState<AddIngredientScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allIngredientsAsync = ref.watch(allIngredientsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Add Ingredient', style: AppTypography.heading2),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
              child: TextField(
                controller: _searchController,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search ingredients...',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                    borderSide: BorderSide(
                      color: AppColors.cardBorder,
                      width: AppSpacing.borderWidthThin,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                    borderSide: BorderSide(
                      color: AppColors.cardBorder,
                      width: AppSpacing.borderWidthThin,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                    borderSide: BorderSide(
                      color: AppColors.primaryPurple,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),

            // Ingredients List
            Expanded(
              child: allIngredientsAsync.when(
                data: (ingredients) {
                  final filteredIngredients = _searchQuery.isEmpty
                      ? ingredients
                      : ingredients
                          .where((ing) =>
                              ing.toLowerCase().contains(_searchQuery))
                          .toList();

                  if (filteredIngredients.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPaddingHorizontal,
                    ),
                    itemCount: filteredIngredients.length,
                    itemBuilder: (context, index) {
                      final ingredient = filteredIngredients[index];
                      return _buildIngredientItem(ingredient);
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
                        'Error loading ingredients',
                        style: AppTypography.bodyMedium,
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'No ingredients found',
              style: AppTypography.heading3,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Try a different search term',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientItem(String ingredient) {
    final isInInventoryAsync = ref.watch(
      isInInventoryProvider(ingredient),
    );

    return isInInventoryAsync.when(
      data: (isInInventory) {
        return Container(
          margin: EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: isInInventory
                ? AppColors.backgroundSecondary
                : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
            border: Border.all(
              color: isInInventory
                  ? AppColors.iconCircleTeal.withOpacity(0.5)
                  : AppColors.cardBorder,
              width: AppSpacing.borderWidthThin,
            ),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isInInventory
                    ? AppColors.iconCircleTeal.withOpacity(0.3)
                    : AppColors.iconCircleTeal,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isInInventory ? Icons.check : Icons.liquor,
                color: AppColors.textPrimary,
                size: 18,
              ),
            ),
            title: Text(
              ingredient,
              style: AppTypography.cardTitle.copyWith(
                color: isInInventory
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
            trailing: isInInventory
                ? Text(
                    'In Bar',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.iconCircleTeal,
                    ),
                  )
                : Icon(
                    Icons.add_circle_outline,
                    color: AppColors.primaryPurple,
                  ),
            onTap: isInInventory
                ? null
                : () => _showAddConfirmation(ingredient),
          ),
        );
      },
      loading: () => Container(
        margin: EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        ),
        child: ListTile(
          leading: SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textSecondary,
            ),
          ),
          title: Text(ingredient, style: AppTypography.cardTitle),
        ),
      ),
      error: (_, __) => Container(
        margin: EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        ),
        child: ListTile(
          leading: Icon(Icons.error_outline, color: Colors.red),
          title: Text(ingredient, style: AppTypography.cardTitle),
        ),
      ),
    );
  }

  void _showAddConfirmation(String ingredient) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Add to Bar?',
          style: AppTypography.heading3,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add "$ingredient" to your bar?',
              style: AppTypography.bodyMedium,
            ),
            SizedBox(height: AppSpacing.md),
            TextField(
              controller: _notesController,
              style: AppTypography.bodyMedium,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Add notes (optional)',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.backgroundSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                  borderSide: BorderSide(
                    color: AppColors.cardBorder,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                  borderSide: BorderSide(
                    color: AppColors.cardBorder,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                  borderSide: BorderSide(
                    color: AppColors.primaryPurple,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _notesController.clear();
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              final notes = _notesController.text.trim();
              _notesController.clear();
              Navigator.pop(context);

              final notifier = ref.read(inventoryNotifierProvider.notifier);
              await notifier.addIngredient(
                ingredient,
                notes: notes.isEmpty ? null : notes,
              );

              // Refresh providers
              ref.invalidate(inventoryProvider);
              ref.invalidate(isInInventoryProvider);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added $ingredient to your bar'),
                    backgroundColor: AppColors.cardBackground,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(
              'Add',
              style: TextStyle(color: AppColors.primaryPurple),
            ),
          ),
        ],
      ),
    );
  }
}
