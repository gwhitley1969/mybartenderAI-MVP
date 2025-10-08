import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/recommendation_repository.dart';
import '../dto/recommendation_dtos.dart';
import '../remote/recommendation_api_client.dart';

final recommendationRepositoryProvider =
    Provider<RecommendationRepository>((ref) {
  final apiClient = ref.watch(recommendationApiClientProvider);
  return RecommendationRepositoryImpl(apiClient);
});

class RecommendationRepositoryImpl implements RecommendationRepository {
  RecommendationRepositoryImpl(this._apiClient);

  final RecommendationApiClient _apiClient;

  @override
  Future<List<RecommendationDto>> getRecommendations(
    RecommendRequestDto payload,
  ) {
    return _apiClient.recommend(payload: payload);
  }
}
