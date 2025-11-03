// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserImpl _$$UserImplFromJson(Map<String, dynamic> json) => _$UserImpl(
  id: json['id'] as String,
  email: json['email'] as String,
  displayName: json['displayName'] as String?,
  givenName: json['givenName'] as String?,
  familyName: json['familyName'] as String?,
  ageVerified: json['ageVerified'] as bool? ?? false,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$$UserImplToJson(_$UserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'displayName': instance.displayName,
      'givenName': instance.givenName,
      'familyName': instance.familyName,
      'ageVerified': instance.ageVerified,
      'createdAt': instance.createdAt?.toIso8601String(),
    };
