import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'backend_service.dart';

/// Subscription status from RevenueCat
class SubscriptionStatus {
  final bool isPaid;
  final String subscriptionStatus; // 'trialing', 'active', 'expired', 'none'
  final String? productId;
  final bool isActive;
  final bool willRenew;
  final DateTime? expirationDate;
  final String? managementUrl;

  const SubscriptionStatus({
    required this.isPaid,
    this.subscriptionStatus = 'none',
    this.productId,
    this.isActive = false,
    this.willRenew = false,
    this.expirationDate,
    this.managementUrl,
  });

  static const SubscriptionStatus none = SubscriptionStatus(
    isPaid: false,
    subscriptionStatus: 'none',
    isActive: false,
  );
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

  // Entitlement identifier (must match RevenueCat dashboard)
  static const String _paidEntitlement = 'paid';

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
    final paidEntitlement = info.entitlements.active[_paidEntitlement];

    if (paidEntitlement != null && paidEntitlement.isActive) {
      // Determine subscription status from entitlement period type
      final status = paidEntitlement.periodType == PeriodType.trial
          ? 'trialing' : 'active';
      return SubscriptionStatus(
        isPaid: true,
        subscriptionStatus: status,
        productId: paidEntitlement.productIdentifier,
        isActive: true,
        willRenew: paidEntitlement.willRenew,
        expirationDate: paidEntitlement.expirationDate != null
            ? DateTime.tryParse(paidEntitlement.expirationDate!)
            : null,
        managementUrl: info.managementURL,
      );
    }

    return SubscriptionStatus.none;
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
      return SubscriptionStatus.none;
    }
    return _parseCustomerInfo(customerInfo);
  }

  /// Refresh and emit current status
  Future<void> refreshStatus() async {
    final status = await getStatus();
    _statusController.add(status);
  }

  /// Check if user has active paid subscription
  bool isPaid([CustomerInfo? info]) {
    final customerInfo = info ?? _cachedCustomerInfo;
    if (customerInfo == null) return false;
    return customerInfo.entitlements.active.containsKey(_paidEntitlement);
  }

  /// Log out current user (call when user signs out)
  Future<void> logout() async {
    if (!_isInitialized) return;

    debugPrint('SubscriptionService: Logging out...');
    try {
      await Purchases.logOut();
      _cachedCustomerInfo = null;
      _statusController.add(SubscriptionStatus.none);
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
