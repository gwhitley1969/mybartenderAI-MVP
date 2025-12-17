import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/background_token_service.dart';

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

  // Initialize background token refresh service
  // This keeps the refresh token active by using it every 10 hours
  // to avoid the 12-hour inactivity timeout in Entra External ID
  try {
    await BackgroundTokenService.instance.initialize();
    debugPrint('BackgroundTokenService initialized');
  } catch (e) {
    debugPrint('Failed to initialize BackgroundTokenService: $e');
  }

  runApp(
    ProviderScope(
      overrides: [envConfigProvider.overrideWithValue(config), ...overrides],
      child: appBuilder(),
    ),
  );
}
