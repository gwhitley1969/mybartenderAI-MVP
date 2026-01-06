import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

import 'auth_service.dart';
import 'notification_service.dart';
import 'token_storage_service.dart';

/// Service that monitors app lifecycle and proactively refreshes tokens
/// when the app comes to the foreground.
///
/// This is the PRIMARY mechanism for preventing the 12-hour inactivity timeout
/// in Microsoft Entra External ID. The background refresh via WorkManager
/// serves as a backup, but this foreground refresh is more reliable because:
/// - It runs every time the user opens the app
/// - It's not affected by OEM battery optimization
/// - It catches all cases where background tasks were delayed or killed
///
/// The refresh strategy:
/// - If token is > 6 hours old, proactively refresh on app resume
/// - This provides a 6-hour safety margin before the 12-hour timeout
class AppLifecycleService with WidgetsBindingObserver {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  static AppLifecycleService get instance => _instance;

  AuthService? _authService;
  TokenStorageService? _tokenStorage;
  bool _isInitialized = false;
  bool _isRefreshing = false;

  /// Callback to notify when re-login is required
  /// Set this from auth_provider to trigger re-login flow
  void Function()? onReloginRequired;

  /// Log with timestamp for diagnostic purposes
  void _log(String message, {Object? error}) {
    final timestamp = DateTime.now().toIso8601String();
    final fullMessage = '[APP-LIFECYCLE][$timestamp] $message';
    print(fullMessage);
    developer.log(
      fullMessage,
      name: 'AppLifecycleService',
      error: error,
    );
  }

  /// Initialize the service with required dependencies
  /// Must be called after WidgetsFlutterBinding.ensureInitialized()
  void initialize({
    required AuthService authService,
    required TokenStorageService tokenStorage,
  }) {
    if (_isInitialized) {
      _log('Already initialized, skipping');
      return;
    }

    _authService = authService;
    _tokenStorage = tokenStorage;

    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    _log('Initialized - now monitoring app lifecycle for token refresh');
  }

  /// Dispose the service
  void dispose() {
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
      _log('Disposed - stopped monitoring app lifecycle');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _log('App lifecycle changed: $state');

    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  /// Called when app comes to foreground
  Future<void> _onAppResumed() async {
    _log('=== APP RESUMED - Checking token freshness ===');

    if (_authService == null || _tokenStorage == null) {
      _log('Services not initialized, skipping refresh check');
      return;
    }

    // Prevent concurrent refresh attempts
    if (_isRefreshing) {
      _log('Refresh already in progress, skipping');
      return;
    }

    try {
      // Check if user is authenticated
      final userProfile = await _tokenStorage!.getUserProfile();
      if (userProfile == null) {
        _log('No user profile - not authenticated, skipping refresh');
        return;
      }

      _log('User authenticated: ${userProfile.email}');

      // Check how old the token is
      final lastRefreshTime = await _tokenStorage!.getLastRefreshTime();
      final tokenAge = lastRefreshTime != null
          ? DateTime.now().difference(lastRefreshTime)
          : null;

      _log('Last token refresh: ${lastRefreshTime?.toIso8601String() ?? "NEVER"}');
      if (tokenAge != null) {
        _log('Token age: ${tokenAge.inHours} hours (${tokenAge.inMinutes} minutes)');
      }

      // Proactive refresh threshold: 6 hours
      // This provides a 6-hour safety margin before the 12-hour Entra timeout
      const refreshThreshold = Duration(hours: 6);

      // Decide if we should refresh
      bool shouldRefresh = false;
      String reason = '';

      if (tokenAge == null) {
        // No refresh time recorded - likely old installation before this fix
        // Check token expiry instead
        final expiresAt = await _tokenStorage!.getExpiresAt();
        if (expiresAt != null) {
          final timeUntilExpiry = expiresAt.difference(DateTime.now());
          if (timeUntilExpiry.inMinutes < 30) {
            shouldRefresh = true;
            reason = 'Token expires in ${timeUntilExpiry.inMinutes} minutes';
          } else {
            _log('No refresh time recorded, but token still valid for ${timeUntilExpiry.inHours} hours');
          }
        } else {
          shouldRefresh = true;
          reason = 'No refresh time or expiry recorded';
        }
      } else if (tokenAge > refreshThreshold) {
        shouldRefresh = true;
        reason = 'Token is ${tokenAge.inHours} hours old (threshold: ${refreshThreshold.inHours} hours)';
      }

      if (shouldRefresh) {
        _log('>>> PROACTIVE REFRESH TRIGGERED: $reason');
        await _performProactiveRefresh();
      } else {
        _log('Token is fresh enough, no refresh needed');
        _log('=== APP RESUMED CHECK COMPLETE - Token OK ===');
      }

    } catch (e, stackTrace) {
      _log('Error during resume check: $e', error: e);
      developer.log(
        'App resume error',
        name: 'AppLifecycleService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Perform the proactive token refresh
  Future<void> _performProactiveRefresh() async {
    _isRefreshing = true;
    _log('Starting proactive token refresh...');

    try {
      final user = await _authService!.refreshToken();

      if (user != null) {
        _log('SUCCESS! Token refreshed proactively');
        _log('User: ${user.email}');

        // Reschedule the AlarmManager token refresh for the next interval
        try {
          await NotificationService.instance.scheduleTokenRefreshAlarm();
          _log('AlarmManager token refresh rescheduled (next in 6 hours)');
        } catch (e) {
          _log('Failed to reschedule AlarmManager token refresh: $e');
        }

        _log('=== APP RESUMED CHECK COMPLETE - Token Refreshed ===');
      } else {
        _log('!!! REFRESH FAILED - Token could not be refreshed');
        _log('This likely means the refresh token has expired (12-hour timeout)');
        _log('User will need to re-authenticate');
        _log('=== APP RESUMED CHECK COMPLETE - RE-LOGIN REQUIRED ===');

        // Notify that re-login is required
        if (onReloginRequired != null) {
          _log('Triggering re-login callback');
          onReloginRequired!();
        }
      }
    } catch (e, stackTrace) {
      _log('!!! REFRESH EXCEPTION: $e', error: e);
      developer.log(
        'Proactive refresh error',
        name: 'AppLifecycleService',
        error: e,
        stackTrace: stackTrace,
      );

      // On error, also trigger re-login
      if (onReloginRequired != null) {
        _log('Triggering re-login callback due to error');
        onReloginRequired!();
      }
    } finally {
      _isRefreshing = false;
    }
  }

  /// Manually trigger a token refresh check
  /// Useful for testing or forcing a refresh
  Future<void> checkAndRefreshIfNeeded() async {
    _log('Manual refresh check requested');
    await _onAppResumed();
  }
}
