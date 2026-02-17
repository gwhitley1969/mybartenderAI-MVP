import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/review_service.dart';

/// Provider for the ReviewService singleton.
///
/// Access via `ref.read(reviewServiceProvider)` at hook points.
/// The service manages its own lifecycle (WidgetsBindingObserver)
/// so it does not need disposal through Riverpod.
final reviewServiceProvider = Provider<ReviewService>((ref) {
  return ReviewService.instance;
});

/// Provider that checks if the user is currently eligible for a review prompt.
/// Useful for conditional UI or debugging.
final reviewEligibleProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(reviewServiceProvider);
  return service.isEligible();
});
