import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// User model representing an authenticated user
@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    String? displayName,
    String? givenName,
    String? familyName,
    @Default(false) bool ageVerified,
    DateTime? createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  /// Create User from JWT token claims
  factory User.fromTokenClaims(Map<String, dynamic> claims) {
    return User(
      id: claims['sub'] as String? ?? claims['oid'] as String? ?? '',
      email: claims['email'] as String? ?? claims['emails']?[0] as String? ?? '',
      displayName: claims['name'] as String?,
      givenName: claims['given_name'] as String?,
      familyName: claims['family_name'] as String?,
      ageVerified: claims['extension_age_verified'] == true ||
          claims['age_verified'] == true,
    );
  }
}
