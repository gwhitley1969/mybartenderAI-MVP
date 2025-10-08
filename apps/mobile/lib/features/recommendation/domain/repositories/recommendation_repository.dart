import '../../data/dto/recommendation_dtos.dart';

abstract class RecommendationRepository {
  Future<List<RecommendationDto>> getRecommendations(
    RecommendRequestDto payload,
  );
}
