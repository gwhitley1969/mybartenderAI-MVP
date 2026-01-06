import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'backend_service.dart';

/// Subscription tier levels
enum SubscriptionTier {
  free,
  premium,
  pro,
}

/// Subscription status from RevenueCat
class SubscriptionStatus {
  final SubscriptionTier tier;
  final String? productId;
  final bool isActive;
  final bool willRenew;
  final DateTime? expirationDate;
  final String? managementUrl;

  const SubscriptionStatus({
    required this.tier,
    this.productId,
    this.isActive = false,
    this.willRenew = false,
    this.expirationDate,
    this.managementUrl,
  });

  /// Free tier default
  static const SubscriptionStatus free = SubscriptionStatus(
    tier: SubscriptionTier.free,
    isActive: false,
  );

  bool get isPremiumOrHigher =>
      tier == SubscriptionTier.premium || tier == SubscriptionTier.pro;

  bool get isPro => tier == SubscriptionTier.pro;
}

/// Service for managing subscriptions via RevenueCat
///
/// Handles:
/// - RevenueCat SDK initialization with user ID
/// - Fetching available subscription offerings
/// - Purchasing subscriptions
/// - Restoring purchases
/// - Checking entitlement status
///
/// Voice minute consumables are handled separately by PurchaseService
class SubscriptionService {
  // RevenueCat API key - fetched from backend (stored in Azure Key Vault)
  // NO hardcoded keys in code - retrieved at runtime from secure backend
  String? _revenueCatApiKey;

  // Entitlement identifiers (must match RevenueCat dashboard)
  static const String _premiumEntitlement = 'premium';
  static const String _proEntitlement = 'pro';

  // Product identifiers (must match Google Play Console & RevenueCat)
  static const Set<String> subscriptionProductIds = {
    'premium_monthly',
    'premium_yearly',
    'pro_monthly',
    'pro_yearly',
  };

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  final _statusController = StreamController<SubscriptionStatus>.broadcast();
  Stream<SubscriptionStatus> get statusStream => _statusController.stream;

  CustomerInfo? _cachedCustomerInfo;

