import 'package:flutter/material.dart';

import '../../../theme/theme.dart';

/// A badge widget displaying the difficulty level of a lesson.
///
/// Colors are assigned based on difficulty:
/// - beginner: Green (success)
/// - intermediate: Purple (primary)
/// - advanced: Orange (accent)
class DifficultyBadge extends StatelessWidget {
  final String difficulty;

  const DifficultyBadge({
    required this.difficulty,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final (color, label) = _getDifficultyStyle(difficulty);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      constraints: const BoxConstraints(
        maxWidth: 100, // Prevent badge from growing too wide
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        border: Border.all(color: color, width: 1),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
        ),
      ),
    );
  }

  (Color, String) _getDifficultyStyle(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return (AppColors.success, 'Beginner');
      case 'intermediate':
        return (AppColors.primaryPurple, 'Intermediate');
      case 'advanced':
        return (AppColors.accentOrange, 'Advanced');
      default:
        return (AppColors.textSecondary, difficulty);
    }
  }
}
