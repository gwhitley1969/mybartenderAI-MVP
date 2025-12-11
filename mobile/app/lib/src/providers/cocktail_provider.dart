import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/backend_service.dart';
import '../services/database_service.dart';
import '../services/snapshot_service.dart';
import 'backend_provider.dart';

/// Provider for DatabaseService singleton
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

/// Provider for SnapshotService
final snapshotServiceProvider = Provider<SnapshotService>((ref) {
  return SnapshotService(
    backendService: ref.watch(backendServiceProvider),
    databaseService: ref.watch(databaseServiceProvider),
  );
});

/// Provider to check if snapshot needs update
final snapshotNeedsUpdateProvider = FutureProvider<bool>((ref) async {
  final snapshotService = ref.watch(snapshotServiceProvider);
  return await snapshotService.needsUpdate();
});

/// Provider for snapshot statistics
final snapshotStatisticsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final snapshotService = ref.watch(snapshotServiceProvider);
  return await snapshotService.getStatistics();
});

/// Provider for all cocktails with optional filtering
final cocktailsProvider = FutureProvider.family<List<Cocktail>, CocktailFilter>(
  (ref, filter) async {
    final db = ref.watch(databaseServiceProvider);
    return await db.getCocktails(
      searchQuery: filter.searchQuery,
      category: filter.category,
      alcoholic: filter.alcoholic,
      limit: filter.limit,
      offset: filter.offset,
    );
  },
);

/// Provider for single cocktail by ID
final cocktailByIdProvider =
    FutureProvider.family<Cocktail?, String>((ref, id) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getCocktailById(id);
});

/// Provider for categories
final categoriesProvider = FutureProvider<List<String>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getCategories();
});

/// Provider for alcoholic types
final alcoholicTypesProvider = FutureProvider<List<String>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getAlcoholicTypes();
});

/// Provider for cocktail count
final cocktailCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getCocktailCount();
});

/// Provider to check if initial database sync is needed
/// Returns true if database is empty (no cocktails)
final needsInitialSyncProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final count = await db.getCocktailCount();
  return count == 0;
});

/// State notifier for tracking if initial sync is needed (for router guard)
/// Similar pattern to ageVerificationProvider - loads async but provides sync state
class InitialSyncStatusNotifier extends StateNotifier<InitialSyncStatus> {
  final DatabaseService _databaseService;

  InitialSyncStatusNotifier(this._databaseService)
      : super(const InitialSyncStatus.checking()) {
    _checkDatabase();
  }

  Future<void> _checkDatabase() async {
    try {
      final count = await _databaseService.getCocktailCount();
      if (count > 0) {
        state = const InitialSyncStatus.hasData();
      } else {
        state = const InitialSyncStatus.needsSync();
      }
    } catch (e) {
      // If we can't check, assume needs sync to be safe
      state = const InitialSyncStatus.needsSync();
    }
  }

  /// Call this after sync completes to update state
  void markSyncCompleted() {
    state = const InitialSyncStatus.hasData();
  }

  /// Force recheck of database state
  Future<void> recheck() async {
    state = const InitialSyncStatus.checking();
    await _checkDatabase();
  }
}

/// State for initial sync status
class InitialSyncStatus {
  final InitialSyncState state;

  const InitialSyncStatus({required this.state});

  const InitialSyncStatus.checking() : this(state: InitialSyncState.checking);
  const InitialSyncStatus.needsSync() : this(state: InitialSyncState.needsSync);
  const InitialSyncStatus.hasData() : this(state: InitialSyncState.hasData);

  bool get isChecking => state == InitialSyncState.checking;
  bool get needsSync => state == InitialSyncState.needsSync;
  bool get hasData => state == InitialSyncState.hasData;
}

enum InitialSyncState {
  checking,
  needsSync,
  hasData,
}

/// Provider for initial sync status (used by router guard)
final initialSyncStatusProvider =
    StateNotifierProvider<InitialSyncStatusNotifier, InitialSyncStatus>((ref) {
  return InitialSyncStatusNotifier(ref.watch(databaseServiceProvider));
});

/// Provider for searching by ingredient
final cocktailsByIngredientProvider =
    FutureProvider.family<List<Cocktail>, String>((ref, ingredientName) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.searchByIngredient(ingredientName);
});

/// State notifier for snapshot sync progress
class SnapshotSyncNotifier extends StateNotifier<SnapshotSyncState> {
  final SnapshotService _snapshotService;

  SnapshotSyncNotifier(this._snapshotService)
      : super(const SnapshotSyncState.idle());

  Future<void> syncSnapshot() async {
    try {
      state = const SnapshotSyncState.syncing(0, 0);

      await _snapshotService.syncSnapshot(
        onProgress: (current, total) {
          state = SnapshotSyncState.syncing(current, total);
        },
      );

      state = const SnapshotSyncState.completed();
    } catch (e) {
      state = SnapshotSyncState.error(e.toString());
    }
  }

  void reset() {
    state = const SnapshotSyncState.idle();
  }
}

/// Provider for snapshot sync notifier
final snapshotSyncProvider =
    StateNotifierProvider<SnapshotSyncNotifier, SnapshotSyncState>((ref) {
  return SnapshotSyncNotifier(ref.watch(snapshotServiceProvider));
});

/// Snapshot sync state
class SnapshotSyncState {
  final SnapshotSyncStatus status;
  final int currentBytes;
  final int totalBytes;
  final String? errorMessage;

  const SnapshotSyncState({
    required this.status,
    this.currentBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
  });

  const SnapshotSyncState.idle()
      : this(status: SnapshotSyncStatus.idle);

  const SnapshotSyncState.syncing(int currentBytes, int totalBytes)
      : this(
          status: SnapshotSyncStatus.syncing,
          currentBytes: currentBytes,
          totalBytes: totalBytes,
        );

  const SnapshotSyncState.completed()
      : this(status: SnapshotSyncStatus.completed);

  const SnapshotSyncState.error(String message)
      : this(status: SnapshotSyncStatus.error, errorMessage: message);

  double get progress {
    if (totalBytes == 0) return 0.0;
    return currentBytes / totalBytes;
  }

  bool get isLoading => status == SnapshotSyncStatus.syncing;
  bool get isCompleted => status == SnapshotSyncStatus.completed;
  bool get isError => status == SnapshotSyncStatus.error;
}

enum SnapshotSyncStatus {
  idle,
  syncing,
  completed,
  error,
}

/// Filter for cocktail queries
class CocktailFilter {
  final String? searchQuery;
  final String? category;
  final String? alcoholic;
  final int limit;
  final int offset;

  const CocktailFilter({
    this.searchQuery,
    this.category,
    this.alcoholic,
    this.limit = 100,
    this.offset = 0,
  });

  CocktailFilter copyWith({
    String? searchQuery,
    String? category,
    String? alcoholic,
    int? limit,
    int? offset,
  }) {
    return CocktailFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      category: category ?? this.category,
      alcoholic: alcoholic ?? this.alcoholic,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CocktailFilter &&
        other.searchQuery == searchQuery &&
        other.category == category &&
        other.alcoholic == alcoholic &&
        other.limit == limit &&
        other.offset == offset;
  }

  @override
  int get hashCode {
    return searchQuery.hashCode ^
        category.hashCode ^
        alcoholic.hashCode ^
        limit.hashCode ^
        offset.hashCode;
  }
}
