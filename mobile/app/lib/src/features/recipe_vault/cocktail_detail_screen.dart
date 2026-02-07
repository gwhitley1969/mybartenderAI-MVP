import 'dart:io' show File, Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/models.dart';
import '../../providers/cocktail_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/providers.dart';
import '../../providers/settings_provider.dart';
import '../../services/cocktail_photo_service.dart';
import '../../services/measurement_service.dart';
import '../../theme/theme.dart';
import '../../widgets/cached_cocktail_image.dart';

class CocktailDetailScreen extends ConsumerStatefulWidget {
  final String cocktailId;

  const CocktailDetailScreen({
    super.key,
    required this.cocktailId,
  });

  @override
  ConsumerState<CocktailDetailScreen> createState() =>
      _CocktailDetailScreenState();
}

class _CocktailDetailScreenState extends ConsumerState<CocktailDetailScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final cocktailAsync = ref.watch(cocktailByIdProvider(widget.cocktailId));

    return cocktailAsync.when(
      data: (cocktail) {
        if (cocktail == null) {
          return Scaffold(
            backgroundColor: AppColors.backgroundPrimary,
            appBar: AppBar(
              backgroundColor: AppColors.backgroundPrimary,
              elevation: 0,
            ),
            body: Center(
              child: Text(
                'Cocktail not found',
                style: AppTypography.heading2,
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          body: CustomScrollView(
            slivers: [
              // App bar with image
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: AppColors.backgroundPrimary,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.primaryPurple),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  // Share button - wrapped in Builder for iOS sharePositionOrigin
                  Builder(
                    builder: (shareContext) => IconButton(
                      icon: Icon(Icons.share, color: AppColors.primaryPurple),
                      onPressed: () => _shareRecipe(shareContext, cocktail),
                    ),
                  ),
                  // Favorite button
                  Consumer(
                    builder: (context, ref, child) {
                      final isFavoriteAsync =
                          ref.watch(isFavoriteProvider(widget.cocktailId));

                      return isFavoriteAsync.when(
                        data: (isFavorite) {
                          return IconButton(
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorite
                                  ? AppColors.accentRed
                                  : AppColors.primaryPurple,
                            ),
                            onPressed: () async {
                              final notifier =
                                  ref.read(favoritesNotifierProvider.notifier);
                              await notifier.toggleFavorite(widget.cocktailId);

                              // Show feedback
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isFavorite
                                          ? 'Removed from favorites'
                                          : 'Added to favorites',
                                    ),
                                    backgroundColor: AppColors.cardBackground,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          );
                        },
                        loading: () => IconButton(
                          icon: Icon(Icons.favorite_border,
                              color: AppColors.primaryPurple),
                          onPressed: null,
                        ),
                        error: (_, __) => IconButton(
                          icon: Icon(Icons.favorite_border,
                              color: AppColors.primaryPurple),
                          onPressed: null,
                        ),
                      );
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildHeroImage(cocktail),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and metadata
                      Text(
                        cocktail.name,
                        style: AppTypography.heading1,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      _buildMetadataRow(cocktail),
                      SizedBox(height: AppSpacing.xl),

                      // Ingredients section
                      _buildSectionHeader('Ingredients'),
                      SizedBox(height: AppSpacing.md),
                      _buildIngredientsCard(
                          context, ref, cocktail.ingredients),
                      SizedBox(height: AppSpacing.xl),

                      // Instructions section
                      if (cocktail.instructions != null) ...[
                        _buildSectionHeader('Instructions'),
                        SizedBox(height: AppSpacing.md),
                        _buildInstructionsCard(cocktail.instructions!),
                        SizedBox(height: AppSpacing.xl),
                      ],

                      // Additional info
                      _buildAdditionalInfo(cocktail),
                      SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundPrimary,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundPrimary,
          elevation: 0,
        ),
        body: Center(
          child: Text(
            'Error loading cocktail',
            style: AppTypography.bodyMedium,
          ),
        ),
      ),
    );
  }

  // ── Hero image with tap-to-add for custom cocktails ─────────

  Widget _buildHeroImage(Cocktail cocktail) {
    final bool isLocalPhoto = cocktail.imageUrl != null &&
        (cocktail.imageUrl!.startsWith('/') ||
            cocktail.imageUrl!.startsWith('file://'));
    final bool hasImage =
        cocktail.imageUrl != null && cocktail.imageUrl!.isNotEmpty;

    // For non-custom cocktails, use the standard image widget
    if (!cocktail.isCustom) {
      return CachedCocktailImage(
        imageUrl: cocktail.imageUrl,
        fit: BoxFit.cover,
      );
    }

    // Custom cocktail — show photo or tappable placeholder
    if (hasImage) {
      // Has a photo — show it with a small change-photo button
      return Stack(
        fit: StackFit.expand,
        children: [
          if (isLocalPhoto)
            Image.file(
              File(cocktail.imageUrl!.startsWith('file://')
                  ? cocktail.imageUrl!.substring(7)
                  : cocktail.imageUrl!),
              fit: BoxFit.cover,
            )
          else
            CachedCocktailImage(
              imageUrl: cocktail.imageUrl,
              fit: BoxFit.cover,
            ),
          // Change-photo overlay button
          Positioned(
            bottom: 12,
            right: 12,
            child: GestureDetector(
              onTap: () => _showPhotoSourcePicker(cocktail),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt, color: Colors.white, size: 18),
                    SizedBox(width: 4),
                    Text(
                      'Change',
                      style: AppTypography.caption.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // No photo — show tappable placeholder
    return GestureDetector(
      onTap: () => _showPhotoSourcePicker(cocktail),
      child: Container(
        color: AppColors.cardBackground,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 56,
              color: AppColors.primaryPurple.withOpacity(0.5),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Tap to add photo',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.primaryPurple.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoSourcePicker(Cocktail cocktail) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppColors.primaryPurple),
              title: Text('Take Photo', style: AppTypography.bodyMedium),
              onTap: () {
                Navigator.pop(ctx);
                _capturePhoto(ImageSource.camera, cocktail);
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.photo_library, color: AppColors.primaryPurple),
              title:
                  Text('Choose from Gallery', style: AppTypography.bodyMedium),
              onTap: () {
                Navigator.pop(ctx);
                _capturePhoto(ImageSource.gallery, cocktail);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capturePhoto(ImageSource source, Cocktail cocktail) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final photoPath =
          await CocktailPhotoService.instance.savePhoto(cocktail.id, bytes);

      // Update the cocktail in SQLite with the new photo path
      final db = ref.read(databaseServiceProvider);
      final updated = cocktail.copyWith(imageUrl: photoPath);
      await db.updateCustomCocktail(updated);

      // Invalidate providers to refresh both detail and list views
      ref.invalidate(cocktailByIdProvider(widget.cocktailId));
      ref.invalidate(customCocktailsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo saved!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ── Existing widgets ────────────────────────────────────────

  Widget _buildMetadataRow(Cocktail cocktail) {
    final items = <Widget>[];

    if (cocktail.category != null) {
      items.add(_buildBadge(cocktail.category!, AppColors.iconCircleOrange));
    }

    if (cocktail.alcoholic != null) {
      items.add(_buildBadge(
        cocktail.alcoholic!,
        cocktail.alcoholic == 'Alcoholic'
            ? AppColors.iconCirclePink
            : AppColors.iconCircleTeal,
      ));
    }

    if (cocktail.glass != null) {
      items.add(_buildBadge(cocktail.glass!, AppColors.iconCircleBlue));
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: items,
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppSpacing.badgeBorderRadius),
        border: Border.all(
          color: color,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(color: color),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTypography.heading2,
    );
  }

  Widget _buildIngredientsCard(
    BuildContext context,
    WidgetRef ref,
    List<DrinkIngredient> ingredients,
  ) {
    // Get measurement unit preference
    final measurementUnitAsync = ref.watch(measurementUnitProvider);
    final measurementUnit = measurementUnitAsync.valueOrNull ?? 'imperial';

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
        children: ingredients.map((ingredient) {
          // Parse and format the measurement
          final formattedMeasure =
              _formatMeasure(ingredient.measure, measurementUnit);

          final isInInventoryAsync =
              ref.watch(isInInventoryProvider(ingredient.ingredientName));

          return isInInventoryAsync.when(
            data: (isInInventory) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isInInventory
                            ? AppColors.iconCircleTeal
                            : AppColors.primaryPurple,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        ingredient.ingredientName,
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                    if (formattedMeasure.isNotEmpty) ...[
                      Text(
                        formattedMeasure,
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      SizedBox(width: AppSpacing.sm),
                    ],
                    // Quick-add button
                    if (isInInventory)
                      Icon(
                        Icons.check_circle,
                        color: AppColors.iconCircleTeal,
                        size: 20,
                      )
                    else
                      IconButton(
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: AppColors.primaryPurple,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        onPressed: () async {
                          final notifier =
                              ref.read(inventoryNotifierProvider.notifier);
                          await notifier.addIngredient(
                            ingredient.ingredientName,
                          );

                          // Refresh inventory providers
                          ref.invalidate(inventoryProvider);
                          ref.invalidate(isInInventoryProvider);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Added ${ingredient.ingredientName} to your bar'),
                                backgroundColor: AppColors.cardBackground,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                  ],
                ),
              );
            },
            loading: () => Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      ingredient.ingredientName,
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                  if (formattedMeasure.isNotEmpty)
                    Text(
                      formattedMeasure,
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            error: (_, __) => Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      ingredient.ingredientName,
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                  if (formattedMeasure.isNotEmpty)
                    Text(
                      formattedMeasure,
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Format a measure string based on user's measurement unit preference
  String _formatMeasure(String? measure, String preference) {
    if (measure == null || measure.isEmpty) return '';

    // Parse the measure string
    final parsed = MeasurementService.instance.parse(measure);

    // Format based on user preference
    return MeasurementService.instance.format(
      amountMl: parsed.amountMl,
      unitOriginal: parsed.unitOriginal,
      preference: preference,
      originalText: parsed.originalText,
    );
  }

  Widget _buildInstructionsCard(String instructions) {
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
      child: Text(
        instructions,
        style: AppTypography.bodyMedium,
      ),
    );
  }

  Widget _buildAdditionalInfo(Cocktail cocktail) {
    final items = <Widget>[];

    if (cocktail.iba != null) {
      items.add(_buildInfoRow('IBA Category', cocktail.iba!));
    }

    if (cocktail.tags.isNotEmpty) {
      items.add(_buildInfoRow('Tags', cocktail.tags.join(', ')));
    }

    if (cocktail.alternateName != null) {
      items.add(_buildInfoRow('Also known as', cocktail.alternateName!));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppSpacing.borderWidthThin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption,
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.bodyMedium,
          ),
        ],
      ),
    );
  }

  // ── Share ────────────────────────────────────────────────────

  /// Share the cocktail recipe using native OS share sheet.
  /// For custom cocktails with a local photo, shares the image as a file.
  Future<void> _shareRecipe(BuildContext context, Cocktail cocktail) async {
    // Build share text
    String description = '';
    if (cocktail.instructions != null && cocktail.instructions!.isNotEmpty) {
      description = cocktail.instructions!.length > 100
          ? '${cocktail.instructions!.substring(0, 100)}...'
          : cocktail.instructions!;
    } else if (cocktail.category != null) {
      description =
          'A delicious ${cocktail.category?.toLowerCase()} cocktail you have to try.';
    } else {
      description = 'A delicious cocktail you have to try.';
    }

    final subject = '${cocktail.name} - My AI Bartender Recipe';

    // For custom cocktails, skip the share URL (they aren't on the server)
    final shareUrl = cocktail.isCustom
        ? ''
        : '\nhttps://share.mybartenderai.com/api/cocktail/${cocktail.id}';

    final shareText = '''
${cocktail.name}

Check out this amazing cocktail recipe I found on My AI Bartender!

$description$shareUrl
''';

    try {
      // Calculate share position origin for iOS
      Rect? sharePositionOrigin;
      if (Platform.isIOS) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final position = renderBox.localToGlobal(Offset.zero);
          sharePositionOrigin = position & renderBox.size;
        }
      }

      // Determine if we have a local photo to share as a file
      final bool hasLocalPhoto = cocktail.isCustom &&
          cocktail.imageUrl != null &&
          (cocktail.imageUrl!.startsWith('/') ||
              cocktail.imageUrl!.startsWith('file://'));

      ShareResult result;
      if (hasLocalPhoto) {
        final photoPath = cocktail.imageUrl!.startsWith('file://')
            ? cocktail.imageUrl!.substring(7)
            : cocktail.imageUrl!;
        final file = File(photoPath);
        if (await file.exists()) {
          result = await Share.shareXFiles(
            [XFile(photoPath)],
            text: shareText.trim(),
            subject: subject,
            sharePositionOrigin: sharePositionOrigin,
          );
        } else {
          debugPrint('[SHARE] Local photo file not found: $photoPath');
          result = await Share.shareWithResult(
            shareText.trim(),
            subject: subject,
            sharePositionOrigin: sharePositionOrigin,
          );
        }
      } else {
        result = await Share.shareWithResult(
          shareText.trim(),
          subject: subject,
          sharePositionOrigin: sharePositionOrigin,
        );
      }

      // Show success feedback if shared successfully
      if (result.status == ShareResultStatus.success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Recipe shared successfully!'),
              backgroundColor: AppColors.cardBackground,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      // Log the actual error for debugging
      debugPrint('[SHARE] Share failed: $e');
      debugPrint('[SHARE] Stack trace: $stackTrace');

      // Handle share errors gracefully
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to share recipe. Please try again.'),
            backgroundColor: AppColors.accentRed.withOpacity(0.9),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
