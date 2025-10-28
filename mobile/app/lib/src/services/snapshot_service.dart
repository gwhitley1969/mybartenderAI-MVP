import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zstandard/zstandard.dart';

import 'backend_service.dart';
import 'database_service.dart';

/// Service for downloading and importing cocktail snapshots
class SnapshotService {
  final BackendService _backendService;
  final DatabaseService _databaseService;
  final Dio _dio;

  SnapshotService({
    required BackendService backendService,
    required DatabaseService databaseService,
  })  : _backendService = backendService,
        _databaseService = databaseService,
        _dio = Dio();

  /// Check if a snapshot update is needed
  Future<bool> needsUpdate() async {
    try {
      // Get latest snapshot metadata from backend
      final metadata = await _backendService.getLatestSnapshot();

      // Get current local version
      final localVersion =
          await _databaseService.getCurrentSnapshotVersion();

      // Need update if no local version or versions don't match
      return localVersion == null ||
          localVersion != metadata.snapshotVersion;
    } catch (e) {
      print('Error checking snapshot version: $e');
      return false;
    }
  }

  /// Download and import the latest snapshot
  Future<void> syncSnapshot({
    Function(int current, int total)? onProgress,
  }) async {
    try {
      // Step 1: Get snapshot metadata
      final metadata = await _backendService.getLatestSnapshot();
      print('Downloading snapshot version: ${metadata.snapshotVersion}');

      // Step 2: Download compressed SQLite file from signed URL
      final response = await _dio.get(
        metadata.signedUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received, total);
          }
        },
      );

      print('Downloaded ${response.data.length} bytes');

      // Step 3: Decompress the Zstandard-compressed file
      print('Decompressing SQLite database...');
      final Uint8List compressedData = Uint8List.fromList(response.data);
      final zstandard = Zstandard();
      final Uint8List? decompressedData = await zstandard.decompress(compressedData);

      if (decompressedData == null) {
        throw Exception('Failed to decompress database file');
      }

      print('Decompressed to ${decompressedData.length} bytes');

      // Step 4: Close existing database connection
      await _databaseService.close();

      // Step 5: Delete old database files (including WAL and SHM files)
      final Directory documentsDirectory = await getApplicationDocumentsDirectory();
      final String dbPath = join(documentsDirectory.path, 'mybartenderai.db');
      final File dbFile = File(dbPath);
      final File walFile = File('$dbPath-wal');
      final File shmFile = File('$dbPath-shm');

      print('Deleting old database files...');
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      if (await walFile.exists()) {
        await walFile.delete();
      }
      if (await shmFile.exists()) {
        await shmFile.delete();
      }

      // Step 6: Write new decompressed database file
      print('Writing new database to $dbPath');
      await dbFile.writeAsBytes(decompressedData, flush: true);
      print('Database file written successfully');

      // Step 7: Update metadata with snapshot version
      await _databaseService.setCurrentSnapshotVersion(metadata.snapshotVersion);

      print('Snapshot sync complete!');
    } catch (e) {
      print('Error syncing snapshot: $e');
      rethrow;
    }
  }


  /// Get current local snapshot version
  Future<String?> getLocalVersion() async {
    return await _databaseService.getCurrentSnapshotVersion();
  }

  /// Get cocktail statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final totalCount = await _databaseService.getCocktailCount();
    final categories = await _databaseService.getCategories();
    final alcoholicTypes = await _databaseService.getAlcoholicTypes();
    final localVersion = await getLocalVersion();

    return {
      'totalCocktails': totalCount,
      'categories': categories.length,
      'alcoholicTypes': alcoholicTypes.length,
      'snapshotVersion': localVersion,
    };
  }
}
