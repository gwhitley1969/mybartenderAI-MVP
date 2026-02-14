import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/custom_cocktails_provider.dart';
import '../../providers/providers.dart';
import '../../services/cocktail_photo_service.dart';
import '../../services/user_settings_service.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../recipe_vault/cocktail_detail_screen.dart';
import 'edit_cocktail_screen.dart';
import 'widgets/share_recipe_dialog.dart';

class CreateStudioScreen extends ConsumerWidget {
  const CreateStudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customCocktailsAsync = ref.watch(customCocktailsProvider);
    final countAsync = ref.watch(customCocktailsCountProvider);

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
          'Create Studio',
          style: AppTypography.appTitle,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: AppColors.textSecondary),
            tooltip: 'Help',
            onPressed: () {
              _showHelp(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics & Info section
          Padding(
            padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
            child: Column(
              children: [
                countAsync.when(
                  data: (count) => _buildStatistics(count),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                SizedBox(height: AppSpacing.md),
                _buildInfoBanner(),
              ],
            ),
          ),

          // Custom cocktails grid
          Expanded(
            child: customCocktailsAsync.when(
              data: (cocktails) =>
                  _buildCocktailsGrid(context, ref, cocktails),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: AppColors.textSecondary),
                      SizedBox(height: AppSpacing.md),
                      Text(
                        'Error loading cocktails',
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCreate(context, ref),
        backgroundColor: AppColors.primaryPurple,
        icon: const Icon(Icons.add),
        label: const Text('Create Cocktail'),
      ),
    );
  }

  Widget _buildStatistics(int count) {
    return Container(
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_fix_high,
              color: AppColors.iconCirclePurple, size: 24),
          SizedBox(width: AppSpacing.md),
          Column(
            children: [
              Text('$count', style: AppTypography.heading2),
              SizedBox(height: AppSpacing.xs),
              Text('Custom Creations', style: AppTypography.caption),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        border: Border.all(
          color: AppColors.primaryPurple.withOpacity(0.3),
          width: AppSpacing.borderWidthThin,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline,
              color: AppColors.primaryPurple, size: 20),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Your personal recipe book \u2014 build and save your own cocktails',
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCocktailsGrid(
      BuildContext context, WidgetRef ref, List<Cocktail> cocktails) {
    if (cocktails.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.cardBorder,
                    width: 2,
                  ),
                ),
                child: Icon(Icons.auto_fix_high,
                    size: 56, color: AppColors.iconCirclePurple),
              ),
              SizedBox(height: AppSpacing.xl),
              Text(
                'No custom cocktails yet',
                style: AppTypography.heading3,
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                'Tap the Create Cocktail button below\nto craft your first signature drink!',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.gridSpacing,
        mainAxisSpacing: AppSpacing.gridSpacing,
        childAspectRatio: 0.75,
      ),
      itemCount: cocktails.length,
      itemBuilder: (context, index) {
        final cocktail = cocktails[index];
        return _buildCocktailCard(context, ref, cocktail);
      },
    );
  }

  Widget _buildCocktailCard(
      BuildContext context, WidgetRef ref, Cocktail cocktail) {
    return GestureDetector(
      onTap: () => _navigateToCocktailDetail(context, cocktail),
      onLongPress: () => _showCocktailOptions(context, ref, cocktail),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
          border: Border.all(
            color: AppColors.primaryPurple.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppSpacing.cardBorderRadius),
                      topRight: Radius.circular(AppSpacing.cardBorderRadius),
                    ),
                    child: cocktail.imageUrl != null
                        ? CachedCocktailImage(
                            imageUrl: cocktail.imageUrl!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: double.infinity,
                            height: double.infinity,
                            clipBehavior: Clip.antiAlias,
                            decoration: const BoxDecoration(),
                            child: Image.asset(
                              'assets/icon/icon.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                  // Custom badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_fix_high,
                              size: 12, color: AppColors.textPrimary),
                          SizedBox(width: 4),
                          Text(
                            'Custom',
                            style: AppTypography.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cocktail.name,
                      style: AppTypography.cardTitle.copyWith(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: AppSpacing.xs),
                    if (cocktail.category != null)
                      Text(
                        cocktail.category!,
                        style: AppTypography.caption.copyWith(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Spacer(),
                    Row(
                      children: [
                        Icon(Icons.edit,
                            size: 14, color: AppColors.textSecondary),
                        SizedBox(width: 4),
                        Text('Tap to edit',
                            style: AppTypography.caption.copyWith(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCreate(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditCocktailScreen(),
      ),
    ).then((result) {
      // Refresh the list after creating
      ref.invalidate(customCocktailsProvider);
      ref.invalidate(customCocktailsCountProvider);
      if (result is String && context.mounted) {
        _maybeShowSharePrompt(context, ref, result);
      }
    });
  }

  void _navigateToCocktailDetail(BuildContext context, Cocktail cocktail) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CocktailDetailScreen(cocktailId: cocktail.id),
      ),
    );
  }

  void _showCocktailOptions(
      BuildContext context, WidgetRef ref, Cocktail cocktail) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    Icon(Icons.edit, color: AppColors.iconCirclePurple),
                title: Text('Edit Cocktail', style: AppTypography.bodyMedium),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToEdit(context, ref, cocktail);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: AppColors.error),
                title: Text('Delete Cocktail', style: AppTypography.bodyMedium),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, ref, cocktail);
                },
              ),
              SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  void _navigateToEdit(
      BuildContext context, WidgetRef ref, Cocktail cocktail) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditCocktailScreen(cocktail: cocktail),
      ),
    ).then((result) {
      // Refresh the list after editing
      ref.invalidate(customCocktailsProvider);
      if (result is String && context.mounted) {
        _maybeShowSharePrompt(context, ref, result);
      }
    });
  }

  Future<void> _maybeShowSharePrompt(
      BuildContext context, WidgetRef ref, String cocktailId) async {
    final dismissed =
        await UserSettingsService.instance.isSharePromptDismissed();
    if (dismissed) return;

    // Fetch the just-saved cocktail by ID
    final cocktail = await ref.read(cocktailByIdProvider(cocktailId).future);
    if (cocktail == null) return;

    if (context.mounted) {
      ShareRecipeDialog.show(context, cocktail: cocktail);
    }
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, Cocktail cocktail) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundSecondary,
          title: Text('Delete Cocktail?', style: AppTypography.heading3),
          content: Text(
            'Are you sure you want to delete "${cocktail.name}"? This action cannot be undone.',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteCocktail(context, ref, cocktail);
              },
              child: Text('Delete',
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.error)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCocktail(
      BuildContext context, WidgetRef ref, Cocktail cocktail) async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.deleteCustomCocktail(cocktail.id);

      // Clean up local photo file if it exists
      await CocktailPhotoService.instance.deletePhoto(cocktail.id);

      // Refresh providers
      ref.invalidate(customCocktailsProvider);
      ref.invalidate(customCocktailsCountProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${cocktail.name} deleted'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting cocktail: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundSecondary,
          title: Row(
            children: [
              Icon(Icons.help_outline, color: AppColors.iconCirclePurple),
              SizedBox(width: AppSpacing.sm),
              Text('Create Studio Help', style: AppTypography.heading3),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Create your own signature cocktails with AI assistance!',
                  style: AppTypography.bodyMedium,
                ),
                SizedBox(height: AppSpacing.md),
                _helpItem(
                  Icons.add,
                  'Create',
                  'Tap the Create Cocktail button to start a new recipe',
                ),
                _helpItem(
                  Icons.auto_awesome,
                  'AI Refinement',
                  'Get professional suggestions to improve your recipe',
                ),
                _helpItem(
                  Icons.edit,
                  'Edit',
                  'Tap any cocktail to view details, long-press to edit or delete',
                ),
                _helpItem(
                  Icons.save,
                  'Save',
                  'Your custom cocktails are saved locally on your device',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Got it!', style: AppTypography.bodyMedium),
            ),
          ],
        );
      },
    );
  }

  Widget _helpItem(IconData icon, String title, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryPurple),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
