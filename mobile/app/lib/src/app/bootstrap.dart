import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/background_token_service.dart';
import '../services/notification_service.dart';

/// SharedPreferences key for pending notification navigation (must match main.dart)
const String _pendingNavigationKey = 'pending_cocktail_navigation';

/// Environment configuration for the app
///
/// NOTE: APIM subscription key has been REMOVED for security.
/// Authentication now uses JWT tokens from Entra External ID.
/// APIM validates the JWT and extracts user identity.
/// Backend looks up user tier from database on each request.
class EnvConfig {
  const EnvConfig({
    this.apiBaseUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 30),
    this.sendTimeout = const Duration(seconds: 10),
  });

  final String? apiBaseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
}

final envConfigProvider = Provider<EnvConfig>((ref) => const EnvConfig());

/// Dio interceptors provider
///
/// NOTE: FunctionKeyInterceptor has been REMOVED.
/// JWT authentication is now handled by individual services
/// (BackendService, VoiceAIService) which add the Authorization header.
final dioInterceptorsProvider = Provider<List<Interceptor>>((ref) {
  return <Interceptor>[
    if (kDebugMode)
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
        responseHeader: false,
      ),
  ];
});

/// Create a base Dio instance with standard configuration
///
/// NOTE: No APIM subscription key in headers.
/// JWT authentication is handled by services that need it.
Dio createBaseDio({
  required EnvConfig config,
  Iterable<Interceptor> interceptors = const [],
}) {
  final baseOptions = BaseOptions(
    connectTimeout: config.connectTimeout,
    receiveTimeout: config.receiveTimeout,
    sendTimeout: config.sendTimeout,
    responseType: ResponseType.json,
    contentType: Headers.jsonContentType,
  );

  final baseUrl = config.apiBaseUrl;
  if (baseUrl != null && baseUrl.isNotEmpty) {
    baseOptions.baseUrl = baseUrl;
  }

  // NOTE: No APIM subscription key in headers
  // JWT authentication handled by individual services

  final dio = Dio(baseOptions);
  dio.interceptors.addAll(interceptors);
  return dio;
}

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(envConfigProvider);
  final interceptors = ref.watch(dioInterceptorsProvider);
  if (kDebugMode) {
    print('Creating Dio with config: apiBaseUrl=${config.apiBaseUrl}');
    print('Number of interceptors: ${interceptors.length}');
    print('NOTE: Using JWT-only authentication (no APIM subscription key)');
  }
  return createBaseDio(config: config, interceptors: interceptors);
});

Future<void> bootstrap(
  Widget Function() appBuilder, {
  EnvConfig config = const EnvConfig(),
  List<Override> overrides = const [],
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // NOTE: APIM subscription key validation REMOVED
  // Using JWT-only authentication - APIM validates JWT token
  // Backend looks up user tier from database

  // iOS COLD START FIX: Skip early notification/background initialization on iOS
  // On iOS, initializing flutter_local_notifications and WorkManager BEFORE runApp()
  // can cause crashes when the app is cold-started from terminated state because:
  // 1. The Flutter engine isn't fully attached to the iOS view hierarchy
  // 2. iOS may try to deliver pending background tasks before Flutter is ready
  // 3. Known issues: flutter_local_notifications #2025, workmanager iOS race conditions
  //
  // On iOS, these services are initialized AFTER runApp() in main.dart's initState()
  // which gives Flutter time to fully initialize first.
  if (!Platform.isIOS) {
    // CRITICAL: Check for notification launch details BEFORE runApp()
    // This is required for Android to properly capture the notification that launched the app
    await _checkNotificationLaunchDetails();

    // Initialize background token refresh service
    // This runs every 8 hours as a BACKUP to keep the refresh token active
    // The PRIMARY mechanism is AppLifecycleService (foreground refresh on app resume)
    // which is initialized in AuthNotifier when providers are ready
    try {
      await BackgroundTokenService.instance.initialize();
      debugPrint('BackgroundTokenService initialized');
    } catch (e) {
      debugPrint('Failed to initialize BackgroundTokenService: $e');
    }
  } else {
    debugPrint('[iOS] Skipping early background service initialization to prevent cold start crash');
    debugPrint('[iOS] NotificationService and BackgroundTokenService will initialize after runApp()');
  }

  runApp(
    ProviderScope(
      overrides: [envConfigProvider.overrideWithValue(config), ...overrides],
      child: appBuilder(),
    ),
  );
}

/// Check if app was launched from a notification and save the payload for later navigation.
/// This MUST be called before runApp() for iOS to properly capture launch details.
Future<void> _checkNotificationLaunchDetails() async {
  try {
    debugPrint('[BOOTSTRAP] Checking notification launch details...');

    // Initialize the notification plugin (minimal init, just to get launch details)
    await NotificationService.instance.initialize();

    // Get the notification that launched the app (if any)
    final launchDetails = await NotificationService.instance.getNotificationAppLaunchDetails();

    debugPrint('[BOOTSTRAP] Launch details: didNotificationLaunchApp=${launchDetails?.didNotificationLaunchApp}');
    debugPrint('[BOOTSTRAP] Launch payload: ${launchDetails?.notificationResponse?.payload}');

    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      final payload = launchDetails.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty && payload != 'TOKEN_REFRESH_TRIGGER') {
        debugPrint('[BOOTSTRAP] App launched from notification! Saving payload: $payload');
        // Save to SharedPreferences so the app can navigate after UI is ready
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_pendingNavigationKey, payload);
        debugPrint('[BOOTSTRAP] Saved pending navigation to SharedPreferences');
      }
    }
  } catch (e) {
    debugPrint('[BOOTSTRAP] Error checking notification launch details: $e');
  }
}
