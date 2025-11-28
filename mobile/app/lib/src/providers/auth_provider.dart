import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_state.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/token_storage_service.dart';

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

  AuthNotifier(this._authService) : super(const AuthState.initial()) {
    _checkAuthStatus();
  }

  /// Check if user is already authenticated on app start
  Future<void> _checkAuthStatus() async {
    try {
      developer.log('Checking auth status...', name: 'AuthNotifier');
      state = const AuthState.loading();

      final user = await _authService.getCurrentUser();

      if (user != null) {
        developer.log('User authenticated: ${user.email}', name: 'AuthNotifier');
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
    // Always transition to unauthenticated after sign out attempt
    state = const AuthState.unauthenticated();
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
}

// Auth state provider
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
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
