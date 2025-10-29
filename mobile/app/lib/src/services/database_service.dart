import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

/// SQLite database service for offline cocktail storage
class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  static Database? _database;

  DatabaseService._internal();

  /// Get database instance (lazy initialization)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final String path = join(documentsDirectory.path, 'mybartenderai.db');

    print('Initializing database at: $path');

    try {
      print('Attempting to open database...');
      final db = await openDatabase(
        path,
        version: 2,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      print('Database opened successfully!');
      return db;
    } catch (e) {
      // Database is corrupted, delete it and try again
      print('ERROR opening database: $e');
      print('Attempting to delete corrupted database...');

      // Close any existing connections and delete the database completely
      try {
        await deleteDatabase(path);
        print('Successfully deleted corrupted database');
      } catch (deleteError) {
        print('ERROR deleting database: $deleteError');
      }

      // Try opening again with fresh database
      print('Attempting to open database again after deletion...');
      final db = await openDatabase(
        path,
        version: 2,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      print('Database opened successfully after recreation!');
      return db;
    }
  }

  /// Create database schema
  Future<void> _onCreate(Database db, int version) async {
    // Check if tables already exist (for snapshot-based databases)
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='drinks'"
    );

    if (tables.isNotEmpty) {
      // Database already has schema (probably from snapshot), skip creation
      print('Database schema already exists, skipping onCreate');
      return;
    }

    await db.execute('''
      CREATE TABLE drinks (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        alternate_name TEXT,
        category TEXT,
        glass TEXT,
        instructions TEXT,
        instructions_es TEXT,
        instructions_de TEXT,
        instructions_fr TEXT,
        instructions_it TEXT,
        image_url TEXT,
        image_attribution TEXT,
        tags TEXT,
        video_url TEXT,
        iba TEXT,
        alcoholic TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        source TEXT DEFAULT 'thecocktaildb',
        is_custom INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE drink_ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        drink_id TEXT NOT NULL,
        ingredient_name TEXT NOT NULL,
        measure TEXT,
        ingredient_order INTEGER NOT NULL,
        FOREIGN KEY (drink_id) REFERENCES drinks (id) ON DELETE CASCADE,
        UNIQUE (drink_id, ingredient_order)
      )
    ''');

    // Create indexes for better query performance
    await db.execute('CREATE INDEX idx_drinks_name ON drinks(name)');
    await db.execute('CREATE INDEX idx_drinks_category ON drinks(category)');
    await db.execute('CREATE INDEX idx_drinks_alcoholic ON drinks(alcoholic)');
    await db
        .execute('CREATE INDEX idx_drink_ingredients_drink ON drink_ingredients(drink_id)');
    await db.execute(
        'CREATE INDEX idx_drink_ingredients_name ON drink_ingredients(ingredient_name)');

    // Table to track snapshot version
    await db.execute('''
      CREATE TABLE metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // User inventory table
    await db.execute('''
      CREATE TABLE user_inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ingredient_name TEXT NOT NULL UNIQUE,
        category TEXT,
        notes TEXT,
        added_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create index for inventory search
    await db.execute('CREATE INDEX idx_inventory_name ON user_inventory(ingredient_name)');

    // Favorites table
    await db.execute('''
      CREATE TABLE favorite_cocktails (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cocktail_id TEXT NOT NULL UNIQUE,
        added_at INTEGER NOT NULL,
        notes TEXT
      )
    ''');

    // Create index for favorites
    await db.execute('CREATE INDEX idx_favorites_cocktail_id ON favorite_cocktails(cocktail_id)');
    await db.execute('CREATE INDEX idx_favorites_added_at ON favorite_cocktails(added_at DESC)');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Version 1 to 2: Add favorites table
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE favorite_cocktails (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cocktail_id TEXT NOT NULL UNIQUE,
          added_at INTEGER NOT NULL,
          notes TEXT
        )
      ''');

      await db.execute('CREATE INDEX idx_favorites_cocktail_id ON favorite_cocktails(cocktail_id)');
      await db.execute('CREATE INDEX idx_favorites_added_at ON favorite_cocktails(added_at DESC)');
    }
  }

  // ==========================================
  // Metadata Operations
  // ==========================================

  /// Get metadata value
  Future<String?> getMetadata(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'metadata',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (result.isEmpty) return null;
    return result.first['value'] as String;
  }

  /// Set metadata value
  Future<void> setMetadata(String key, String value) async {
    final db = await database;
    await db.insert(
      'metadata',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get current snapshot version
  Future<String?> getCurrentSnapshotVersion() async {
    return await getMetadata('snapshot_version');
  }

  /// Set current snapshot version
  Future<void> setCurrentSnapshotVersion(String version) async {
    await setMetadata('snapshot_version', version);
  }

  // ==========================================
  // Cocktail Operations
  // ==========================================

  /// Insert a cocktail with its ingredients
  Future<void> insertCocktail(Cocktail cocktail) async {
    final db = await database;
    await db.transaction((txn) async {
      // Insert drink
      await txn.insert('drinks', cocktail.toDb(),
          conflictAlgorithm: ConflictAlgorithm.replace);

      // Delete existing ingredients for this drink
      await txn.delete('drink_ingredients',
          where: 'drink_id = ?', whereArgs: [cocktail.id]);

      // Insert new ingredients
      for (final ingredient in cocktail.ingredients) {
        await txn.insert('drink_ingredients', ingredient.toDb(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Batch insert cocktails (faster for large imports)
  Future<void> insertCocktailsBatch(List<Cocktail> cocktails) async {
    final db = await database;
    final batch = db.batch();

    for (final cocktail in cocktails) {
      batch.insert('drinks', cocktail.toDb(),
          conflictAlgorithm: ConflictAlgorithm.replace);

      for (final ingredient in cocktail.ingredients) {
        batch.insert('drink_ingredients', ingredient.toDb(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    await batch.commit(noResult: true);
  }

  /// Get cocktail by ID with ingredients
  Future<Cocktail?> getCocktailById(String id) async {
    final db = await database;

    // Get drink
    final List<Map<String, dynamic>> drinkResult = await db.query(
      'drinks',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (drinkResult.isEmpty) return null;

    // Get ingredients
    final List<Map<String, dynamic>> ingredientsResult = await db.query(
      'drink_ingredients',
      where: 'drink_id = ?',
      whereArgs: [id],
      orderBy: 'ingredient_order ASC',
    );

    final cocktail = Cocktail.fromDb(drinkResult.first);
    final ingredients =
        ingredientsResult.map((row) => DrinkIngredient.fromDb(row)).toList();

    return cocktail.copyWith(ingredients: ingredients);
  }

  /// Get all cocktails with optional filtering
  Future<List<Cocktail>> getCocktails({
    String? searchQuery,
    String? category,
    String? alcoholic,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;

    String where = '';
    List<dynamic> whereArgs = [];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      where = 'name LIKE ? OR tags LIKE ?';
      whereArgs = ['%$searchQuery%', '%$searchQuery%'];
    }

    if (category != null) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'category = ?';
      whereArgs.add(category);
    }

    if (alcoholic != null) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'alcoholic = ?';
      whereArgs.add(alcoholic);
    }

    final List<Map<String, dynamic>> result = await db.query(
      'drinks',
      where: where.isNotEmpty ? where : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );

    // Load ingredients for each cocktail
    final cocktails = <Cocktail>[];
    for (final row in result) {
      final cocktail = Cocktail.fromDb(row);
      final ingredients = await _getIngredientsForDrink(cocktail.id);
      cocktails.add(cocktail.copyWith(ingredients: ingredients));
    }

    return cocktails;
  }

  /// Get ingredients for a specific drink
  Future<List<DrinkIngredient>> _getIngredientsForDrink(String drinkId) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'drink_ingredients',
      where: 'drink_id = ?',
      whereArgs: [drinkId],
      orderBy: 'ingredient_order ASC',
    );

    return result.map((row) => DrinkIngredient.fromDb(row)).toList();
  }

  /// Get total cocktail count
  Future<int> getCocktailCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM drinks');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get unique categories
  Future<List<String>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT DISTINCT category
      FROM drinks
      WHERE category IS NOT NULL
      ORDER BY category ASC
    ''');

    return result
        .map((row) => row['category'] as String)
        .where((c) => c.isNotEmpty)
        .toList();
  }

  /// Get unique alcoholic types
  Future<List<String>> getAlcoholicTypes() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT DISTINCT alcoholic
      FROM drinks
      WHERE alcoholic IS NOT NULL
      ORDER BY alcoholic ASC
    ''');

    return result
        .map((row) => row['alcoholic'] as String)
        .where((a) => a.isNotEmpty)
        .toList();
  }

  /// Search cocktails by ingredient
  Future<List<Cocktail>> searchByIngredient(String ingredientName) async {
    final db = await database;

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT DISTINCT d.*
      FROM drinks d
      INNER JOIN drink_ingredients di ON d.id = di.drink_id
      WHERE di.ingredient_name LIKE ?
      ORDER BY d.name ASC
    ''', ['%$ingredientName%']);

    final cocktails = <Cocktail>[];
    for (final row in result) {
      final cocktail = Cocktail.fromDb(row);
      final ingredients = await _getIngredientsForDrink(cocktail.id);
      cocktails.add(cocktail.copyWith(ingredients: ingredients));
    }

    return cocktails;
  }

  /// Delete all cocktails (for re-sync)
  Future<void> deleteAllCocktails() async {
    final db = await database;
    await db.delete('drinks');
    await db.delete('drink_ingredients');
  }

  // ==========================================
  // Inventory Operations
  // ==========================================

  /// Add ingredient to user inventory
  Future<void> addToInventory(String ingredientName, {String? category, String? notes}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.insert(
      'user_inventory',
      {
        'ingredient_name': ingredientName,
        'category': category,
        'notes': notes,
        'added_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Remove ingredient from user inventory
  Future<void> removeFromInventory(String ingredientName) async {
    final db = await database;
    await db.delete(
      'user_inventory',
      where: 'ingredient_name = ?',
      whereArgs: [ingredientName],
    );
  }

  /// Get all inventory items
  Future<List<Map<String, dynamic>>> getInventory() async {
    final db = await database;
    return await db.query(
      'user_inventory',
      orderBy: 'ingredient_name ASC',
    );
  }

  /// Check if ingredient is in inventory
  Future<bool> isInInventory(String ingredientName) async {
    final db = await database;
    final result = await db.query(
      'user_inventory',
      where: 'ingredient_name = ?',
      whereArgs: [ingredientName],
    );
    return result.isNotEmpty;
  }

  /// Get count of inventory items
  Future<int> getInventoryCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM user_inventory');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get all unique ingredients from cocktail database (for picker)
  Future<List<String>> getAllIngredients() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT DISTINCT ingredient_name
      FROM drink_ingredients
      WHERE ingredient_name IS NOT NULL
      ORDER BY ingredient_name ASC
    ''');

    return result
        .map((row) => row['ingredient_name'] as String)
        .where((name) => name.isNotEmpty)
        .toList();
  }

  /// Get cocktails that can be made with current inventory
  Future<List<Cocktail>> getCocktailsWithInventory({
    String? searchQuery,
    String? category,
    String? alcoholic,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;

    // Get user's ingredients
    final inventoryResult = await db.query('user_inventory');
    final userIngredients = inventoryResult
        .map((row) => row['ingredient_name'] as String)
        .toSet();

    if (userIngredients.isEmpty) {
      return [];
    }

    // Build where clause
    String where = '';
    List<dynamic> whereArgs = [];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      where = 'name LIKE ? OR tags LIKE ?';
      whereArgs = ['%$searchQuery%', '%$searchQuery%'];
    }

    if (category != null) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'category = ?';
      whereArgs.add(category);
    }

    if (alcoholic != null) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'alcoholic = ?';
      whereArgs.add(alcoholic);
    }

    final List<Map<String, dynamic>> result = await db.query(
      'drinks',
      where: where.isNotEmpty ? where : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );

    // Filter cocktails where all ingredients are in inventory
    final cocktails = <Cocktail>[];
    for (final row in result) {
      final cocktail = Cocktail.fromDb(row);
      final ingredients = await _getIngredientsForDrink(cocktail.id);

      // Check if all ingredients are in inventory
      final cocktailIngredients = ingredients
          .map((i) => i.ingredientName)
          .toSet();

      if (cocktailIngredients.every((ing) => userIngredients.contains(ing))) {
        cocktails.add(cocktail.copyWith(ingredients: ingredients));
      }
    }

    return cocktails;
  }

  // ==========================================
  // Favorites Operations
  // ==========================================

  /// Add cocktail to favorites
  Future<void> addToFavorites(String cocktailId, {String? notes}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'favorite_cocktails',
      {
        'cocktail_id': cocktailId,
        'added_at': now,
        'notes': notes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Remove cocktail from favorites
  Future<void> removeFromFavorites(String cocktailId) async {
    final db = await database;
    await db.delete(
      'favorite_cocktails',
      where: 'cocktail_id = ?',
      whereArgs: [cocktailId],
    );
  }

  /// Get all favorite cocktails
  Future<List<Map<String, dynamic>>> getFavorites() async {
    final db = await database;
    return await db.query(
      'favorite_cocktails',
      orderBy: 'added_at DESC',
    );
  }

  /// Check if cocktail is favorited
  Future<bool> isFavorite(String cocktailId) async {
    final db = await database;
    final result = await db.query(
      'favorite_cocktails',
      where: 'cocktail_id = ?',
      whereArgs: [cocktailId],
    );
    return result.isNotEmpty;
  }

  /// Get count of favorited cocktails
  Future<int> getFavoritesCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM favorite_cocktails');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get favorite cocktail IDs
  Future<List<String>> getFavoriteCocktailIds() async {
    final db = await database;
    final result = await db.query(
      'favorite_cocktails',
      columns: ['cocktail_id'],
      orderBy: 'added_at DESC',
    );
    return result.map((row) => row['cocktail_id'] as String).toList();
  }

  /// Update favorite notes
  Future<void> updateFavoriteNotes(String cocktailId, String? notes) async {
    final db = await database;
    await db.update(
      'favorite_cocktails',
      {'notes': notes},
      where: 'cocktail_id = ?',
      whereArgs: [cocktailId],
    );
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
