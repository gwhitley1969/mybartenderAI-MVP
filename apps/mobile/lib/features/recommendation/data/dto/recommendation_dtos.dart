import 'package:freezed_annotation/freezed_annotation.dart';

part 'recommendation_dtos.freezed.dart';
part 'recommendation_dtos.g.dart';

@freezed
class InventoryDto with _$InventoryDto {
  const factory InventoryDto({
    List<String>? spirits,
    List<String>? mixers,
  }) = _InventoryDto;

  factory InventoryDto.fromJson(Map<String, dynamic> json) =>
      _$InventoryDtoFromJson(json);
}

@freezed
class TasteProfileDto with _$TasteProfileDto {
  const factory TasteProfileDto({
    List<String>? preferredFlavors,
    List<String>? dislikedFlavors,
    String? abvRange,
  }) = _TasteProfileDto;

  factory TasteProfileDto.fromJson(Map<String, dynamic> json) =>
      _$TasteProfileDtoFromJson(json);
}

@freezed
class RecommendRequestDto with _$RecommendRequestDto {
  @JsonSerializable(explicitToJson: true)
  const factory RecommendRequestDto({
    required InventoryDto inventory,
    TasteProfileDto? tasteProfile,
  }) = _RecommendRequestDto;

  factory RecommendRequestDto.fromJson(Map<String, dynamic> json) =>
      _$RecommendRequestDtoFromJson(json);
}

@freezed
class RecommendationIngredientDto with _$RecommendationIngredientDto {
  const factory RecommendationIngredientDto({
    required String name,
    required double amount,
    required String unit,
  }) = _RecommendationIngredientDto;

  factory RecommendationIngredientDto.fromJson(Map<String, dynamic> json) =>
      _$RecommendationIngredientDtoFromJson(json);
}

@freezed
class RecommendationDto with _$RecommendationDto {
  @JsonSerializable(explicitToJson: true)
  const factory RecommendationDto({
    required String id,
    required String name,
    String? reason,
    required List<RecommendationIngredientDto> ingredients,
    required String instructions,
    String? glassware,
    String? garnish,
  }) = _RecommendationDto;

  factory RecommendationDto.fromJson(Map<String, dynamic> json) =>
      _$RecommendationDtoFromJson(json);
}

@freezed
class ErrorDto with _$ErrorDto {
  const factory ErrorDto({
    required String code,
    required String message,
    required String traceId,
    Map<String, dynamic>? details,
  }) = _ErrorDto;

  factory ErrorDto.fromJson(Map<String, dynamic> json) =>
      _$ErrorDtoFromJson(json);
}
