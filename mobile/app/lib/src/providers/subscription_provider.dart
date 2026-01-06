import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/backend_service.dart';
import '../services/subscription_service.dart';
import 'backend_provider.dart';

/// Provider for the subscription service singleton
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final service = SubscriptionService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for the current subscription status (from stream)
final subscriptionStatusProvider = StreamProvider<SubscriptionStatus>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  return service.statusStream;
});

/// Provider for the current subscription status (one-time fetch)
final currentSubscriptionProvider = FutureProvider<SubscriptionStatus>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  if (!service.isInitialized) {
    return SubscriptionStatus.free;
  }
  return service.getStatus();
});

/// Provider for available subscription offerings
final subscriptionOfferingsProvider = FutureProvider<Offerings?>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  if (!service.isInitialized) return null;
  return service.getOfferings();
});

/// Provider for checking if user has premium or higher subscription
final isPremiumOrHigherProvider = Provider<bool>((ref) {
  final statusAsync = ref.watch(subscriptionStatusProvider);
  return statusAsync.when(
    data: (status) => status.isPremiumOrHigher,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Provider for checking if user has pro subscription
final isProSubscriberProvider = Provider<bool>((ref) {
  final statusAsync = ref.watch(subscriptionStatusProvider);
  return statusAsync.when(
    data: (status) => status.isPro,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Provider for the current subscription tier
final currentTierProvider = Provider<SubscriptionTier>((ref) {
  final statusAsync = ref.watch(subscriptionStatusProvider);
  return statusAsync.when(
    data: (status) => status.tier,
    loading: () => SubscriptionTier.free,
    error: (_, __) => SubscriptionTier.free,
  );
});

/// Initialize the subscription service with the user's ID
///
/// Call this after successful authentication
/// [userId] should be the azure_ad_sub from the JWT
/// Uses BackendService to fetch RevenueCat API key from Azure Key Vault
Future<void> initializeSubscriptionService(Ref ref, String userId) async {
  final subscriptionService = ref.read(subscriptionServiceProvider);
  final backendService = ref.read(backendServiceProvider);
  await subscriptionService.initialize(userId, backendService);
}

/// State for subscription purchase flow
enum SubscriptionPurchaseState {
  idle,
  loading,
  purchasing,
  success,
  cancelled,
  error,
}

/// Notifier for managing subscription purchase flow
class SubscriptionPurchaseNotifier extends StateNotifier<SubscriptionPurchaseState> {
  final SubscriptionService _service;
  String? _errorMessage;

  SubscriptionPurchaseNotifier(this._service) : super(SubscriptionPurchaseState.idle);

  String? get errorMessage => _errorMessage;

  /// Purchase a subscription package
  Future<bool> purchase(Package package) async {
    state = SubscriptionPurchaseState.purchasing;
    _errorMessage = null;

    try {
      final result = await _service.purchasePackage(package);

      if (result != null) {
        state = SubscriptionPurchaseState.success;
        return true;
      } else {
        // User cancelled or error
        state = SubscriptionPurchaseState.cancelled;
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      state = SubscriptionPurchaseState.error;
      return false;
    }
  }

  /// Restore purchases
  Future<bool> restorePurchases() async {
    state = SubscriptionPurchaseState.loading;
    _errorMessage = null;

    try {
      final result = await _service.restorePurchases();

      if (result != null) {
        state = SubscriptionPurchaseState.success;
        return true;
      } else {
        state = SubscriptionPurchaseState.idle;
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      state = SubscriptionPurchaseState.error;
      return false;
    }
  }

  /// Reset to idle state
  void reset() {
    state = SubscriptionPurchaseState.idle;
    _errorMessage = null;
  }
}

/// Provider for the subscription purchase state notifier
final subscriptionPurchaseNotifierProvider =
    StateNotifierProvider<SubscriptionPurchaseNotifier, SubscriptionPurchaseState>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  return SubscriptionPurchaseNotifier(service);
});

/// Provider for getting the error message from purchase flow
final subscriptionPurchaseErrorProvider = Provider<String?>((ref) {
  final notifier = ref.watch(subscriptionPurchaseNotifierProvider.notifier);
  return notifier.errorMessage;
});

/// Provider for checking if subscription is currently being processed
final isSubscriptionProcessingProvider = Provider<bool>((ref) {
  final state = ref.watch(subscriptionPurchaseNotifierProvider);
  return state == SubscriptionPurchaseState.loading ||
      state == SubscriptionPurchaseState.purchasing;
});

/// Convenience provider for determining if upgrade prompt should be shown
/// Returns true if user is on free tier and not currently processing a purchase
final shouldShowUpgradePromptProvider = Provider<bool>((ref) {
  final tier = ref.watch(currentTierProvider);
  final isProcessing = ref.watch(isSubscriptionProcessingProvider);
  return tier == SubscriptionTier.free && !isProcessing;
});

/// Provider for management URL (to cancel/modify subscription in Play Store)
final subscriptionManagementUrlProvider = Provider<String?>((ref) {
  final statusAsync = ref.watch(subscriptionStatusProvider);
  return statusAsync.when(
    data: (status) => status.managementUrl,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider for subscription expiration date
final subscriptionExpirationProvider = Provider<DateTime?>((ref) {
  final statusAsync = ref.watch(subscriptionStatusProvider);
  return statusAsync.when(
    data: (status) => status.expirationDate,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider for checking if subscription will auto-renew
final subscriptionWillRenewProvider = Provider<bool>((ref) {
  final statusAsync = ref.watch(subscriptionStatusProvider);
  return statusAsync.when(
    data: (status) => status.willRenew,
    loading: () => false,
    error: (_, __) => false,
  );
});
