import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'subscription_provider.dart';

/// Tri-state representation of the user's subscription check, designed to be
/// read synchronously from inside a GoRouter `redirect` function.
///
/// The router redirect must return synchronously, but both
/// [subscriptionStatusProvider] (stream) and [backendEntitlementProvider]
/// (future) are async. A naive `bool` check would briefly report `unpaid` on
/// cold start for paying subscribers and bounce them to the paywall.
///
/// This enum mirrors the codebase's existing pattern for `isAuthenticating`
/// and `initialSyncStatus.isChecking`: while [checking], the redirect returns
/// `null` (do nothing), only committing to a verdict once the underlying
/// async sources have resolved.
enum SubscriptionGateState {
  /// At least one of RevenueCat / backend is still resolving. Router must wait.
  checking,

  /// User has an active subscription (paid or trialing). Let them through.
  paid,

  /// Both sources have resolved to non-paid. Redirect to /paywall.
  unpaid,
}

/// Synchronous provider that combines the RevenueCat stream and the backend
/// PostgreSQL entitlement into a single tri-state verdict.
///
/// Resolution order mirrors the 3-step check in
/// `subscription_sheet.dart`'s `navigateOrGate`:
/// 1. RevenueCat says paid → paid (fast path; cache-backed even offline)
/// 2. Either source still loading → checking (don't commit)
/// 3. Backend says paid → paid (handles manual PostgreSQL overrides for beta
///    testers, per USER_SUBSCRIPTION_MANAGEMENT.md)
/// 4. Otherwise → unpaid
///
/// Also respects the server-side `paywallEnabled` kill switch: if the backend
/// has paywall disabled globally, every user is treated as paid. This lets
/// operations disable the paywall without shipping a new mobile binary.
final subscriptionGateProvider = Provider<SubscriptionGateState>((ref) {
  final statusAsync = ref.watch(subscriptionStatusProvider);
  final backendAsync = ref.watch(backendEntitlementProvider);
  final killSwitchAsync = ref.watch(paywallEnabledProvider);

  // Server-side kill switch: if disabled globally, let everyone through.
  final killSwitchDisabled = killSwitchAsync.maybeWhen(
    data: (enabled) => enabled == false,
    orElse: () => false,
  );
  if (killSwitchDisabled) {
    developer.log('subscriptionGate: kill-switch disabled → paid',
        name: 'Subscription');
    return SubscriptionGateState.paid;
  }

  // Fast path — RevenueCat cache yields 'paid' even without a network call,
  // so offline subscribers keep their access.
  final rcPaid = statusAsync.maybeWhen(
    data: (s) => s.isPaid,
    orElse: () => false,
  );
  if (rcPaid) {
    developer.log('subscriptionGate: RevenueCat = paid', name: 'Subscription');
    return SubscriptionGateState.paid;
  }

  // Don't commit to a verdict while either source is loading.
  if (statusAsync.isLoading || backendAsync.isLoading) {
    developer.log('subscriptionGate: checking (stream/backend loading)',
        name: 'Subscription');
    return SubscriptionGateState.checking;
  }

  // Backend is authoritative for manual overrides RevenueCat doesn't know.
  final backendPaid = backendAsync.maybeWhen(
    data: (entitlement) => entitlement == 'paid',
    orElse: () => false,
  );
  if (backendPaid) {
    developer.log('subscriptionGate: backend = paid', name: 'Subscription');
    return SubscriptionGateState.paid;
  }

  developer.log('subscriptionGate: unpaid', name: 'Subscription');
  return SubscriptionGateState.unpaid;
});
