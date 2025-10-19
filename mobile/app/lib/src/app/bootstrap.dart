import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    if (functionKey != null && functionKey!.isNotEmpty) {
      options.headers['x-functions-key'] = functionKey;
    }
    handler.next(options);
  }
}

final dioInterceptorsProvider = Provider<List<Interceptor>>((ref) {
  final config = ref.watch(envConfigProvider);
  return <Interceptor>[
    if (config.functionKey != null) FunctionKeyInterceptor(config.functionKey),
    LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: false,
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

  final dio = Dio(baseOptions);
  dio.interceptors.addAll(interceptors);
  return dio;
}

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(envConfigProvider);
  final interceptors = ref.watch(dioInterceptorsProvider);
  return createBaseDio(config: config, interceptors: interceptors);
});

Future<void> bootstrap(
  Widget Function() appBuilder, {
  EnvConfig config = const EnvConfig(),
  List<Override> overrides = const [],
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ProviderScope(
      overrides: [envConfigProvider.overrideWithValue(config), ...overrides],
      child: appBuilder(),
    ),
  );
}
