import 'dart:io';

import 'package:flutter/material.dart';

import '../services/image_cache_service.dart';

/// Widget that displays a cocktail image from local cache or network
class CachedCocktailImage extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final Widget Function(BuildContext context, Object error, StackTrace? stackTrace)? errorBuilder;
  final Widget? placeholder;

  const CachedCocktailImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return placeholder ?? _buildPlaceholder(context);
    }

    return FutureBuilder<String>(
      future: ImageCacheService().getLocalPath(imageUrl!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // While checking, show placeholder
          return placeholder ?? _buildPlaceholder(context);
        }

        final localPath = snapshot.data!;

        // Check if file exists locally
        return FutureBuilder<bool>(
          future: File(localPath).exists(),
          builder: (context, existsSnapshot) {
            if (!existsSnapshot.hasData) {
              return placeholder ?? _buildPlaceholder(context);
            }

            if (existsSnapshot.data == true) {
              // Use local file
              return Image.file(
                File(localPath),
                fit: fit,
                errorBuilder: errorBuilder ?? _defaultErrorBuilder,
              );
            } else {
              // Fall back to network (shouldn't happen after sync, but handle gracefully)
              return Image.network(
                imageUrl!,
                fit: fit,
                errorBuilder: errorBuilder ?? _defaultErrorBuilder,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
              );
            }
          },
        );
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      child: Center(
        child: Icon(
          Icons.local_bar,
          size: 64,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _defaultErrorBuilder(BuildContext context, Object error, StackTrace? stackTrace) {
    return Container(
      color: Theme.of(context).cardColor,
      child: Center(
        child: Icon(
          Icons.broken_image,
          size: 64,
          color: Theme.of(context).colorScheme.error.withOpacity(0.5),
        ),
      ),
    );
  }
}
