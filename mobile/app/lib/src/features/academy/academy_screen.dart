import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme.dart';
import 'academy_category_screen.dart';
import 'data/academy_repository.dart';
import 'models/academy_models.dart';

/// Main Academy screen showing a grid of lesson categories.
///
/// Users can tap a category to see its lessons.
class AcademyScreen extends StatefulWidget {
  const AcademyScreen({super.key});

  @override
  State<AcademyScreen> createState() => _AcademyScreenState();
}

class _AcademyScreenState extends State<AcademyScreen> {
  late Future<List<AcademyCategory>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = AcademyRepository.getCategories();
  }

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
          'Academy',
          style: AppTypography.appTitle,
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<AcademyCategory>>(
          future: _categoriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoading();
            }

            if (snapshot.hasError) {
              return _buildError(snapshot.error.toString());
            }

            final categories = snapshot.data ?? [];
            if (categories.isEmpty) {
              return _buildEmpty();
            }

            return _buildCategoryGrid(categories);
          },
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.iconCirclePink,
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'Loading lessons...',
            style: AppTypography.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Failed to load academy content',
              style: AppTypography.heading4,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  AcademyRepository.clearCache();
                  _categoriesFuture = AcademyRepository.getCategories();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.iconCirclePink,
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'No lessons available',
            style: AppTypography.heading4,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Check back later for new content',
            style: AppTypography.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(List<AcademyCategory> categories) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header text
          Text(
            'Professional Techniques',
            style: AppTypography.heading3,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Master bartending skills with curated video lessons',
            style: AppTypography.bodyMedium,
          ),
          SizedBox(height: AppSpacing.xl),
          // Category grid
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.gridSpacing,
              mainAxisSpacing: AppSpacing.gridSpacing,
              childAspectRatio: 0.70,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return _buildCategoryCard(category);
            },
          ),
          SizedBox(height: AppSpacing.xl),
          // AI Concierge prompt card
          _buildConciergeCTA(),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(AcademyCategory category) {
    final iconColor = _getCategoryColor(category.id);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AcademyCategoryScreen(category: category),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.cardLargeBorderRadius),
          border: Border.all(
            color: AppColors.cardBorder,
            width: AppSpacing.borderWidthThin,
          ),
        ),
        padding: EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon circle
            Container(
              width: AppSpacing.iconCircleLarge,
              height: AppSpacing.iconCircleLarge,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIconData(category.iconName),
                color: AppColors.textPrimary,
                size: AppSpacing.iconSizeLarge,
              ),
            ),
            SizedBox(height: AppSpacing.md),
            // Title
            Text(
              category.title,
              style: AppTypography.cardTitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: AppSpacing.xs),
            // Lesson count badge
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppSpacing.badgeBorderRadius),
              ),
              child: Text(
                '${category.lessonCount} lessons',
                style: AppTypography.caption.copyWith(
                  color: iconColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            // Description
            Text(
              category.description,
              style: AppTypography.cardSubtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Build the AI Concierge call-to-action card.
  Widget _buildConciergeCTA() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppSpacing.borderWidthThin,
        ),
      ),
      child: Column(
        children: [
          // Icon
          Icon(
            Icons.chat_bubble_outline,
            size: 32,
            color: AppColors.iconCircleBlue,
          ),
          SizedBox(height: AppSpacing.sm),
          // Text
          Text(
            'Have questions? Your AI Concierge\nis here to help',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.lg),
          // Buttons row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/ask-bartender'),
                  icon: Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text('Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.iconCircleBlue,
                    foregroundColor: AppColors.textPrimary,
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.cardBorderRadius),
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/voice-ai'),
                  icon: Icon(Icons.mic, size: 18),
                  label: Text('Voice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.iconCircleTeal,
                    foregroundColor: AppColors.textPrimary,
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.cardBorderRadius),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Get a unique color for each category.
  Color _getCategoryColor(String categoryId) {
    switch (categoryId) {
      case 'fundamentals':
        return AppColors.iconCircleBlue;
      case 'shaking-stirring':
        return AppColors.iconCircleTeal;
      case 'garnishes':
        return AppColors.iconCircleOrange;
      case 'advanced-techniques':
        return AppColors.iconCirclePink;
      default:
        return AppColors.iconCirclePurple;
    }
  }

  /// Map icon name strings to IconData.
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
