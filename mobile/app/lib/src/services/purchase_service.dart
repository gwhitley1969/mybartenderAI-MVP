import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

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
///
/// Note: this is deliberately distinct from RevenueCat's `rc.PurchaseResult`.
/// The `rc` import prefix keeps the two apart — do not drop it.
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

/// Service for handling voice-minute consumable purchases via RevenueCat.
///
/// Both platforms use the same path as of v1.2.1+35:
/// 1. Fetch the `voice_minutes_60` product from RevenueCat
/// 2. Purchase it through the store (Google Play / StoreKit)
/// 3. RevenueCat fires a `NON_RENEWING_PURCHASE` webhook to the backend
/// 4. `subscription-webhook` credits 60 minutes (idempotent via
///    `voice_purchase_transactions`) and the client re-reads its quota
///
/// Crediting is asynchronous — the server is the source of truth for balances,
/// so callers should refresh `voiceQuotaProvider` shortly after success rather
/// than trusting the optimistic numbers emitted here.
class PurchaseService {
  /// Product ID for the voice minutes pack: $3.99 for 60 minutes.
  /// Registered in both stores and in the RevenueCat product catalog.
  static const String voiceMinutesProductId = 'voice_minutes_60';

  /// Minutes granted per pack. Mirrors the backend's `NON_RENEWING_PURCHASE`
  /// handler, which is the authority — this value is display-only.
  static const int minutesPerPack = 60;

  final _purchaseController = StreamController<PurchaseResult>.broadcast();
  Stream<PurchaseResult> get purchaseStream => _purchaseController.stream;

  /// Fetch the voice minutes product (price, title) from RevenueCat.
  ///
  /// IMPORTANT: `voice_minutes_60` is a one-time product, not a subscription.
  /// `Purchases.getProducts` defaults to [rc.ProductCategory.subscription] and
  /// on Android that default causes INAPP products to silently come back empty.
  /// The parameter has no effect on iOS, so omitting it fails on Android only.
  Future<rc.StoreProduct?> getVoiceMinutesProduct() async {
    debugPrint('PurchaseService: Querying product: $voiceMinutesProductId');

    try {
      final products = await rc.Purchases.getProducts(
        [voiceMinutesProductId],
        productCategory: rc.ProductCategory.nonSubscription,
      );

      if (products.isEmpty) {
        debugPrint('PurchaseService: Product not found: $voiceMinutesProductId');
        return null;
      }

      final product = products.first;
      debugPrint(
          'PurchaseService: Product found: ${product.title} - ${product.priceString}');
      return product;
    } catch (e) {
      debugPrint('PurchaseService: Error querying products: $e');
      return null;
    }
  }

  /// Initiate a purchase of the voice minutes pack.
  ///
  /// Returns true if the store reported a completed purchase. Minutes are
  /// credited server-side via the RevenueCat webhook, so a `true` here means
  /// "purchase went through", not "balance already updated".
  Future<bool> purchaseVoiceMinutes() async {
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
    debugPrint('PurchaseService: Starting purchase for ${product.identifier}');

    try {
      await rc.Purchases.purchase(rc.PurchaseParams.storeProduct(product));

      // RevenueCat acknowledges and consumes the purchase, then fires
      // NON_RENEWING_PURCHASE to the backend which credits the minutes.
      debugPrint('PurchaseService: Purchase completed, awaiting webhook credit');
      _purchaseController.add(PurchaseResult(
        state: PurchaseState.success,
        minutesAdded: minutesPerPack,
        totalMinutes: minutesPerPack,
        message: '$minutesPerPack voice minutes added!',
      ));
      return true;
    } on PlatformException catch (e) {
      final errorCode = rc.PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == rc.PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('PurchaseService: Purchase cancelled by user');
        _purchaseController.add(PurchaseResult(state: PurchaseState.cancelled));
      } else {
        debugPrint('PurchaseService: Purchase error (${errorCode.name}): ${e.message}');
        _purchaseController.add(PurchaseResult(
          state: PurchaseState.error,
          message: 'Purchase failed: ${e.message}',
        ));
      }
      return false;
    } catch (e) {
      debugPrint('PurchaseService: Unexpected purchase error: $e');
      _purchaseController.add(PurchaseResult(
        state: PurchaseState.error,
        message: 'Purchase failed: $e',
      ));
      return false;
    }
  }

  /// Emit a success result (called from provider after backend confirmation)
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
    _purchaseController.close();
  }
}
