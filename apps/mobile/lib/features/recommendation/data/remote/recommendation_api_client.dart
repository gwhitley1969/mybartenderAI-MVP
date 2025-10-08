import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import '../dto/recommendation_dtos.dart';

final recommendationApiClientProvider = Provider<RecommendationApiClient>(
  (ref) {
    final dio = ref.watch(dioProvider);
    return RecommendationApiClient(dio: dio);
  },
);

class RecommendationApiClient {
  RecommendationApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _recommendPath = '/v1/recommend';

  Future<List<RecommendationDto>> recommend({
    required RecommendRequestDto payload,
  }) async {
    try {
      final response = await _dio.post<List<dynamic>>(
        _recommendPath,
        data: payload.toJson(),
      );

      final data = response.data;
      if (data == null) {
        return const [];
      }

      return data
          .map(
            (dynamic item) => RecommendationDto.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw RecommendationApiException.fromDio(error);
    }
  }
}

class RecommendationApiException implements Exception {
  RecommendationApiException({
    this.statusCode,
    this.message,
    this.errorBody,
  });

  final int? statusCode;
  final String? message;
  final ErrorDto? errorBody;

  factory RecommendationApiException.fromDio(DioException error) {
    ErrorDto? parsed;
    final response = error.response;
    final data = response?.data;
    if (data is Map<String, dynamic>) {
      try {
        parsed = ErrorDto.fromJson(data);
      } catch (_) {
        parsed = null;
      }
    }

    return RecommendationApiException(
      statusCode: response?.statusCode,
      message: parsed?.message ?? error.message,
      errorBody: parsed,
    );
  }

  @override
  String toString() =>
      'RecommendationApiException(statusCode: $statusCode, message: $message)';
}
