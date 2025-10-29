import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import 'cocktail_provider.dart';

/// Provider for user's inventory list
final inventoryProvider = FutureProvider<List<UserIngredient>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final items = await db.getInventory();
  return items.map((item) => UserIngredient.fromDb(item)).toList();
});

/// Provider for inventory count
final inventoryCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getInventoryCount();
});

/// Provider to check if an ingredient is in inventory
final isInInventoryProvider =
    FutureProvider.family<bool, String>((ref, ingredientName) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.isInInventory(ingredientName);
});

/// Provider for all available ingredients (for picker)
final allIngredientsProvider = FutureProvider<List<String>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getAllIngredients();
});

/// Provider for cocktails that can be made with inventory
final cocktailsWithInventoryProvider =
    FutureProvider.family<List<Cocktail>, CocktailFilter>((ref, filter) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getCocktailsWithInventory(
    searchQuery: filter.searchQuery,
    category: filter.category,
    alcoholic: filter.alcoholic,
    limit: filter.limit,
    offset: filter.offset,
  );
});

/// State notifier for inventory management
class InventoryNotifier extends StateNotifier<InventoryState> {
  final DatabaseService _databaseService;
  final Ref _ref;

  InventoryNotifier(this._databaseService, this._ref)
      : super(const InventoryState.idle());

  /// Add ingredient to inventory
  Future<void> addIngredient(
    String ingredientName, {
    String? category,
    String? notes,
  }) async {
    try {
      state = const InventoryState.loading();

      await _databaseService.addToInventory(
        ingredientName,
        category: category,
        notes: notes,
      );

      // Invalidate providers to trigger refresh
      _ref.invalidate(inventoryProvider);
      _ref.invalidate(inventoryCountProvider);
      _ref.invalidate(isInInventoryProvider);
      _ref.invalidate(cocktailsWithInventoryProvider);

      state = const InventoryState.success();
    } catch (e) {
      state = InventoryState.error(e.toString());
    }
  }

  /// Remove ingredient from inventory
  Future<void> removeIngredient(String ingredientName) async {
    try {
      state = const InventoryState.loading();

      await _databaseService.removeFromInventory(ingredientName);

      // Invalidate providers to trigger refresh
      _ref.invalidate(inventoryProvider);
      _ref.invalidate(inventoryCountProvider);
      _ref.invalidate(isInInventoryProvider);
      _ref.invalidate(cocktailsWithInventoryProvider);

      state = const InventoryState.success();
    } catch (e) {
      state = InventoryState.error(e.toString());
    }
  }

  /// Reset state to idle
  void reset() {
    state = const InventoryState.idle();
  }
}

/// Provider for inventory notifier
final inventoryNotifierProvider =
    StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  return InventoryNotifier(
    ref.watch(databaseServiceProvider),
    ref,
  );
});

/// Inventory operation state
class InventoryState {
  final InventoryStatus status;
  final String? errorMessage;

  const InventoryState({
    required this.status,
    this.errorMessage,
  });

  const InventoryState.idle() : this(status: InventoryStatus.idle);
  const InventoryState.loading() : this(status: InventoryStatus.loading);
  const InventoryState.success() : this(status: InventoryStatus.success);
  const InventoryState.error(String message)
      : this(status: InventoryStatus.error, errorMessage: message);

  bool get isLoading => status == InventoryStatus.loading;
  bool get isSuccess => status == InventoryStatus.success;
  bool get isError => status == InventoryStatus.error;
  bool get isIdle => status == InventoryStatus.idle;
}

enum InventoryStatus {
  idle,
  loading,
  success,
  error,
}
