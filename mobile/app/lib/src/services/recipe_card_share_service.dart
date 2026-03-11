import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../widgets/shareable_recipe_card.dart';
import 'image_cache_service.dart';

/// Orchestrates recipe card image generation and sharing.
///
/// Flow: load cocktail image bytes → build [ShareableRecipeCard] widget →
/// capture as PNG via [ScreenshotController] → save temp file → share via
/// [Share.shareXFiles].
class RecipeCardShareService {
  static final RecipeCardShareService instance = RecipeCardShareService._();

  final ImageCacheService _imageCache = ImageCacheService();
  final Dio _dio = Dio();

  RecipeCardShareService._();

  /// Load the cocktail's image as raw bytes for synchronous rendering.
  ///
  /// Checks local file paths first, then the image cache, then falls back
  /// to a network download. Returns null if no image is available.
  Future<Uint8List?> _loadCocktailImageBytes(Cocktail cocktail) async {
    final imageUrl = cocktail.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return null;

    try {
      // Local file path (custom cocktail photos)
      if (imageUrl.startsWith('/') || imageUrl.startsWith('file://')) {
        final path =
            imageUrl.startsWith('file://') ? imageUrl.substring(7) : imageUrl;
        final file = File(path);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
        return null;
      }

      // Network URL — check image cache first
      final cachedPath = await _imageCache.getLocalPath(imageUrl);
      final cachedFile = File(cachedPath);
      if (await cachedFile.exists()) {
        return await cachedFile.readAsBytes();
      }

      // Download from network as fallback
      final response = await _dio.get<List<int>>(
        imageUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      if (response.data != null) {
        return Uint8List.fromList(response.data!);
      }
    } catch (e) {
      debugPrint('[RecipeCardShare] Failed to load image: $e');
    }
    return null;
  }

  /// Generate a shareable PNG image of the recipe card.
  ///
  /// Returns a temporary [File] containing the rendered PNG.
  Future<File> generateShareableImage(Cocktail cocktail) async {
    // Pre-load image bytes so the widget renders synchronously
    final imageBytes = await _loadCocktailImageBytes(cocktail);

    // Build the card widget
    final widget = ShareableRecipeCard(
      cocktail: cocktail,
      imageBytes: imageBytes,
    );

    // Capture widget to PNG at 2x resolution for sharp output
    final screenshotController = ScreenshotController();
    final pngBytes = await screenshotController.captureFromWidget(
      widget,
      pixelRatio: 2.0,
      delay: const Duration(milliseconds: 100),
    );

    // Save to temp directory
    final tempDir = await getTemporaryDirectory();
    final shareDir = Directory('${tempDir.path}/share_cards');
    if (!await shareDir.exists()) {
      await shareDir.create(recursive: true);
    }

    // Use cocktail id for filename (sanitize non-alphanumeric chars)
    final safeId = cocktail.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${shareDir.path}/$safeId.png');
    await file.writeAsBytes(pngBytes);

    return file;
  }

  /// Generate a recipe card image and share it via the OS share sheet.
  ///
  /// Shows a loading indicator while generating, falls back to text-only
  /// sharing if image generation fails.
  Future<ShareResult?> shareRecipeCard(
    BuildContext context,
    Cocktail cocktail, {
    Rect? sharePositionOrigin,
  }) async {
    // Show loading indicator
    final messenger = ScaffoldMessenger.of(context);
    final loadingBar = messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Preparing recipe card...'),
          ],
        ),
        duration: const Duration(seconds: 30), // long enough for generation
      ),
    );

    try {
      // Generate the card image
      final imageFile = await generateShareableImage(cocktail);
      loadingBar.close();

      // Build share text
      final subject = '${cocktail.name} - My AI Bartender Recipe';
      final shareText = _buildShareText(cocktail);

      // Share image + text
      final result = await Share.shareXFiles(
        [XFile(imageFile.path)],
        text: shareText,
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      );

      return result;
    } catch (e, stackTrace) {
      loadingBar.close();
      debugPrint('[RecipeCardShare] Image generation failed: $e');
      debugPrint('[RecipeCardShare] Stack trace: $stackTrace');

      // Fall back to text-only sharing
      try {
        final subject = '${cocktail.name} - My AI Bartender Recipe';
        final shareText = _buildShareText(cocktail);

        final result = await Share.shareWithResult(
          shareText,
          subject: subject,
          sharePositionOrigin: sharePositionOrigin,
        );
        return result;
      } catch (fallbackError) {
        debugPrint('[RecipeCardShare] Text fallback also failed: $fallbackError');
        return null;
      }
    }
  }

  /// Build the text that accompanies the shared image.
  String _buildShareText(Cocktail cocktail) {
    final buffer = StringBuffer();

    buffer.writeln(cocktail.name);
    buffer.writeln();

    // For standard cocktails, include the share URL
    if (!cocktail.isCustom) {
      buffer.writeln(
          'https://share.mybartenderai.com/api/cocktail/${cocktail.id}');
      buffer.writeln();
    }

    buffer.writeln('Made with My AI Bartender');
    buffer.writeln(
        'https://play.google.com/store/apps/details?id=ai.mybartender.mybartenderai');

    return buffer.toString().trim();
  }
}
