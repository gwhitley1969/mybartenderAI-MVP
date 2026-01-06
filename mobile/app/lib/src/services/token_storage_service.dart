import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/auth_config.dart';
import '../models/user.dart';

/// Secure storage service for authentication tokens and user data
class TokenStorageService {
  final FlutterSecureStorage _storage;

  TokenStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
            );

  // Token management

  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: AuthConfig.accessTokenKey, value: token);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: AuthConfig.accessTokenKey);
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: AuthConfig.refreshTokenKey, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: AuthConfig.refreshTokenKey);
  }

  Future<void> saveIdToken(String token) async {
    await _storage.write(key: AuthConfig.idTokenKey, value: token);
  }

  Future<String?> getIdToken() async {
    return await _storage.read(key: AuthConfig.idTokenKey);
  }

  Future<void> saveExpiresAt(DateTime expiresAt) async {
    await _storage.write(
      key: AuthConfig.expiresAtKey,
      value: expiresAt.toIso8601String(),
    );
  }

  Future<DateTime?> getExpiresAt() async {
    final value = await _storage.read(key: AuthConfig.expiresAtKey);
    if (value == null) return null;
    return DateTime.parse(value);
  }

  /// Check if access token is expired
  Future<bool> isTokenExpired() async {
    final expiresAt = await getExpiresAt();
    if (expiresAt == null) return true;
    return DateTime.now().isAfter(expiresAt);
  }

  /// Save the last time tokens were successfully refreshed
  /// Used for proactive refresh to prevent 12-hour inactivity timeout
  Future<void> saveLastRefreshTime(DateTime time) async {
    await _storage.write(
      key: AuthConfig.lastRefreshTimeKey,
      value: time.toIso8601String(),
    );
  }

  /// Get the last time tokens were successfully refreshed
  Future<DateTime?> getLastRefreshTime() async {
    final value = await _storage.read(key: AuthConfig.lastRefreshTimeKey);
    if (value == null) return null;
    return DateTime.parse(value);
  }

  /// Check how long since last token refresh
  /// Returns null if no refresh time is recorded
  Future<Duration?> getTimeSinceLastRefresh() async {
    final lastRefresh = await getLastRefreshTime();
    if (lastRefresh == null) return null;
    return DateTime.now().difference(lastRefresh);
  }

  // User profile management

  Future<void> saveUserProfile(User user) async {
    final jsonString = jsonEncode(user.toJson());
    await _storage.write(key: AuthConfig.userProfileKey, value: jsonString);
  }

  Future<User?> getUserProfile() async {
    final jsonString = await _storage.read(key: AuthConfig.userProfileKey);
    if (jsonString == null) return null;
    return User.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  // Clear all stored data (logout)

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Clear only authentication tokens (keep other app data)
  Future<void> clearAuthTokens() async {
    await _storage.delete(key: AuthConfig.accessTokenKey);
    await _storage.delete(key: AuthConfig.refreshTokenKey);
    await _storage.delete(key: AuthConfig.idTokenKey);
    await _storage.delete(key: AuthConfig.expiresAtKey);
    await _storage.delete(key: AuthConfig.userProfileKey);
    await _storage.delete(key: AuthConfig.lastRefreshTimeKey);
  }
}
