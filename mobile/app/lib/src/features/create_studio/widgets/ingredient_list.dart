import 'package:flutter/material.dart';

import '../../../theme/theme.dart';
import '../edit_cocktail_screen.dart';

class IngredientList extends StatelessWidget {
  const IngredientList({
    super.key,
    required this.ingredients,
    required this.onIngredientsChanged,
  });

  final List<IngredientInput> ingredients;
  final ValueChanged<List<IngredientInput>> onIngredientsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ingredient list
        ...ingredients.asMap().entries.map((entry) {
          final index = entry.key;
          final ingredient = entry.value;
          return _buildIngredientRow(context, index, ingredient);
        }).toList(),

        SizedBox(height: AppSpacing.md),

        // Add ingredient button
        OutlinedButton.icon(
          onPressed: () => _addIngredient(),
          icon: Icon(Icons.add, color: AppColors.primaryPurple),
          label: Text(
            'Add Ingredient',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.primaryPurple,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.primaryPurple),
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientRow(
      BuildContext context, int index, IngredientInput ingredient) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ingredient name field (3/5 width)
          Expanded(
            flex: 3,
            child: TextFormField(
              initialValue: ingredient.name,
              style: AppTypography.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Ingredient',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                  borderSide: BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                  borderSide: BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                  borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              onChanged: (value) => _updateIngredientName(index, value),
            ),
          ),
          SizedBox(width: AppSpacing.sm),

          // Measure field (2/5 width)
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: ingredient.measure,
              style: AppTypography.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Amount',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                  borderSide: BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                  borderSide: BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                  borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              onChanged: (value) => _updateIngredientMeasure(index, value),
            ),
          ),
          SizedBox(width: AppSpacing.sm),

          // Delete button
          IconButton(
            onPressed: ingredients.length > 1 ? () => _removeIngredient(index) : null,
            icon: Icon(
              Icons.remove_circle_outline,
              color: ingredients.length > 1
                  ? AppColors.error
                  : AppColors.textSecondary.withOpacity(0.3),
            ),
            tooltip: 'Remove ingredient',
          ),
        ],
      ),
    );
  }

  void _addIngredient() {
    final updatedIngredients = List<IngredientInput>.from(ingredients)
      ..add(IngredientInput(name: '', measure: ''));
    onIngredientsChanged(updatedIngredients);
  }

  void _removeIngredient(int index) {
    if (ingredients.length > 1) {
      final updatedIngredients = List<IngredientInput>.from(ingredients)
        ..removeAt(index);
      onIngredientsChanged(updatedIngredients);
    }
  }

  void _updateIngredientName(int index, String name) {
    final updatedIngredients = List<IngredientInput>.from(ingredients);
    updatedIngredients[index].name = name;
    onIngredientsChanged(updatedIngredients);
  }

  void _updateIngredientMeasure(int index, String measure) {
    final updatedIngredients = List<IngredientInput>.from(ingredients);
    updatedIngredients[index].measure = measure;
    onIngredientsChanged(updatedIngredients);
  }
}
