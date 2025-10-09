import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/recommend_api.dart';
import '../generated/models.dart';

typedef RecommendRequest = ({
  Inventory inventory,
  TasteProfile? tasteProfile,
  String? clientRequestId,
});

class RecommendRepository {
  RecommendRepository(this._api);

  final RecommendApi _api;

  Future<List<Recommendation>> recommend({
    required Inventory inventory,
    TasteProfile? tasteProfile,
    String? clientRequestId,
  }) async {
    final response = await _api.recommend(
      inventory: inventory,
      tasteProfile: tasteProfile,
      clientRequestId: clientRequestId,
    );
    return response.recommendations;
  }
}

final recommendRepositoryProvider = Provider<RecommendRepository>((ref) {
  final api = ref.watch(recommendApiProvider);
  return RecommendRepository(api);
});

final recommendProvider = FutureProvider.autoDispose
    .family<List<Recommendation>, RecommendRequest>((ref, request) async {
      final repository = ref.watch(recommendRepositoryProvider);
      return repository.recommend(
        inventory: request.inventory,
        tasteProfile: request.tasteProfile,
        clientRequestId: request.clientRequestId,
      );
    });
