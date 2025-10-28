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
        version: 1,
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
        version: 1,
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
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle schema migrations here if needed in future versions
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

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
