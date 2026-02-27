import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/subscription_service.dart';
import 'backend_provider.dart';

/// Provider for the subscription service singleton
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final service = SubscriptionService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for the current subscription status (from stream)
///
/// Uses an async* generator to always yield an initial value immediately,
/// preventing the "forever spinner" when RevenueCat init fails.
/// If the service is initialized, fetches real status first; otherwise yields none.
final subscriptionStatusProvider = StreamProvider<SubscriptionStatus>((ref) async* {
  final service = ref.watch(subscriptionServiceProvider);

  // Always yield an initial value so the provider never stays in loading state
  if (service.isInitialized) {
    yield await service.getStatus();
  } else {
    yield SubscriptionStatus.none;
  }

  // Forward all future updates from RevenueCat
  await for (final status in service.statusStream) {
    yield status;
  }
});

/// Provider for the current subscription status (one-time fetch)
final currentSubscriptionProvider = FutureProvider<SubscriptionStatus>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  if (!service.isInitialized) {
    return SubscriptionStatus.none;
  }
  return service.getStatus();
});

/// Provider for available subscription offerings
final subscriptionOfferingsProvider = FutureProvider<Offerings?>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  if (!service.isInitialized) return null;
  return service.getOfferings();
});

/// Backend entitlement check (PostgreSQL authoritative source).
/// Fetched once per session and cached. Handles manual DB overrides
/// that RevenueCat doesn't know about (e.g., beta testers).
final backendEntitlementProvider = FutureProvider<String?>((ref) async {
  final backendService = ref.watch(backendServiceProvider);
  try {
    final entitlement = await backendService.getBackendEntitlement();
    developer.log('backendEntitlementProvider: got entitlement=$entitlement',
        name: 'Subscription');
    return entitlement;
  } catch (e) {
    developer.log('backendEntitlementProvider: error=$e',
        name: 'Subscription');
    return null;
  }
});

/// Provider for checking if user has active subscription.
/// Checks RevenueCat first (fast, local). Falls back to backend
/// entitlement from PostgreSQL (handles manual DB overrides).
final isPaidProvider = Provider<bool>((ref) {
  // Fast path: RevenueCat says paid
  final statusAsync = ref.watch(subscriptionStatusProvider);
  final revenueCatPaid = statusAsync.when(
    data: (status) => status.isPaid,
    loading: () => false,
    error: (_, __) => false,
  );
  if (revenueCatPaid) {
    developer.log('isPaidProvider: TRUE (RevenueCat)', name: 'Subscription');
    return true;
  }

  // Slow path: check backend entitlement (PostgreSQL is authoritative)
  final backendEntitlement = ref.watch(backendEntitlementProvider);
  final result = backendEntitlement.when(
    data: (entitlement) {
      developer.log('isPaidProvider: backend entitlement=$entitlement',
          name: 'Subscription');
      return entitlement == 'paid';
    },
    loading: () {
      developer.log('isPaidProvider: backend LOADING', name: 'Subscription');
      return false;
    },
    error: (e, _) {
      developer.log('isPaidProvider: backend ERROR=$e', name: 'Subscription');
      return false;
    },
  );
  return result;
});

/// Provider for subscription status string (trialing/active/expired/none)
final subscriptionStatusStringProvider = Provider<String>((ref) {
  final statusAsync = ref.watch(subscriptionStatusProvider);
  return statusAsync.when(
    data: (status) => status.subscriptionStatus,
    loading: () => 'none',
    error: (_, __) => 'none',
  );
});

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
/// Returns true if user is not paid and not currently processing a purchase
final shouldShowUpgradePromptProvider = Provider<bool>((ref) {
  final isPaid = ref.watch(isPaidProvider);
  final isProcessing = ref.watch(isSubscriptionProcessingProvider);
  return !isPaid && !isProcessing;
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
