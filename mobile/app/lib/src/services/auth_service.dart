import 'dart:developer' as developer;

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../config/auth_config.dart';
import '../models/user.dart';
import 'token_storage_service.dart';

/// Authentication service for Entra External ID (Azure AD B2C)
class AuthService {
  final FlutterAppAuth _appAuth;
  final TokenStorageService _tokenStorage;

  AuthService({
    FlutterAppAuth? appAuth,
    required TokenStorageService tokenStorage,
  })  : _appAuth = appAuth ?? const FlutterAppAuth(),
        _tokenStorage = tokenStorage;

  /// Sign in with Entra External ID (supports Email, Google, Facebook)
  Future<User?> signIn() async {
    try {
      developer.log('Starting sign in flow', name: 'AuthService');

      final AuthorizationTokenResponse? result =
          await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          AuthConfig.clientId,
          AuthConfig.redirectUrl,
          // Use explicit endpoints instead of discovery to avoid path issues
          serviceConfiguration: AuthorizationServiceConfiguration(
            authorizationEndpoint: AuthConfig.authorizationEndpoint,
            tokenEndpoint: AuthConfig.tokenEndpoint,
            endSessionEndpoint: AuthConfig.endSessionEndpoint,
          ),
          scopes: AuthConfig.scopes,
          // In flutter_appauth 7.x, prompt is a direct parameter
          promptValues: ['select_account'],
        ),
      );

      if (result == null) {
        developer.log('Sign in cancelled by user', name: 'AuthService');
        return null;
      }

