import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiBaseUrlProvider = Provider<String>(
  (ref) => 'https://api.mybartender.ai',
);

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);

  final options = BaseOptions(
    baseUrl: baseUrl,
    contentType: 'application/json',
    responseType: ResponseType.json,
  );

  return Dio(options);
});
