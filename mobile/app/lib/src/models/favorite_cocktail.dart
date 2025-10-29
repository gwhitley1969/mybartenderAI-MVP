class FavoriteCocktail {
  final int? id;
  final String cocktailId;
  final DateTime addedAt;
  final String? notes;

  FavoriteCocktail({
    this.id,
    required this.cocktailId,
    required this.addedAt,
    this.notes,
  });

  // Convert from database map
  factory FavoriteCocktail.fromDb(Map<String, dynamic> map) {
    return FavoriteCocktail(
      id: map['id'] as int?,
      cocktailId: map['cocktail_id'] as String,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
      notes: map['notes'] as String?,
    );
  }

  // Convert to database map
  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'cocktail_id': cocktailId,
      'added_at': addedAt.millisecondsSinceEpoch,
      'notes': notes,
    };
  }

  // CopyWith method for updates
  FavoriteCocktail copyWith({
    int? id,
    String? cocktailId,
    DateTime? addedAt,
    String? notes,
  }) {
    return FavoriteCocktail(
      id: id ?? this.id,
      cocktailId: cocktailId ?? this.cocktailId,
      addedAt: addedAt ?? this.addedAt,
      notes: notes ?? this.notes,
    );
  }
}
