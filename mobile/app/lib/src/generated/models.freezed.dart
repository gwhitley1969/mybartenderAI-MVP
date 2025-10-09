// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Inventory _$InventoryFromJson(Map<String, dynamic> json) {
  return _Inventory.fromJson(json);
}

/// @nodoc
mixin _$Inventory {
  List<String>? get spirits => throw _privateConstructorUsedError;
  List<String>? get mixers => throw _privateConstructorUsedError;

  /// Serializes this Inventory to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Inventory
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $InventoryCopyWith<Inventory> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InventoryCopyWith<$Res> {
  factory $InventoryCopyWith(Inventory value, $Res Function(Inventory) then) =
      _$InventoryCopyWithImpl<$Res, Inventory>;
  @useResult
  $Res call({List<String>? spirits, List<String>? mixers});
}

/// @nodoc
class _$InventoryCopyWithImpl<$Res, $Val extends Inventory>
    implements $InventoryCopyWith<$Res> {
  _$InventoryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Inventory
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? spirits = freezed, Object? mixers = freezed}) {
    return _then(
      _value.copyWith(
            spirits: freezed == spirits
                ? _value.spirits
                : spirits // ignore: cast_nullable_to_non_nullable
                      as List<String>?,
            mixers: freezed == mixers
                ? _value.mixers
                : mixers // ignore: cast_nullable_to_non_nullable
                      as List<String>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$InventoryImplCopyWith<$Res>
    implements $InventoryCopyWith<$Res> {
  factory _$$InventoryImplCopyWith(
    _$InventoryImpl value,
    $Res Function(_$InventoryImpl) then,
  ) = __$$InventoryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<String>? spirits, List<String>? mixers});
}

/// @nodoc
class __$$InventoryImplCopyWithImpl<$Res>
    extends _$InventoryCopyWithImpl<$Res, _$InventoryImpl>
    implements _$$InventoryImplCopyWith<$Res> {
  __$$InventoryImplCopyWithImpl(
    _$InventoryImpl _value,
    $Res Function(_$InventoryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Inventory
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? spirits = freezed, Object? mixers = freezed}) {
    return _then(
      _$InventoryImpl(
        spirits: freezed == spirits
            ? _value._spirits
            : spirits // ignore: cast_nullable_to_non_nullable
                  as List<String>?,
        mixers: freezed == mixers
            ? _value._mixers
            : mixers // ignore: cast_nullable_to_non_nullable
                  as List<String>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$InventoryImpl implements _Inventory {
  const _$InventoryImpl({
    final List<String>? spirits,
    final List<String>? mixers,
  }) : _spirits = spirits,
       _mixers = mixers;

  factory _$InventoryImpl.fromJson(Map<String, dynamic> json) =>
      _$$InventoryImplFromJson(json);

  final List<String>? _spirits;
  @override
  List<String>? get spirits {
    final value = _spirits;
    if (value == null) return null;
    if (_spirits is EqualUnmodifiableListView) return _spirits;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<String>? _mixers;
  @override
  List<String>? get mixers {
    final value = _mixers;
    if (value == null) return null;
    if (_mixers is EqualUnmodifiableListView) return _mixers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'Inventory(spirits: $spirits, mixers: $mixers)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InventoryImpl &&
            const DeepCollectionEquality().equals(other._spirits, _spirits) &&
            const DeepCollectionEquality().equals(other._mixers, _mixers));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_spirits),
    const DeepCollectionEquality().hash(_mixers),
  );

  /// Create a copy of Inventory
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InventoryImplCopyWith<_$InventoryImpl> get copyWith =>
      __$$InventoryImplCopyWithImpl<_$InventoryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$InventoryImplToJson(this);
  }
}

abstract class _Inventory implements Inventory {
  const factory _Inventory({
    final List<String>? spirits,
    final List<String>? mixers,
  }) = _$InventoryImpl;

  factory _Inventory.fromJson(Map<String, dynamic> json) =
      _$InventoryImpl.fromJson;

  @override
  List<String>? get spirits;
  @override
  List<String>? get mixers;

  /// Create a copy of Inventory
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InventoryImplCopyWith<_$InventoryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TasteProfile _$TasteProfileFromJson(Map<String, dynamic> json) {
  return _TasteProfile.fromJson(json);
}

/// @nodoc
mixin _$TasteProfile {
  List<String>? get preferredFlavors => throw _privateConstructorUsedError;
  List<String>? get dislikedFlavors => throw _privateConstructorUsedError;
  String? get abvRange => throw _privateConstructorUsedError;

  /// Serializes this TasteProfile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TasteProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TasteProfileCopyWith<TasteProfile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TasteProfileCopyWith<$Res> {
  factory $TasteProfileCopyWith(
    TasteProfile value,
    $Res Function(TasteProfile) then,
  ) = _$TasteProfileCopyWithImpl<$Res, TasteProfile>;
  @useResult
  $Res call({
    List<String>? preferredFlavors,
    List<String>? dislikedFlavors,
    String? abvRange,
  });
}

/// @nodoc
class _$TasteProfileCopyWithImpl<$Res, $Val extends TasteProfile>
    implements $TasteProfileCopyWith<$Res> {
  _$TasteProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TasteProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? preferredFlavors = freezed,
    Object? dislikedFlavors = freezed,
    Object? abvRange = freezed,
  }) {
    return _then(
      _value.copyWith(
            preferredFlavors: freezed == preferredFlavors
                ? _value.preferredFlavors
                : preferredFlavors // ignore: cast_nullable_to_non_nullable
                      as List<String>?,
            dislikedFlavors: freezed == dislikedFlavors
                ? _value.dislikedFlavors
                : dislikedFlavors // ignore: cast_nullable_to_non_nullable
                      as List<String>?,
            abvRange: freezed == abvRange
                ? _value.abvRange
                : abvRange // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TasteProfileImplCopyWith<$Res>
    implements $TasteProfileCopyWith<$Res> {
  factory _$$TasteProfileImplCopyWith(
    _$TasteProfileImpl value,
    $Res Function(_$TasteProfileImpl) then,
  ) = __$$TasteProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<String>? preferredFlavors,
    List<String>? dislikedFlavors,
    String? abvRange,
  });
}

/// @nodoc
class __$$TasteProfileImplCopyWithImpl<$Res>
    extends _$TasteProfileCopyWithImpl<$Res, _$TasteProfileImpl>
    implements _$$TasteProfileImplCopyWith<$Res> {
  __$$TasteProfileImplCopyWithImpl(
    _$TasteProfileImpl _value,
    $Res Function(_$TasteProfileImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TasteProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? preferredFlavors = freezed,
    Object? dislikedFlavors = freezed,
    Object? abvRange = freezed,
  }) {
    return _then(
      _$TasteProfileImpl(
        preferredFlavors: freezed == preferredFlavors
            ? _value._preferredFlavors
            : preferredFlavors // ignore: cast_nullable_to_non_nullable
                  as List<String>?,
        dislikedFlavors: freezed == dislikedFlavors
            ? _value._dislikedFlavors
            : dislikedFlavors // ignore: cast_nullable_to_non_nullable
                  as List<String>?,
        abvRange: freezed == abvRange
            ? _value.abvRange
            : abvRange // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TasteProfileImpl implements _TasteProfile {
  const _$TasteProfileImpl({
    final List<String>? preferredFlavors,
    final List<String>? dislikedFlavors,
    this.abvRange,
  }) : _preferredFlavors = preferredFlavors,
       _dislikedFlavors = dislikedFlavors;

  factory _$TasteProfileImpl.fromJson(Map<String, dynamic> json) =>
      _$$TasteProfileImplFromJson(json);

  final List<String>? _preferredFlavors;
  @override
  List<String>? get preferredFlavors {
    final value = _preferredFlavors;
    if (value == null) return null;
    if (_preferredFlavors is EqualUnmodifiableListView)
      return _preferredFlavors;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<String>? _dislikedFlavors;
  @override
  List<String>? get dislikedFlavors {
    final value = _dislikedFlavors;
    if (value == null) return null;
    if (_dislikedFlavors is EqualUnmodifiableListView) return _dislikedFlavors;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final String? abvRange;

  @override
  String toString() {
    return 'TasteProfile(preferredFlavors: $preferredFlavors, dislikedFlavors: $dislikedFlavors, abvRange: $abvRange)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TasteProfileImpl &&
            const DeepCollectionEquality().equals(
              other._preferredFlavors,
              _preferredFlavors,
            ) &&
            const DeepCollectionEquality().equals(
              other._dislikedFlavors,
              _dislikedFlavors,
            ) &&
            (identical(other.abvRange, abvRange) ||
                other.abvRange == abvRange));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_preferredFlavors),
    const DeepCollectionEquality().hash(_dislikedFlavors),
    abvRange,
  );

  /// Create a copy of TasteProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TasteProfileImplCopyWith<_$TasteProfileImpl> get copyWith =>
      __$$TasteProfileImplCopyWithImpl<_$TasteProfileImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TasteProfileImplToJson(this);
  }
}

abstract class _TasteProfile implements TasteProfile {
  const factory _TasteProfile({
    final List<String>? preferredFlavors,
    final List<String>? dislikedFlavors,
    final String? abvRange,
  }) = _$TasteProfileImpl;

  factory _TasteProfile.fromJson(Map<String, dynamic> json) =
      _$TasteProfileImpl.fromJson;

  @override
  List<String>? get preferredFlavors;
  @override
  List<String>? get dislikedFlavors;
  @override
  String? get abvRange;

  /// Create a copy of TasteProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TasteProfileImplCopyWith<_$TasteProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RecommendationIngredient _$RecommendationIngredientFromJson(
  Map<String, dynamic> json,
) {
  return _RecommendationIngredient.fromJson(json);
}

/// @nodoc
mixin _$RecommendationIngredient {
  String get name => throw _privateConstructorUsedError;
  double get amount => throw _privateConstructorUsedError;
  String get unit => throw _privateConstructorUsedError;

  /// Serializes this RecommendationIngredient to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RecommendationIngredient
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecommendationIngredientCopyWith<RecommendationIngredient> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecommendationIngredientCopyWith<$Res> {
  factory $RecommendationIngredientCopyWith(
    RecommendationIngredient value,
    $Res Function(RecommendationIngredient) then,
  ) = _$RecommendationIngredientCopyWithImpl<$Res, RecommendationIngredient>;
  @useResult
  $Res call({String name, double amount, String unit});
}

/// @nodoc
class _$RecommendationIngredientCopyWithImpl<
  $Res,
  $Val extends RecommendationIngredient
>
    implements $RecommendationIngredientCopyWith<$Res> {
  _$RecommendationIngredientCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecommendationIngredient
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? name = null, Object? amount = null, Object? unit = null}) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as double,
            unit: null == unit
                ? _value.unit
                : unit // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecommendationIngredientImplCopyWith<$Res>
    implements $RecommendationIngredientCopyWith<$Res> {
  factory _$$RecommendationIngredientImplCopyWith(
    _$RecommendationIngredientImpl value,
    $Res Function(_$RecommendationIngredientImpl) then,
  ) = __$$RecommendationIngredientImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, double amount, String unit});
}

/// @nodoc
class __$$RecommendationIngredientImplCopyWithImpl<$Res>
    extends
        _$RecommendationIngredientCopyWithImpl<
          $Res,
          _$RecommendationIngredientImpl
        >
    implements _$$RecommendationIngredientImplCopyWith<$Res> {
  __$$RecommendationIngredientImplCopyWithImpl(
    _$RecommendationIngredientImpl _value,
    $Res Function(_$RecommendationIngredientImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecommendationIngredient
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? name = null, Object? amount = null, Object? unit = null}) {
    return _then(
      _$RecommendationIngredientImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as double,
        unit: null == unit
            ? _value.unit
            : unit // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RecommendationIngredientImpl implements _RecommendationIngredient {
  const _$RecommendationIngredientImpl({
    required this.name,
    required this.amount,
    required this.unit,
  });

  factory _$RecommendationIngredientImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecommendationIngredientImplFromJson(json);

  @override
  final String name;
  @override
  final double amount;
  @override
  final String unit;

  @override
  String toString() {
    return 'RecommendationIngredient(name: $name, amount: $amount, unit: $unit)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecommendationIngredientImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.unit, unit) || other.unit == unit));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, amount, unit);

  /// Create a copy of RecommendationIngredient
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecommendationIngredientImplCopyWith<_$RecommendationIngredientImpl>
  get copyWith =>
      __$$RecommendationIngredientImplCopyWithImpl<
        _$RecommendationIngredientImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RecommendationIngredientImplToJson(this);
  }
}

abstract class _RecommendationIngredient implements RecommendationIngredient {
  const factory _RecommendationIngredient({
    required final String name,
    required final double amount,
    required final String unit,
  }) = _$RecommendationIngredientImpl;

  factory _RecommendationIngredient.fromJson(Map<String, dynamic> json) =
      _$RecommendationIngredientImpl.fromJson;

  @override
  String get name;
  @override
  double get amount;
  @override
  String get unit;

  /// Create a copy of RecommendationIngredient
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecommendationIngredientImplCopyWith<_$RecommendationIngredientImpl>
  get copyWith => throw _privateConstructorUsedError;
}

Recommendation _$RecommendationFromJson(Map<String, dynamic> json) {
  return _Recommendation.fromJson(json);
}

/// @nodoc
mixin _$Recommendation {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get reason => throw _privateConstructorUsedError;
  List<RecommendationIngredient> get ingredients =>
      throw _privateConstructorUsedError;
  String get instructions => throw _privateConstructorUsedError;
  String? get glassware => throw _privateConstructorUsedError;
  String? get garnish => throw _privateConstructorUsedError;

  /// Serializes this Recommendation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Recommendation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecommendationCopyWith<Recommendation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecommendationCopyWith<$Res> {
  factory $RecommendationCopyWith(
    Recommendation value,
    $Res Function(Recommendation) then,
  ) = _$RecommendationCopyWithImpl<$Res, Recommendation>;
  @useResult
  $Res call({
    String id,
    String name,
    String? reason,
    List<RecommendationIngredient> ingredients,
    String instructions,
    String? glassware,
    String? garnish,
  });
}

/// @nodoc
class _$RecommendationCopyWithImpl<$Res, $Val extends Recommendation>
    implements $RecommendationCopyWith<$Res> {
  _$RecommendationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Recommendation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? reason = freezed,
    Object? ingredients = null,
    Object? instructions = null,
    Object? glassware = freezed,
    Object? garnish = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            reason: freezed == reason
                ? _value.reason
                : reason // ignore: cast_nullable_to_non_nullable
                      as String?,
            ingredients: null == ingredients
                ? _value.ingredients
                : ingredients // ignore: cast_nullable_to_non_nullable
                      as List<RecommendationIngredient>,
            instructions: null == instructions
                ? _value.instructions
                : instructions // ignore: cast_nullable_to_non_nullable
                      as String,
            glassware: freezed == glassware
                ? _value.glassware
                : glassware // ignore: cast_nullable_to_non_nullable
                      as String?,
            garnish: freezed == garnish
                ? _value.garnish
                : garnish // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecommendationImplCopyWith<$Res>
    implements $RecommendationCopyWith<$Res> {
  factory _$$RecommendationImplCopyWith(
    _$RecommendationImpl value,
    $Res Function(_$RecommendationImpl) then,
  ) = __$$RecommendationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String? reason,
    List<RecommendationIngredient> ingredients,
    String instructions,
    String? glassware,
    String? garnish,
  });
}

/// @nodoc
class __$$RecommendationImplCopyWithImpl<$Res>
    extends _$RecommendationCopyWithImpl<$Res, _$RecommendationImpl>
    implements _$$RecommendationImplCopyWith<$Res> {
  __$$RecommendationImplCopyWithImpl(
    _$RecommendationImpl _value,
    $Res Function(_$RecommendationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Recommendation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? reason = freezed,
    Object? ingredients = null,
    Object? instructions = null,
    Object? glassware = freezed,
    Object? garnish = freezed,
  }) {
    return _then(
      _$RecommendationImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        reason: freezed == reason
            ? _value.reason
            : reason // ignore: cast_nullable_to_non_nullable
                  as String?,
        ingredients: null == ingredients
            ? _value._ingredients
            : ingredients // ignore: cast_nullable_to_non_nullable
                  as List<RecommendationIngredient>,
        instructions: null == instructions
            ? _value.instructions
            : instructions // ignore: cast_nullable_to_non_nullable
                  as String,
        glassware: freezed == glassware
            ? _value.glassware
            : glassware // ignore: cast_nullable_to_non_nullable
                  as String?,
        garnish: freezed == garnish
            ? _value.garnish
            : garnish // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _$RecommendationImpl implements _Recommendation {
  const _$RecommendationImpl({
    required this.id,
    required this.name,
    this.reason,
    required final List<RecommendationIngredient> ingredients,
    required this.instructions,
    this.glassware,
    this.garnish,
  }) : _ingredients = ingredients;

  factory _$RecommendationImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecommendationImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? reason;
  final List<RecommendationIngredient> _ingredients;
  @override
  List<RecommendationIngredient> get ingredients {
    if (_ingredients is EqualUnmodifiableListView) return _ingredients;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_ingredients);
  }

  @override
  final String instructions;
  @override
  final String? glassware;
  @override
  final String? garnish;

  @override
  String toString() {
    return 'Recommendation(id: $id, name: $name, reason: $reason, ingredients: $ingredients, instructions: $instructions, glassware: $glassware, garnish: $garnish)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecommendationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            const DeepCollectionEquality().equals(
              other._ingredients,
              _ingredients,
            ) &&
            (identical(other.instructions, instructions) ||
                other.instructions == instructions) &&
            (identical(other.glassware, glassware) ||
                other.glassware == glassware) &&
            (identical(other.garnish, garnish) || other.garnish == garnish));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    reason,
    const DeepCollectionEquality().hash(_ingredients),
    instructions,
    glassware,
    garnish,
  );

  /// Create a copy of Recommendation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecommendationImplCopyWith<_$RecommendationImpl> get copyWith =>
      __$$RecommendationImplCopyWithImpl<_$RecommendationImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RecommendationImplToJson(this);
  }
}

abstract class _Recommendation implements Recommendation {
  const factory _Recommendation({
    required final String id,
    required final String name,
    final String? reason,
    required final List<RecommendationIngredient> ingredients,
    required final String instructions,
    final String? glassware,
    final String? garnish,
  }) = _$RecommendationImpl;

  factory _Recommendation.fromJson(Map<String, dynamic> json) =
      _$RecommendationImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get reason;
  @override
  List<RecommendationIngredient> get ingredients;
  @override
  String get instructions;
  @override
  String? get glassware;
  @override
  String? get garnish;

  /// Create a copy of Recommendation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecommendationImplCopyWith<_$RecommendationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SnapshotCounts _$SnapshotCountsFromJson(Map<String, dynamic> json) {
  return _SnapshotCounts.fromJson(json);
}

/// @nodoc
mixin _$SnapshotCounts {
  int? get drinks => throw _privateConstructorUsedError;
  int? get ingredients => throw _privateConstructorUsedError;
  int? get measures => throw _privateConstructorUsedError;
  int? get categories => throw _privateConstructorUsedError;
  int? get glasses => throw _privateConstructorUsedError;

  /// Serializes this SnapshotCounts to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SnapshotCounts
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SnapshotCountsCopyWith<SnapshotCounts> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SnapshotCountsCopyWith<$Res> {
  factory $SnapshotCountsCopyWith(
    SnapshotCounts value,
    $Res Function(SnapshotCounts) then,
  ) = _$SnapshotCountsCopyWithImpl<$Res, SnapshotCounts>;
  @useResult
  $Res call({
    int? drinks,
    int? ingredients,
    int? measures,
    int? categories,
    int? glasses,
  });
}

/// @nodoc
class _$SnapshotCountsCopyWithImpl<$Res, $Val extends SnapshotCounts>
    implements $SnapshotCountsCopyWith<$Res> {
  _$SnapshotCountsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SnapshotCounts
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? drinks = freezed,
    Object? ingredients = freezed,
    Object? measures = freezed,
    Object? categories = freezed,
    Object? glasses = freezed,
  }) {
    return _then(
      _value.copyWith(
            drinks: freezed == drinks
                ? _value.drinks
                : drinks // ignore: cast_nullable_to_non_nullable
                      as int?,
            ingredients: freezed == ingredients
                ? _value.ingredients
                : ingredients // ignore: cast_nullable_to_non_nullable
                      as int?,
            measures: freezed == measures
                ? _value.measures
                : measures // ignore: cast_nullable_to_non_nullable
                      as int?,
            categories: freezed == categories
                ? _value.categories
                : categories // ignore: cast_nullable_to_non_nullable
                      as int?,
            glasses: freezed == glasses
                ? _value.glasses
                : glasses // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SnapshotCountsImplCopyWith<$Res>
    implements $SnapshotCountsCopyWith<$Res> {
  factory _$$SnapshotCountsImplCopyWith(
    _$SnapshotCountsImpl value,
    $Res Function(_$SnapshotCountsImpl) then,
  ) = __$$SnapshotCountsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int? drinks,
    int? ingredients,
    int? measures,
    int? categories,
    int? glasses,
  });
}

/// @nodoc
class __$$SnapshotCountsImplCopyWithImpl<$Res>
    extends _$SnapshotCountsCopyWithImpl<$Res, _$SnapshotCountsImpl>
    implements _$$SnapshotCountsImplCopyWith<$Res> {
  __$$SnapshotCountsImplCopyWithImpl(
    _$SnapshotCountsImpl _value,
    $Res Function(_$SnapshotCountsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SnapshotCounts
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? drinks = freezed,
    Object? ingredients = freezed,
    Object? measures = freezed,
    Object? categories = freezed,
    Object? glasses = freezed,
  }) {
    return _then(
      _$SnapshotCountsImpl(
        drinks: freezed == drinks
            ? _value.drinks
            : drinks // ignore: cast_nullable_to_non_nullable
                  as int?,
        ingredients: freezed == ingredients
            ? _value.ingredients
            : ingredients // ignore: cast_nullable_to_non_nullable
                  as int?,
        measures: freezed == measures
            ? _value.measures
            : measures // ignore: cast_nullable_to_non_nullable
                  as int?,
        categories: freezed == categories
            ? _value.categories
            : categories // ignore: cast_nullable_to_non_nullable
                  as int?,
        glasses: freezed == glasses
            ? _value.glasses
            : glasses // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SnapshotCountsImpl implements _SnapshotCounts {
  const _$SnapshotCountsImpl({
    this.drinks,
    this.ingredients,
    this.measures,
    this.categories,
    this.glasses,
  });

  factory _$SnapshotCountsImpl.fromJson(Map<String, dynamic> json) =>
      _$$SnapshotCountsImplFromJson(json);

  @override
  final int? drinks;
  @override
  final int? ingredients;
  @override
  final int? measures;
  @override
  final int? categories;
  @override
  final int? glasses;

  @override
  String toString() {
    return 'SnapshotCounts(drinks: $drinks, ingredients: $ingredients, measures: $measures, categories: $categories, glasses: $glasses)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SnapshotCountsImpl &&
            (identical(other.drinks, drinks) || other.drinks == drinks) &&
            (identical(other.ingredients, ingredients) ||
                other.ingredients == ingredients) &&
            (identical(other.measures, measures) ||
                other.measures == measures) &&
            (identical(other.categories, categories) ||
                other.categories == categories) &&
            (identical(other.glasses, glasses) || other.glasses == glasses));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    drinks,
    ingredients,
    measures,
    categories,
    glasses,
  );

  /// Create a copy of SnapshotCounts
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SnapshotCountsImplCopyWith<_$SnapshotCountsImpl> get copyWith =>
      __$$SnapshotCountsImplCopyWithImpl<_$SnapshotCountsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SnapshotCountsImplToJson(this);
  }
}

abstract class _SnapshotCounts implements SnapshotCounts {
  const factory _SnapshotCounts({
    final int? drinks,
    final int? ingredients,
    final int? measures,
    final int? categories,
    final int? glasses,
  }) = _$SnapshotCountsImpl;

  factory _SnapshotCounts.fromJson(Map<String, dynamic> json) =
      _$SnapshotCountsImpl.fromJson;

  @override
  int? get drinks;
  @override
  int? get ingredients;
  @override
  int? get measures;
  @override
  int? get categories;
  @override
  int? get glasses;

  /// Create a copy of SnapshotCounts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SnapshotCountsImplCopyWith<_$SnapshotCountsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SnapshotInfo _$SnapshotInfoFromJson(Map<String, dynamic> json) {
  return _SnapshotInfo.fromJson(json);
}

/// @nodoc
mixin _$SnapshotInfo {
  String get schemaVersion => throw _privateConstructorUsedError;
  String get snapshotVersion => throw _privateConstructorUsedError;
  int get sizeBytes => throw _privateConstructorUsedError;
  String get sha256 => throw _privateConstructorUsedError;
  String get signedUrl => throw _privateConstructorUsedError;
  DateTime get createdAtUtc => throw _privateConstructorUsedError;
  SnapshotCounts? get counts => throw _privateConstructorUsedError;

  /// Serializes this SnapshotInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SnapshotInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SnapshotInfoCopyWith<SnapshotInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SnapshotInfoCopyWith<$Res> {
  factory $SnapshotInfoCopyWith(
    SnapshotInfo value,
    $Res Function(SnapshotInfo) then,
  ) = _$SnapshotInfoCopyWithImpl<$Res, SnapshotInfo>;
  @useResult
  $Res call({
    String schemaVersion,
    String snapshotVersion,
    int sizeBytes,
    String sha256,
    String signedUrl,
    DateTime createdAtUtc,
    SnapshotCounts? counts,
  });

  $SnapshotCountsCopyWith<$Res>? get counts;
}

/// @nodoc
class _$SnapshotInfoCopyWithImpl<$Res, $Val extends SnapshotInfo>
    implements $SnapshotInfoCopyWith<$Res> {
  _$SnapshotInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SnapshotInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? schemaVersion = null,
    Object? snapshotVersion = null,
    Object? sizeBytes = null,
    Object? sha256 = null,
    Object? signedUrl = null,
    Object? createdAtUtc = null,
    Object? counts = freezed,
  }) {
    return _then(
      _value.copyWith(
            schemaVersion: null == schemaVersion
                ? _value.schemaVersion
                : schemaVersion // ignore: cast_nullable_to_non_nullable
                      as String,
            snapshotVersion: null == snapshotVersion
                ? _value.snapshotVersion
                : snapshotVersion // ignore: cast_nullable_to_non_nullable
                      as String,
            sizeBytes: null == sizeBytes
                ? _value.sizeBytes
                : sizeBytes // ignore: cast_nullable_to_non_nullable
                      as int,
            sha256: null == sha256
                ? _value.sha256
                : sha256 // ignore: cast_nullable_to_non_nullable
                      as String,
            signedUrl: null == signedUrl
                ? _value.signedUrl
                : signedUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAtUtc: null == createdAtUtc
                ? _value.createdAtUtc
                : createdAtUtc // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            counts: freezed == counts
                ? _value.counts
                : counts // ignore: cast_nullable_to_non_nullable
                      as SnapshotCounts?,
          )
          as $Val,
    );
  }

  /// Create a copy of SnapshotInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SnapshotCountsCopyWith<$Res>? get counts {
    if (_value.counts == null) {
      return null;
    }

    return $SnapshotCountsCopyWith<$Res>(_value.counts!, (value) {
      return _then(_value.copyWith(counts: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SnapshotInfoImplCopyWith<$Res>
    implements $SnapshotInfoCopyWith<$Res> {
  factory _$$SnapshotInfoImplCopyWith(
    _$SnapshotInfoImpl value,
    $Res Function(_$SnapshotInfoImpl) then,
  ) = __$$SnapshotInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String schemaVersion,
    String snapshotVersion,
    int sizeBytes,
    String sha256,
    String signedUrl,
    DateTime createdAtUtc,
    SnapshotCounts? counts,
  });

  @override
  $SnapshotCountsCopyWith<$Res>? get counts;
}

/// @nodoc
class __$$SnapshotInfoImplCopyWithImpl<$Res>
    extends _$SnapshotInfoCopyWithImpl<$Res, _$SnapshotInfoImpl>
    implements _$$SnapshotInfoImplCopyWith<$Res> {
  __$$SnapshotInfoImplCopyWithImpl(
    _$SnapshotInfoImpl _value,
    $Res Function(_$SnapshotInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SnapshotInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? schemaVersion = null,
    Object? snapshotVersion = null,
    Object? sizeBytes = null,
    Object? sha256 = null,
    Object? signedUrl = null,
    Object? createdAtUtc = null,
    Object? counts = freezed,
  }) {
    return _then(
      _$SnapshotInfoImpl(
        schemaVersion: null == schemaVersion
            ? _value.schemaVersion
            : schemaVersion // ignore: cast_nullable_to_non_nullable
                  as String,
        snapshotVersion: null == snapshotVersion
            ? _value.snapshotVersion
            : snapshotVersion // ignore: cast_nullable_to_non_nullable
                  as String,
        sizeBytes: null == sizeBytes
            ? _value.sizeBytes
            : sizeBytes // ignore: cast_nullable_to_non_nullable
                  as int,
        sha256: null == sha256
            ? _value.sha256
            : sha256 // ignore: cast_nullable_to_non_nullable
                  as String,
        signedUrl: null == signedUrl
            ? _value.signedUrl
            : signedUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAtUtc: null == createdAtUtc
            ? _value.createdAtUtc
            : createdAtUtc // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        counts: freezed == counts
            ? _value.counts
            : counts // ignore: cast_nullable_to_non_nullable
                  as SnapshotCounts?,
      ),
    );
  }
}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _$SnapshotInfoImpl implements _SnapshotInfo {
  const _$SnapshotInfoImpl({
    required this.schemaVersion,
    required this.snapshotVersion,
    required this.sizeBytes,
    required this.sha256,
    required this.signedUrl,
    required this.createdAtUtc,
    this.counts,
  });

  factory _$SnapshotInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$SnapshotInfoImplFromJson(json);

  @override
  final String schemaVersion;
  @override
  final String snapshotVersion;
  @override
  final int sizeBytes;
  @override
  final String sha256;
  @override
  final String signedUrl;
  @override
  final DateTime createdAtUtc;
  @override
  final SnapshotCounts? counts;

  @override
  String toString() {
    return 'SnapshotInfo(schemaVersion: $schemaVersion, snapshotVersion: $snapshotVersion, sizeBytes: $sizeBytes, sha256: $sha256, signedUrl: $signedUrl, createdAtUtc: $createdAtUtc, counts: $counts)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SnapshotInfoImpl &&
            (identical(other.schemaVersion, schemaVersion) ||
                other.schemaVersion == schemaVersion) &&
            (identical(other.snapshotVersion, snapshotVersion) ||
                other.snapshotVersion == snapshotVersion) &&
            (identical(other.sizeBytes, sizeBytes) ||
                other.sizeBytes == sizeBytes) &&
            (identical(other.sha256, sha256) || other.sha256 == sha256) &&
            (identical(other.signedUrl, signedUrl) ||
                other.signedUrl == signedUrl) &&
            (identical(other.createdAtUtc, createdAtUtc) ||
                other.createdAtUtc == createdAtUtc) &&
            (identical(other.counts, counts) || other.counts == counts));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    schemaVersion,
    snapshotVersion,
    sizeBytes,
    sha256,
    signedUrl,
    createdAtUtc,
    counts,
  );

  /// Create a copy of SnapshotInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SnapshotInfoImplCopyWith<_$SnapshotInfoImpl> get copyWith =>
      __$$SnapshotInfoImplCopyWithImpl<_$SnapshotInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SnapshotInfoImplToJson(this);
  }
}

abstract class _SnapshotInfo implements SnapshotInfo {
  const factory _SnapshotInfo({
    required final String schemaVersion,
    required final String snapshotVersion,
    required final int sizeBytes,
    required final String sha256,
    required final String signedUrl,
    required final DateTime createdAtUtc,
    final SnapshotCounts? counts,
  }) = _$SnapshotInfoImpl;

  factory _SnapshotInfo.fromJson(Map<String, dynamic> json) =
      _$SnapshotInfoImpl.fromJson;

  @override
  String get schemaVersion;
  @override
  String get snapshotVersion;
  @override
  int get sizeBytes;
  @override
  String get sha256;
  @override
  String get signedUrl;
  @override
  DateTime get createdAtUtc;
  @override
  SnapshotCounts? get counts;

  /// Create a copy of SnapshotInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SnapshotInfoImplCopyWith<_$SnapshotInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ApiError _$ApiErrorFromJson(Map<String, dynamic> json) {
  return _ApiError.fromJson(json);
}

/// @nodoc
mixin _$ApiError {
  String get code => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;
  String get traceId => throw _privateConstructorUsedError;
  Map<String, dynamic>? get details => throw _privateConstructorUsedError;

  /// Serializes this ApiError to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ApiError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ApiErrorCopyWith<ApiError> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ApiErrorCopyWith<$Res> {
  factory $ApiErrorCopyWith(ApiError value, $Res Function(ApiError) then) =
      _$ApiErrorCopyWithImpl<$Res, ApiError>;
  @useResult
  $Res call({
    String code,
    String message,
    String traceId,
    Map<String, dynamic>? details,
  });
}

/// @nodoc
class _$ApiErrorCopyWithImpl<$Res, $Val extends ApiError>
    implements $ApiErrorCopyWith<$Res> {
  _$ApiErrorCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ApiError
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? code = null,
    Object? message = null,
    Object? traceId = null,
    Object? details = freezed,
  }) {
    return _then(
      _value.copyWith(
            code: null == code
                ? _value.code
                : code // ignore: cast_nullable_to_non_nullable
                      as String,
            message: null == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String,
            traceId: null == traceId
                ? _value.traceId
                : traceId // ignore: cast_nullable_to_non_nullable
                      as String,
            details: freezed == details
                ? _value.details
                : details // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ApiErrorImplCopyWith<$Res>
    implements $ApiErrorCopyWith<$Res> {
  factory _$$ApiErrorImplCopyWith(
    _$ApiErrorImpl value,
    $Res Function(_$ApiErrorImpl) then,
  ) = __$$ApiErrorImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String code,
    String message,
    String traceId,
    Map<String, dynamic>? details,
  });
}

/// @nodoc
class __$$ApiErrorImplCopyWithImpl<$Res>
    extends _$ApiErrorCopyWithImpl<$Res, _$ApiErrorImpl>
    implements _$$ApiErrorImplCopyWith<$Res> {
  __$$ApiErrorImplCopyWithImpl(
    _$ApiErrorImpl _value,
    $Res Function(_$ApiErrorImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ApiError
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? code = null,
    Object? message = null,
    Object? traceId = null,
    Object? details = freezed,
  }) {
    return _then(
      _$ApiErrorImpl(
        code: null == code
            ? _value.code
            : code // ignore: cast_nullable_to_non_nullable
                  as String,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
        traceId: null == traceId
            ? _value.traceId
            : traceId // ignore: cast_nullable_to_non_nullable
                  as String,
        details: freezed == details
            ? _value._details
            : details // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ApiErrorImpl implements _ApiError {
  const _$ApiErrorImpl({
    required this.code,
    required this.message,
    required this.traceId,
    final Map<String, dynamic>? details,
  }) : _details = details;

  factory _$ApiErrorImpl.fromJson(Map<String, dynamic> json) =>
      _$$ApiErrorImplFromJson(json);

  @override
  final String code;
  @override
  final String message;
  @override
  final String traceId;
  final Map<String, dynamic>? _details;
  @override
  Map<String, dynamic>? get details {
    final value = _details;
    if (value == null) return null;
    if (_details is EqualUnmodifiableMapView) return _details;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'ApiError(code: $code, message: $message, traceId: $traceId, details: $details)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ApiErrorImpl &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.traceId, traceId) || other.traceId == traceId) &&
            const DeepCollectionEquality().equals(other._details, _details));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    code,
    message,
    traceId,
    const DeepCollectionEquality().hash(_details),
  );

  /// Create a copy of ApiError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ApiErrorImplCopyWith<_$ApiErrorImpl> get copyWith =>
      __$$ApiErrorImplCopyWithImpl<_$ApiErrorImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ApiErrorImplToJson(this);
  }
}

abstract class _ApiError implements ApiError {
  const factory _ApiError({
    required final String code,
    required final String message,
    required final String traceId,
    final Map<String, dynamic>? details,
  }) = _$ApiErrorImpl;

  factory _ApiError.fromJson(Map<String, dynamic> json) =
      _$ApiErrorImpl.fromJson;

  @override
  String get code;
  @override
  String get message;
  @override
  String get traceId;
  @override
  Map<String, dynamic>? get details;

  /// Create a copy of ApiError
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ApiErrorImplCopyWith<_$ApiErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
