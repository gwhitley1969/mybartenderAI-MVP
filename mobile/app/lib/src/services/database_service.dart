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
        version: 3,
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
        version: 3,
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

    // Version 2 to 3: Add user_inventory table
    if (oldVersion < 3) {
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

      await db.execute('CREATE INDEX idx_inventory_name ON user_inventory(ingredient_name)');
    }
  }

  /// Ensure user-specific tables exist after snapshot import
  /// The backend snapshot only contains cocktail data, so we need to add user tables
  Future<void> ensureUserTablesExist() async {
    final db = await database;

    // Check if user_inventory table exists
    final inventoryTableExists = await _tableExists(db, 'user_inventory');
    if (!inventoryTableExists) {
      print('Creating user_inventory table...');
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
      await db.execute('CREATE INDEX idx_inventory_name ON user_inventory(ingredient_name)');
    }

    // Check if favorite_cocktails table exists
    final favoritesTableExists = await _tableExists(db, 'favorite_cocktails');
    if (!favoritesTableExists) {
      print('Creating favorite_cocktails table...');
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

  /// Helper method to check if a table exists
  Future<bool> _tableExists(Database db, String tableName) async {
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return result.isNotEmpty;
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

  /// Get a random cocktail (defaults to curated cocktails only)
  Future<Cocktail?> getRandomCocktail({bool includeCustom = false}) async {
    final db = await database;

    final String sql = '''
      SELECT *
      FROM drinks
      ${includeCustom ? '' : 'WHERE is_custom = 0'}
      ORDER BY RANDOM()
      LIMIT 1
    ''';

    final List<Map<String, dynamic>> result = await db.rawQuery(sql);

    if (result.isEmpty) {
      if (!includeCustom) {
        // Retry including custom cocktails as a fallback
        return getRandomCocktail(includeCustom: true);
      }
      return null;
    }

    final cocktailRow = result.first;
    final String cocktailId = cocktailRow['id'] as String;

    final List<Map<String, dynamic>> ingredientsResult = await db.query(
      'drink_ingredients',
      where: 'drink_id = ?',
      whereArgs: [cocktailId],
      orderBy: 'ingredient_order ASC',
    );

    final cocktail = Cocktail.fromDb(cocktailRow);
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
      where = 'd.name LIKE ? OR d.tags LIKE ?';
      whereArgs = ['%$searchQuery%', '%$searchQuery%'];
    }

    if (category != null) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'd.category = ?';
      whereArgs.add(category);
    }

    if (alcoholic != null) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'd.alcoholic = ?';
      whereArgs.add(alcoholic);
    }

    // Use a single query with JOIN to fetch drinks and ingredients together
    // This eliminates the N+1 query problem (was 1 + N queries, now just 1 query)
    final String sql = '''
      SELECT
        d.*,
        di.drink_id as ing_drink_id,
        di.ingredient_name,
        di.measure,
        di.ingredient_order
      FROM drinks d
      LEFT JOIN drink_ingredients di ON d.id = di.drink_id
      ${where.isNotEmpty ? 'WHERE $where' : ''}
      ORDER BY d.name ASC, di.ingredient_order ASC
      ${limit > 0 ? 'LIMIT $limit OFFSET $offset' : ''}
    ''';

    final List<Map<String, dynamic>> result = await db.rawQuery(
      sql,
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    // Group results by cocktail ID
    final Map<String, Cocktail> cocktailsMap = {};
    final Map<String, List<DrinkIngredient>> ingredientsMap = {};

    for (final row in result) {
      final cocktailId = row['id'] as String;

      // Create cocktail entry if not exists
      if (!cocktailsMap.containsKey(cocktailId)) {
        cocktailsMap[cocktailId] = Cocktail.fromDb(row);
        ingredientsMap[cocktailId] = [];
      }

      // Add ingredient if exists (LEFT JOIN may have null ingredients)
      if (row['ing_drink_id'] != null) {
        ingredientsMap[cocktailId]!.add(DrinkIngredient.fromDb({
          'drink_id': row['ing_drink_id'],
          'ingredient_name': row['ingredient_name'],
          'measure': row['measure'],
          'ingredient_order': row['ingredient_order'],
        }));
      }
    }

    // Combine cocktails with their ingredients
    final cocktails = <Cocktail>[];
    for (final entry in cocktailsMap.entries) {
      cocktails.add(entry.value.copyWith(ingredients: ingredientsMap[entry.key]!));
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

    // Build where clause for drink filters
    String drinkWhere = '';
    List<dynamic> whereArgs = [];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      drinkWhere = 'd.name LIKE ? OR d.tags LIKE ?';
      whereArgs = ['%$searchQuery%', '%$searchQuery%'];
    }

    if (category != null) {
      if (drinkWhere.isNotEmpty) drinkWhere += ' AND ';
      drinkWhere += 'd.category = ?';
      whereArgs.add(category);
    }

    if (alcoholic != null) {
      if (drinkWhere.isNotEmpty) drinkWhere += ' AND ';
      drinkWhere += 'd.alcoholic = ?';
      whereArgs.add(alcoholic);
    }

    // Use optimized SQL query that:
    // 1. JOINs drinks with ingredients in one query (eliminates N+1)
    // 2. Filters at database level using GROUP BY and HAVING (more efficient)
    final String sql = '''
      SELECT
        d.*,
        di.drink_id as ing_drink_id,
        di.ingredient_name,
        di.measure,
        di.ingredient_order
      FROM drinks d
      INNER JOIN drink_ingredients di ON d.id = di.drink_id
      ${drinkWhere.isNotEmpty ? 'WHERE $drinkWhere' : ''}
      AND d.id IN (
        SELECT drink_id
        FROM drink_ingredients
        GROUP BY drink_id
        HAVING COUNT(DISTINCT CASE
          WHEN ingredient_name IN (${userIngredients.map((_) => '?').join(',')})
          THEN ingredient_name
        END) = COUNT(DISTINCT ingredient_name)
      )
      ORDER BY d.name ASC, di.ingredient_order ASC
      ${limit > 0 ? 'LIMIT $limit' : ''}
    ''';

    // Add user ingredients to whereArgs for the IN clause
    whereArgs.addAll(userIngredients);

    final List<Map<String, dynamic>> result = await db.rawQuery(sql, whereArgs);

    // Group results by cocktail ID
    final Map<String, Cocktail> cocktailsMap = {};
    final Map<String, List<DrinkIngredient>> ingredientsMap = {};

    for (final row in result) {
      final cocktailId = row['id'] as String;

      // Create cocktail entry if not exists
      if (!cocktailsMap.containsKey(cocktailId)) {
        cocktailsMap[cocktailId] = Cocktail.fromDb(row);
        ingredientsMap[cocktailId] = [];
      }

      // Add ingredient
      ingredientsMap[cocktailId]!.add(DrinkIngredient.fromDb({
        'drink_id': row['ing_drink_id'],
        'ingredient_name': row['ingredient_name'],
        'measure': row['measure'],
        'ingredient_order': row['ingredient_order'],
      }));
    }

    // Combine cocktails with their ingredients
    final cocktails = <Cocktail>[];
    for (final entry in cocktailsMap.entries) {
      cocktails.add(entry.value.copyWith(ingredients: ingredientsMap[entry.key]!));
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

  // ==========================================
  // Custom Cocktail Operations
  // ==========================================

  /// Get all custom cocktails
  Future<List<Cocktail>> getCustomCocktails({
    String? searchQuery,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;

    // Build where clause
    String where = 'is_custom = 1';
    List<dynamic> whereArgs = [];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      where += ' AND (name LIKE ? OR tags LIKE ?)';
      whereArgs = ['%$searchQuery%', '%$searchQuery%'];
    }

    final List<Map<String, dynamic>> result = await db.query(
      'drinks',
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );

    final cocktails = <Cocktail>[];
    for (final row in result) {
      final cocktail = Cocktail.fromDb(row);
      final ingredients = await _getIngredientsForDrink(cocktail.id);
      cocktails.add(cocktail.copyWith(ingredients: ingredients));
    }

    return cocktails;
  }

  /// Get count of custom cocktails
  Future<int> getCustomCocktailCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM drinks WHERE is_custom = 1');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Update an existing custom cocktail
  Future<void> updateCustomCocktail(Cocktail cocktail) async {
    if (cocktail.isCustom != true) {
      throw ArgumentError('Can only update custom cocktails');
    }

    final db = await database;
    final now = DateTime.now().toIso8601String();

    // Update the drink record
    await db.update(
      'drinks',
      {
        'name': cocktail.name,
        'category': cocktail.category,
        'alcoholic': cocktail.alcoholic,
        'glass': cocktail.glass,
        'instructions': cocktail.instructions,
        'image_url': cocktail.imageUrl,
        'tags': cocktail.tags,
        'updated_at': now,
      },
      where: 'id = ? AND is_custom = 1',
      whereArgs: [cocktail.id],
    );

    // Delete existing ingredients
    await db.delete(
      'drink_ingredients',
      where: 'drink_id = ?',
      whereArgs: [cocktail.id],
    );

    // Insert updated ingredients
    if (cocktail.ingredients.isNotEmpty) {
      for (int i = 0; i < cocktail.ingredients.length; i++) {
        final ingredient = cocktail.ingredients[i];
        await db.insert(
          'drink_ingredients',
          {
            'drink_id': cocktail.id,
            'ingredient_name': ingredient.ingredientName,
            'measure': ingredient.measure,
            'ingredient_order': i + 1,
          },
        );
      }
    }
  }

  /// Delete a custom cocktail
  Future<void> deleteCustomCocktail(String cocktailId) async {
    final db = await database;

    // Verify it's a custom cocktail before deleting
    final result = await db.query(
      'drinks',
      where: 'id = ? AND is_custom = 1',
      whereArgs: [cocktailId],
    );

    if (result.isEmpty) {
      throw ArgumentError('Cocktail not found or is not a custom cocktail');
    }

    // Delete ingredients first (foreign key relationship)
    await db.delete(
      'drink_ingredients',
      where: 'drink_id = ?',
      whereArgs: [cocktailId],
    );

    // Delete the cocktail
    await db.delete(
      'drinks',
      where: 'id = ? AND is_custom = 1',
      whereArgs: [cocktailId],
    );

    // Remove from favorites if it was favorited
    await db.delete(
      'favorite_cocktails',
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