  /// Initialize RevenueCat with the user's ID
  ///
  /// [userId] should be the user's azure_ad_sub from Entra External ID
  /// [backendService] is used to fetch the RevenueCat API key from Azure Key Vault
  /// This links RevenueCat purchases to our backend user
  Future<void> initialize(String userId, BackendService backendService) async {
    if (_isInitialized) {
      debugPrint('SubscriptionService: Already initialized');
      return;
    }

    debugPrint('SubscriptionService: Initializing with userId: ${userId.substring(0, 8)}...');

    try {
      // Fetch RevenueCat API key from backend (stored in Azure Key Vault)
      debugPrint('SubscriptionService: Fetching API key from backend...');
      final config = await backendService.getSubscriptionConfig();
      _revenueCatApiKey = config.revenueCatApiKey;
      debugPrint('SubscriptionService: API key retrieved successfully');

      // Configure RevenueCat
      await Purchases.configure(
        PurchasesConfiguration(_revenueCatApiKey!)..appUserID = userId,
      );

      // Enable debug logs in debug mode
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      // Listen for customer info updates
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdate);

      _isInitialized = true;
      debugPrint('SubscriptionService: Initialized successfully');

      // Fetch initial status
      await refreshStatus();
    } catch (e) {
      debugPrint('SubscriptionService: Initialization error: $e');
      rethrow;
    }
  }

  /// Handle customer info updates from RevenueCat
  void _onCustomerInfoUpdate(CustomerInfo info) {
    debugPrint('SubscriptionService: Customer info updated');
    _cachedCustomerInfo = info;
    _statusController.add(_parseCustomerInfo(info));
  }

  /// Parse CustomerInfo into our SubscriptionStatus
  SubscriptionStatus _parseCustomerInfo(CustomerInfo info) {
    // Check entitlements (pro takes priority over premium)
    final proEntitlement = info.entitlements.active[_proEntitlement];
    final premiumEntitlement = info.entitlements.active[_premiumEntitlement];

    if (proEntitlement != null && proEntitlement.isActive) {
      return SubscriptionStatus(
        tier: SubscriptionTier.pro,
        productId: proEntitlement.productIdentifier,
        isActive: true,
        willRenew: proEntitlement.willRenew,
        expirationDate: proEntitlement.expirationDate != null
            ? DateTime.tryParse(proEntitlement.expirationDate!)
            : null,
        managementUrl: info.managementURL,
      );
    }

    if (premiumEntitlement != null && premiumEntitlement.isActive) {
      return SubscriptionStatus(
        tier: SubscriptionTier.premium,
        productId: premiumEntitlement.productIdentifier,
        isActive: true,
        willRenew: premiumEntitlement.willRenew,
        expirationDate: premiumEntitlement.expirationDate != null
            ? DateTime.tryParse(premiumEntitlement.expirationDate!)
            : null,
        managementUrl: info.managementURL,
      );
    }

    return SubscriptionStatus.free;
  }

  /// Get available subscription offerings
  Future<Offerings?> getOfferings() async {
    if (!_isInitialized) {
      debugPrint('SubscriptionService: Not initialized');
      return null;
    }

    try {
      final offerings = await Purchases.getOfferings();
      debugPrint('SubscriptionService: Retrieved offerings: ${offerings.current?.identifier}');
      return offerings;
    } catch (e) {
      debugPrint('SubscriptionService: Error getting offerings: $e');
      return null;
    }
  }

  /// Purchase a subscription package
  ///
  /// Returns CustomerInfo on success, null on failure/cancellation
  Future<CustomerInfo?> purchasePackage(Package package) async {
    if (!_isInitialized) {
      debugPrint('SubscriptionService: Not initialized');
      return null;
    }

    debugPrint('SubscriptionService: Purchasing package: ${package.identifier}');

    try {
      final customerInfo = await Purchases.purchasePackage(package);
      _cachedCustomerInfo = customerInfo;
      _statusController.add(_parseCustomerInfo(customerInfo));
      debugPrint('SubscriptionService: Purchase successful');
      return customerInfo;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('SubscriptionService: Purchase cancelled by user');
      } else {
        debugPrint('SubscriptionService: Purchase error: ${e.message}');
      }
      return null;
    } catch (e) {
      debugPrint('SubscriptionService: Purchase error: $e');
      return null;
    }
  }

  /// Restore purchases (for app reinstall or device switch)
  Future<CustomerInfo?> restorePurchases() async {
    if (!_isInitialized) {
      debugPrint('SubscriptionService: Not initialized');
      return null;
    }

    debugPrint('SubscriptionService: Restoring purchases...');

    try {
      final customerInfo = await Purchases.restorePurchases();
      _cachedCustomerInfo = customerInfo;
      _statusController.add(_parseCustomerInfo(customerInfo));
      debugPrint('SubscriptionService: Restore completed');
      return customerInfo;
    } catch (e) {
      debugPrint('SubscriptionService: Restore error: $e');
      return null;
    }
  }

  /// Get current customer info
  Future<CustomerInfo?> getCustomerInfo() async {
    if (!_isInitialized) {
      debugPrint('SubscriptionService: Not initialized');
      return null;
    }

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _cachedCustomerInfo = customerInfo;
      return customerInfo;
    } catch (e) {
      debugPrint('SubscriptionService: Error getting customer info: $e');
      return null;
    }
  }

  /// Get current subscription status
  Future<SubscriptionStatus> getStatus() async {
    final customerInfo = await getCustomerInfo();
    if (customerInfo == null) {
      return SubscriptionStatus.free;
    }
    return _parseCustomerInfo(customerInfo);
  }

  /// Refresh and emit current status
  Future<void> refreshStatus() async {
    final status = await getStatus();
    _statusController.add(status);
  }

  /// Check if user has premium entitlement (premium or pro)
  bool isPremiumOrHigher([CustomerInfo? info]) {
    final customerInfo = info ?? _cachedCustomerInfo;
    if (customerInfo == null) return false;

    return customerInfo.entitlements.active.containsKey(_premiumEntitlement) ||
        customerInfo.entitlements.active.containsKey(_proEntitlement);
  }

  /// Check if user has pro entitlement
  bool isPro([CustomerInfo? info]) {
    final customerInfo = info ?? _cachedCustomerInfo;
    if (customerInfo == null) return false;

    return customerInfo.entitlements.active.containsKey(_proEntitlement);
  }

  /// Get the current tier from cached info
  SubscriptionTier get currentTier {
    if (_cachedCustomerInfo == null) return SubscriptionTier.free;
    return _parseCustomerInfo(_cachedCustomerInfo!).tier;
  }

  /// Log out current user (call when user signs out)
  Future<void> logout() async {
    if (!_isInitialized) return;

    debugPrint('SubscriptionService: Logging out...');
    try {
      await Purchases.logOut();
      _cachedCustomerInfo = null;
      _statusController.add(SubscriptionStatus.free);
    } catch (e) {
      debugPrint('SubscriptionService: Logout error: $e');
    }
  }

  /// Dispose service resources
  void dispose() {
    debugPrint('SubscriptionService: Disposing...');
    Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdate);
    _statusController.close();
  }
}
