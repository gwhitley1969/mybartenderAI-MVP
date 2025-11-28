import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'academy_lesson_screen.dart';
import 'models/academy_models.dart';
import 'widgets/lesson_card.dart';

/// Screen showing all lessons within a specific category.
///
/// Displays a header with the category info and a scrollable list of lessons.
class AcademyCategoryScreen extends StatelessWidget {
  final AcademyCategory category;

  const AcademyCategoryScreen({
    required this.category,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
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
          category.title,
          style: AppTypography.appTitle,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
          children: [
            // Category header
            _buildHeader(),
            SizedBox(height: AppSpacing.xl),
            // Lessons list
            ...category.lessons.map(
              (lesson) => LessonCard(
                lesson: lesson,
                onTap: () => _navigateToLesson(context, lesson),
              ),
            ),
            // Bottom padding for better scroll experience
            SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
          Row(
            children: [
              // Category icon
              Container(
                width: AppSpacing.iconCircleMedium,
                height: AppSpacing.iconCircleMedium,
                decoration: BoxDecoration(
                  color: AppColors.iconCirclePink,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconData(category.iconName),
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
                      category.title,
                      style: AppTypography.heading4,
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      '${category.lessonCount} lessons',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.iconCirclePink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            category.description,
            style: AppTypography.bodyMedium,
          ),
        ],
      ),
    );
  }

  void _navigateToLesson(BuildContext context, AcademyLesson lesson) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AcademyLessonScreen(lesson: lesson),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'school':
        return Icons.school;
      case 'sports_bar':
        return Icons.sports_bar;
      case 'eco':
        return Icons.eco;
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'local_bar':
        return Icons.local_bar;
      case 'restaurant':
        return Icons.restaurant;
      default:
        return Icons.school;
    }
  }
}
