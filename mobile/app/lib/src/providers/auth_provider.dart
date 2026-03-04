import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_state.dart';
import '../models/user.dart';
import '../services/app_lifecycle_service.dart';
import '../services/review_service.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../services/token_storage_service.dart';
import '../services/subscription_service.dart';
import 'backend_provider.dart';
import 'subscription_provider.dart';

// Token storage service provider
final tokenStorageServiceProvider = Provider<TokenStorageService>((ref) {
  return TokenStorageService();
});

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    tokenStorage: ref.watch(tokenStorageServiceProvider),
  );
});

// Auth state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final TokenStorageService _tokenStorage;
  final SubscriptionService _subscriptionService;
  final BackendService _backendService;

  AuthNotifier(
    this._authService,
    this._tokenStorage,
    this._subscriptionService,
    this._backendService,
  ) : super(const AuthState.initial()) {
    _initializeAppLifecycle();
    _checkAuthStatus();
  }

  /// Initialize AppLifecycleService for foreground token refresh
  void _initializeAppLifecycle() {
    try {
      AppLifecycleService.instance.initialize(
        authService: _authService,
        tokenStorage: _tokenStorage,
      );

      // Set up callback for when re-login is required
      AppLifecycleService.instance.onReloginRequired = _handleReloginRequired;

      developer.log('AppLifecycleService initialized', name: 'AuthNotifier');

      // Initialize ReviewService (separate WidgetsBindingObserver for session tracking)
      ReviewService.instance.initialize();
      developer.log('ReviewService initialized', name: 'AuthNotifier');
    } catch (e) {
      developer.log('Failed to initialize AppLifecycleService: $e', name: 'AuthNotifier');
    }
  }

  /// Last known user info (stored when re-login is required)
  /// Used to show "Welcome back, [Name]!" in the re-login dialog
  User? _lastKnownUser;

  /// Get the last known user (for welcome back dialog)
  User? get lastKnownUser => _lastKnownUser;

  /// Handle when token refresh fails and re-login is required
  void _handleReloginRequired() {
    developer.log('Re-login required - token refresh failed', name: 'AuthNotifier');

    // Store the current user info before clearing state
    // This allows us to show "Welcome back, [Name]!" in the re-login dialog
    final currentState = state;
    if (currentState is AuthStateAuthenticated) {
      _lastKnownUser = currentState.user;
      developer.log('Stored last known user: ${_lastKnownUser?.email}', name: 'AuthNotifier');
    }

    // Clear local state and redirect to login
    // This provides a graceful UX instead of cryptic errors
    state = const AuthState.unauthenticated();
  }

  /// Perform quick re-login with stored user's email as hint.
  ///
  /// This provides a smoother re-authentication experience when the
  /// refresh token has expired. The user's email is pre-filled.
  Future<void> quickRelogin() async {
    developer.log('Starting quick re-login...', name: 'AuthNotifier');

    state = const AuthState.loading();

    try {
      final user = await _authService.quickRelogin();

      if (user != null) {
        developer.log('Quick re-login successful: ${user.email}', name: 'AuthNotifier');
        // Initialize RevenueCat with Entra sub as App User ID, email as attribute
        await _initializeSubscription(user.id, email: user.email, displayName: user.displayName);
        state = AuthState.authenticated(user);
        _lastKnownUser = null; // Clear since we're now logged in
      } else {
        developer.log('Quick re-login cancelled or failed', name: 'AuthNotifier');
        state = const AuthState.unauthenticated();
      }
    } catch (e) {
      developer.log('Quick re-login error', name: 'AuthNotifier', error: e);
      state = AuthState.error(e.toString());
    }
  }

  /// Check if user is already authenticated on app start
  Future<void> _checkAuthStatus() async {
    try {
      developer.log('Checking auth status...', name: 'AuthNotifier');
      state = const AuthState.loading();

      final user = await _authService.getCurrentUser();

      if (user != null) {
        developer.log('User authenticated: ${user.email}', name: 'AuthNotifier');
        // Initialize RevenueCat with Entra sub as App User ID, email as attribute
        await _initializeSubscription(user.id, email: user.email, displayName: user.displayName);
        state = AuthState.authenticated(user);
      } else {
        developer.log('User not authenticated - redirecting to login', name: 'AuthNotifier');
        state = const AuthState.unauthenticated();
      }
    } catch (e) {
      developer.log('Auth check error - setting unauthenticated', name: 'AuthNotifier', error: e);
      state = const AuthState.unauthenticated();
    }
  }

  /// Sign in with Entra External ID
  Future<void> signIn() async {
    try {
      state = const AuthState.loading();

      final user = await _authService.signIn();

      if (user != null) {
        developer.log('Sign in successful: ${user.email}', name: 'AuthNotifier');
        // Initialize RevenueCat with Entra sub as App User ID, email as attribute
        await _initializeSubscription(user.id, email: user.email, displayName: user.displayName);
        state = AuthState.authenticated(user);
      } else {
        developer.log('Sign in cancelled', name: 'AuthNotifier');
        state = const AuthState.unauthenticated();
      }
    } catch (e) {
      developer.log('Sign in error', name: 'AuthNotifier', error: e);
      state = AuthState.error(e.toString());
    }
  }

  /// Sign up with Entra External ID
  Future<void> signUp() async {
    try {
      state = const AuthState.loading();

      final user = await _authService.signUp();

      if (user != null) {
        developer.log('Sign up successful: ${user.email}', name: 'AuthNotifier');
        // Initialize RevenueCat with Entra sub as App User ID, email as attribute
        await _initializeSubscription(user.id, email: user.email, displayName: user.displayName);
        state = AuthState.authenticated(user);
      } else {
        developer.log('Sign up cancelled', name: 'AuthNotifier');
        state = const AuthState.unauthenticated();
      }
    } catch (e) {
      developer.log('Sign up error', name: 'AuthNotifier', error: e);
      state = AuthState.error(e.toString());
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      developer.log('Sign out successful', name: 'AuthNotifier');
    } catch (e) {
      // Log the error but still transition to unauthenticated
      // The auth service already cleared local storage, so we're effectively signed out
      developer.log('Sign out error (non-fatal): ${e.toString()}', name: 'AuthNotifier', error: e);
    }

    // Logout from RevenueCat
    try {
      await _subscriptionService.logout();
      developer.log('RevenueCat logout successful', name: 'AuthNotifier');
    } catch (e) {
      developer.log('RevenueCat logout error (non-fatal): $e', name: 'AuthNotifier');
    }

    // Always transition to unauthenticated after sign out attempt
    state = const AuthState.unauthenticated();
  }

  /// Delete account: removes all server-side data, then signs out.
  /// Apple guideline 5.1.1(v) requires apps to offer account deletion.
  Future<void> deleteAccount() async {
    try {
      // NOTE: Do NOT set state = AuthState.loading() here.
      // The profile screen shows its own loading dialog, and changing
      // auth state triggers RouterRefreshNotifier which can interfere
      // with the in-flight DELETE request.

      // Step 1: Delete all server-side data
      await _backendService.deleteAccount();
      developer.log('Account data deleted from backend', name: 'AuthNotifier');

      // Step 2: Sign out (clear tokens, MSAL session)
      try {
        await _authService.signOut();
      } catch (e) {
        developer.log('Auth signOut during account deletion (non-fatal): $e', name: 'AuthNotifier');
      }

      // Step 3: Log out from RevenueCat
      try {
        await _subscriptionService.logout();
      } catch (e) {
        developer.log('RevenueCat logout during account deletion (non-fatal): $e', name: 'AuthNotifier');
      }

      developer.log('Account deletion complete', name: 'AuthNotifier');
      state = const AuthState.unauthenticated();
    } catch (e) {
      developer.log('Account deletion failed: $e', name: 'AuthNotifier', error: e);
      // Try to restore authenticated state if deletion fails
      try {
        final user = await _authService.getCurrentUser();
        if (user != null) {
          state = AuthState.authenticated(user);
        } else {
          state = const AuthState.unauthenticated();
        }
      } catch (_) {
        state = const AuthState.unauthenticated();
      }
      rethrow;
    }
  }

  /// Clear error state and return to unauthenticated
  /// Call this when user dismisses an error or wants to retry
  void clearError() {
    if (state is AuthStateError) {
      developer.log('Clearing error state', name: 'AuthNotifier');
      state = const AuthState.unauthenticated();
    }
  }

  /// Refresh authentication state
  Future<void> refresh() async {
    try {
      final user = await _authService.getCurrentUser();

      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        state = const AuthState.unauthenticated();
      }
    } catch (e) {
      developer.log('Refresh error', name: 'AuthNotifier', error: e);
      state = const AuthState.unauthenticated();
    }
  }

  /// DEBUG: Force token expiration to test refresh flow
  /// This simulates what happens when the access token expires
  Future<void> debugForceTokenExpiration() async {
    developer.log('DEBUG: Forcing token expiration...', name: 'AuthNotifier');
    await _authService.debugForceTokenExpiration();
    developer.log('DEBUG: Token expired, now refreshing auth state...', name: 'AuthNotifier');
    // Trigger a refresh which will now see the expired token
    await refresh();
  }

  /// Initialize RevenueCat subscription service with user's Entra sub as App User ID.
  /// Email is set as $email subscriber attribute for dashboard search (Ctrl+K).
  /// Uses BackendService to fetch the RevenueCat API key from Azure Key Vault.
  Future<void> _initializeSubscription(String userId, {String? email, String? displayName}) async {
    try {
      await _subscriptionService.initialize(userId, _backendService, email: email, displayName: displayName);
      developer.log('RevenueCat initialized for user', name: 'AuthNotifier');
    } catch (e) {
      // Log the FULL error for debugging - don't silently swallow
      developer.log(
        'RevenueCat initialization failed: $e',
        name: 'AuthNotifier',
        level: 900, // Warning level
      );
      // Don't fail auth — subscription is non-critical for app startup.
      // The subscription provider will yield SubscriptionStatus.none
      // and the UI will show "Subscribe" state. If the user taps Subscribe,
      // the subscription sheet will attempt lazy re-initialization.
    }
  }
}

// Auth state provider
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authServiceProvider),
    ref.watch(tokenStorageServiceProvider),
    ref.watch(subscriptionServiceProvider),
    ref.watch(backendServiceProvider),
  );
});

// Helper providers

/// Current authenticated user (null if not authenticated)
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.maybeWhen(
    authenticated: (user) => user,
    orElse: () => null,
  );
});

/// Whether user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.maybeWhen(
    authenticated: (_) => true,
    orElse: () => false,
  );
});

/// Access token provider (for API calls)
final accessTokenProvider = FutureProvider<String?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getValidAccessToken();
});
