import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Purchase status states
enum PurchaseState {
  idle,
  loading,
  purchasing,
  verifying,
  success,
  cancelled,
  error,
}

/// Result of a purchase operation
class PurchaseResult {
  final PurchaseState state;
  final String? message;
  final int? minutesAdded;
  final int? totalMinutes;

  PurchaseResult({
    required this.state,
    this.message,
    this.minutesAdded,
    this.totalMinutes,
  });
}

/// Service for handling Google Play in-app purchases
///
/// Manages the purchase flow for voice minutes:
/// 1. Initialize and connect to Google Play
/// 2. Query product details (price, description)
/// 3. Initiate purchase
/// 4. Listen for purchase updates
/// 5. Delegate verification to backend
/// 6. Complete purchase with Google Play
class PurchaseService {
  // Product ID for voice minutes pack: $5.99 for 60 minutes
  static const String voiceMinutesProductId = 'voice_minutes_60';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final _purchaseController = StreamController<PurchaseResult>.broadcast();
  Stream<PurchaseResult> get purchaseStream => _purchaseController.stream;

  /// Callback for verifying purchases with backend
  Future<Map<String, dynamic>> Function(String purchaseToken, String productId)?
      _onVerifyPurchase;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize the purchase service
  ///
  /// [onVerifyPurchase] - Callback to verify purchase with backend
  /// Returns the backend verification result: {success, minutesAdded, totalPurchasedMinutes}
  Future<void> initialize({
    required Future<Map<String, dynamic>> Function(
            String purchaseToken, String productId)
        onVerifyPurchase,
  }) async {
    if (_isInitialized) {
      debugPrint('PurchaseService: Already initialized');
      return;
    }

    _onVerifyPurchase = onVerifyPurchase;

    debugPrint('PurchaseService: Initializing...');

    _isAvailable = await _inAppPurchase.isAvailable();
    debugPrint('PurchaseService: isAvailable = $_isAvailable');

    if (!_isAvailable) {
      debugPrint('PurchaseService: In-app purchases not available on this device');
      _isInitialized = true;
      return;
    }

    // Listen to purchase updates
    _subscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: _onPurchaseError,
      onDone: () {
        debugPrint('PurchaseService: Purchase stream closed');
      },
    );

    _isInitialized = true;
    debugPrint('PurchaseService: Initialized successfully');

