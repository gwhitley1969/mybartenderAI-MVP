// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$InventoryImpl _$$InventoryImplFromJson(Map<String, dynamic> json) =>
    _$InventoryImpl(
      spirits: (json['spirits'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      mixers: (json['mixers'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$$InventoryImplToJson(_$InventoryImpl instance) =>
    <String, dynamic>{'spirits': instance.spirits, 'mixers': instance.mixers};

_$TasteProfileImpl _$$TasteProfileImplFromJson(Map<String, dynamic> json) =>
    _$TasteProfileImpl(
      preferredFlavors: (json['preferredFlavors'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      dislikedFlavors: (json['dislikedFlavors'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      abvRange: json['abvRange'] as String?,
    );

Map<String, dynamic> _$$TasteProfileImplToJson(_$TasteProfileImpl instance) =>
    <String, dynamic>{
      'preferredFlavors': instance.preferredFlavors,
      'dislikedFlavors': instance.dislikedFlavors,
      'abvRange': instance.abvRange,
    };

_$RecommendationIngredientImpl _$$RecommendationIngredientImplFromJson(
  Map<String, dynamic> json,
) => _$RecommendationIngredientImpl(
  name: json['name'] as String,
  amount: (json['amount'] as num).toDouble(),
  unit: json['unit'] as String,
);

Map<String, dynamic> _$$RecommendationIngredientImplToJson(
  _$RecommendationIngredientImpl instance,
) => <String, dynamic>{
  'name': instance.name,
  'amount': instance.amount,
  'unit': instance.unit,
};

_$RecommendationImpl _$$RecommendationImplFromJson(Map<String, dynamic> json) =>
    _$RecommendationImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      reason: json['reason'] as String?,
      ingredients: (json['ingredients'] as List<dynamic>)
          .map(
            (e) => RecommendationIngredient.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      instructions: json['instructions'] as String,
      glassware: json['glassware'] as String?,
      garnish: json['garnish'] as String?,
    );

Map<String, dynamic> _$$RecommendationImplToJson(
  _$RecommendationImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'reason': instance.reason,
  'ingredients': instance.ingredients.map((e) => e.toJson()).toList(),
  'instructions': instance.instructions,
  'glassware': instance.glassware,
  'garnish': instance.garnish,
};

_$SnapshotCountsImpl _$$SnapshotCountsImplFromJson(Map<String, dynamic> json) =>
    _$SnapshotCountsImpl(
      drinks: (json['drinks'] as num?)?.toInt(),
      ingredients: (json['ingredients'] as num?)?.toInt(),
      measures: (json['measures'] as num?)?.toInt(),
      categories: (json['categories'] as num?)?.toInt(),
      glasses: (json['glasses'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$SnapshotCountsImplToJson(
  _$SnapshotCountsImpl instance,
) => <String, dynamic>{
  'drinks': instance.drinks,
  'ingredients': instance.ingredients,
  'measures': instance.measures,
  'categories': instance.categories,
  'glasses': instance.glasses,
};

_$SnapshotInfoImpl _$$SnapshotInfoImplFromJson(Map<String, dynamic> json) =>
    _$SnapshotInfoImpl(
      schemaVersion: json['schemaVersion'] as String,
      snapshotVersion: json['snapshotVersion'] as String,
      sizeBytes: (json['sizeBytes'] as num).toInt(),
      sha256: json['sha256'] as String,
      signedUrl: json['signedUrl'] as String,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      counts: json['counts'] == null
          ? null
          : SnapshotCounts.fromJson(json['counts'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$SnapshotInfoImplToJson(_$SnapshotInfoImpl instance) =>
    <String, dynamic>{
      'schemaVersion': instance.schemaVersion,
      'snapshotVersion': instance.snapshotVersion,
      'sizeBytes': instance.sizeBytes,
      'sha256': instance.sha256,
      'signedUrl': instance.signedUrl,
      'createdAtUtc': instance.createdAtUtc.toIso8601String(),
      'counts': instance.counts?.toJson(),
    };

_$ApiErrorImpl _$$ApiErrorImplFromJson(Map<String, dynamic> json) =>
    _$ApiErrorImpl(
      code: json['code'] as String,
      message: json['message'] as String,
      traceId: json['traceId'] as String,
      details: json['details'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$ApiErrorImplToJson(_$ApiErrorImpl instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
      'traceId': instance.traceId,
      'details': instance.details,
    };
