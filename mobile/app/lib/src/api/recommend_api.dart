import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../app/bootstrap.dart';
import '../generated/models.dart';

class RecommendResponse {
  const RecommendResponse({required this.recommendations, this.cacheHit});

  final List<Recommendation> recommendations;
  final bool? cacheHit;
}

class RecommendApi {
  RecommendApi(this._dio);

  final Dio _dio;

  @visibleForTesting
  static const clientRequestIdHeader = 'X-Client-Request-Id';

  Future<RecommendResponse> recommend({
    required Inventory inventory,
    TasteProfile? tasteProfile,
    String? clientRequestId,
  }) async {
    final payload = <String, dynamic>{
      'inventory': inventory.toJson(),
      if (tasteProfile != null) 'tasteProfile': tasteProfile.toJson(),
    };

    final options = Options(
      headers: {
        if (clientRequestId != null) clientRequestIdHeader: clientRequestId,
      },
    );

    final response = await _dio.post<List<dynamic>>(
      '/v1/recommend',
      data: payload,
      options: options,
    );

    final rawData = response.data;
    if (rawData is! List) {
      throw StateError('Expected recommendations array but received $rawData');
    }

    final recommendations = rawData
        .map(
          (item) => Recommendation.fromJson(
            Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          ),
        )
        .toList(growable: false);

    final cacheHitHeader = response.headers.value('x-cache-hit');
    final cacheHit = cacheHitHeader != null
        ? cacheHitHeader.trim().toLowerCase() == 'true'
        : null;

    return RecommendResponse(
      recommendations: recommendations,
      cacheHit: cacheHit,
    );
  }
}

final recommendApiProvider = Provider<RecommendApi>((ref) {
  final dio = ref.watch(dioProvider);
  return RecommendApi(dio);
});
