
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recommendation_dtos.dart';

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed a class using a private constructor. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

InventoryDto _$InventoryDtoFromJson(Map<String, dynamic> json) {
  return _InventoryDto.fromJson(json);
}

/// @nodoc
mixin _$InventoryDto {
  List<String>? get spirits => throw _privateConstructorUsedError;
  List<String>? get mixers => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $InventoryDtoCopyWith<InventoryDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InventoryDtoCopyWith<$Res> {
  factory $InventoryDtoCopyWith(
          InventoryDto value, $Res Function(InventoryDto) then) =
      _$InventoryDtoCopyWithImpl<$Res, InventoryDto>;
  @useResult
  $Res call({List<String>? spirits, List<String>? mixers});
}

/// @nodoc
class _$InventoryDtoCopyWithImpl<$Res, $Val extends InventoryDto>
    implements $InventoryDtoCopyWith<$Res> {
  _$InventoryDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? spirits = freezed,
    Object? mixers = freezed,
  }) {
    return _then(_value.copyWith(
      spirits: freezed == spirits
          ? _value.spirits
          : spirits // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      mixers: freezed == mixers
          ? _value.mixers
          : mixers // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$InventoryDtoImplCopyWith<$Res>
    implements $InventoryDtoCopyWith<$Res> {
  factory _$$InventoryDtoImplCopyWith(
          _$InventoryDtoImpl value, $Res Function(_$InventoryDtoImpl) then) =
      __$$InventoryDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<String>? spirits, List<String>? mixers});
}

/// @nodoc
class __$$InventoryDtoImplCopyWithImpl<$Res>
    extends _$InventoryDtoCopyWithImpl<$Res, _$InventoryDtoImpl>
    implements _$$InventoryDtoImplCopyWith<$Res> {
  __$$InventoryDtoImplCopyWithImpl(
      _$InventoryDtoImpl _value, $Res Function(_$InventoryDtoImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? spirits = freezed,
    Object? mixers = freezed,
  }) {
    return _then(_$InventoryDtoImpl(
      spirits: freezed == spirits
          ? _value._spirits
          : spirits // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      mixers: freezed == mixers
          ? _value._mixers
          : mixers // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$InventoryDtoImpl implements _InventoryDto {
  const _$InventoryDtoImpl({final List<String>? spirits, final List<String>? mixers})
      : _spirits = spirits,
        _mixers = mixers;

  factory _$InventoryDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$InventoryDtoImplFromJson(json);

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
    return 'InventoryDto(spirits: $spirits, mixers: $mixers)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InventoryDtoImpl &&
            const DeepCollectionEquality().equals(other._spirits, _spirits) &&
            const DeepCollectionEquality().equals(other._mixers, _mixers));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_spirits),
      const DeepCollectionEquality().hash(_mixers));

  @override
  Map<String, dynamic> toJson() {
    return _$$InventoryDtoImplToJson(
      this,
    );
  }

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$InventoryDtoImplCopyWith<_$InventoryDtoImpl> get copyWith =>
      __$$InventoryDtoImplCopyWithImpl<_$InventoryDtoImpl>(this, _$identity);
}

/// @nodoc
abstract class _InventoryDto implements InventoryDto {
  const factory _InventoryDto(
      {final List<String>? spirits,
      final List<String>? mixers}) = _$InventoryDtoImpl;

  factory _InventoryDto.fromJson(Map<String, dynamic> json) =
      _$InventoryDtoImpl.fromJson;

  @override
  List<String>? get spirits;
  @override
  List<String>? get mixers;
  @override
  @JsonKey(ignore: true)
  _$$InventoryDtoImplCopyWith<_$InventoryDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
TasteProfileDto _$TasteProfileDtoFromJson(Map<String, dynamic> json) {
  return _TasteProfileDto.fromJson(json);
}

/// @nodoc
mixin _$TasteProfileDto {
  List<String>? get preferredFlavors => throw _privateConstructorUsedError;
  List<String>? get dislikedFlavors => throw _privateConstructorUsedError;
  String? get abvRange => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $TasteProfileDtoCopyWith<TasteProfileDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TasteProfileDtoCopyWith<$Res> {
  factory $TasteProfileDtoCopyWith(
          TasteProfileDto value, $Res Function(TasteProfileDto) then) =
      _$TasteProfileDtoCopyWithImpl<$Res, TasteProfileDto>;
  @useResult
  $Res call(
      {List<String>? preferredFlavors,
      List<String>? dislikedFlavors,
      String? abvRange});
}

/// @nodoc
class _$TasteProfileDtoCopyWithImpl<$Res, $Val extends TasteProfileDto>
    implements $TasteProfileDtoCopyWith<$Res> {
  _$TasteProfileDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? preferredFlavors = freezed,
    Object? dislikedFlavors = freezed,
    Object? abvRange = freezed,
  }) {
    return _then(_value.copyWith(
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
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TasteProfileDtoImplCopyWith<$Res>
    implements $TasteProfileDtoCopyWith<$Res> {
  factory _$$TasteProfileDtoImplCopyWith(_$TasteProfileDtoImpl value,
          $Res Function(_$TasteProfileDtoImpl) then) =
      __$$TasteProfileDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<String>? preferredFlavors,
      List<String>? dislikedFlavors,
      String? abvRange});
}

/// @nodoc
class __$$TasteProfileDtoImplCopyWithImpl<$Res>
    extends _$TasteProfileDtoCopyWithImpl<$Res, _$TasteProfileDtoImpl>
    implements _$$TasteProfileDtoImplCopyWith<$Res> {
  __$$TasteProfileDtoImplCopyWithImpl(_$TasteProfileDtoImpl _value,
      $Res Function(_$TasteProfileDtoImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? preferredFlavors = freezed,
    Object? dislikedFlavors = freezed,
    Object? abvRange = freezed,
  }) {
    return _then(_$TasteProfileDtoImpl(
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
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TasteProfileDtoImpl implements _TasteProfileDto {
  const _$TasteProfileDtoImpl(
      {final List<String>? preferredFlavors,
      final List<String>? dislikedFlavors,
      this.abvRange})
      : _preferredFlavors = preferredFlavors,
        _dislikedFlavors = dislikedFlavors;

  factory _$TasteProfileDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$TasteProfileDtoImplFromJson(json);

  final List<String>? _preferredFlavors;
  @override
  List<String>? get preferredFlavors {
    final value = _preferredFlavors;
    if (value == null) return null;
    if (_preferredFlavors is EqualUnmodifiableListView) {
      return _preferredFlavors;
    }
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<String>? _dislikedFlavors;
  @override
  List<String>? get dislikedFlavors {
    final value = _dislikedFlavors;
    if (value == null) return null;
    if (_dislikedFlavors is EqualUnmodifiableListView) {
      return _dislikedFlavors;
    }
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final String? abvRange;

  @override
  String toString() {
    return 'TasteProfileDto(preferredFlavors: $preferredFlavors, dislikedFlavors: $dislikedFlavors, abvRange: $abvRange)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TasteProfileDtoImpl &&
            const DeepCollectionEquality()
                .equals(other._preferredFlavors, _preferredFlavors) &&
            const DeepCollectionEquality()
                .equals(other._dislikedFlavors, _dislikedFlavors) &&
            (identical(other.abvRange, abvRange) ||
                other.abvRange == abvRange));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_preferredFlavors),
      const DeepCollectionEquality().hash(_dislikedFlavors),
      abvRange);

  @override
  Map<String, dynamic> toJson() {
    return _$$TasteProfileDtoImplToJson(
      this,
    );
  }

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TasteProfileDtoImplCopyWith<_$TasteProfileDtoImpl> get copyWith =>
      __$$TasteProfileDtoImplCopyWithImpl<_$TasteProfileDtoImpl>(
          this, _$identity);
}

/// @nodoc
abstract class _TasteProfileDto implements TasteProfileDto {
  const factory _TasteProfileDto(
      {final List<String>? preferredFlavors,
      final List<String>? dislikedFlavors,
      final String? abvRange}) = _$TasteProfileDtoImpl;

  factory _TasteProfileDto.fromJson(Map<String, dynamic> json) =
      _$TasteProfileDtoImpl.fromJson;

  @override
  List<String>? get preferredFlavors;
  @override
  List<String>? get dislikedFlavors;
  @override
  String? get abvRange;
  @override
  @JsonKey(ignore: true)
  _$$TasteProfileDtoImplCopyWith<_$TasteProfileDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
RecommendRequestDto _$RecommendRequestDtoFromJson(Map<String, dynamic> json) {
  return _RecommendRequestDto.fromJson(json);
}

/// @nodoc
mixin _$RecommendRequestDto {
  InventoryDto get inventory => throw _privateConstructorUsedError;
  TasteProfileDto? get tasteProfile => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $RecommendRequestDtoCopyWith<RecommendRequestDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecommendRequestDtoCopyWith<$Res> {
  factory $RecommendRequestDtoCopyWith(RecommendRequestDto value,
          $Res Function(RecommendRequestDto) then) =
      _$RecommendRequestDtoCopyWithImpl<$Res, RecommendRequestDto>;
  @useResult
  $Res call({InventoryDto inventory, TasteProfileDto? tasteProfile});

  $InventoryDtoCopyWith<$Res> get inventory;
  $TasteProfileDtoCopyWith<$Res>? get tasteProfile;
}

/// @nodoc
class _$RecommendRequestDtoCopyWithImpl<$Res,
        $Val extends RecommendRequestDto>
    implements $RecommendRequestDtoCopyWith<$Res> {
  _$RecommendRequestDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? inventory = null,
    Object? tasteProfile = freezed,
  }) {
    return _then(_value.copyWith(
      inventory: null == inventory
          ? _value.inventory
          : inventory // ignore: cast_nullable_to_non_nullable
              as InventoryDto,
      tasteProfile: freezed == tasteProfile
          ? _value.tasteProfile
          : tasteProfile // ignore: cast_nullable_to_non_nullable
              as TasteProfileDto?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $InventoryDtoCopyWith<$Res> get inventory {
    return $InventoryDtoCopyWith<$Res>(_value.inventory, (value) {
      return _then(_value.copyWith(inventory: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $TasteProfileDtoCopyWith<$Res>? get tasteProfile {
    if (_value.tasteProfile == null) {
      return null;
    }

    return $TasteProfileDtoCopyWith<$Res>(_value.tasteProfile!, (value) {
      return _then(_value.copyWith(tasteProfile: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$RecommendRequestDtoImplCopyWith<$Res>
    implements $RecommendRequestDtoCopyWith<$Res> {
  factory _$$RecommendRequestDtoImplCopyWith(_$RecommendRequestDtoImpl value,
          $Res Function(_$RecommendRequestDtoImpl) then) =
      __$$RecommendRequestDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({InventoryDto inventory, TasteProfileDto? tasteProfile});

  @override
  $InventoryDtoCopyWith<$Res> get inventory;
  @override
  $TasteProfileDtoCopyWith<$Res>? get tasteProfile;
}

/// @nodoc
class __$$RecommendRequestDtoImplCopyWithImpl<$Res>
    extends _$RecommendRequestDtoCopyWithImpl<$Res, _$RecommendRequestDtoImpl>
    implements _$$RecommendRequestDtoImplCopyWith<$Res> {
  __$$RecommendRequestDtoImplCopyWithImpl(_$RecommendRequestDtoImpl _value,
      $Res Function(_$RecommendRequestDtoImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? inventory = null,
    Object? tasteProfile = freezed,
  }) {
    return _then(_$RecommendRequestDtoImpl(
      inventory: null == inventory
          ? _value.inventory
          : inventory // ignore: cast_nullable_to_non_nullable
              as InventoryDto,
      tasteProfile: freezed == tasteProfile
          ? _value.tasteProfile
          : tasteProfile // ignore: cast_nullable_to_non_nullable
              as TasteProfileDto?,
    ));
  }
}

/// @nodoc
@JsonSerializable(explicitToJson: true)
class _$RecommendRequestDtoImpl implements _RecommendRequestDto {
  const _$RecommendRequestDtoImpl({required this.inventory, this.tasteProfile});

  factory _$RecommendRequestDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecommendRequestDtoImplFromJson(json);

  @override
  final InventoryDto inventory;
  @override
  final TasteProfileDto? tasteProfile;

  @override
  String toString() {
    return 'RecommendRequestDto(inventory: $inventory, tasteProfile: $tasteProfile)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecommendRequestDtoImpl &&
            (identical(other.inventory, inventory) ||
                other.inventory == inventory) &&
            (identical(other.tasteProfile, tasteProfile) ||
                other.tasteProfile == tasteProfile));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, inventory, tasteProfile);

  @override
  Map<String, dynamic> toJson() {
    return _$$RecommendRequestDtoImplToJson(
      this,
    );
  }

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RecommendRequestDtoImplCopyWith<_$RecommendRequestDtoImpl> get copyWith =>
      __$$RecommendRequestDtoImplCopyWithImpl<_$RecommendRequestDtoImpl>(
          this, _$identity);
}

/// @nodoc
abstract class _RecommendRequestDto implements RecommendRequestDto {
  const factory _RecommendRequestDto(
      {required final InventoryDto inventory,
      final TasteProfileDto? tasteProfile}) = _$RecommendRequestDtoImpl;

  factory _RecommendRequestDto.fromJson(Map<String, dynamic> json) =
      _$RecommendRequestDtoImpl.fromJson;

  @override
  InventoryDto get inventory;
  @override
  TasteProfileDto? get tasteProfile;
  @override
  @JsonKey(ignore: true)
  _$$RecommendRequestDtoImplCopyWith<_$RecommendRequestDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
RecommendationIngredientDto _$RecommendationIngredientDtoFromJson(
    Map<String, dynamic> json) {
  return _RecommendationIngredientDto.fromJson(json);
}

/// @nodoc
mixin _$RecommendationIngredientDto {
  String get name => throw _privateConstructorUsedError;
  double get amount => throw _privateConstructorUsedError;
  String get unit => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $RecommendationIngredientDtoCopyWith<RecommendationIngredientDto>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecommendationIngredientDtoCopyWith<$Res> {
  factory $RecommendationIngredientDtoCopyWith(
          RecommendationIngredientDto value,
          $Res Function(RecommendationIngredientDto) then) =
      _$RecommendationIngredientDtoCopyWithImpl<$Res,
          RecommendationIngredientDto>;
  @useResult
  $Res call({String name, double amount, String unit});
}

/// @nodoc
class _$RecommendationIngredientDtoCopyWithImpl<$Res,
        $Val extends RecommendationIngredientDto>
    implements $RecommendationIngredientDtoCopyWith<$Res> {
  _$RecommendationIngredientDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? amount = null,
    Object? unit = null,
  }) {
    return _then(_value.copyWith(
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
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RecommendationIngredientDtoImplCopyWith<$Res>
    implements $RecommendationIngredientDtoCopyWith<$Res> {
  factory _$$RecommendationIngredientDtoImplCopyWith(
          _$RecommendationIngredientDtoImpl value,
          $Res Function(_$RecommendationIngredientDtoImpl) then) =
      __$$RecommendationIngredientDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, double amount, String unit});
}

/// @nodoc
class __$$RecommendationIngredientDtoImplCopyWithImpl<$Res>
    extends _$RecommendationIngredientDtoCopyWithImpl<$Res,
        _$RecommendationIngredientDtoImpl>
    implements _$$RecommendationIngredientDtoImplCopyWith<$Res> {
  __$$RecommendationIngredientDtoImplCopyWithImpl(
      _$RecommendationIngredientDtoImpl _value,
      $Res Function(_$RecommendationIngredientDtoImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? amount = null,
    Object? unit = null,
  }) {
    return _then(_$RecommendationIngredientDtoImpl(
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
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RecommendationIngredientDtoImpl implements _RecommendationIngredientDto {
  const _$RecommendationIngredientDtoImpl(
      {required this.name, required this.amount, required this.unit});

  factory _$RecommendationIngredientDtoImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$RecommendationIngredientDtoImplFromJson(json);

  @override
  final String name;
  @override
  final double amount;
  @override
  final String unit;

  @override
  String toString() {
    return 'RecommendationIngredientDto(name: $name, amount: $amount, unit: $unit)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecommendationIngredientDtoImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.unit, unit) || other.unit == unit));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, name, amount, unit);

  @override
  Map<String, dynamic> toJson() {
    return _$$RecommendationIngredientDtoImplToJson(
      this,
    );
  }

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RecommendationIngredientDtoImplCopyWith<_$RecommendationIngredientDtoImpl>
      get copyWith => __$$RecommendationIngredientDtoImplCopyWithImpl<
          _$RecommendationIngredientDtoImpl>(this, _$identity);
}

/// @nodoc
abstract class _RecommendationIngredientDto
    implements RecommendationIngredientDto {
  const factory _RecommendationIngredientDto(
      {required final String name,
      required final double amount,
      required final String unit}) = _$RecommendationIngredientDtoImpl;

  factory _RecommendationIngredientDto.fromJson(Map<String, dynamic> json) =
      _$RecommendationIngredientDtoImpl.fromJson;

  @override
  String get name;
  @override
  double get amount;
  @override
  String get unit;
  @override
  @JsonKey(ignore: true)
  _$$RecommendationIngredientDtoImplCopyWith<
          _$RecommendationIngredientDtoImpl>
      get copyWith => throw _privateConstructorUsedError;
}
RecommendationDto _$RecommendationDtoFromJson(Map<String, dynamic> json) {
  return _RecommendationDto.fromJson(json);
}

/// @nodoc
mixin _$RecommendationDto {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get reason => throw _privateConstructorUsedError;
  List<RecommendationIngredientDto> get ingredients =>
      throw _privateConstructorUsedError;
  String get instructions => throw _privateConstructorUsedError;
  String? get glassware => throw _privateConstructorUsedError;
  String? get garnish => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $RecommendationDtoCopyWith<RecommendationDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecommendationDtoCopyWith<$Res> {
  factory $RecommendationDtoCopyWith(
          RecommendationDto value, $Res Function(RecommendationDto) then) =
      _$RecommendationDtoCopyWithImpl<$Res, RecommendationDto>;
  @useResult
  $Res call(
      {String id,
      String name,
      String? reason,
      List<RecommendationIngredientDto> ingredients,
      String instructions,
      String? glassware,
      String? garnish});
}

/// @nodoc
class _$RecommendationDtoCopyWithImpl<$Res, $Val extends RecommendationDto>
    implements $RecommendationDtoCopyWith<$Res> {
  _$RecommendationDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

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
    return _then(_value.copyWith(
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
              as List<RecommendationIngredientDto>,
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
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RecommendationDtoImplCopyWith<$Res>
    implements $RecommendationDtoCopyWith<$Res> {
  factory _$$RecommendationDtoImplCopyWith(_$RecommendationDtoImpl value,
          $Res Function(_$RecommendationDtoImpl) then) =
      __$$RecommendationDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String? reason,
      List<RecommendationIngredientDto> ingredients,
      String instructions,
      String? glassware,
      String? garnish});
}

/// @nodoc
class __$$RecommendationDtoImplCopyWithImpl<$Res>
    extends _$RecommendationDtoCopyWithImpl<$Res, _$RecommendationDtoImpl>
    implements _$$RecommendationDtoImplCopyWith<$Res> {
  __$$RecommendationDtoImplCopyWithImpl(_$RecommendationDtoImpl _value,
      $Res Function(_$RecommendationDtoImpl) _then)
      : super(_value, _then);

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
    return _then(_$RecommendationDtoImpl(
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
              as List<RecommendationIngredientDto>,
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
    ));
  }
}

/// @nodoc
@JsonSerializable(explicitToJson: true)
class _$RecommendationDtoImpl implements _RecommendationDto {
  const _$RecommendationDtoImpl(
      {required this.id,
      required this.name,
      this.reason,
      required final List<RecommendationIngredientDto> ingredients,
      required this.instructions,
      this.glassware,
      this.garnish})
      : _ingredients = ingredients;

  factory _$RecommendationDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecommendationDtoImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? reason;
  final List<RecommendationIngredientDto> _ingredients;
  @override
  List<RecommendationIngredientDto> get ingredients {
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
    return 'RecommendationDto(id: $id, name: $name, reason: $reason, ingredients: $ingredients, instructions: $instructions, glassware: $glassware, garnish: $garnish)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecommendationDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            const DeepCollectionEquality()
                .equals(other._ingredients, _ingredients) &&
            (identical(other.instructions, instructions) ||
                other.instructions == instructions) &&
            (identical(other.glassware, glassware) ||
                other.glassware == glassware) &&
            (identical(other.garnish, garnish) || other.garnish == garnish));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      reason,
      const DeepCollectionEquality().hash(_ingredients),
      instructions,
      glassware,
      garnish);

  @override
  Map<String, dynamic> toJson() {
    return _$$RecommendationDtoImplToJson(
      this,
    );
  }

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RecommendationDtoImplCopyWith<_$RecommendationDtoImpl> get copyWith =>
      __$$RecommendationDtoImplCopyWithImpl<_$RecommendationDtoImpl>(
          this, _$identity);
}

/// @nodoc
abstract class _RecommendationDto implements RecommendationDto {
  const factory _RecommendationDto(
      {required final String id,
      required final String name,
      final String? reason,
      required final List<RecommendationIngredientDto> ingredients,
      required final String instructions,
      final String? glassware,
      final String? garnish}) = _$RecommendationDtoImpl;

  factory _RecommendationDto.fromJson(Map<String, dynamic> json) =
      _$RecommendationDtoImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get reason;
  @override
  List<RecommendationIngredientDto> get ingredients;
  @override
  String get instructions;
  @override
  String? get glassware;
  @override
  String? get garnish;
  @override
  @JsonKey(ignore: true)
  _$$RecommendationDtoImplCopyWith<_$RecommendationDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
ErrorDto _$ErrorDtoFromJson(Map<String, dynamic> json) {
  return _ErrorDto.fromJson(json);
}

/// @nodoc
mixin _$ErrorDto {
  String get code => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;
  String get traceId => throw _privateConstructorUsedError;
  Map<String, dynamic>? get details => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ErrorDtoCopyWith<ErrorDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ErrorDtoCopyWith<$Res> {
  factory $ErrorDtoCopyWith(ErrorDto value, $Res Function(ErrorDto) then) =
      _$ErrorDtoCopyWithImpl<$Res, ErrorDto>;
  @useResult
  $Res call(
      {String code, String message, String traceId, Map<String, dynamic>? details});
}

/// @nodoc
class _$ErrorDtoCopyWithImpl<$Res, $Val extends ErrorDto>
    implements $ErrorDtoCopyWith<$Res> {
  _$ErrorDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? code = null,
    Object? message = null,
    Object? traceId = null,
    Object? details = freezed,
  }) {
    return _then(_value.copyWith(
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
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ErrorDtoImplCopyWith<$Res>
    implements $ErrorDtoCopyWith<$Res> {
  factory _$$ErrorDtoImplCopyWith(
          _$ErrorDtoImpl value, $Res Function(_$ErrorDtoImpl) then) =
      __$$ErrorDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String code, String message, String traceId, Map<String, dynamic>? details});
}

/// @nodoc
class __$$ErrorDtoImplCopyWithImpl<$Res>
    extends _$ErrorDtoCopyWithImpl<$Res, _$ErrorDtoImpl>
    implements _$$ErrorDtoImplCopyWith<$Res> {
  __$$ErrorDtoImplCopyWithImpl(
      _$ErrorDtoImpl _value, $Res Function(_$ErrorDtoImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? code = null,
    Object? message = null,
    Object? traceId = null,
    Object? details = freezed,
  }) {
    return _then(_$ErrorDtoImpl(
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
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ErrorDtoImpl implements _ErrorDto {
  const _$ErrorDtoImpl(
      {required this.code,
      required this.message,
      required this.traceId,
      final Map<String, dynamic>? details})
      : _details = details;

  factory _$ErrorDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ErrorDtoImplFromJson(json);

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
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'ErrorDto(code: $code, message: $message, traceId: $traceId, details: $details)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ErrorDtoImpl &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.traceId, traceId) || other.traceId == traceId) &&
            const DeepCollectionEquality().equals(other._details, _details));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, code, message, traceId,
      const DeepCollectionEquality().hash(_details));

  @override
  Map<String, dynamic> toJson() {
    return _$$ErrorDtoImplToJson(
      this,
    );
  }

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ErrorDtoImplCopyWith<_$ErrorDtoImpl> get copyWith =>
      __$$ErrorDtoImplCopyWithImpl<_$ErrorDtoImpl>(this, _$identity);
}

/// @nodoc
abstract class _ErrorDto implements ErrorDto {
  const factory _ErrorDto(
      {required final String code,
      required final String message,
      required final String traceId,
      final Map<String, dynamic>? details}) = _$ErrorDtoImpl;

  factory _ErrorDto.fromJson(Map<String, dynamic> json) =
      _$ErrorDtoImpl.fromJson;

  @override
  String get code;
  @override
  String get message;
  @override
  String get traceId;
  @override
  Map<String, dynamic>? get details;
  @override
  @JsonKey(ignore: true)
  _$$ErrorDtoImplCopyWith<_$ErrorDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
