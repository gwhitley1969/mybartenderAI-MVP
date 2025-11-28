import 'package:flutter/material.dart';

import '../../../theme/theme.dart';
import '../models/academy_models.dart';
import 'difficulty_badge.dart';

/// A card widget for displaying a lesson in the category lesson list.
///
/// Shows:
/// - YouTube thumbnail on the left
/// - Title, duration, and difficulty badge on the right
class LessonCard extends StatelessWidget {
  final AcademyLesson lesson;
  final VoidCallback onTap;

  const LessonCard({
    required this.lesson,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.md),
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
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(AppSpacing.cardBorderRadius),
              ),
              child: Stack(
                children: [
                  Image.network(
                    lesson.thumbnailUrl,
                    width: 120,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _buildPlaceholder();
                    },
                  ),
                  // Play icon overlay
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.overlay,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: AppColors.textPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lesson.title,
                      style: AppTypography.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        SizedBox(width: AppSpacing.xs),
                        Text(
                          lesson.duration,
                          style: AppTypography.caption,
                        ),
                        SizedBox(width: AppSpacing.md),
                        DifficultyBadge(difficulty: lesson.difficulty),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Chevron
            Padding(
              padding: EdgeInsets.only(right: AppSpacing.md),
              child: Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 120,
      height: 90,
      color: AppColors.backgroundSecondary,
      child: Icon(
        Icons.play_circle_outline,
        color: AppColors.textSecondary,
        size: 32,
      ),
    );
  }
}
