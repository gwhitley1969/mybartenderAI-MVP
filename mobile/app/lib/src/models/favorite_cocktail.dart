import '../utils/db_type_helpers.dart';

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
      id: dbIntOrNull(map['id']),
      cocktailId: dbString(map['cocktail_id']),
      addedAt: DateTime.fromMillisecondsSinceEpoch(dbInt(map['added_at'])),
      notes: dbStringOrNull(map['notes']),
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