    // Check for any pending purchases from previous sessions
    await _restorePendingPurchases();
  }

  /// Get voice minutes product details
  Future<ProductDetails?> getVoiceMinutesProduct() async {
    if (!_isAvailable) {
      debugPrint('PurchaseService: Cannot query products - not available');
      return null;
    }

    debugPrint('PurchaseService: Querying product: $voiceMinutesProductId');

    final response = await _inAppPurchase.queryProductDetails({voiceMinutesProductId});

    if (response.error != null) {
      debugPrint('PurchaseService: Error querying products: ${response.error}');
      return null;
    }

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('PurchaseService: Product not found: ${response.notFoundIDs}');
      return null;
    }

    if (response.productDetails.isEmpty) {
      debugPrint('PurchaseService: No product details returned');
      return null;
    }

    final product = response.productDetails.first;
    debugPrint('PurchaseService: Product found: ${product.title} - ${product.price}');
    return product;
  }

  /// Initiate purchase of voice minutes
  Future<bool> purchaseVoiceMinutes() async {
    if (!_isAvailable) {
      _purchaseController.add(PurchaseResult(
        state: PurchaseState.error,
        message: 'In-app purchases not available on this device',
      ));
      return false;
    }

    _purchaseController.add(PurchaseResult(state: PurchaseState.loading));

    final product = await getVoiceMinutesProduct();
    if (product == null) {
      _purchaseController.add(PurchaseResult(
        state: PurchaseState.error,
        message: 'Voice minutes product not available',
      ));
      return false;
    }

    _purchaseController.add(PurchaseResult(state: PurchaseState.purchasing));

    debugPrint('PurchaseService: Starting purchase for ${product.id}');

    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      final success = await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
      debugPrint('PurchaseService: buyConsumable returned: $success');
      return success;
    } catch (e) {
      debugPrint('PurchaseService: Error initiating purchase: $e');
      _purchaseController.add(PurchaseResult(
        state: PurchaseState.error,
        message: 'Failed to start purchase: $e',
      ));
      return false;
    }
  }

  /// Handle purchase update stream events
  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    debugPrint('PurchaseService: Received ${purchases.length} purchase updates');

    for (final purchase in purchases) {
      debugPrint('PurchaseService: Purchase ${purchase.productID} status: ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchaseController.add(PurchaseResult(state: PurchaseState.purchasing));
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _handleSuccessfulPurchase(purchase);
          break;

        case PurchaseStatus.error:
          debugPrint('PurchaseService: Purchase error: ${purchase.error}');
          _purchaseController.add(PurchaseResult(
            state: PurchaseState.error,
            message: purchase.error?.message ?? 'Purchase failed',
          ));
          // Still need to complete the purchase to clear it
          if (purchase.pendingCompletePurchase) {
            _inAppPurchase.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.canceled:
          debugPrint('PurchaseService: Purchase cancelled by user');
          _purchaseController.add(PurchaseResult(state: PurchaseState.cancelled));
          break;
      }
    }
  }

  /// Handle a successful purchase - verify with backend and deliver
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    debugPrint('PurchaseService: Handling successful purchase: ${purchase.productID}');

    _purchaseController.add(PurchaseResult(state: PurchaseState.verifying));

    try {
      if (_onVerifyPurchase == null) {
        throw Exception('No verification callback configured');
      }

      // Get the purchase token for server verification
      final purchaseToken = purchase.verificationData.serverVerificationData;
      debugPrint('PurchaseService: Verifying with backend, token length: ${purchaseToken.length}');

      // Verify with backend
      final result = await _onVerifyPurchase!(purchaseToken, purchase.productID);
      debugPrint('PurchaseService: Backend verification result: $result');

      if (result['success'] == true) {
        // Complete the purchase with Google Play
        if (purchase.pendingCompletePurchase) {
          debugPrint('PurchaseService: Completing purchase with Google Play');
          await _inAppPurchase.completePurchase(purchase);
        }

        _purchaseController.add(PurchaseResult(
          state: PurchaseState.success,
          minutesAdded: result['minutesAdded'] ?? 10,
          totalMinutes: result['totalPurchasedMinutes'] ?? 10,
          message: result['message'] ?? '60 voice minutes added!',
        ));
      } else {
        _purchaseController.add(PurchaseResult(
          state: PurchaseState.error,
          message: result['error'] ?? 'Verification failed',
        ));
        // Still complete to clear the pending purchase
        if (purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }
      }
    } catch (e) {
      debugPrint('PurchaseService: Verification error: $e');
      _purchaseController.add(PurchaseResult(
        state: PurchaseState.error,
        message: 'Verification failed: $e',
      ));
      // Complete to avoid stuck purchases
      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  /// Handle purchase stream errors
  void _onPurchaseError(dynamic error) {
    debugPrint('PurchaseService: Purchase stream error: $error');
    _purchaseController.add(PurchaseResult(
      state: PurchaseState.error,
      message: 'Purchase error: $error',
    ));
  }

  /// Check for and restore any pending purchases from previous sessions
  Future<void> _restorePendingPurchases() async {
    // The purchase stream automatically emits pending purchases on startup
    // This method is here for explicit documentation
    debugPrint('PurchaseService: Checking for pending purchases...');
  }

  /// Emit a success result (called from provider after backend verification)
  void emitSuccess({required int minutesAdded, required int totalMinutes}) {
    _purchaseController.add(PurchaseResult(
      state: PurchaseState.success,
      minutesAdded: minutesAdded,
      totalMinutes: totalMinutes,
      message: '$minutesAdded voice minutes added!',
    ));
  }

  /// Emit an error result
  void emitError(String message) {
    _purchaseController.add(PurchaseResult(
      state: PurchaseState.error,
      message: message,
    ));
  }

  /// Dispose service resources
  void dispose() {
    debugPrint('PurchaseService: Disposing...');
    _subscription?.cancel();
    _purchaseController.close();
  }
}
