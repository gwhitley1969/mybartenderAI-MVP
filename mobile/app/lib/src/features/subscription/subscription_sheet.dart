import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../providers/backend_provider.dart';
import '../../providers/subscription_provider.dart';

/// Show the subscription paywall bottom sheet.
///
/// [onPurchaseComplete] is called after a successful purchase or restore
/// so callers can refresh their own state (e.g., invalidate providers).
void showSubscriptionSheet(BuildContext context, {VoidCallback? onPurchaseComplete}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => SubscriptionSheet(onPurchaseComplete: onPurchaseComplete),
  );
}

// Historical note: `navigateOrGate` was removed in v1.2.0+33 when the paywall
// moved from per-button gating to a router-level redirect in `main.dart`.
// For voluntary upgrades (e.g., Profile "change plan") use
// `showSubscriptionSheet` above. For the forced paywall flow see
// `PaywallScreen` at `lib/src/features/subscription/paywall_screen.dart`.

/// Bottom sheet for subscription options (shared across screens).
///
/// Displays RevenueCat offerings (monthly + annual), handles purchase flow,
/// and supports lazy RevenueCat initialization if the SDK wasn't initialized
/// at login time (e.g., due to transient network failure).
class SubscriptionSheet extends ConsumerStatefulWidget {
  final VoidCallback? onPurchaseComplete;

  const SubscriptionSheet({super.key, this.onPurchaseComplete});

  @override
  ConsumerState<SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends ConsumerState<SubscriptionSheet> {
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Attempt lazy init if RevenueCat wasn't initialized at login
    final service = ref.read(subscriptionServiceProvider);
    if (!service.isInitialized) {
      _attemptLazyInit();
    }
  }

  /// Try to initialize RevenueCat now if it failed at login time.
  /// This handles transient network failures at app startup.
  /// Uses user.id (Entra sub) as App User ID — always available, no email dependency.
  Future<void> _attemptLazyInit() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(subscriptionServiceProvider);
      final backendService = ref.read(backendServiceProvider);
      await service.initialize(user.id, backendService,
          email: user.email, displayName: user.displayName);
      developer.log('SubscriptionSheet: Lazy RevenueCat init succeeded', name: 'SubscriptionSheet');
      ref.invalidate(subscriptionOfferingsProvider);
      ref.invalidate(subscriptionStatusProvider);
    } catch (e) {
      developer.log('SubscriptionSheet: Lazy RevenueCat init failed: $e', name: 'SubscriptionSheet');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offeringsAsync = ref.watch(subscriptionOfferingsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Subscribe',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                'Unlock the full bartender experience',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),

              // Feature list
              _buildFeatureRow(Icons.mic, 'Voice AI conversations'),
              _buildFeatureRow(Icons.auto_awesome, 'AI cocktail concierge'),
              _buildFeatureRow(Icons.camera_alt, 'Scan My Bar'),
              _buildFeatureRow(Icons.local_bar, 'Unlimited cocktail access'),
              const SizedBox(height: 20),

              // Error message
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Loading or offerings
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: Colors.amber),
                )
              else
                offeringsAsync.when(
                  data: (offerings) => _buildOfferingOptions(offerings),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: Colors.amber),
                  ),
                  error: (e, _) => _buildErrorState(e.toString()),
                ),

              const SizedBox(height: 12),

              // Compliance text
              Text(
                'Trial auto-converts to \$3.99/month unless canceled before trial ends.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Restore purchases link
              TextButton(
                onPressed: _restorePurchases,
                child: Text(
                  'Restore Purchases',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
              ),

              // Cancel button
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber.shade400, size: 18),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferingOptions(Offerings? offerings) {
    if (offerings == null || offerings.current == null) {
      return _buildErrorState('No subscription options available');
    }

    // Show ALL available packages from the current offering
    final packages = offerings.current!.availablePackages.toList();

    if (packages.isEmpty) {
      return _buildErrorState('No subscription options available');
    }

    // Sort: monthly first, then yearly
    packages.sort((a, b) {
      final aIsMonthly = a.storeProduct.identifier.contains('monthly');
      final bIsMonthly = b.storeProduct.identifier.contains('monthly');
      if (aIsMonthly && !bIsMonthly) return -1;
      if (!aIsMonthly && bIsMonthly) return 1;
      return 0;
    });

    return Column(
      children: packages.map((package) {
        final isYearly = package.storeProduct.identifier.contains('yearly') ||
            package.storeProduct.identifier.contains('annual');

        if (!isYearly) {
          // Monthly with trial — primary CTA
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildMonthlyTile(package),
          );
        } else {
          // Annual — secondary CTA with savings badge
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildAnnualTile(package),
          );
        }
      }).toList(),
    );
  }

  Widget _buildMonthlyTile(Package package) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _purchasePackage(package),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.amber.shade700, width: 2),
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Colors.amber.shade900.withOpacity(0.3),
                Colors.orange.shade900.withOpacity(0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              const Text(
                'Start 7-Day Free Trial',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Then ${package.storeProduct.priceString}/month. Cancel anytime.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnualTile(Package package) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _purchasePackage(package),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade700),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${package.storeProduct.priceString}/year',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Save over 15%',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.cloud_off, color: Colors.grey.shade600, size: 48),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final subscriptionService = ref.read(subscriptionServiceProvider);
      final result = await subscriptionService.restorePurchases();

      if (mounted) {
        setState(() => _isLoading = false);

        if (result != null) {
          Navigator.of(context).pop();
          widget.onPurchaseComplete?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchases restored successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No purchases found to restore.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _purchasePackage(Package package) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final subscriptionService = ref.read(subscriptionServiceProvider);
      final result = await subscriptionService.purchasePackage(package);

      if (result != null && mounted) {
        // Success! Close the sheet and notify
        Navigator.of(context).pop();
        widget.onPurchaseComplete?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome! You now have 60 voice minutes per month.'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          // User cancelled - no error message needed
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }
}