      developer.log('Sign in successful, saving tokens', name: 'AuthService');
      return await _handleAuthResult(result);
    } catch (e, stackTrace) {
      developer.log(
        'Sign in error',
        name: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Sign up with Entra External ID (supports Email, Google, Facebook)
  /// Note: Uses the same flow as sign-in - Entra handles signup/signin in one user flow
  Future<User?> signUp() async {
    // Entra External ID user flow handles both signup and signin
    return signIn();
  }

  /// Sign out and clear all stored tokens
  Future<void> signOut() async {
    try {
      developer.log('Starting sign out', name: 'AuthService');

      final idToken = await _tokenStorage.getIdToken();

      if (idToken != null) {
        // End session with Entra External ID
        await _appAuth.endSession(
          EndSessionRequest(
            idTokenHint: idToken,
            postLogoutRedirectUrl: AuthConfig.redirectUrl,
            serviceConfiguration: AuthorizationServiceConfiguration(
              authorizationEndpoint: AuthConfig.authorizationEndpoint,
              tokenEndpoint: AuthConfig.tokenEndpoint,
              endSessionEndpoint: AuthConfig.endSessionEndpoint,
            ),
          ),
        );
      }

      // Clear all stored tokens
      await _tokenStorage.clearAuthTokens();

      developer.log('Sign out complete', name: 'AuthService');
    } catch (e, stackTrace) {
      developer.log(
        'Sign out error',
        name: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      // Clear tokens even if end session fails
      await _tokenStorage.clearAuthTokens();
    }
  }

  /// Refresh access token using refresh token
  Future<User?> refreshToken() async {
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null) {
        developer.log('No refresh token available', name: 'AuthService');
        return null;
      }

      developer.log('Refreshing access token', name: 'AuthService');

      final TokenResponse? result = await _appAuth.token(
        TokenRequest(
          AuthConfig.clientId,
          AuthConfig.redirectUrl,
          serviceConfiguration: AuthorizationServiceConfiguration(
            authorizationEndpoint: AuthConfig.authorizationEndpoint,
            tokenEndpoint: AuthConfig.tokenEndpoint,
            endSessionEndpoint: AuthConfig.endSessionEndpoint,
          ),
          scopes: AuthConfig.scopes,
          refreshToken: refreshToken,
        ),
      );

      if (result == null) {
        developer.log('Token refresh failed', name: 'AuthService');
        return null;
      }

      developer.log('Token refresh successful', name: 'AuthService');
      return await _handleTokenResponse(result);
    } catch (e, stackTrace) {
      developer.log(
        'Token refresh error',
        name: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get current user from stored tokens
  Future<User?> getCurrentUser() async {
    try {
      // Check if we have a stored user profile
      final user = await _tokenStorage.getUserProfile();
      if (user == null) return null;

      // Check if token is expired
      final isExpired = await _tokenStorage.isTokenExpired();
      if (isExpired) {
        developer.log(
          'Access token expired, attempting refresh',
          name: 'AuthService',
        );
        return await refreshToken();
      }

      return user;
    } catch (e) {
      developer.log(
        'Get current user error',
        name: 'AuthService',
        error: e,
      );
      return null;
    }
  }

  /// Get valid access token (refreshes if expired)
  Future<String?> getValidAccessToken() async {
    try {
      // Check if token is expired
      final isExpired = await _tokenStorage.isTokenExpired();

      if (isExpired) {
        developer.log('Token expired, refreshing', name: 'AuthService');
        await refreshToken();
      }

      return await _tokenStorage.getAccessToken();
    } catch (e) {
      developer.log(
        'Get valid access token error',
        name: 'AuthService',
        error: e,
      );
      return null;
    }
  }

  // Private helper methods

  Future<User?> _handleAuthResult(AuthorizationTokenResponse result) async {
    if (result.accessToken == null) {
      developer.log('No access token in response', name: 'AuthService');
      return null;
    }

    // Save tokens
    await _tokenStorage.saveAccessToken(result.accessToken!);

    if (result.refreshToken != null) {
      await _tokenStorage.saveRefreshToken(result.refreshToken!);
    }

    if (result.idToken != null) {
      await _tokenStorage.saveIdToken(result.idToken!);
    }

    // Save expiration time
    if (result.accessTokenExpirationDateTime != null) {
      await _tokenStorage.saveExpiresAt(result.accessTokenExpirationDateTime!);
    }

    // Decode ID token to get user info
    User? user;
    if (result.idToken != null) {
      try {
        final Map<String, dynamic> decodedToken =
            JwtDecoder.decode(result.idToken!);
        developer.log(
          'Decoded ID token claims: ${decodedToken.keys.toList()}',
          name: 'AuthService',
        );
        user = User.fromTokenClaims(decodedToken);
        await _tokenStorage.saveUserProfile(user);
      } catch (e) {
        developer.log(
          'Error decoding ID token',
          name: 'AuthService',
          error: e,
        );
      }
    }

    return user;
  }

  Future<User?> _handleTokenResponse(TokenResponse result) async {
    if (result.accessToken == null) {
      developer.log('No access token in response', name: 'AuthService');
      return null;
    }

    // Save tokens
    await _tokenStorage.saveAccessToken(result.accessToken!);

    if (result.refreshToken != null) {
      await _tokenStorage.saveRefreshToken(result.refreshToken!);
    }

    if (result.idToken != null) {
      await _tokenStorage.saveIdToken(result.idToken!);
    }

    // Save expiration time
    if (result.accessTokenExpirationDateTime != null) {
      await _tokenStorage.saveExpiresAt(result.accessTokenExpirationDateTime!);
    }

    // Decode ID token to get user info
    User? user;
    if (result.idToken != null) {
      try {
        final Map<String, dynamic> decodedToken =
            JwtDecoder.decode(result.idToken!);
        developer.log(
          'Decoded ID token claims: ${decodedToken.keys.toList()}',
          name: 'AuthService',
        );
        user = User.fromTokenClaims(decodedToken);
        await _tokenStorage.saveUserProfile(user);
      } catch (e) {
        developer.log(
          'Error decoding ID token',
          name: 'AuthService',
          error: e,
        );
      }
    }

    return user;
  }
}
