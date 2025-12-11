import 'dart:developer' as developer;

import 'package:msal_auth/msal_auth.dart';
import 'package:workmanager/workmanager.dart';

import '../config/auth_config.dart';
import 'token_storage_service.dart';

/// Background task name for token refresh keepalive
const String tokenRefreshTaskName = 'com.mybartenderai.tokenRefreshKeepalive';

/// Background task unique name
const String tokenRefreshTaskUniqueName = 'tokenRefreshKeepaliveTask';

/// Callback dispatcher for background tasks
/// This MUST be a top-level function (not a class method)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('[BG-TOKEN] Background task started: $task');
    developer.log('Background task started: $task', name: 'BackgroundTokenService');

    try {
      switch (task) {
        case tokenRefreshTaskName:
        case Workmanager.iOSBackgroundTask:
          return await _performTokenRefresh();
        default:
          print('[BG-TOKEN] Unknown task: $task');
          return Future.value(true);
      }
    } catch (e, stackTrace) {
      print('[BG-TOKEN] Background task error: $e');
      developer.log(
        'Background task error: $e',
        name: 'BackgroundTokenService',
        error: e,
        stackTrace: stackTrace,
      );
      // Return true to indicate task completed (even if with error)
      // Returning false would cause WorkManager to retry
      return Future.value(true);
    }
  });
}

/// Perform the token refresh in the background
Future<bool> _performTokenRefresh() async {
  print('[BG-TOKEN] === TOKEN REFRESH KEEPALIVE STARTED ===');
  print('[BG-TOKEN] Time: ${DateTime.now().toIso8601String()}');

  try {
    // Check if user has stored credentials
    final tokenStorage = TokenStorageService();
    final userProfile = await tokenStorage.getUserProfile();

    if (userProfile == null) {
      print('[BG-TOKEN] No user profile found - user not logged in, skipping refresh');
      return true;
    }

    print('[BG-TOKEN] User found: ${userProfile.email}');

    // Initialize MSAL
    print('[BG-TOKEN] Initializing MSAL...');
    final msalAuth = await SingleAccountPca.create(
      clientId: AuthConfig.clientId,
      androidConfig: AndroidConfig(
        configFilePath: 'assets/msal_config.json',
        redirectUri: 'msauth://ai.mybartender.mybartenderai/callback',
      ),
    );
    print('[BG-TOKEN] MSAL initialized');

    // Check if MSAL has a cached account
    try {
      final currentAccount = await msalAuth.currentAccount;
      print('[BG-TOKEN] MSAL account found: ${currentAccount.username}');
    } catch (e) {
      print('[BG-TOKEN] No MSAL account in cache - cannot refresh');
      return true;
    }

    // Attempt silent token refresh
    print('[BG-TOKEN] Attempting acquireTokenSilent...');
    final scopes = [
      'https://graph.microsoft.com/User.Read',
      'openid',
      'profile',
      'email',
    ];

    final result = await msalAuth.acquireTokenSilent(scopes: scopes);

    if (result != null) {
      print('[BG-TOKEN] SUCCESS! Token refreshed silently');
      print('[BG-TOKEN] New token expires: ${result.expiresOn?.toIso8601String()}');

      // Save the new tokens
      if (result.accessToken != null) {
        await tokenStorage.saveAccessToken(result.accessToken!);
        print('[BG-TOKEN] Access token saved');
      }
      if (result.idToken != null) {
        await tokenStorage.saveIdToken(result.idToken!);
        print('[BG-TOKEN] ID token saved');
      }
      if (result.expiresOn != null) {
        await tokenStorage.saveExpiresAt(result.expiresOn!);
        print('[BG-TOKEN] Expiry saved');
      }

      print('[BG-TOKEN] === TOKEN REFRESH KEEPALIVE SUCCEEDED ===');
    } else {
      print('[BG-TOKEN] acquireTokenSilent returned null');
    }

    return true;
  } on MsalException catch (e) {
    print('[BG-TOKEN] MSAL Exception: ${e.message}');

    // Check for specific errors
    final errorMessage = e.message.toLowerCase();
    if (errorMessage.contains('interaction_required') ||
        errorMessage.contains('invalid_grant') ||
        errorMessage.contains('700082')) {
      print('[BG-TOKEN] Refresh token expired server-side - user will need to re-login');
    }

    print('[BG-TOKEN] === TOKEN REFRESH KEEPALIVE FAILED ===');
    return true; // Task completed, even if refresh failed
  } catch (e, stackTrace) {
    print('[BG-TOKEN] Unexpected error: $e');
    developer.log(
      'Token refresh error',
      name: 'BackgroundTokenService',
      error: e,
      stackTrace: stackTrace,
    );
    print('[BG-TOKEN] === TOKEN REFRESH KEEPALIVE FAILED ===');
    return true;
  }
}

/// Service to manage background token refresh scheduling
class BackgroundTokenService {
  static final BackgroundTokenService _instance = BackgroundTokenService._internal();
  factory BackgroundTokenService() => _instance;
  BackgroundTokenService._internal();

  static BackgroundTokenService get instance => _instance;

  bool _isInitialized = false;

  /// Initialize the WorkManager and register the callback dispatcher
  Future<void> initialize() async {
    if (_isInitialized) {
      print('[BG-TOKEN] BackgroundTokenService already initialized');
      return;
    }

    print('[BG-TOKEN] Initializing BackgroundTokenService...');

    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true, // Set to false in production
    );

    _isInitialized = true;
    print('[BG-TOKEN] BackgroundTokenService initialized');
  }

  /// Schedule the periodic token refresh task
  /// Runs every 10 hours to keep the refresh token active
  Future<void> scheduleTokenRefresh() async {
    print('[BG-TOKEN] Scheduling periodic token refresh task...');

    // Cancel any existing task first
    await Workmanager().cancelByUniqueName(tokenRefreshTaskUniqueName);

    // Schedule periodic task - runs approximately every 10 hours
    // Note: Android has a minimum of 15 minutes for periodic tasks
    // We use 10 hours to stay well under the 12-hour inactivity limit
    await Workmanager().registerPeriodicTask(
      tokenRefreshTaskUniqueName,
      tokenRefreshTaskName,
      frequency: const Duration(hours: 10),
      constraints: Constraints(
        networkType: NetworkType.connected, // Requires network connection
        requiresBatteryNotLow: false, // Run even on low battery
        requiresCharging: false, // Don't require charging
        requiresDeviceIdle: false, // Don't wait for device idle
        requiresStorageNotLow: false, // Don't require storage
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 15),
      tag: 'token_refresh',
    );

    print('[BG-TOKEN] Periodic token refresh scheduled (every 10 hours)');
  }

  /// Cancel the periodic token refresh task
  Future<void> cancelTokenRefresh() async {
    print('[BG-TOKEN] Cancelling token refresh task...');
    await Workmanager().cancelByUniqueName(tokenRefreshTaskUniqueName);
    print('[BG-TOKEN] Token refresh task cancelled');
  }

  /// Run an immediate token refresh (for testing)
  Future<void> runImmediateRefresh() async {
    print('[BG-TOKEN] Running immediate token refresh...');

    await Workmanager().registerOneOffTask(
      '${tokenRefreshTaskUniqueName}_immediate',
      tokenRefreshTaskName,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    print('[BG-TOKEN] Immediate refresh task scheduled');
  }
}
