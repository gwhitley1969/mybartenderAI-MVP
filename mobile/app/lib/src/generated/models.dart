import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';
part 'models.g.dart';

@freezed
class Inventory with _$Inventory {
  const factory Inventory({List<String>? spirits, List<String>? mixers}) =
      _Inventory;

  factory Inventory.fromJson(Map<String, dynamic> json) =>
      _$InventoryFromJson(json);
}

@freezed
class TasteProfile with _$TasteProfile {
  const factory TasteProfile({
    List<String>? preferredFlavors,
    List<String>? dislikedFlavors,
    String? abvRange,
  }) = _TasteProfile;

  factory TasteProfile.fromJson(Map<String, dynamic> json) =>
      _$TasteProfileFromJson(json);
}

@freezed
class RecommendationIngredient with _$RecommendationIngredient {
  const factory RecommendationIngredient({
    required String name,
    required double amount,
    required String unit,
  }) = _RecommendationIngredient;

  factory RecommendationIngredient.fromJson(Map<String, dynamic> json) =>
      _$RecommendationIngredientFromJson(json);
}

@freezed
class Recommendation with _$Recommendation {
  @JsonSerializable(explicitToJson: true)
  const factory Recommendation({
    required String id,
    required String name,
    String? reason,
    required List<RecommendationIngredient> ingredients,
    required String instructions,
    String? glassware,
    String? garnish,
  }) = _Recommendation;

  factory Recommendation.fromJson(Map<String, dynamic> json) =>
      _$RecommendationFromJson(json);
}

@freezed
class SnapshotCounts with _$SnapshotCounts {
  const factory SnapshotCounts({
    int? drinks,
    int? ingredients,
    int? measures,
    int? categories,
    int? glasses,
  }) = _SnapshotCounts;

  factory SnapshotCounts.fromJson(Map<String, dynamic> json) =>
      _$SnapshotCountsFromJson(json);
}

@freezed
class SnapshotInfo with _$SnapshotInfo {
  @JsonSerializable(explicitToJson: true)
  const factory SnapshotInfo({
    required String schemaVersion,
    required String snapshotVersion,
    required int sizeBytes,
    required String sha256,
    required String signedUrl,
    required DateTime createdAtUtc,
    SnapshotCounts? counts,
  }) = _SnapshotInfo;

  factory SnapshotInfo.fromJson(Map<String, dynamic> json) =>
      _$SnapshotInfoFromJson(json);
}

@freezed
class ApiError with _$ApiError {
  const factory ApiError({
    required String code,
    required String message,
    required String traceId,
    Map<String, dynamic>? details,
  }) = _ApiError;

  factory ApiError.fromJson(Map<String, dynamic> json) =>
      _$ApiErrorFromJson(json);
}
