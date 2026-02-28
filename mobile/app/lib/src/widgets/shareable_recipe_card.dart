import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/theme.dart';

/// A self-contained, fixed-size widget that renders a complete cocktail recipe
/// card suitable for off-screen image capture via the `screenshot` package.
///
/// Accepts pre-loaded [imageBytes] to avoid async image loading issues during
/// capture. Uses static [AppColors] and [AppTypography] constants so it works
/// without a live [BuildContext] theme.
class ShareableRecipeCard extends StatelessWidget {
  final Cocktail cocktail;
  final Uint8List? imageBytes;

  /// Card width in logical pixels (rendered at 2x pixel ratio → 2160px).
  static const double cardWidth = 1080;

  const ShareableRecipeCard({
    super.key,
    required this.cocktail,
    this.imageBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: cardWidth,
      color: AppColors.backgroundPrimary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero image area ──────────────────────────────────
          _buildHeroImage(),

          // ── Content area ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cocktail name
                Text(
                  cocktail.name,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),

                // Tags row
                _buildTagsRow(),
                const SizedBox(height: 20),

                // Ingredients section
                _buildSectionTitle('Ingredients'),
                const SizedBox(height: 10),
                _buildIngredientsList(),
                const SizedBox(height: 20),

                // Instructions section
                if (cocktail.instructions != null &&
                    cocktail.instructions!.isNotEmpty) ...[
                  _buildSectionTitle('Instructions'),
                  const SizedBox(height: 10),
                  _buildInstructions(),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),

          // ── App promo footer ────────────────────────────────
          _buildPromoFooter(),
        ],
      ),
    );
  }

  // ── Hero image ──────────────────────────────────────────────

  Widget _buildHeroImage() {
    const double heroHeight = 280;

    if (imageBytes != null) {
      return SizedBox(
        height: heroHeight,
        width: double.infinity,
        child: Image.memory(
          imageBytes!,
          fit: BoxFit.cover,
        ),
      );
    }

    // Placeholder when no image
    return Container(
      height: heroHeight,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2D1B69), // deep purple
            AppColors.backgroundPrimary,
          ],
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_bar,
            color: AppColors.primaryPurple,
            size: 80,
          ),
          SizedBox(height: 16),
          Text(
            'Custom Creation',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryPurpleLight,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tags row ────────────────────────────────────────────────

  Widget _buildTagsRow() {
    final chips = <Widget>[];

    if (cocktail.category != null) {
      chips.add(_buildChip(cocktail.category!));
    }
    if (cocktail.alcoholic != null) {
      chips.add(_buildChip(cocktail.alcoholic!));
    }
    if (cocktail.glass != null) {
      chips.add(_buildChip(cocktail.glass!));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: chips,
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withOpacity(0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primaryPurple.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryPurpleLight,
          height: 1.3,
        ),
      ),
    );
  }

  // ── Section title ───────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
    );
  }

  // ── Ingredients list ────────────────────────────────────────

  Widget _buildIngredientsList() {
    return Column(
      children: cocktail.ingredients.map((ingredient) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Purple dot bullet
              Container(
                margin: const EdgeInsets.only(top: 7),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primaryPurple,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              // Ingredient name
              Expanded(
                child: Text(
                  ingredient.ingredientName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              // Measurement
              if (ingredient.measure != null &&
                  ingredient.measure!.isNotEmpty)
                Text(
                  ingredient.measure!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textTertiary,
                    height: 1.5,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Instructions ────────────────────────────────────────────

  Widget _buildInstructions() {
    String text = cocktail.instructions ?? '';
    // Truncate very long instructions so card stays reasonable height
    if (text.length > 200) {
      text = '${text.substring(0, 197)}...';
    }

    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.6,
      ),
    );
  }

  // ── App promo footer ────────────────────────────────────────

  Widget _buildPromoFooter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(32, 0, 32, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2D1B69),
            Color(0xFF1A1040),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primaryPurple.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // App promo text
          const Text(
            'Get My AI Bartender for more recipes,\nAI recommendations, and bar inventory tracking!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),

          // Store buttons (visual only — static image)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStoreButton('Google Play'),
              const SizedBox(width: 16),
              _buildStoreButton('App Store'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreButton(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.3,
        ),
      ),
    );
  }
}
