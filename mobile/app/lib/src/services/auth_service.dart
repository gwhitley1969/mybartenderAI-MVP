import 'dart:developer' as developer;

import 'package:msal_auth/msal_auth.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../config/auth_config.dart';
import '../models/user.dart';
import 'background_token_service.dart';
import 'token_storage_service.dart';

/// Authentication service for Entra External ID (Azure AD B2C) using MSAL
///
/// DIAGNOSTIC VERSION - Added detailed logging to investigate 24-hour re-login issue
/// Date: December 2025
class AuthService {
  SingleAccountPca? _msalAuth;
  final TokenStorageService _tokenStorage;

  /// Track if we've already attempted recovery to prevent infinite loops
  bool _recoveryAttempted = false;

  /// Track last successful token refresh for diagnostics
  DateTime? _lastSuccessfulRefresh;

  /// Track last authentication time for diagnostics
  DateTime? _lastAuthTime;

  AuthService({
    required TokenStorageService tokenStorage,
  }) : _tokenStorage = tokenStorage;

  /// Log with timestamp for diagnostic purposes
  /// Using print() instead of developer.log() so output appears in logcat as "I flutter :"
  void _diagLog(String message, {Object? error, StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toIso8601String();
    final fullMessage = '[AUTH-DIAG][$timestamp] $message';
    // Use print() for reliable logcat output
    print(fullMessage);
    // Also log to developer.log for debug console
    developer.log(
      fullMessage,
      name: 'AuthService.DIAG',
      error: error,
      stackTrace: stackTrace,
    );
    if (error != null) {
      print('[AUTH-DIAG] Error: $error');
    }
    if (stackTrace != null) {
      print('[AUTH-DIAG] StackTrace: $stackTrace');
    }
  }

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
    _diagLog('=== INTERACTIVE SIGN IN STARTED ===');

    try {
      if (_msalAuth == null) {
        _diagLog('MSAL not initialized, initializing now...');
        await initialize();
      }

      _diagLog('Starting interactive sign in flow with MSAL');
      _diagLog('Client ID: ${AuthConfig.clientId}');

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
        _diagLog('Sign in cancelled by user');
        _diagLog('=== INTERACTIVE SIGN IN CANCELLED ===');
        return null;
      }

      _diagLog('Interactive sign in completed successfully!');
      _diagLog('Access token received: ${result.accessToken != null}');
      _diagLog('ID token received: ${result.idToken != null}');
      _diagLog('Expires on: ${result.expiresOn?.toIso8601String() ?? "UNKNOWN"}');

      final user = await _handleAuthResult(result);
      _diagLog('=== INTERACTIVE SIGN IN SUCCEEDED ===');
      return user;
    } catch (e, stackTrace) {
      // Reset recovery flag on error
      _recoveryAttempted = false;
      _diagLog('!!! INTERACTIVE SIGN IN FAILED !!!');
      _diagLog('Exception type: ${e.runtimeType}');
      _diagLog('Exception message: ${e.toString()}');
      _diagLog('=== INTERACTIVE SIGN IN ERROR ===');

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

      // Cancel background token refresh task
      try {
        await BackgroundTokenService.instance.cancelTokenRefresh();
        developer.log('Background token refresh cancelled', name: 'AuthService');
      } catch (e) {
        developer.log('Failed to cancel background token refresh: $e', name: 'AuthService');
      }

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
      _diagLog('Processing authentication result...');

      final accessToken = result.accessToken;
      final idToken = result.idToken;

      if (accessToken == null || idToken == null) {
        _diagLog('ERROR: No tokens received in auth result');
        _diagLog('Access token null: ${accessToken == null}');
        _diagLog('ID token null: ${idToken == null}');
        return null;
      }

      // Decode the ID token to get user information
      final decodedToken = JwtDecoder.decode(idToken);
      _diagLog('ID token decoded successfully');

      // Log token claims for diagnostics (excluding sensitive data)
      _diagLog('Token issuer (iss): ${decodedToken['iss']}');
      _diagLog('Token audience (aud): ${decodedToken['aud']}');
      _diagLog('Token issued at (iat): ${decodedToken['iat']}');
      _diagLog('Token expires (exp): ${decodedToken['exp']}');

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
      _diagLog('Access token saved to FlutterSecureStorage');

      if (idToken != null) {
        await _tokenStorage.saveIdToken(idToken);
        _diagLog('ID token saved to FlutterSecureStorage');
      }

      final expiresOn = result.expiresOn ?? DateTime.now().add(const Duration(hours: 1));
      await _tokenStorage.saveExpiresAt(expiresOn);
      _diagLog('Token expiry saved: ${expiresOn.toIso8601String()}');

      // Calculate and log token lifetime
      final tokenLifetime = expiresOn.difference(DateTime.now());
      _diagLog('Token will be valid for: ${tokenLifetime.inMinutes} minutes');

      // Create and return User object using the correct constructor
      final user = User(
        id: userId,
        email: email,
        displayName: displayName,
        givenName: givenName,
        familyName: familyName,
      );

      await _tokenStorage.saveUserProfile(user);
      _diagLog('User profile saved to FlutterSecureStorage');

      // Update tracking timestamps
      _lastAuthTime = DateTime.now();
      _lastSuccessfulRefresh = DateTime.now();
      _diagLog('Authentication timestamps updated');

      // Schedule background token refresh to keep refresh token active
      // This prevents the 12-hour inactivity timeout in Entra External ID
      try {
        await BackgroundTokenService.instance.scheduleTokenRefresh();
        _diagLog('Background token refresh scheduled (every 10 hours)');
      } catch (e) {
        _diagLog('Failed to schedule background token refresh: $e');
      }

      _diagLog('User authenticated successfully: ${user.email}');
      return user;
    } catch (e, stackTrace) {
      _diagLog(
        'ERROR in _handleAuthResult: ${e.toString()}',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Get the current user if authenticated
  Future<User?> getCurrentUser() async {
    try {
      _diagLog('getCurrentUser() called - checking authentication state');

      final userProfile = await _tokenStorage.getUserProfile();
      if (userProfile == null) {
        _diagLog('No user profile in FlutterSecureStorage - user not authenticated');
        return null;
      }

      _diagLog('Found user profile in storage: ${userProfile.email}');

      // Check if token is still valid
      final expiresAt = await _tokenStorage.getExpiresAt();
      final now = DateTime.now();

      if (expiresAt != null) {
        final timeUntilExpiry = expiresAt.difference(now);
        _diagLog('Access token expires at: ${expiresAt.toIso8601String()}');
        _diagLog('Time until expiry: ${timeUntilExpiry.inMinutes} minutes (${timeUntilExpiry.inHours} hours)');

        if (expiresAt.isBefore(now)) {
          _diagLog('ACCESS TOKEN EXPIRED - attempting silent refresh');
          _diagLog('Token was expired by: ${now.difference(expiresAt).inMinutes} minutes');

          // DIAGNOSTIC: Check MSAL account state before refresh
          await _checkMsalAccountState();

          return await refreshToken();
        }
      } else {
        _diagLog('WARNING: No expiry time stored - this should not happen');
      }

      _diagLog('Token still valid, returning cached user profile');
      return userProfile;
    } catch (e, stackTrace) {
      _diagLog(
        'ERROR in getCurrentUser: ${e.toString()}',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// DIAGNOSTIC: Check MSAL's internal account state
  Future<void> _checkMsalAccountState() async {
    _diagLog('--- MSAL Account State Check ---');

    if (_msalAuth == null) {
      _diagLog('MSAL not initialized yet, will initialize during refresh');
      return;
    }

    try {
      final currentAccount = await _msalAuth!.currentAccount;
      _diagLog('MSAL HAS cached account: ${currentAccount.username}');
      _diagLog('Account ID: ${currentAccount.id}');
    } catch (e) {
      _diagLog('MSAL has NO cached account: ${e.runtimeType}');
      _diagLog('Exception details: ${e.toString()}');
    }

    _diagLog('--- End MSAL Account State Check ---');
  }

  /// Refresh the access token silently
  Future<User?> refreshToken() async {
    _diagLog('=== REFRESH TOKEN ATTEMPT STARTED ===');
    _diagLog('Last successful refresh: ${_lastSuccessfulRefresh?.toIso8601String() ?? "NEVER"}');
    _diagLog('Last auth time: ${_lastAuthTime?.toIso8601String() ?? "UNKNOWN"}');

    if (_lastSuccessfulRefresh != null) {
      final timeSinceLastRefresh = DateTime.now().difference(_lastSuccessfulRefresh!);
      _diagLog('Time since last successful refresh: ${timeSinceLastRefresh.inHours} hours (${timeSinceLastRefresh.inMinutes} minutes)');
    }

    try {
      if (_msalAuth == null) {
        _diagLog('MSAL not initialized, initializing now...');
        await initialize();
        _diagLog('MSAL initialization complete');
      }

      // CRITICAL DIAGNOSTIC: Check if MSAL has an account BEFORE calling acquireTokenSilent
      _diagLog('Checking MSAL account state before acquireTokenSilent...');
      bool hasAccount = false;
      String? accountUsername;

      try {
        final currentAccount = await _msalAuth!.currentAccount;
        hasAccount = true;
        accountUsername = currentAccount.username;
        _diagLog('MSAL ACCOUNT FOUND: $accountUsername');
        _diagLog('Account ID: ${currentAccount.id}');
      } catch (e) {
        _diagLog('!!! MSAL HAS NO ACCOUNT - THIS IS LIKELY THE PROBLEM !!!');
        _diagLog('Exception type: ${e.runtimeType}');
        _diagLog('Exception message: ${e.toString()}');
        _diagLog('Without a cached account, acquireTokenSilent WILL FAIL');

        // Return early with diagnostic info
        _diagLog('=== REFRESH TOKEN FAILED - NO MSAL ACCOUNT ===');
        return null;
      }

      _diagLog('Calling acquireTokenSilent...');
      final scopes = [
        'https://graph.microsoft.com/User.Read',
        'openid',
        'profile',
        'email',
      ];
      _diagLog('Requested scopes: $scopes');

      // Try to acquire token silently
      final AuthenticationResult? result = await _msalAuth!.acquireTokenSilent(
        scopes: scopes,
      );

      if (result == null) {
        _diagLog('!!! acquireTokenSilent returned NULL !!!');
        _diagLog('This means MSAL could not refresh the token');
        _diagLog('=== REFRESH TOKEN FAILED - NULL RESULT ===');
        return null;
      }

      // SUCCESS!
      _lastSuccessfulRefresh = DateTime.now();
      _diagLog('SUCCESS! acquireTokenSilent returned a result');
      _diagLog('Access token received: ${result.accessToken != null}');
      _diagLog('ID token received: ${result.idToken != null}');
      _diagLog('Expires on: ${result.expiresOn?.toIso8601String() ?? "UNKNOWN"}');

      if (result.expiresOn != null) {
        final tokenLifetime = result.expiresOn!.difference(DateTime.now());
        _diagLog('Token lifetime: ${tokenLifetime.inMinutes} minutes');
      }

      _diagLog('=== REFRESH TOKEN SUCCEEDED ===');
      return await _handleAuthResult(result);

    } on MsalException catch (e) {
      // Specific MSAL exception handling
      _diagLog('!!! MSAL EXCEPTION CAUGHT !!!');
      _diagLog('Exception type: MsalException');
      _diagLog('Message: ${e.message}');

      final errorMessage = e.message.toLowerCase();

      // Check for specific error types based on message content
      if (errorMessage.contains('interaction_required') ||
          errorMessage.contains('interaction')) {
        _diagLog('>>> INTERACTION REQUIRED - Refresh token may be expired or revoked');
        _diagLog('>>> User needs to re-authenticate interactively');
      }

      if (errorMessage.contains('no_account') ||
          errorMessage.contains('no account') ||
          errorMessage.contains('no current account')) {
        _diagLog('>>> NO ACCOUNT IN CACHE - MSAL native cache is empty');
      }

      if (errorMessage.contains('invalid_grant')) {
        _diagLog('>>> INVALID GRANT - Refresh token has been revoked or expired server-side');
      }

      if (errorMessage.contains('ui_required')) {
        _diagLog('>>> UI REQUIRED - Silent auth not possible, need interactive flow');
      }

      _diagLog('=== REFRESH TOKEN FAILED - MSAL EXCEPTION ===');
      return null;

    } catch (e, stackTrace) {
      // Generic exception handling
      _diagLog('!!! UNEXPECTED EXCEPTION CAUGHT !!!');
      _diagLog('Exception type: ${e.runtimeType}');
      _diagLog('Exception message: ${e.toString()}');
      _diagLog('Stack trace available: ${stackTrace != null}');

      developer.log(
        'Token refresh error: ${e.toString()}',
        name: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );

      _diagLog('=== REFRESH TOKEN FAILED - UNEXPECTED ERROR ===');
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

  /// DIAGNOSTIC TEST: Force token expiration to simulate the 24-hour issue
  /// This sets the token expiry to 1 minute ago, forcing a refresh attempt
  /// Call this to test what happens when the access token expires
  Future<void> debugForceTokenExpiration() async {
    _diagLog('=== DEBUG: FORCING TOKEN EXPIRATION ===');

    // Get current expiry for logging
    final currentExpiry = await _tokenStorage.getExpiresAt();
    _diagLog('Current token expiry: ${currentExpiry?.toIso8601String() ?? "NONE"}');

    // Set expiry to 1 minute ago
    final expiredTime = DateTime.now().subtract(const Duration(minutes: 1));
    await _tokenStorage.saveExpiresAt(expiredTime);

    _diagLog('Token expiry set to: ${expiredTime.toIso8601String()}');
    _diagLog('Token is now EXPIRED - next getCurrentUser() will trigger refresh');
    _diagLog('=== DEBUG: TOKEN EXPIRATION FORCED ===');
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