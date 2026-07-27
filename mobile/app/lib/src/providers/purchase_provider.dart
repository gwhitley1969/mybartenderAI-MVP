import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import '../services/purchase_service.dart';
import 'voice_ai_provider.dart';

/// Provider for the purchase service singleton
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final service = PurchaseService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for the voice minutes product details (price, title)
final voiceMinutesProductProvider =
    FutureProvider<rc.StoreProduct?>((ref) async {
  final service = ref.watch(purchaseServiceProvider);
  return service.getVoiceMinutesProduct();
});

/// Provider for the purchase result stream
final purchaseStreamProvider = StreamProvider<PurchaseResult>((ref) {
  final service = ref.watch(purchaseServiceProvider);
  return service.purchaseStream;
});

/// State notifier for managing purchase flow
class PurchaseNotifier extends StateNotifier<PurchaseState> {
  final PurchaseService _service;
  final Ref _ref;

  PurchaseNotifier(this._service, this._ref) : super(PurchaseState.idle);

  /// Time allowed for the RevenueCat `NON_RENEWING_PURCHASE` webhook to reach
  /// the backend and credit the minutes before we re-read the quota.
  static const _webhookSettleDelay = Duration(seconds: 2);

  /// Initiate a voice minutes purchase.
  ///
  /// Minutes are credited server-side by the RevenueCat webhook, so on success
  /// we wait briefly and then invalidate the quota provider to pick up the new
  /// balance. The server is authoritative — we never write the balance locally.
  Future<bool> purchaseVoiceMinutes() async {
    state = PurchaseState.loading;
    final success = await _service.purchaseVoiceMinutes();

    if (!success) {
      state = PurchaseState.error;
      return false;
    }

    state = PurchaseState.success;
    await Future.delayed(_webhookSettleDelay);
    _ref.invalidate(voiceQuotaProvider);
    return true;
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
  return PurchaseNotifier(service, ref);
});

/// Convenience provider to check if user can purchase voice minutes
/// Based on tier (Premium or Pro can purchase)
final canPurchaseVoiceMinutesProvider = Provider<bool>((ref) {
  final quotaAsync = ref.watch(voiceQuotaProvider);
  return quotaAsync.when(
    data: (quota) => quota.hasAccess,
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
        (quota.hasAccess),
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
        (quota.hasAccess),
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
        (quota.hasAccess),
    loading: () => false,
    error: (_, __) => false,
  );
});
