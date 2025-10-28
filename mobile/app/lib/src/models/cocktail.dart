/// Cocktail data model matching backend schema
class Cocktail {
  final String id;
  final String name;
  final String? alternateName;
  final String? category;
  final String? glass;
  final String? instructions;
  final String? instructionsEs;
  final String? instructionsDe;
  final String? instructionsFr;
  final String? instructionsIt;
  final String? imageUrl;
  final String? imageAttribution;
  final List<String> tags;
  final String? videoUrl;
  final String? iba;
  final String? alcoholic;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String source;
  final bool isCustom;
  final List<DrinkIngredient> ingredients;

  const Cocktail({
    required this.id,
    required this.name,
    this.alternateName,
    this.category,
    this.glass,
    this.instructions,
    this.instructionsEs,
    this.instructionsDe,
    this.instructionsFr,
    this.instructionsIt,
    this.imageUrl,
    this.imageAttribution,
    this.tags = const [],
    this.videoUrl,
    this.iba,
    this.alcoholic,
    required this.createdAt,
    required this.updatedAt,
    this.source = 'thecocktaildb',
    this.isCustom = false,
    this.ingredients = const [],
  });

  /// Create from JSON (backend API response)
  factory Cocktail.fromJson(Map<String, dynamic> json) {
    return Cocktail(
      id: json['id'] as String,
      name: json['name'] as String,
      alternateName: json['alternate_name'] as String?,
      category: json['category'] as String?,
      glass: json['glass'] as String?,
      instructions: json['instructions'] as String?,
      instructionsEs: json['instructions_es'] as String?,
      instructionsDe: json['instructions_de'] as String?,
      instructionsFr: json['instructions_fr'] as String?,
      instructionsIt: json['instructions_it'] as String?,
      imageUrl: json['image_url'] as String?,
      imageAttribution: json['image_attribution'] as String?,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : [],
      videoUrl: json['video_url'] as String?,
      iba: json['iba'] as String?,
      alcoholic: json['alcoholic'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      source: json['source'] as String? ?? 'thecocktaildb',
      isCustom: json['is_custom'] as bool? ?? false,
      ingredients: json['ingredients'] != null
          ? (json['ingredients'] as List)
              .map((i) => DrinkIngredient.fromJson(i as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  /// Create from SQLite database row
  factory Cocktail.fromDb(Map<String, dynamic> row) {
    return Cocktail(
      id: row['id'] as String,
      name: row['name'] as String,
      alternateName: row['alternate_name'] as String?,
      category: row['category'] as String?,
      glass: row['glass'] as String?,
      instructions: row['instructions'] as String?,
      instructionsEs: row['instructions_es'] as String?,
      instructionsDe: row['instructions_de'] as String?,
      instructionsFr: row['instructions_fr'] as String?,
      instructionsIt: row['instructions_it'] as String?,
      imageUrl: row['image_url'] as String?,
      imageAttribution: row['image_attribution'] as String?,
      tags: row['tags'] != null
          ? (row['tags'] as String).split(',').where((t) => t.isNotEmpty).toList()
          : [],
      videoUrl: row['video_url'] as String?,
      iba: row['iba'] as String?,
      alcoholic: row['alcoholic'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      source: row['source'] as String? ?? 'thecocktaildb',
      isCustom: (row['is_custom'] as int?) == 1,
      ingredients: [], // Populated separately via join
    );
  }

  /// Convert to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'alternate_name': alternateName,
      'category': category,
      'glass': glass,
      'instructions': instructions,
      'instructions_es': instructionsEs,
      'instructions_de': instructionsDe,
      'instructions_fr': instructionsFr,
      'instructions_it': instructionsIt,
      'image_url': imageUrl,
      'image_attribution': imageAttribution,
      'tags': tags,
      'video_url': videoUrl,
      'iba': iba,
      'alcoholic': alcoholic,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'source': source,
      'is_custom': isCustom,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
    };
  }

  /// Convert to SQLite database row
  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'name': name,
      'alternate_name': alternateName,
      'category': category,
      'glass': glass,
      'instructions': instructions,
      'instructions_es': instructionsEs,
      'instructions_de': instructionsDe,
      'instructions_fr': instructionsFr,
      'instructions_it': instructionsIt,
      'image_url': imageUrl,
      'image_attribution': imageAttribution,
      'tags': tags.join(','),
      'video_url': videoUrl,
      'iba': iba,
      'alcoholic': alcoholic,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'source': source,
      'is_custom': isCustom ? 1 : 0,
    };
  }

  /// Copy with new values
  Cocktail copyWith({
    String? id,
    String? name,
    String? alternateName,
    String? category,
    String? glass,
    String? instructions,
    String? instructionsEs,
    String? instructionsDe,
    String? instructionsFr,
    String? instructionsIt,
    String? imageUrl,
    String? imageAttribution,
    List<String>? tags,
    String? videoUrl,
    String? iba,
    String? alcoholic,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? source,
    bool? isCustom,
    List<DrinkIngredient>? ingredients,
  }) {
    return Cocktail(
      id: id ?? this.id,
      name: name ?? this.name,
      alternateName: alternateName ?? this.alternateName,
      category: category ?? this.category,
      glass: glass ?? this.glass,
      instructions: instructions ?? this.instructions,
      instructionsEs: instructionsEs ?? this.instructionsEs,
      instructionsDe: instructionsDe ?? this.instructionsDe,
      instructionsFr: instructionsFr ?? this.instructionsFr,
      instructionsIt: instructionsIt ?? this.instructionsIt,
      imageUrl: imageUrl ?? this.imageUrl,
      imageAttribution: imageAttribution ?? this.imageAttribution,
      tags: tags ?? this.tags,
      videoUrl: videoUrl ?? this.videoUrl,
      iba: iba ?? this.iba,
      alcoholic: alcoholic ?? this.alcoholic,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
      isCustom: isCustom ?? this.isCustom,
      ingredients: ingredients ?? this.ingredients,
    );
  }

  @override
  String toString() {
    return 'Cocktail(id: $id, name: $name, category: $category, ingredients: ${ingredients.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Cocktail && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Drink ingredient model matching backend schema
class DrinkIngredient {
  final int? id;
  final String drinkId;
  final String ingredientName;
  final String? measure;
  final int ingredientOrder;

  const DrinkIngredient({
    this.id,
    required this.drinkId,
    required this.ingredientName,
    this.measure,
    required this.ingredientOrder,
  });

  factory DrinkIngredient.fromJson(Map<String, dynamic> json) {
    return DrinkIngredient(
      id: json['id'] as int?,
      drinkId: json['drink_id'] as String,
      ingredientName: json['ingredient_name'] as String,
      measure: json['measure'] as String?,
      ingredientOrder: json['ingredient_order'] as int,
    );
  }

  factory DrinkIngredient.fromDb(Map<String, dynamic> row) {
    return DrinkIngredient(
      id: row['id'] as int?,
      drinkId: row['drink_id'] as String,
      ingredientName: row['ingredient_name'] as String,
      measure: row['measure'] as String?,
      ingredientOrder: row['ingredient_order'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'drink_id': drinkId,
      'ingredient_name': ingredientName,
      'measure': measure,
      'ingredient_order': ingredientOrder,
    };
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'drink_id': drinkId,
      'ingredient_name': ingredientName,
      'measure': measure,
      'ingredient_order': ingredientOrder,
    };
  }

  @override
  String toString() {
    return 'DrinkIngredient(ingredientName: $ingredientName, measure: $measure)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DrinkIngredient &&
        other.drinkId == drinkId &&
        other.ingredientName == ingredientName &&
        other.ingredientOrder == ingredientOrder;
  }

  @override
  int get hashCode =>
      drinkId.hashCode ^ ingredientName.hashCode ^ ingredientOrder.hashCode;
}
