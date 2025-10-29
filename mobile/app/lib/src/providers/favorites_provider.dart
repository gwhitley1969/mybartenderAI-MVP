import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import 'cocktail_provider.dart';

// Provider for the list of favorite cocktails
final favoritesProvider = FutureProvider<List<FavoriteCocktail>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final favoriteMaps = await db.getFavorites();
  return favoriteMaps.map((map) => FavoriteCocktail.fromDb(map)).toList();
});

// Provider for the count of favorites
final favoritesCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getFavoritesCount();
});

// Provider for checking if a specific cocktail is favorited
final isFavoriteProvider = FutureProvider.family<bool, String>((ref, cocktailId) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.isFavorite(cocktailId);
});

// Provider for the list of favorite cocktail IDs
final favoriteCocktailIdsProvider = FutureProvider<List<String>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getFavoriteCocktailIds();
});

// State for favorites operations
enum FavoritesStatus {
  idle,
  loading,
  success,
  error,
}

class FavoritesState {
  final FavoritesStatus status;
  final String? errorMessage;

  FavoritesState({
    required this.status,
    this.errorMessage,
  });

  factory FavoritesState.initial() {
    return FavoritesState(status: FavoritesStatus.idle);
  }

  FavoritesState copyWith({
    FavoritesStatus? status,
    String? errorMessage,
  }) {
    return FavoritesState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// Notifier for managing favorites operations
class FavoritesNotifier extends StateNotifier<FavoritesState> {
  final Ref ref;

  FavoritesNotifier(this.ref) : super(FavoritesState.initial());

  Future<void> addFavorite(String cocktailId, {String? notes}) async {
    state = state.copyWith(status: FavoritesStatus.loading);
    try {
      final db = ref.read(databaseServiceProvider);
      await db.addToFavorites(cocktailId, notes: notes);

      // Invalidate providers to refresh the UI
      ref.invalidate(favoritesProvider);
      ref.invalidate(favoritesCountProvider);
      ref.invalidate(isFavoriteProvider);
      ref.invalidate(favoriteCocktailIdsProvider);

      state = state.copyWith(status: FavoritesStatus.success);
    } catch (e) {
      state = state.copyWith(
        status: FavoritesStatus.error,
        errorMessage: 'Failed to add favorite: $e',
      );
    }
  }

  Future<void> removeFavorite(String cocktailId) async {
    state = state.copyWith(status: FavoritesStatus.loading);
    try {
      final db = ref.read(databaseServiceProvider);
      await db.removeFromFavorites(cocktailId);

      // Invalidate providers to refresh the UI
      ref.invalidate(favoritesProvider);
      ref.invalidate(favoritesCountProvider);
      ref.invalidate(isFavoriteProvider);
      ref.invalidate(favoriteCocktailIdsProvider);

      state = state.copyWith(status: FavoritesStatus.success);
    } catch (e) {
      state = state.copyWith(
        status: FavoritesStatus.error,
        errorMessage: 'Failed to remove favorite: $e',
      );
    }
  }

  Future<void> updateNotes(String cocktailId, String? notes) async {
    state = state.copyWith(status: FavoritesStatus.loading);
    try {
      final db = ref.read(databaseServiceProvider);
      await db.updateFavoriteNotes(cocktailId, notes);

      // Invalidate favorites provider to refresh the list
      ref.invalidate(favoritesProvider);

      state = state.copyWith(status: FavoritesStatus.success);
    } catch (e) {
      state = state.copyWith(
        status: FavoritesStatus.error,
        errorMessage: 'Failed to update notes: $e',
      );
    }
  }

  Future<void> toggleFavorite(String cocktailId, {String? notes}) async {
    final db = ref.read(databaseServiceProvider);
    final isFav = await db.isFavorite(cocktailId);

    if (isFav) {
      await removeFavorite(cocktailId);
    } else {
      await addFavorite(cocktailId, notes: notes);
    }
  }
}

// Provider for the favorites notifier
final favoritesNotifierProvider = StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
  return FavoritesNotifier(ref);
});
