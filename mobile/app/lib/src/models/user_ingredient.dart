/// User-owned ingredient in their bar inventory
class UserIngredient {
  final int? id;
  final String ingredientName;
  final String? category;
  final String? notes;
  final DateTime addedAt;
  final DateTime updatedAt;

  const UserIngredient({
    this.id,
    required this.ingredientName,
    this.category,
    this.notes,
    required this.addedAt,
    required this.updatedAt,
  });

  /// Create from database row
  factory UserIngredient.fromDb(Map<String, dynamic> map) {
    return UserIngredient(
      id: map['id'] as int?,
      ingredientName: map['ingredient_name'] as String,
      category: map['category'] as String?,
      notes: map['notes'] as String?,
      addedAt: DateTime.parse(map['added_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Convert to database row
  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'ingredient_name': ingredientName,
      'category': category,
      'notes': notes,
      'added_at': addedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Copy with modifications
  UserIngredient copyWith({
    int? id,
    String? ingredientName,
    String? category,
    String? notes,
    DateTime? addedAt,
    DateTime? updatedAt,
  }) {
    return UserIngredient(
      id: id ?? this.id,
      ingredientName: ingredientName ?? this.ingredientName,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserIngredient &&
        other.id == id &&
        other.ingredientName == ingredientName &&
        other.category == category &&
        other.notes == notes &&
        other.addedAt == addedAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      ingredientName,
      category,
      notes,
      addedAt,
      updatedAt,
    );
  }
}
