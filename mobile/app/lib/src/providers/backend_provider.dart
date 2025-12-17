import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../services/backend_service.dart';
import 'auth_provider.dart';

/// Provider for the BackendService singleton with JWT authentication
///
/// AUTHENTICATION: Uses ID token (not access token) for APIM validation
/// - ID Token audience: client app ID (correct for APIM)
/// - Access Token audience: Microsoft Graph (wrong for APIM)
/// - Backend looks up user tier from database on each request
final backendServiceProvider = Provider<BackendService>((ref) {
  return BackendService(
    baseUrl: AppConfig.backendBaseUrl,
    getIdToken: () async {
      // Get valid ID token (auto-refreshes if expired)
      // ID token has correct audience for APIM JWT validation
      final authService = ref.read(authServiceProvider);
      return await authService.getValidIdToken();
    },
  );
});

/// Provider for backend connectivity check (uses snapshots endpoint)
final healthCheckProvider = FutureProvider<bool>((ref) async {
  final backendService = ref.watch(backendServiceProvider);
  try {
    // Use snapshots endpoint to verify backend is reachable
    await backendService.getLatestSnapshot();
    return true;
  } catch (e) {
    return false;
  }
});

/// Provider for latest snapshot metadata
final latestSnapshotProvider = FutureProvider<SnapshotMetadata>((ref) async {
  final backendService = ref.watch(backendServiceProvider);
  return await backendService.getLatestSnapshot();
});

/// Provider for realtime token
final realtimeTokenProvider = FutureProvider<RealtimeToken>((ref) async {
  final backendService = ref.watch(backendServiceProvider);
  return await backendService.getRealtimeToken();
});

/// Provider family for cocktail recommendations
final recommendationsProvider = FutureProvider.family<RecommendationResponse, RecommendationRequest>(
  (ref, request) async {
    final backendService = ref.watch(backendServiceProvider);
    return await backendService.getRecommendations(
      availableIngredients: request.availableIngredients,
      occasion: request.occasion,
      mood: request.mood,
    );
  },
);

/// Request class for recommendations
class RecommendationRequest {
  final List<String>? availableIngredients;
  final String? occasion;
  final String? mood;

  const RecommendationRequest({
    this.availableIngredients,
    this.occasion,
    this.mood,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecommendationRequest &&
          runtimeType == other.runtimeType &&
          availableIngredients == other.availableIngredients &&
          occasion == other.occasion &&
          mood == other.mood;

  @override
  int get hashCode =>
      availableIngredients.hashCode ^ occasion.hashCode ^ mood.hashCode;
}
