import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Service to manage locally-stored cocktail photos.
///
/// Photos are saved to `{appDocDir}/cocktail_photos/{cocktailId}.jpg`.
/// The returned file path can be stored in [Cocktail.imageUrl] and
/// recognised by [CachedCocktailImage] as a local file.
class CocktailPhotoService {
  CocktailPhotoService._();
  static final instance = CocktailPhotoService._();

  /// Save [bytes] as the photo for [cocktailId]. Returns the absolute path.
  Future<String> savePhoto(String cocktailId, Uint8List bytes) async {
    final dir = await _photosDir();
    final file = File('${dir.path}/$cocktailId.jpg');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Delete the photo for [cocktailId] if it exists.
  Future<void> deletePhoto(String cocktailId) async {
    final path = await getPhotoPath(cocktailId);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Return the expected absolute path (may or may not exist yet).
  Future<String> getPhotoPath(String cocktailId) async {
    final dir = await _photosDir();
    return '${dir.path}/$cocktailId.jpg';
  }

  /// Check whether a photo file exists for [cocktailId].
  Future<bool> hasPhoto(String cocktailId) async {
    final path = await getPhotoPath(cocktailId);
    return File(path).exists();
  }

  /// Ensure the `cocktail_photos` subdirectory exists and return it.
  Future<Directory> _photosDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/cocktail_photos');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
