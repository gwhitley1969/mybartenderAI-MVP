import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dto/recommendation_dtos.dart';
import '../data/repository/recommendation_repository_impl.dart';

final recommendationsProvider = AutoDisposeFutureProvider.family<
    List<RecommendationDto>, RecommendRequestDto>(
  (ref, payload) async {
    final repository = ref.watch(recommendationRepositoryProvider);
    return repository.getRecommendations(payload);
  },
);
