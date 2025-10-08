
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recommendation_dtos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$InventoryDtoImpl _$$InventoryDtoImplFromJson(Map<String, dynamic> json) =>
    _$InventoryDtoImpl(
      spirits: (json['spirits'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      mixers: (json['mixers'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$$InventoryDtoImplToJson(_$InventoryDtoImpl instance) =>
    <String, dynamic>{
      'spirits': instance.spirits,
      'mixers': instance.mixers,
    };

_$TasteProfileDtoImpl _$$TasteProfileDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$TasteProfileDtoImpl(
      preferredFlavors: (json['preferredFlavors'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      dislikedFlavors: (json['dislikedFlavors'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      abvRange: json['abvRange'] as String?,
    );

Map<String, dynamic> _$$TasteProfileDtoImplToJson(
        _$TasteProfileDtoImpl instance) =>
    <String, dynamic>{
      'preferredFlavors': instance.preferredFlavors,
      'dislikedFlavors': instance.dislikedFlavors,
      'abvRange': instance.abvRange,
    };

_$RecommendRequestDtoImpl _$$RecommendRequestDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$RecommendRequestDtoImpl(
      inventory:
          InventoryDto.fromJson(json['inventory'] as Map<String, dynamic>),
      tasteProfile: json['tasteProfile'] == null
          ? null
          : TasteProfileDto.fromJson(
              json['tasteProfile'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$RecommendRequestDtoImplToJson(
        _$RecommendRequestDtoImpl instance) =>
    <String, dynamic>{
      'inventory': instance.inventory.toJson(),
      'tasteProfile': instance.tasteProfile?.toJson(),
    };

_$RecommendationIngredientDtoImpl _$$RecommendationIngredientDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$RecommendationIngredientDtoImpl(
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      unit: json['unit'] as String,
    );

Map<String, dynamic> _$$RecommendationIngredientDtoImplToJson(
        _$RecommendationIngredientDtoImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'amount': instance.amount,
      'unit': instance.unit,
    };

_$RecommendationDtoImpl _$$RecommendationDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$RecommendationDtoImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      reason: json['reason'] as String?,
      ingredients: (json['ingredients'] as List<dynamic>)
          .map((e) => RecommendationIngredientDto.fromJson(
              e as Map<String, dynamic>))
          .toList(),
      instructions: json['instructions'] as String,
      glassware: json['glassware'] as String?,
      garnish: json['garnish'] as String?,
    );

Map<String, dynamic> _$$RecommendationDtoImplToJson(
        _$RecommendationDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'reason': instance.reason,
      'ingredients': instance.ingredients.map((e) => e.toJson()).toList(),
      'instructions': instance.instructions,
      'glassware': instance.glassware,
      'garnish': instance.garnish,
    };

_$ErrorDtoImpl _$$ErrorDtoImplFromJson(Map<String, dynamic> json) =>
    _$ErrorDtoImpl(
      code: json['code'] as String,
      message: json['message'] as String,
      traceId: json['traceId'] as String,
      details: json['details'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$ErrorDtoImplToJson(_$ErrorDtoImpl instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
      'traceId': instance.traceId,
      'details': instance.details,
    };
