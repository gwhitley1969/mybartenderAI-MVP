import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/cocktail_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/user_settings_service.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import 'cocktail_detail_screen.dart';

class RecipeVaultScreen extends ConsumerStatefulWidget {
  const RecipeVaultScreen({super.key});

  @override
  ConsumerState<RecipeVaultScreen> createState() => _RecipeVaultScreenState();
}

class _RecipeVaultScreenState extends ConsumerState<RecipeVaultScreen> {
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedAlcoholic;
  bool _showCanMakeOnly = false;
  bool _showFavoritesOnly = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch snapshot statistics
    final statisticsAsync = ref.watch(snapshotStatisticsProvider);
    final snapshotSync = ref.watch(snapshotSyncProvider);

    // Build cocktail filter
    final filter = CocktailFilter(
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      category: _selectedCategory,
      alcoholic: _selectedAlcoholic,
      limit: 10000, // Increased to handle full cocktail database
    );

    // Watch cocktails - use inventory-based provider if "Can Make" is enabled
    var cocktailsAsync = _showCanMakeOnly
        ? ref.watch(cocktailsWithInventoryProvider(filter))
        : ref.watch(cocktailsProvider(filter));

    // Filter by favorites if enabled
    if (_showFavoritesOnly) {
      final favoriteCocktailIdsAsync = ref.watch(favoriteCocktailIdsProvider);

      cocktailsAsync = cocktailsAsync.whenData((cocktails) {
        return favoriteCocktailIdsAsync.maybeWhen(
          data: (favoriteIds) {
            final favoriteIdsSet = favoriteIds.toSet();
            return cocktails.where((c) => favoriteIdsSet.contains(c.id)).toList();
          },
          orElse: () => cocktails,
        );
      });
    }

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
          'Recipe Vault',
          style: AppTypography.appTitle,
        ),
        actions: [
          // Measurement unit toggle (oz/ml)
          _buildMeasurementToggle(ref),
          // Sync button
          IconButton(
            icon: Icon(
              Icons.sync,
              color: AppColors.iconCircleBlue,
            ),
            onPressed: snapshotSync.isLoading
                ? null
                : () async {
                    await ref
                        .read(snapshotSyncProvider.notifier)
                        .syncSnapshot();
                    ref.invalidate(cocktailsProvider);
                    ref.invalidate(snapshotStatisticsProvider);
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter section
          Padding(
            padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
            child: Column(
              children: [
                // Statistics
                statisticsAsync.when(
                  data: (stats) => _buildStatistics(stats),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                SizedBox(height: AppSpacing.md),

                // Search bar
                _buildSearchBar(),
                SizedBox(height: AppSpacing.md),

                // Filter chips
                _buildFilterChips(),
              ],
            ),
          ),

          // Sync progress indicator
          if (snapshotSync.isLoading)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingHorizontal),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: snapshotSync.progress > 0 ? snapshotSync.progress : null,
                    backgroundColor: AppColors.cardBackground,
                    color: AppColors.primaryPurple,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    snapshotSync.progress > 0
                        ? 'Downloading: ${(snapshotSync.progress * 100).toStringAsFixed(0)}%'
                        : 'Syncing cocktails...',
                    style: AppTypography.caption,
                  ),
                  SizedBox(height: AppSpacing.md),
                ],
              ),
            ),

          // Cocktail grid
          Expanded(
            child: cocktailsAsync.when(
              data: (cocktails) => _buildCocktailGrid(cocktails),
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
    );
  }

  String _formatVersion(String? version) {
    if (version == null || version == 'None') return 'None';

    // Format: YYYYMMDD.HHMMSS -> MM/DD
    if (version.length >= 8) {
      final dateStr = version.substring(0, 8); // YYYYMMDD
      final month = dateStr.substring(4, 6);
      final day = dateStr.substring(6, 8);
      return '$month/$day';
    }

    return version;
  }

  Widget _buildStatistics(Map<String, dynamic> stats) {
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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Cocktails', '${stats['totalCocktails'] ?? 0}'),
          _buildStatItem('Categories', '${stats['categories'] ?? 0}'),
          _buildStatItem(
              'Updated', _formatVersion(stats['snapshotVersion']?.toString())),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTypography.heading3),
        SizedBox(height: AppSpacing.xs),
        Text(label, style: AppTypography.caption),
      ],
    );
  }

  /// Build the measurement unit toggle button (oz/ml) for the app bar
  Widget _buildMeasurementToggle(WidgetRef ref) {
    final measurementUnitAsync = ref.watch(measurementUnitProvider);

    return measurementUnitAsync.when(
      data: (unit) {
        final isImperial = unit == UserSettingsService.imperial;
        return GestureDetector(
          onTap: () async {
            // Toggle the measurement unit
            final newUnit = isImperial
                ? UserSettingsService.metric
                : UserSettingsService.imperial;
            await UserSettingsService.instance.setMeasurementUnit(newUnit);
            ref.invalidate(measurementUnitProvider);
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryPurple.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isImperial ? 'oz' : 'ml',
                  style: AppTypography.buttonSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.swap_horiz,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => SizedBox(width: 48),
      error: (_, __) => SizedBox(width: 48),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: AppTypography.bodyMedium,
      decoration: InputDecoration(
        hintText: 'Search cocktails...',
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        prefixIcon: Icon(Icons.search, color: AppColors.iconCircleBlue),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, color: AppColors.textSecondary),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
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
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Can Make toggle
          FilterChip(
            label: Text(
              'Can Make',
              style: AppTypography.buttonSmall.copyWith(
                color: _showCanMakeOnly
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
            selected: _showCanMakeOnly,
            onSelected: (selected) {
              setState(() {
                _showCanMakeOnly = selected;
              });
            },
            backgroundColor: AppColors.cardBackground,
            selectedColor: AppColors.iconCircleTeal,
            checkmarkColor: AppColors.textPrimary,
            side: BorderSide(
              color: _showCanMakeOnly
                  ? AppColors.iconCircleTeal
                  : AppColors.cardBorder,
            ),
          ),
          SizedBox(width: AppSpacing.md),

          // Favorites toggle
          FilterChip(
            label: Text(
              'Favorites',
              style: AppTypography.buttonSmall.copyWith(
                color: _showFavoritesOnly
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
            selected: _showFavoritesOnly,
            onSelected: (selected) {
              setState(() {
                _showFavoritesOnly = selected;
              });
            },
            backgroundColor: AppColors.cardBackground,
            selectedColor: AppColors.accentRed,
            checkmarkColor: AppColors.textPrimary,
            side: BorderSide(
              color: _showFavoritesOnly
                  ? AppColors.accentRed
                  : AppColors.cardBorder,
            ),
          ),
          SizedBox(width: AppSpacing.md),

          // Category filter
          DropdownButton<String?>(
            value: _selectedCategory,
            hint: Text('Category', style: AppTypography.buttonSmall),
            dropdownColor: AppColors.cardBackground,
            style: AppTypography.buttonSmall,
            underline: Container(),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text('All Categories'),
              ),
              ...['Cocktail', 'Shot', 'Ordinary Drink', 'Coffee / Tea', 'Beer', 'Soft Drink']
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      )),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCategory = value;
              });
            },
          ),
          SizedBox(width: AppSpacing.md),

          // Alcoholic filter
          DropdownButton<String?>(
            value: _selectedAlcoholic,
            hint: Text('Type', style: AppTypography.buttonSmall),
            dropdownColor: AppColors.cardBackground,
            style: AppTypography.buttonSmall,
            underline: Container(),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text('All Types'),
              ),
              DropdownMenuItem(
                value: 'Alcoholic',
                child: Text('Alcoholic'),
              ),
              DropdownMenuItem(
                value: 'Non alcoholic',
                child: Text('Non-Alcoholic'),
              ),
              DropdownMenuItem(
                value: 'Optional alcohol',
                child: Text('Optional Alcohol'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedAlcoholic = value;
              });
            },
          ),

          // Clear filters
          if (_selectedCategory != null || _selectedAlcoholic != null || _showCanMakeOnly || _showFavoritesOnly)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedCategory = null;
                  _selectedAlcoholic = null;
                  _showCanMakeOnly = false;
                  _showFavoritesOnly = false;
                });
              },
              icon: Icon(Icons.clear, size: 16, color: AppColors.primaryPurple),
              label: Text('Clear', style: AppTypography.buttonSmall.copyWith(color: AppColors.primaryPurple)),
            ),
        ],
      ),
    );
  }

  Widget _buildCocktailGrid(List<Cocktail> cocktails) {
    if (cocktails.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_bar, size: 64, color: AppColors.textSecondary),
            SizedBox(height: AppSpacing.lg),
            Text(
              'No cocktails found',
              style: AppTypography.heading3,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Try syncing the database or\nadjusting your filters',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
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
        return CompactRecipeCard(
          name: cocktail.name,
          imageUrl: cocktail.imageUrl,
          matchCount: cocktail.ingredients.length,
          totalIngredients: cocktail.ingredients.length,
          isCustom: cocktail.isCustom ?? false,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CocktailDetailScreen(cocktailId: cocktail.id),
              ),
            );
          },
        );
      },
    );
  }
}
