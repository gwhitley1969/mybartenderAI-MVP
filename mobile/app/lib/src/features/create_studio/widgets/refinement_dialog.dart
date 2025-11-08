import 'package:flutter/material.dart';

import '../../../api/create_studio_api.dart';
import '../../../theme/theme.dart';

Future<void> showRefinementDialog({
  required BuildContext context,
  required RefinementResponse refinement,
  required Function(RefinedRecipe) onApply,
  Function(RefinedRecipe)? onSaveAsNew,
  bool isEditMode = false,
}) {
  return showDialog(
    context: context,
    builder: (context) => RefinementDialog(
      refinement: refinement,
      onApply: onApply,
      onSaveAsNew: onSaveAsNew,
      isEditMode: isEditMode,
    ),
  );
}

class RefinementDialog extends StatefulWidget {
  const RefinementDialog({
    super.key,
    required this.refinement,
    required this.onApply,
    this.onSaveAsNew,
    this.isEditMode = false,
  });

  final RefinementResponse refinement;
  final Function(RefinedRecipe) onApply;
  final Function(RefinedRecipe)? onSaveAsNew;
  final bool isEditMode;

  @override
  State<RefinementDialog> createState() => _RefinementDialogState();
}

class _RefinementDialogState extends State<RefinementDialog> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final hasRefinedRecipe = widget.refinement.refinedRecipe != null;
    final highPrioritySuggestions = widget.refinement.suggestions
        .where((s) => s.isHighPriority)
        .toList();

    return Dialog(
      backgroundColor: AppColors.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardLargeBorderRadius),
      ),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppSpacing.cardLargeBorderRadius),
                  topRight: Radius.circular(AppSpacing.cardLargeBorderRadius),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.electricBlue, size: 28),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'AI Refinement',
                      style: AppTypography.heading2,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Overall assessment
                    Container(
                      padding: EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Text(
                        widget.refinement.overall,
                        style: AppTypography.bodyMedium,
                      ),
                    ),

                    // High priority suggestions (if any)
                    if (highPrioritySuggestions.isNotEmpty) ...[
                      SizedBox(height: AppSpacing.lg),
                      Text(
                        'Key Suggestions',
                        style: AppTypography.heading3.copyWith(fontSize: 16),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      ...highPrioritySuggestions.map((suggestion) {
                        return _buildSuggestionCard(suggestion, isHighlighted: true);
                      }).toList(),
                    ],

                    // All suggestions toggle
                    if (widget.refinement.suggestions.length > highPrioritySuggestions.length) ...[
                      SizedBox(height: AppSpacing.md),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showDetails = !_showDetails;
                          });
                        },
                        icon: Icon(
                          _showDetails ? Icons.expand_less : Icons.expand_more,
                          color: AppColors.textSecondary,
                        ),
                        label: Text(
                          _showDetails
                              ? 'Hide additional suggestions'
                              : 'Show all suggestions (${widget.refinement.suggestions.length - highPrioritySuggestions.length} more)',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],

                    // Additional suggestions (when expanded)
                    if (_showDetails) ...[
                      SizedBox(height: AppSpacing.sm),
                      ...widget.refinement.suggestions
                          .where((s) => !s.isHighPriority)
                          .map((suggestion) {
                        return _buildSuggestionCard(suggestion);
                      }).toList(),
                    ],

                    // Refined recipe preview (if available)
                    if (hasRefinedRecipe) ...[
                      SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                          border: Border.all(
                            color: AppColors.success.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: AppColors.success, size: 20),
                                SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Refined Recipe Ready',
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: AppSpacing.sm),
                            Text(
                              'Tap "Apply Refinements" to update your recipe with AI suggestions.',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.backgroundPrimary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(AppSpacing.cardLargeBorderRadius),
                  bottomRight: Radius.circular(AppSpacing.cardLargeBorderRadius),
                ),
              ),
              child: widget.isEditMode && hasRefinedRecipe
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Update This Recipe button
                        ElevatedButton(
                          onPressed: () {
                            widget.onApply(widget.refinement.refinedRecipe!);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                            ),
                          ),
                          child: Text(
                            'Update This Recipe',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (widget.onSaveAsNew != null) ...[
                          SizedBox(height: AppSpacing.sm),
                          // Save as New Recipe button
                          ElevatedButton(
                            onPressed: () {
                              widget.onSaveAsNew!(widget.refinement.refinedRecipe!);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                              ),
                            ),
                            child: Text(
                              'Save as New Recipe',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: AppSpacing.sm),
                        // Keep Original button
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.textSecondary),
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                            ),
                          ),
                          child: Text(
                            'Keep Original',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.textSecondary),
                              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                              ),
                            ),
                            child: Text(
                              'Keep Original',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        if (hasRefinedRecipe) ...[
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                widget.onApply(widget.refinement.refinedRecipe!);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                                ),
                              ),
                              child: Text(
                                'Apply Refinements',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(RefinementSuggestion suggestion,
      {bool isHighlighted = false}) {
    Color categoryColor;
    IconData categoryIcon;

    switch (suggestion.category.toLowerCase()) {
      case 'name':
        categoryColor = AppColors.iconCircleBlue;
        categoryIcon = Icons.title;
        break;
      case 'ingredients':
        categoryColor = AppColors.iconCircleOrange;
        categoryIcon = Icons.liquor;
        break;
      case 'instructions':
        categoryColor = AppColors.iconCircleTeal;
        categoryIcon = Icons.list_alt;
        break;
      case 'glass':
        categoryColor = AppColors.iconCirclePurple;
        categoryIcon = Icons.local_bar;
        break;
      case 'balance':
        categoryColor = AppColors.success;
        categoryIcon = Icons.balance;
        break;
      default:
        categoryColor = AppColors.textSecondary;
        categoryIcon = Icons.lightbulb_outline;
    }

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppColors.warning.withOpacity(0.1)
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        border: Border.all(
          color: isHighlighted
              ? AppColors.warning.withOpacity(0.3)
              : AppColors.cardBorder,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(categoryIcon, size: 20, color: categoryColor),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      suggestion.category.toUpperCase(),
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: categoryColor,
                        fontSize: 11,
                      ),
                    ),
                    if (isHighlighted) ...[
                      SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'HIGH',
                          style: AppTypography.caption.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.backgroundPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  suggestion.suggestion,
                  style: AppTypography.bodyMedium.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
