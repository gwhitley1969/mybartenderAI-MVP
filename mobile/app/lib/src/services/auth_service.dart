import 'dart:developer' as developer;

import 'package:msal_auth/msal_auth.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../config/auth_config.dart';
import '../models/user.dart';
import 'token_storage_service.dart';

/// Authentication service for Entra External ID (Azure AD B2C) using MSAL
class AuthService {
  SingleAccountPca? _msalAuth;
  final TokenStorageService _tokenStorage;

  /// Track if we've already attempted recovery to prevent infinite loops
  bool _recoveryAttempted = false;

  AuthService({
    required TokenStorageService tokenStorage,
  }) : _tokenStorage = tokenStorage;

  /// Initialize MSAL authentication
  Future<void> initialize() async {
    try {
      developer.log('Initializing MSAL authentication', name: 'AuthService');

      _msalAuth = await SingleAccountPca.create(
        clientId: AuthConfig.clientId,
        androidConfig: AndroidConfig(
          configFilePath: 'assets/msal_config.json',
          redirectUri: 'msauth://ai.mybartender.mybartenderai/callback',
        ),
        // iOS configuration would go here if needed
        // appleConfig: AppleConfig(
        //   authorityType: AuthorityType.aad,
        // ),
      );

      developer.log('MSAL initialization successful', name: 'AuthService');
    } catch (e, stackTrace) {
      developer.log(
        'MSAL initialization error: ${e.toString()}',
        name: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Sign in with Entra External ID (supports Email, Google, Facebook)
  Future<User?> signIn() async {
    try {
      if (_msalAuth == null) {
        await initialize();
      }

      developer.log('Starting sign in flow with MSAL', name: 'AuthService');
      developer.log('Client ID: ${AuthConfig.clientId}', name: 'AuthService');

      // LAYER 1: Clear any stale accounts before attempting sign-in
      // This prevents the current_account_mismatch error
      await _clearStaleAccountIfExists();

      // Use Microsoft Graph scopes
      // Note: For MSAL, we need to use the full URL format for Graph API scopes
      // offline_access might be automatically handled by MSAL
      final scopes = [
        'https://graph.microsoft.com/User.Read',  // Capital U and R
        'openid',
        'profile',
        'email',
        // Try without offline_access - MSAL might handle it automatically
        // 'offline_access',
      ];

      developer.log('Requesting scopes: $scopes', name: 'AuthService');

      // Interactive sign in with error recovery
      AuthenticationResult? result;
      try {
        result = await _msalAuth!.acquireToken(
          scopes: scopes,
          prompt: Prompt.login, // Force showing the login prompt
        );
      } catch (e) {
        // LAYER 2: Handle current_account_mismatch by clearing and retrying
        if (_isAccountMismatchError(e) && !_recoveryAttempted) {
          developer.log(
            'Caught current_account_mismatch error, attempting recovery',
            name: 'AuthService',
          );
          result = await _recoverFromAccountMismatch(scopes);
        } else {
          rethrow;
        }
      }

      // Reset recovery flag on successful sign-in
      _recoveryAttempted = false;

      if (result == null) {
        developer.log('Sign in cancelled by user', name: 'AuthService');
        return null;
      }

      developer.log('Sign in successful', name: 'AuthService');
      developer.log('Access token received: ${result.accessToken != null}', name: 'AuthService');
      developer.log('ID token received: ${result.idToken != null}', name: 'AuthService');

      return await _handleAuthResult(result);
    } catch (e, stackTrace) {
      // Reset recovery flag on error
      _recoveryAttempted = false;
      developer.log(
        'Sign in error: ${e.toString()}',
        name: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// LAYER 1: Check for and clear any stale accounts in MSAL's native cache
  Future<void> _clearStaleAccountIfExists() async {
    try {
      if (_msalAuth == null) return;

      // Try to get the current account - if one exists, it's stale
      // (we wouldn't be in signIn if we had a valid session)
      final currentAccount = await _msalAuth!.currentAccount;

      // If we get here without exception, there's a stale account
      developer.log(
        'Found stale account in MSAL cache: ${currentAccount.username}, clearing it',
        name: 'AuthService',
      );

      await _msalAuth!.signOut();
      developer.log('Stale account cleared successfully', name: 'AuthService');
    } catch (e) {
      // MsalException is thrown when no account exists, which is expected
      // This is the normal case - no stale account to clear
      developer.log(
        'No stale account found (expected): ${e.runtimeType}',
        name: 'AuthService',
      );
    }
  }

  /// Check if an exception is the current_account_mismatch error
  bool _isAccountMismatchError(Object e) {
    final errorString = e.toString().toLowerCase();
    return errorString.contains('current_account_mismatch') ||
           errorString.contains('account does not match');
  }

  /// LAYER 2: Recover from current_account_mismatch by clearing everything and retrying
  Future<AuthenticationResult?> _recoverFromAccountMismatch(List<String> scopes) async {
    _recoveryAttempted = true;

    developer.log('Starting recovery from account mismatch', name: 'AuthService');

    // Clear local storage first
    await _tokenStorage.clearAll();

    // Try to sign out from MSAL (may fail, but that's ok)
    try {
      if (_msalAuth != null) {
        await _msalAuth!.signOut();
      }
    } catch (e) {
      developer.log(
        'MSAL signOut during recovery failed (expected): ${e.toString()}',
        name: 'AuthService',
      );
    }

    // LAYER 3: Reset MSAL instance to force fresh initialization
    _msalAuth = null;

    // Re-initialize with fresh instance
    await initialize();

    // Retry the sign-in
    developer.log('Retrying acquireToken after recovery', name: 'AuthService');
    return await _msalAuth!.acquireToken(
      scopes: scopes,
      prompt: Prompt.login,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      developer.log('Starting sign out flow', name: 'AuthService');

      // LAYER 4: Clear local storage FIRST before MSAL sign out
      // This minimizes the corruption window if the user closes the app mid-signout
      await _tokenStorage.clearAll();
      developer.log('Local tokens cleared', name: 'AuthService');

      if (_msalAuth == null) {
        developer.log('MSAL not initialized, local cleanup complete', name: 'AuthService');
        return;
      }

      // Sign out from MSAL
      try {
        await _msalAuth!.signOut();
        developer.log('MSAL sign out successful', name: 'AuthService');
      } catch (e) {
        // Log but don't fail - local storage is already cleared
        developer.log(
          'MSAL signOut failed (non-fatal): ${e.toString()}',
          name: 'AuthService',
        );
      }

      // LAYER 3: Reset MSAL instance to force fresh initialization on next use
      // This prevents any stale internal state from persisting
      _msalAuth = null;
      developer.log('MSAL instance reset', name: 'AuthService');

      developer.log('Sign out complete', name: 'AuthService');
    } catch (e, stackTrace) {
      developer.log(
        'Sign out error: ${e.toString()}',
        name: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      // Ensure cleanup happens even on error
      await _tokenStorage.clearAll();
      _msalAuth = null;
      rethrow;
    }
  }

  /// Handle the authentication result and create a User object
  Future<User?> _handleAuthResult(AuthenticationResult result) async {
    try {
      final accessToken = result.accessToken;
      final idToken = result.idToken;

      if (accessToken == null || idToken == null) {
        developer.log('No tokens received', name: 'AuthService');
        return null;
      }

      // Decode the ID token to get user information
      final decodedToken = JwtDecoder.decode(idToken);
      developer.log('Decoded ID token: $decodedToken', name: 'AuthService');

      // Extract user information from the ID token
      final userId = decodedToken['sub'] ?? decodedToken['oid'] ?? '';
      final email = decodedToken['email'] ??
                   decodedToken['preferred_username'] ??
                   decodedToken['unique_name'] ??
                   '';
      final displayName = decodedToken['name'];
      final givenName = decodedToken['given_name'];
      final familyName = decodedToken['family_name'];

      // Store tokens individually
      await _tokenStorage.saveAccessToken(accessToken);
      if (idToken != null) {
        await _tokenStorage.saveIdToken(idToken);
      }
      final expiresOn = result.expiresOn ?? DateTime.now().add(const Duration(hours: 1));
      await _tokenStorage.saveExpiresAt(expiresOn);

      // Create and return User object using the correct constructor
      final user = User(
        id: userId,
        email: email,
        displayName: displayName,
        givenName: givenName,
        familyName: familyName,
      );

      await _tokenStorage.saveUserProfile(user);

      developer.log('User authenticated: ${user.email}', name: 'AuthService');
      return user;
    } catch (e, stackTrace) {
      developer.log(
        'Error handling auth result: ${e.toString()}',
        name: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Get the current user if authenticated
  Future<User?> getCurrentUser() async {
    try {
      final userProfile = await _tokenStorage.getUserProfile();
      if (userProfile == null) {
        return null;
      }

      // Check if token is still valid
      final expiresAt = await _tokenStorage.getExpiresAt();
      if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
        // Token expired, try to refresh silently
        developer.log('Token expired, attempting silent refresh', name: 'AuthService');
        return await refreshToken();
      }

      return userProfile;
    } catch (e, stackTrace) {
      developer.log(
        'Error getting current user: ${e.toString()}',
        name: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Refresh the access token silently
  Future<User?> refreshToken() async {
    try {
      if (_msalAuth == null) {
        await initialize();
      }

      developer.log('Attempting silent token refresh', name: 'AuthService');

      // Try to acquire token silently
      final AuthenticationResult? result = await _msalAuth!.acquireTokenSilent(
        scopes: [
          'https://graph.microsoft.com/User.Read',  // Capital U and R
          'openid',
          'profile',
          'email',
          // 'offline_access',  // MSAL handles this automatically
        ],
      );

      if (result == null) {
        developer.log('Silent refresh failed', name: 'AuthService');
        return null;
      }

      developer.log('Silent refresh successful', name: 'AuthService');
      return await _handleAuthResult(result);
    } catch (e, stackTrace) {
      developer.log(
        'Token refresh error: ${e.toString()}',
        name: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final user = await getCurrentUser();
    return user != null;
  }

  /// Sign up (same as sign in for MSAL)
  Future<User?> signUp() async {
    // For MSAL with Entra External ID, sign up and sign in use the same flow
    return await signIn();
  }

  /// Get valid access token (refreshes if expired)
  Future<String?> getValidAccessToken() async {
    try {
      // First check if we have a stored token
      final storedToken = await _tokenStorage.getAccessToken();
      final expiresAt = await _tokenStorage.getExpiresAt();

      // Check if token is still valid
      if (storedToken != null &&
          expiresAt != null &&
          expiresAt.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
        // Token is still valid for at least 5 more minutes
        return storedToken;
      }

      // Try to refresh the token
      developer.log('Access token expired or missing, attempting refresh', name: 'AuthService');
      final user = await refreshToken();

      if (user != null) {
        return await _tokenStorage.getAccessToken();
      }

      // If refresh fails, return null
      return null;
    } catch (e, stackTrace) {
      developer.log(
        'Error getting valid access token: ${e.toString()}',
        name: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}