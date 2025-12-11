import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/background_token_service.dart';

class EnvConfig {
  const EnvConfig({
    this.apiBaseUrl,
    this.functionKey,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 30),
    this.sendTimeout = const Duration(seconds: 10),
  });

  final String? apiBaseUrl;
  final String? functionKey;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
}

final envConfigProvider = Provider<EnvConfig>((ref) => const EnvConfig());

class FunctionKeyInterceptor extends Interceptor {
  FunctionKeyInterceptor(this.functionKey);

  final String? functionKey;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Always add the APIM subscription key to all requests if available
    if (functionKey != null && functionKey!.isNotEmpty) {
      // FIXED: Use correct header name for APIM
      options.headers['Ocp-Apim-Subscription-Key'] = functionKey;
      if (kDebugMode) {
        print('Added APIM subscription key to request: ${options.uri}');
      }
    }
    handler.next(options);
  }
}

final dioInterceptorsProvider = Provider<List<Interceptor>>((ref) {
  final config = ref.watch(envConfigProvider);
  if (kDebugMode) {
    print('Creating interceptors - functionKey: ${config.functionKey != null ? "***" : "null"}');
  }
  return <Interceptor>[
    if (config.functionKey != null) FunctionKeyInterceptor(config.functionKey),
    if (kDebugMode)
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,  // Enable header logging to see if function key is added
        responseHeader: false,
      ),
  ];
});

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

  // Add APIM subscription key to default headers if provided
  if (config.functionKey != null && config.functionKey!.isNotEmpty) {
    baseOptions.headers = {
      'Ocp-Apim-Subscription-Key': config.functionKey,
    };
    if (kDebugMode) {
      print('Added Ocp-Apim-Subscription-Key to default headers');
    }
  }

  final dio = Dio(baseOptions);
  dio.interceptors.addAll(interceptors);
  return dio;
}

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(envConfigProvider);
  final interceptors = ref.watch(dioInterceptorsProvider);
  if (kDebugMode) {
    print('Creating Dio with config: apiBaseUrl=${config.apiBaseUrl}, functionKey=${config.functionKey != null ? "***" : "null"}');
    print('Number of interceptors: ${interceptors.length}');
  }
  return createBaseDio(config: config, interceptors: interceptors);
});

Future<void> bootstrap(
  Widget Function() appBuilder, {
  EnvConfig config = const EnvConfig(),
  List<Override> overrides = const [],
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Validate that function key is provided (warning only for now)
  if (config.functionKey == null || config.functionKey!.isEmpty) {
    debugPrint(
      'WARNING: AZURE_FUNCTION_KEY not set. Some features may not work.\n'
      'Build with: flutter build apk --dart-define=AZURE_FUNCTION_KEY=<your_key>',
    );
  }

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
