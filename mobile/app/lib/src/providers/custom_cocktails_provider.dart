import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'providers.dart';

/// Provider for custom cocktails list
final customCocktailsProvider = FutureProvider<List<Cocktail>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getCustomCocktails();
});

/// Provider for custom cocktails count
final customCocktailsCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getCustomCocktailCount();
});

/// Provider for a specific custom cocktail by ID
final customCocktailByIdProvider =
    FutureProvider.family<Cocktail?, String>((ref, id) async {
  final db = ref.watch(databaseServiceProvider);
  final cocktails = await db.getCustomCocktails();
  try {
    return cocktails.firstWhere((c) => c.id == id);
  } catch (e) {
    return null;
  }
});

/// Provider for custom cocktails with search
final searchedCustomCocktailsProvider =
    FutureProvider.family<List<Cocktail>, String>((ref, query) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getCustomCocktails(searchQuery: query);
});
