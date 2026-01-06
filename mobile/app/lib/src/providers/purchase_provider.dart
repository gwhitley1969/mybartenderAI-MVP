import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/purchase_service.dart';
import 'backend_provider.dart';
import 'voice_ai_provider.dart';

/// Provider for the purchase service singleton
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final service = PurchaseService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for the voice minutes product details (price, description)
final voiceMinutesProductProvider = FutureProvider<ProductDetails?>((ref) async {
  final service = ref.watch(purchaseServiceProvider);
  if (!service.isAvailable) return null;
  return service.getVoiceMinutesProduct();
});

/// Provider for the purchase result stream
final purchaseStreamProvider = StreamProvider<PurchaseResult>((ref) {
  final service = ref.watch(purchaseServiceProvider);
  return service.purchaseStream;
});

/// Provider for checking if purchases are available
final purchasesAvailableProvider = Provider<bool>((ref) {
  final service = ref.watch(purchaseServiceProvider);
  return service.isAvailable;
});

/// Initialize the purchase service with backend verification
///
/// Call this during app initialization, after authentication is set up
Future<void> initializePurchaseService(Ref ref) async {
  final purchaseService = ref.read(purchaseServiceProvider);
  final backendService = ref.read(backendServiceProvider);

  await purchaseService.initialize(
    onVerifyPurchase: (purchaseToken, productId) async {
      // Call backend to verify and credit minutes
      try {
        final response = await backendService.dio.post(
          '/v1/voice/purchase',
          data: {
            'purchaseToken': purchaseToken,
            'productId': productId,
          },
        );

        // Refresh voice quota after successful purchase
        if (response.data['success'] == true) {
          ref.invalidate(voiceQuotaProvider);
        }

        return Map<String, dynamic>.from(response.data);
      } catch (e) {
        return {'success': false, 'error': e.toString()};
      }
    },
  );
}

/// State notifier for managing purchase flow
class PurchaseNotifier extends StateNotifier<PurchaseState> {
  final PurchaseService _service;

  PurchaseNotifier(this._service) : super(PurchaseState.idle);

  /// Initiate a voice minutes purchase
  Future<bool> purchaseVoiceMinutes() async {
    state = PurchaseState.loading;
    final success = await _service.purchaseVoiceMinutes();
    if (!success) {
      state = PurchaseState.error;
    }
    // State will be updated via the purchase stream
    return success;
  }

  /// Reset to idle state
  void reset() {
    state = PurchaseState.idle;
  }
}

/// Provider for the purchase state notifier
final purchaseNotifierProvider =
    StateNotifierProvider<PurchaseNotifier, PurchaseState>((ref) {
  final service = ref.watch(purchaseServiceProvider);
  return PurchaseNotifier(service);
});

/// Convenience provider to check if user can purchase voice minutes
/// Based on tier (Premium or Pro can purchase)
final canPurchaseVoiceMinutesProvider = Provider<bool>((ref) {
  final quotaAsync = ref.watch(voiceQuotaProvider);
  return quotaAsync.when(
    data: (quota) => quota.tier == 'premium' || quota.tier == 'pro',
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Convenience provider to check if user needs to purchase (out of minutes)
final needsVoiceMinutesPurchaseProvider = Provider<bool>((ref) {
  final quotaAsync = ref.watch(voiceQuotaProvider);
  return quotaAsync.when(
    data: (quota) =>
        !quota.hasQuota &&
        (quota.tier == 'premium' || quota.tier == 'pro'),
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Provider for low minutes warning (less than 5 minutes)
final lowVoiceMinutesWarningProvider = Provider<bool>((ref) {
  final quotaAsync = ref.watch(voiceQuotaProvider);
  return quotaAsync.when(
    data: (quota) =>
        quota.hasQuota &&
        quota.remainingMinutes <= 5 &&
        quota.remainingMinutes > 0 &&
        (quota.tier == 'premium' || quota.tier == 'pro'),
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Provider for critical minutes warning (less than 2 minutes)
final criticalVoiceMinutesWarningProvider = Provider<bool>((ref) {
  final quotaAsync = ref.watch(voiceQuotaProvider);
  return quotaAsync.when(
    data: (quota) =>
        quota.hasQuota &&
        quota.remainingMinutes <= 2 &&
        quota.remainingMinutes > 0 &&
        (quota.tier == 'premium' || quota.tier == 'pro'),
    loading: () => false,
    error: (_, __) => false,
  );
});
