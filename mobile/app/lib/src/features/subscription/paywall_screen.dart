import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../providers/backend_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Full-screen paywall shown to every authenticated user who does not have an
/// active subscription. This is a hard wall — the only ways out are:
///   1. Complete a subscription purchase (trial or paid)
///   2. Restore a prior purchase on a different device
///   3. Sign out (→ /login)
///   4. Delete the account (→ /login, data wiped)
///
/// Reached via the router's `/paywall` redirect (see `main.dart`). The
/// [SubscriptionSheet] bottom sheet is still used for *voluntary* upgrade
/// flows from Profile (e.g., a paying user switching from monthly to annual).
///
/// Navigation stack note: when the router sends an unpaid user here it uses
/// `go('/paywall')`, replacing the stack. Android system back naturally exits
/// the app. iOS has no system back — intentional.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  static const _monthlyProductId = 'pro_monthly';
  static const _termsUrl = 'https://mybartenderai.com/terms';
  static const _privacyUrl = 'https://mybartenderai.com/privacy';

  bool _isPurchasing = false;
  String? _error;
  IntroEligibilityStatus? _monthlyEligibility;
  bool _shownEventLogged = false;

  @override
  void initState() {
    super.initState();
    // Lazy init if RevenueCat didn't configure at login (transient network).
    final service = ref.read(subscriptionServiceProvider);
    if (!service.isInitialized) {
      _attemptLazyInit();
    } else {
      _checkTrialEligibility();
    }
  }

  Future<void> _attemptLazyInit() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final service = ref.read(subscriptionServiceProvider);
      final backendService = ref.read(backendServiceProvider);
      await service.initialize(user.id, backendService,
          email: user.email, displayName: user.displayName);
      developer.log('Paywall: lazy RevenueCat init succeeded',
          name: 'Subscription');
      ref.invalidate(subscriptionOfferingsProvider);
      ref.invalidate(subscriptionStatusProvider);
      await _checkTrialEligibility();
    } catch (e) {
      developer.log('Paywall: lazy RevenueCat init failed: $e',
          name: 'Subscription');
    }
  }

  Future<void> _checkTrialEligibility() async {
    try {
      final result = await Purchases.checkTrialOrIntroductoryPriceEligibility(
          [_monthlyProductId]);
      if (!mounted) return;
      setState(() {
        _monthlyEligibility = result[_monthlyProductId]?.status;
      });
    } catch (e) {
      developer.log('Paywall: trial eligibility check failed: $e',
          name: 'Subscription');
      if (mounted) {
        setState(() {
          _monthlyEligibility = IntroEligibilityStatus.introEligibilityStatusUnknown;
        });
      }
    }
  }

  /// Treat both `eligible` and `unknown` as "show free-trial CTA". Only an
  /// explicit `ineligible` flips to a direct subscribe CTA. Matches
  /// RevenueCat's recommended optimistic-eligibility handling.
  bool get _showTrialCta {
    final status = _monthlyEligibility;
    return status != IntroEligibilityStatus.introEligibilityStatusIneligible;
  }

  @override
  Widget build(BuildContext context) {
    // Analytics: log paywall shown once per mount.
    if (!_shownEventLogged) {
      _shownEventLogged = true;
      developer.log(
          'event=PaywallShown source=router_redirect trialEligible=$_showTrialCta',
          name: 'Analytics');
    }

    final offeringsAsync = ref.watch(subscriptionOfferingsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  _buildHero(),
                  const SizedBox(height: 24),
                  _buildTitle(),
                  const SizedBox(height: 20),
                  _buildFeatureList(),
                  const SizedBox(height: 24),
                  if (_error != null) _buildErrorBanner(),
                  offeringsAsync.when(
                    data: (offerings) => _buildCtaBlock(offerings),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primaryPurple),
                      ),
                    ),
                    error: (e, _) => _buildOfferingsError(e.toString()),
                  ),
                  const SizedBox(height: 16),
                  _buildComplianceText(),
                  const SizedBox(height: 16),
                  _buildRestoreButton(),
                  const SizedBox(height: 8),
                  _buildFooter(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          if (_isPurchasing) _buildPurchasingOverlay(),
        ],
      ),
    );
  }

  Widget _buildHero() {
    // NOTE: Replace with an `Image.asset('assets/paywall/hero_<n>.jpg')` once
    // photo assets are bundled (see pubspec.yaml `assets:` section). Until
    // then the branded gradient looks intentional rather than placeholder-y
    // and, critically, works on fresh installs where no SQLite cocktail data
    // has been downloaded yet.
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7C3AED),
            Color(0xFFEC4899),
            Color(0xFFF59E0B),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.local_bar,
          size: 96,
          color: Colors.white.withOpacity(0.95),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Unlock My AI Bartender',
          style: AppTypography.heading1,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _showTrialCta
              ? 'Start your 7-day free trial'
              : 'Subscribe to continue',
          style: AppTypography.appSubtitle,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeatureList() {
    return Column(
      children: [
        _featureRow(Icons.menu_book, '621 cocktail recipes, always offline'),
        _featureRow(Icons.auto_awesome, 'AI Bartender chat concierge'),
        _featureRow(Icons.camera_alt, 'Smart Scanner — ID bottles from a photo'),
        _featureRow(Icons.mic, 'Voice AI — 60 minutes of conversational guidance'),
        _featureRow(Icons.local_drink, 'Custom Studio & My Bar inventory'),
      ],
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primaryPurpleLight, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppTypography.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.15),
          border: Border.all(color: AppColors.error.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _error!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCtaBlock(Offerings? offerings) {
    if (offerings == null || offerings.current == null) {
      return _buildOfferingsError('No subscription options available.');
    }

    final packages = offerings.current!.availablePackages;
    if (packages.isEmpty) {
      return _buildOfferingsError('No subscription options available.');
    }

    Package? monthly;
    Package? annual;
    for (final p in packages) {
      final id = p.storeProduct.identifier.toLowerCase();
      if (id.contains('annual') || id.contains('yearly')) {
        annual ??= p;
      } else if (id.contains('monthly')) {
        monthly ??= p;
      }
    }

    return Column(
      children: [
        if (monthly != null) _buildPrimaryCta(monthly),
        if (monthly != null && annual != null) const SizedBox(height: 12),
        if (annual != null) _buildSecondaryCta(annual),
      ],
    );
  }

  Widget _buildPrimaryCta(Package package) {
    final label = _showTrialCta
        ? 'Start 7-Day Free Trial'
        : 'Subscribe — ${package.storeProduct.priceString}/month';
    final subline = _showTrialCta
        ? 'Then ${package.storeProduct.priceString}/month. Cancel anytime.'
        : 'Monthly, auto-renewing. Cancel anytime.';

    return InkWell(
      onTap: () => _purchasePackage(package),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: AppColors.purpleGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryPurple.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: AppTypography.heading4.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              subline,
              style: AppTypography.bodySmall
                  .copyWith(color: Colors.white.withOpacity(0.85)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryCta(Package package) {
    return InkWell(
      onTap: () => _purchasePackage(package),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Annual ${package.storeProduct.priceString}',
              style: AppTypography.bodyMedium
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Save 17%',
                style: AppTypography.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferingsError(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.cloud_off, color: AppColors.textTertiary, size: 48),
          const SizedBox(height: 12),
          Text(
            'Connect to the internet to subscribe.',
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              ref.invalidate(subscriptionOfferingsProvider);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceText() {
    return Text(
      'Subscriptions auto-renew until canceled. Cancel anytime in your '
      'Google Play or App Store account settings. Trial auto-converts to '
      '\$3.99/month unless canceled before the trial ends.',
      style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildRestoreButton() {
    return Center(
      child: TextButton(
        onPressed: _isPurchasing ? null : _restorePurchases,
        child: Text(
          'Already subscribed? Restore Purchases',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.primaryPurpleLight,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => _launchUrl(_termsUrl),
              child: Text('Terms',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary)),
            ),
            Text('·',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textTertiary)),
            TextButton(
              onPressed: () => _launchUrl(_privacyUrl),
              child: Text('Privacy',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _isPurchasing ? null : _confirmSignOut,
              child: Text('Sign Out',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary)),
            ),
            Text('·',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textTertiary)),
            TextButton(
              onPressed: _isPurchasing ? null : _confirmDeleteAccount,
              child: Text('Delete Account',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.error)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPurchasingOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: AppColors.primaryPurple),
              SizedBox(height: 16),
              Text('Processing...',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _purchasePackage(Package package) async {
    developer.log(
        'event=PaywallPurchaseStarted packageId=${package.identifier}',
        name: 'Analytics');

    setState(() {
      _isPurchasing = true;
      _error = null;
    });

    try {
      final service = ref.read(subscriptionServiceProvider);
      final result = await service.purchasePackage(package);

      if (!mounted) return;

      if (result != null) {
        developer.log(
            'event=PaywallPurchaseCompleted packageId=${package.identifier}',
            name: 'Analytics');
        // Force downstream providers to re-read; router redirect handles nav.
        ref.invalidate(subscriptionStatusProvider);
        ref.invalidate(backendEntitlementProvider);
        setState(() => _isPurchasing = false);
        // Don't navigate manually — the router's subscription gate will flip
        // to paid once the stream updates, and the redirect will send the
        // user to /initial-sync (if needed) or home.
      } else {
        developer.log(
            'event=PaywallPurchaseCancelled packageId=${package.identifier}',
            name: 'Analytics');
        setState(() => _isPurchasing = false);
      }
    } catch (e) {
      developer.log(
          'event=PaywallPurchaseError packageId=${package.identifier} error=$e',
          name: 'Analytics');
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _restorePurchases() async {
    developer.log('event=PaywallRestoreAttempted', name: 'Analytics');
    setState(() {
      _isPurchasing = true;
      _error = null;
    });

    try {
      final service = ref.read(subscriptionServiceProvider);
      final result = await service.restorePurchases();

      if (!mounted) return;
      setState(() => _isPurchasing = false);

      if (result != null) {
        developer.log('event=PaywallRestoreSucceeded', name: 'Analytics');
        ref.invalidate(subscriptionStatusProvider);
        ref.invalidate(backendEntitlementProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchases restored.'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        developer.log(
            'event=PaywallRestoreFailed reason=no_purchases_found',
            name: 'Analytics');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No prior purchases found.')),
        );
      }
    } catch (e) {
      developer.log('event=PaywallRestoreFailed error=$e', name: 'Analytics');
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        title: Text('Sign Out?', style: AppTypography.heading3),
        content: Text(
          'You can sign back in at any time.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Sign Out',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    developer.log('event=PaywallExitedViaSignOut', name: 'Analytics');
    await ref.read(authNotifierProvider.notifier).signOut();
    // Router auto-redirects to /login.
  }

  Future<void> _confirmDeleteAccount() async {
    // Step 1 — explain what will be deleted.
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        title: Text('Delete Account?', style: AppTypography.heading3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This permanently deletes your account and all data on our servers:',
              style: AppTypography.bodyMedium,
            ),
            SizedBox(height: AppSpacing.sm),
            Text('  • Profile and preferences', style: AppTypography.bodySmall),
            Text('  • Custom recipes and shared recipes',
                style: AppTypography.bodySmall),
            Text('  • Voice session history',
                style: AppTypography.bodySmall),
            Text('  • Bar inventory and scan history',
                style: AppTypography.bodySmall),
            SizedBox(height: AppSpacing.md),
            Text(
              'This action cannot be undone.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete Account',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;

    // Step 2 — final confirmation.
    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        title: Text('Are you sure?',
            style: AppTypography.heading3.copyWith(color: AppColors.error)),
        content: Text(
          'All your data will be permanently deleted. This cannot be reversed.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep Account',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete Forever',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                )),
          ),
        ],
      ),
    );
    if (finalConfirm != true || !mounted) return;

    // Step 3 — execute.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.backgroundSecondary,
          content: Row(
            children: [
              const CircularProgressIndicator(),
              SizedBox(width: AppSpacing.lg),
              Text('Deleting account...', style: AppTypography.bodyMedium),
            ],
          ),
        ),
      ),
    );

    try {
      developer.log('event=PaywallExitedViaDeleteAccount', name: 'Analytics');
      await ref.read(authNotifierProvider.notifier).deleteAccount();
      // Router auto-redirects to /login once auth state flips.
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to delete account. Please try again or contact support.'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
