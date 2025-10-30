import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Service for downloading and caching cocktail images locally
class ImageCacheService {
  final Dio _dio;
  static const String _imagesDirName = 'cocktail_images';

  ImageCacheService() : _dio = Dio();

  /// Get the directory where images are stored
  Future<Directory> getImagesDirectory() async {
    final Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final Directory imagesDir = Directory(join(documentsDirectory.path, _imagesDirName));

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    return imagesDir;
  }

  /// Generate a safe filename from a URL
  String _generateFilename(String url) {
    // Use MD5 hash of URL to create a safe, unique filename
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    final extension = url.split('.').last.split('?').first; // Get extension before query params
    return '${digest.toString()}.$extension';
  }

  /// Get local file path for an image URL
  Future<String> getLocalPath(String imageUrl) async {
    final imagesDir = await getImagesDirectory();
    final filename = _generateFilename(imageUrl);
    return join(imagesDir.path, filename);
  }

  /// Check if image exists locally
  Future<bool> isImageCached(String imageUrl) async {
    final localPath = await getLocalPath(imageUrl);
    return await File(localPath).exists();
  }

  /// Download a single image
  Future<String?> downloadImage(String imageUrl, {
    Function(int received, int total)? onProgress,
  }) async {
    try {
      final localPath = await getLocalPath(imageUrl);

      // Skip if already cached
      if (await File(localPath).exists()) {
        print('Image already cached: $imageUrl');
        return localPath;
      }

      // Download image
      final response = await _dio.get(
        imageUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
        onReceiveProgress: onProgress,
      );

      // Save to file
      final file = File(localPath);
      await file.writeAsBytes(response.data as List<int>);

      print('Downloaded image: $imageUrl -> $localPath');
      return localPath;
    } catch (e) {
      print('Error downloading image $imageUrl: $e');
      return null;
    }
  }

  /// Download multiple images in batches
  Future<Map<String, String?>> downloadImages(
    List<Map<String, String>> cocktails, {
    int batchSize = 5,
    Function(int completed, int total)? onProgress,
  }) async {
    final results = <String, String?>{};
    final total = cocktails.length;
    int completed = 0;

    print('Starting download of $total images...');

    // Process in batches to avoid overwhelming the network
    for (int i = 0; i < cocktails.length; i += batchSize) {
      final end = (i + batchSize < cocktails.length) ? i + batchSize : cocktails.length;
      final batch = cocktails.sublist(i, end);

      // Download batch in parallel
      final batchFutures = batch.map((cocktail) async {
        final id = cocktail['id']!;
        final imageUrl = cocktail['imageUrl'];

        if (imageUrl == null || imageUrl.isEmpty) {
          return MapEntry(id, null);
        }

        final localPath = await downloadImage(imageUrl);
        return MapEntry(id, localPath);
      }).toList();

      final batchResults = await Future.wait(batchFutures);

      for (final entry in batchResults) {
        results[entry.key] = entry.value;
        completed++;

        if (onProgress != null) {
          onProgress(completed, total);
        }
      }

      // Small delay between batches to be nice to the server
      if (i + batchSize < cocktails.length) {
        await Future.delayed(Duration(milliseconds: 100));
      }
    }

    print('Completed downloading $completed/$total images');
    return results;
  }

  /// Clear all cached images
  Future<void> clearCache() async {
    try {
      final imagesDir = await getImagesDirectory();
      if (await imagesDir.exists()) {
        await imagesDir.delete(recursive: true);
        await imagesDir.create(recursive: true);
        print('Image cache cleared');
      }
    } catch (e) {
      print('Error clearing image cache: $e');
    }
  }

  /// Get cache size in bytes
  Future<int> getCacheSize() async {
    try {
      final imagesDir = await getImagesDirectory();
      if (!await imagesDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in imagesDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      print('Error calculating cache size: $e');
      return 0;
    }
  }

  /// Get cached image count
  Future<int> getCachedImageCount() async {
    try {
      final imagesDir = await getImagesDirectory();
      if (!await imagesDir.exists()) {
        return 0;
      }

      int count = 0;
      await for (final entity in imagesDir.list()) {
        if (entity is File) {
          count++;
        }
      }
      return count;
    } catch (e) {
      print('Error counting cached images: $e');
      return 0;
    }
  }
}
