# Voice Minute Purchase - Implementation Plan

**Created:** December 22, 2025
**Status:** Planning
**Priority:** High
**Phase:** Beta

---

## Overview

Enable Premium and Pro users to purchase additional voice minutes ($4.99 for 20 minutes) via Google Play Billing.

### Business Rules

| User Tier | Included Minutes | Can Purchase | Notes |
|-----------|------------------|--------------|-------|
| Free | 0 | No | Must upgrade to Premium first |
| Premium | 0 | Yes | $4.99 per 20 minutes |
| Pro | 60/month | Yes | $4.99 per 20 minutes top-up |

### Key Policies

- **Purchased minutes NEVER expire** - persist across tier changes, subscription lapses
- **Deduction order:** Subscription minutes first, then purchased (subscription expires anyway)
- **Margin:** 40% on each $4.99 purchase ($3.00 cost at 30% utilization)

---

## Phase 1: Infrastructure Setup

### 1.1 Google Play Console - Create IAP Product

1. Go to **Google Play Console** → Your App → **Monetize** → **Products** → **In-app products**
2. Click **Create product**
3. Configure:
   - **Product ID:** `voice_minutes_10`
   - **Name:** Voice Minutes (10 min)
   - **Description:** Add 10 minutes of Voice AI conversation time. Minutes never expire.
   - **Default price:** $4.99 USD
   - **Type:** Consumable (managed product)
4. **Activate** the product

### 1.2 Google Cloud Console - Service Account Setup

Required for server-side purchase verification.

1. Go to **Google Cloud Console** → Select your project (or create one linked to Play Console)
2. Navigate to **IAM & Admin** → **Service Accounts**
3. Click **Create Service Account**:
   - Name: `play-billing-verifier`
   - Description: Verifies Google Play purchases for MyBartenderAI
4. **Skip** granting roles (not needed for Play API)
5. Click **Done**, then click on the new service account
6. Go to **Keys** tab → **Add Key** → **Create new key** → **JSON**
7. Download the JSON key file (keep secure!)

### 1.3 Google Play Console - Grant Service Account Access

1. Go to **Google Play Console** → **Settings** → **API access**
2. Find your service account under "Service accounts"
3. Click **Grant access**
4. Set permissions:
   - **App permissions:** Select MyBartenderAI app
   - **Account permissions:** "View financial data, orders, and cancellation survey responses"
5. **Invite user**

### 1.4 Azure Key Vault - Store Service Account Key

```bash
# Store the entire JSON key file contents as a secret
az keyvault secret set \
  --vault-name kv-mybartenderai-prod \
  --name GOOGLE-PLAY-SERVICE-ACCOUNT-KEY \
  --file path/to/service-account-key.json
```

Add to Function App settings:
```bash
az functionapp config appsettings set \
  --name func-mba-fresh \
  --resource-group rg-mba-prod \
  --settings "GOOGLE_PLAY_SERVICE_ACCOUNT_KEY=@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/GOOGLE-PLAY-SERVICE-ACCOUNT-KEY/)"
```

### 1.5 Database Migration

```sql
-- Run this migration on pg-mybartenderdb
-- STATUS: COMPLETED on December 22, 2025

-- 1. Create purchase audit table
CREATE TABLE voice_minute_purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES user_profile(user_id) ON DELETE CASCADE,
    minutes_credited INTEGER NOT NULL DEFAULT 10,
    purchase_token TEXT NOT NULL,
    google_order_id TEXT,
    price_cents INTEGER NOT NULL DEFAULT 499,
    currency TEXT NOT NULL DEFAULT 'USD',
    environment TEXT NOT NULL DEFAULT 'production',  -- 'production' or 'sandbox'
    status TEXT NOT NULL DEFAULT 'completed',        -- 'pending', 'completed', 'refunded'
    purchased_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    verified_at TIMESTAMPTZ,
    refunded_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Indexes
CREATE UNIQUE INDEX idx_voice_purchases_token ON voice_minute_purchases(purchase_token);
CREATE INDEX idx_voice_purchases_user_date ON voice_minute_purchases(user_id, purchased_at DESC);
CREATE INDEX idx_voice_purchases_status ON voice_minute_purchases(status) WHERE status = 'pending';

-- 3. Add denormalized column to user_profile
ALTER TABLE user_profile
ADD COLUMN IF NOT EXISTS purchased_voice_minutes INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN user_profile.purchased_voice_minutes IS
    'Total purchased voice minutes remaining. Never expires. Separate from subscription minutes.';

-- 4. Add constraint to prevent negative balance
ALTER TABLE user_profile
ADD CONSTRAINT chk_purchased_voice_minutes_non_negative
CHECK (purchased_voice_minutes >= 0);
```

---

## Phase 2: Backend Implementation

### 2.1 Add npm Dependencies

```bash
cd backend/functions
npm install googleapis
```

### 2.2 New Function: `voice-purchase`

**File:** `backend/functions/voice-purchase/index.js`

```javascript
const { google } = require('googleapis');
const { Pool } = require('pg');

const PACKAGE_NAME = 'com.mybartenderai.app';
const PRODUCT_ID = 'voice_minutes_10';
const MINUTES_PER_PURCHASE = 10;

module.exports = async function (context, req) {
    const userId = req.headers['x-user-id'];
    if (!userId) {
        context.res = { status: 401, body: { error: 'Unauthorized' } };
        return;
    }

    const { purchaseToken, productId } = req.body;

    if (!purchaseToken || productId !== PRODUCT_ID) {
        context.res = { status: 400, body: { error: 'Invalid request' } };
        return;
    }

    const pool = new Pool({ connectionString: process.env.POSTGRES_CONNECTION_STRING });

    try {
        // 1. Check if already processed (idempotent)
        const existing = await pool.query(
            'SELECT id, status FROM voice_minute_purchases WHERE purchase_token = $1',
            [purchaseToken]
        );

        if (existing.rows.length > 0) {
            if (existing.rows[0].status === 'completed') {
                context.res = {
                    status: 200,
                    body: { success: true, message: 'Purchase already credited', alreadyProcessed: true }
                };
                return;
            }
            // If pending, continue to verify
        }

        // 2. Verify with Google Play API
        const verification = await verifyWithGooglePlay(purchaseToken);

        if (!verification.valid) {
            context.log.warn('Purchase verification failed', { userId, purchaseToken: purchaseToken.substring(0, 20) });
            context.res = { status: 400, body: { error: verification.error } };
            return;
        }

        // 3. Credit minutes atomically
        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            // Insert purchase record (ON CONFLICT handles race conditions)
            const insertResult = await client.query(`
                INSERT INTO voice_minute_purchases
                    (user_id, purchase_token, google_order_id, minutes_credited, environment, status, verified_at)
                VALUES ($1, $2, $3, $4, $5, 'completed', NOW())
                ON CONFLICT (purchase_token) DO UPDATE SET
                    status = CASE WHEN voice_minute_purchases.status = 'pending' THEN 'completed' ELSE voice_minute_purchases.status END,
                    verified_at = COALESCE(voice_minute_purchases.verified_at, NOW())
                RETURNING id, (xmax = 0) as is_new
            `, [userId, purchaseToken, verification.orderId, MINUTES_PER_PURCHASE, verification.environment]);

            const isNew = insertResult.rows[0]?.is_new;

            if (isNew) {
                // Only credit if this is a new purchase
                await client.query(`
                    UPDATE user_profile
                    SET purchased_voice_minutes = purchased_voice_minutes + $1
                    WHERE id = $2
                `, [MINUTES_PER_PURCHASE, userId]);
            }

            await client.query('COMMIT');

            // 4. Get updated balance
            const balanceResult = await client.query(
                'SELECT purchased_voice_minutes FROM user_profile WHERE id = $1',
                [userId]
            );

            context.res = {
                status: 200,
                body: {
                    success: true,
                    minutesAdded: isNew ? MINUTES_PER_PURCHASE : 0,
                    totalPurchasedMinutes: balanceResult.rows[0]?.purchased_voice_minutes || 0,
                    message: isNew ? '10 voice minutes added to your account' : 'Purchase already credited'
                }
            };

        } catch (dbError) {
            await client.query('ROLLBACK');
            throw dbError;
        } finally {
            client.release();
        }

    } catch (error) {
        context.log.error('voice-purchase error', error);
        context.res = { status: 500, body: { error: 'Purchase processing failed' } };
    } finally {
        await pool.end();
    }
};

async function verifyWithGooglePlay(purchaseToken) {
    try {
        const credentials = JSON.parse(process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY);

        const auth = new google.auth.GoogleAuth({
            credentials,
            scopes: ['https://www.googleapis.com/auth/androidpublisher']
        });

        const androidpublisher = google.androidpublisher({ version: 'v3', auth });

        const response = await androidpublisher.purchases.products.get({
            packageName: PACKAGE_NAME,
            productId: PRODUCT_ID,
            token: purchaseToken
        });

        const purchase = response.data;

        // purchaseState: 0 = Purchased, 1 = Canceled/Refunded
        if (purchase.purchaseState !== 0) {
            return { valid: false, error: 'Purchase was canceled or refunded' };
        }

        // acknowledgementState: 0 = Not acknowledged, 1 = Acknowledged
        // We should acknowledge if not already done
        if (purchase.acknowledgementState === 0) {
            await androidpublisher.purchases.products.acknowledge({
                packageName: PACKAGE_NAME,
                productId: PRODUCT_ID,
                token: purchaseToken
            });
        }

        return {
            valid: true,
            orderId: purchase.orderId,
            environment: purchase.purchaseType === 0 ? 'sandbox' : 'production'
        };

    } catch (error) {
        if (error.code === 404) {
            return { valid: false, error: 'Purchase not found' };
        }
        throw error;
    }
}
```

**File:** `backend/functions/voice-purchase/function.json`

```json
{
  "bindings": [
    {
      "authLevel": "anonymous",
      "type": "httpTrigger",
      "direction": "in",
      "name": "req",
      "methods": ["post"],
      "route": "v1/voice/purchase"
    },
    {
      "type": "http",
      "direction": "out",
      "name": "res"
    }
  ]
}
```

### 2.3 Update Function: `voice/quota`

Update the existing voice quota endpoint to return both subscription and purchased minutes:

```javascript
// Updated response format
const response = {
    subscription: {
        remainingMinutes: user.subscription_voice_minutes || 0,
        totalMinutes: tierLimits[user.tier]?.voiceMinutes || 0,
        resetsAt: user.subscription_period_end
    },
    purchased: {
        remainingMinutes: user.purchased_voice_minutes || 0,
        neverExpires: true
    },
    totalAvailable: (user.subscription_voice_minutes || 0) + (user.purchased_voice_minutes || 0),
    canPurchase: user.tier === 'premium' || user.tier === 'pro'
};
```

### 2.4 Update Function: `voice/usage` - CRITICAL FIX

**Deduction order: Subscription FIRST, then Purchased**

```javascript
async function deductVoiceMinutes(userId, minutesUsed) {
    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        // Get current balances
        const result = await client.query(
            'SELECT subscription_voice_minutes, purchased_voice_minutes FROM user_profile WHERE id = $1 FOR UPDATE',
            [userId]
        );

        const user = result.rows[0];
        let subscriptionMinutes = user.subscription_voice_minutes || 0;
        let purchasedMinutes = user.purchased_voice_minutes || 0;
        let remaining = minutesUsed;

        // DEDUCT FROM SUBSCRIPTION FIRST (they expire monthly anyway)
        if (subscriptionMinutes > 0 && remaining > 0) {
            const fromSubscription = Math.min(remaining, subscriptionMinutes);
            subscriptionMinutes -= fromSubscription;
            remaining -= fromSubscription;
        }

        // THEN FROM PURCHASED (never expire, user paid extra)
        if (purchasedMinutes > 0 && remaining > 0) {
            const fromPurchased = Math.min(remaining, purchasedMinutes);
            purchasedMinutes -= fromPurchased;
            remaining -= fromPurchased;
        }

        if (remaining > 0) {
            await client.query('ROLLBACK');
            return { success: false, error: 'Insufficient minutes' };
        }

        // Update balances
        await client.query(`
            UPDATE user_profile
            SET subscription_voice_minutes = $1, purchased_voice_minutes = $2
            WHERE id = $3
        `, [subscriptionMinutes, purchasedMinutes, userId]);

        await client.query('COMMIT');

        return {
            success: true,
            deductedFromSubscription: (user.subscription_voice_minutes || 0) - subscriptionMinutes,
            deductedFromPurchased: (user.purchased_voice_minutes || 0) - purchasedMinutes
        };

    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
}
```

### 2.5 New Function: `voice-purchase-webhook` (Refund Handling)

For handling Google Play refunds via Real-time Developer Notifications (RTDN).

**File:** `backend/functions/voice-purchase-webhook/index.js`

```javascript
module.exports = async function (context, req) {
    // Google sends a base64-encoded Pub/Sub message
    const message = req.body?.message;
    if (!message?.data) {
        context.res = { status: 400, body: 'Invalid message' };
        return;
    }

    const data = JSON.parse(Buffer.from(message.data, 'base64').toString());

    // Handle voided purchase (refund)
    if (data.voidedPurchaseNotification) {
        const { purchaseToken, orderId } = data.voidedPurchaseNotification;

        await handleRefund(context, purchaseToken, orderId);
    }

    // Acknowledge receipt
    context.res = { status: 200 };
};

async function handleRefund(context, purchaseToken, orderId) {
    const pool = new Pool({ connectionString: process.env.POSTGRES_CONNECTION_STRING });

    try {
        const client = await pool.connect();
        await client.query('BEGIN');

        // Find the purchase
        const result = await client.query(
            'SELECT id, user_id, minutes_credited, status FROM voice_minute_purchases WHERE purchase_token = $1',
            [purchaseToken]
        );

        if (result.rows.length === 0 || result.rows[0].status === 'refunded') {
            await client.query('COMMIT');
            return;
        }

        const purchase = result.rows[0];

        // Revoke minutes
        await client.query(`
            UPDATE user_profile
            SET purchased_voice_minutes = GREATEST(0, purchased_voice_minutes - $1)
            WHERE id = $2
        `, [purchase.minutes_credited, purchase.user_id]);

        // Mark purchase as refunded
        await client.query(`
            UPDATE voice_minute_purchases
            SET status = 'refunded', refunded_at = NOW()
            WHERE id = $1
        `, [purchase.id]);

        await client.query('COMMIT');

        context.log.info('Refund processed', { purchaseId: purchase.id, userId: purchase.user_id });

    } finally {
        await pool.end();
    }
}
```

**Note:** RTDN webhook setup requires configuring Pub/Sub in Google Cloud and pointing it to this endpoint. See [Google's RTDN documentation](https://developer.android.com/google/play/billing/getting-ready#configure-rtdn).

---

## Phase 3: Flutter Implementation

### 3.1 Add Dependencies

**pubspec.yaml:**
```yaml
dependencies:
  in_app_purchase: ^3.1.13
```

```bash
cd mobile/app
flutter pub get
```

**android/app/src/main/AndroidManifest.xml:**
```xml
<uses-permission android:name="com.android.vending.BILLING" />
```

### 3.2 Voice Quota Model

**File:** `lib/src/models/voice_quota.dart`

```dart
class VoiceQuota {
  final SubscriptionQuota subscription;
  final PurchasedQuota purchased;
  final int totalAvailable;
  final bool canPurchase;

  VoiceQuota({
    required this.subscription,
    required this.purchased,
    required this.totalAvailable,
    required this.canPurchase,
  });

  factory VoiceQuota.fromJson(Map<String, dynamic> json) {
    return VoiceQuota(
      subscription: SubscriptionQuota.fromJson(json['subscription']),
      purchased: PurchasedQuota.fromJson(json['purchased']),
      totalAvailable: json['totalAvailable'] ?? 0,
      canPurchase: json['canPurchase'] ?? false,
    );
  }

  bool get isLow => totalAvailable <= 5 && totalAvailable > 0;
  bool get isCritical => totalAvailable <= 2 && totalAvailable > 0;
  bool get isEmpty => totalAvailable == 0;
}

class SubscriptionQuota {
  final int remainingMinutes;
  final int totalMinutes;
  final DateTime? resetsAt;

  SubscriptionQuota({
    required this.remainingMinutes,
    required this.totalMinutes,
    this.resetsAt,
  });

  factory SubscriptionQuota.fromJson(Map<String, dynamic> json) {
    return SubscriptionQuota(
      remainingMinutes: json['remainingMinutes'] ?? 0,
      totalMinutes: json['totalMinutes'] ?? 0,
      resetsAt: json['resetsAt'] != null ? DateTime.parse(json['resetsAt']) : null,
    );
  }
}

class PurchasedQuota {
  final int remainingMinutes;
  final bool neverExpires;

  PurchasedQuota({
    required this.remainingMinutes,
    this.neverExpires = true,
  });

  factory PurchasedQuota.fromJson(Map<String, dynamic> json) {
    return PurchasedQuota(
      remainingMinutes: json['remainingMinutes'] ?? 0,
      neverExpires: json['neverExpires'] ?? true,
    );
  }
}
```

### 3.3 Purchase Service

**File:** `lib/src/services/purchase_service.dart`

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

enum PurchaseStatus {
  idle,
  loading,
  purchasing,
  verifying,
  success,
  cancelled,
  error,
}

class PurchaseResult {
  final PurchaseStatus status;
  final String? message;
  final int? minutesAdded;
  final int? totalMinutes;

  PurchaseResult({
    required this.status,
    this.message,
    this.minutesAdded,
    this.totalMinutes,
  });
}

class PurchaseService {
  static const String voiceMinutesProductId = 'voice_minutes_20';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final _purchaseController = StreamController<PurchaseResult>.broadcast();
  Stream<PurchaseResult> get purchaseStream => _purchaseController.stream;

  Function(PurchaseDetails)? _onPurchaseVerify;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  Future<void> initialize({required Function(PurchaseDetails) onVerify}) async {
    _onPurchaseVerify = onVerify;

    _isAvailable = await _inAppPurchase.isAvailable();
    if (!_isAvailable) {
      debugPrint('In-app purchases not available');
      return;
    }

    _subscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: _onPurchaseError,
    );

    // Check for pending purchases from previous sessions
    await _restorePendingPurchases();
  }

  Future<ProductDetails?> getVoiceMinutesProduct() async {
    if (!_isAvailable) return null;

    final response = await _inAppPurchase.queryProductDetails({voiceMinutesProductId});

    if (response.error != null) {
      debugPrint('Error querying products: ${response.error}');
      return null;
    }

    if (response.productDetails.isEmpty) {
      debugPrint('Product not found: $voiceMinutesProductId');
      return null;
    }

    return response.productDetails.first;
  }

  Future<bool> purchaseVoiceMinutes() async {
    if (!_isAvailable) {
      _purchaseController.add(PurchaseResult(
        status: PurchaseStatus.error,
        message: 'In-app purchases not available',
      ));
      return false;
    }

    _purchaseController.add(PurchaseResult(status: PurchaseStatus.loading));

    final product = await getVoiceMinutesProduct();
    if (product == null) {
      _purchaseController.add(PurchaseResult(
        status: PurchaseStatus.error,
        message: 'Product not available',
      ));
      return false;
    }

    _purchaseController.add(PurchaseResult(status: PurchaseStatus.purchasing));

    final purchaseParam = PurchaseParam(productDetails: product);
    return _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchaseController.add(PurchaseResult(status: PurchaseStatus.purchasing));
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _handleSuccessfulPurchase(purchase);
          break;

        case PurchaseStatus.error:
          _purchaseController.add(PurchaseResult(
            status: PurchaseStatus.error,
            message: purchase.error?.message ?? 'Purchase failed',
          ));
          if (purchase.pendingCompletePurchase) {
            _inAppPurchase.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.canceled:
          _purchaseController.add(PurchaseResult(status: PurchaseStatus.cancelled));
          break;
      }
    }
  }

  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    _purchaseController.add(PurchaseResult(status: PurchaseStatus.verifying));

    try {
      // Call backend to verify and credit
      if (_onPurchaseVerify != null) {
        await _onPurchaseVerify!(purchase);
      }

      // Complete the purchase with Google Play
      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }

    } catch (e) {
      _purchaseController.add(PurchaseResult(
        status: PurchaseStatus.error,
        message: 'Verification failed: $e',
      ));
    }
  }

  void _onPurchaseError(dynamic error) {
    debugPrint('Purchase stream error: $error');
    _purchaseController.add(PurchaseResult(
      status: PurchaseStatus.error,
      message: 'Purchase error: $error',
    ));
  }

  Future<void> _restorePendingPurchases() async {
    // The purchase stream will automatically emit pending purchases
    // when the app starts. No explicit action needed.
  }

  void emitSuccess({required int minutesAdded, required int totalMinutes}) {
    _purchaseController.add(PurchaseResult(
      status: PurchaseStatus.success,
      minutesAdded: minutesAdded,
      totalMinutes: totalMinutes,
      message: '$minutesAdded voice minutes added!',
    ));
  }

  void emitError(String message) {
    _purchaseController.add(PurchaseResult(
      status: PurchaseStatus.error,
      message: message,
    ));
  }

  void dispose() {
    _subscription?.cancel();
    _purchaseController.close();
  }
}
```

### 3.4 Purchase Repository

**File:** `lib/src/repositories/purchase_repository.dart`

```dart
import '../services/backend_service.dart';

class PurchaseRepository {
  final BackendService _backend;

  PurchaseRepository(this._backend);

  Future<PurchaseVerificationResult> verifyPurchase({
    required String purchaseToken,
    required String productId,
  }) async {
    final response = await _backend.post(
      '/v1/voice/purchase',
      body: {
        'purchaseToken': purchaseToken,
        'productId': productId,
      },
    );

    return PurchaseVerificationResult.fromJson(response);
  }
}

class PurchaseVerificationResult {
  final bool success;
  final int minutesAdded;
  final int totalPurchasedMinutes;
  final String? message;
  final String? error;

  PurchaseVerificationResult({
    required this.success,
    this.minutesAdded = 0,
    this.totalPurchasedMinutes = 0,
    this.message,
    this.error,
  });

  factory PurchaseVerificationResult.fromJson(Map<String, dynamic> json) {
    return PurchaseVerificationResult(
      success: json['success'] ?? false,
      minutesAdded: json['minutesAdded'] ?? 0,
      totalPurchasedMinutes: json['totalPurchasedMinutes'] ?? 0,
      message: json['message'],
      error: json['error'],
    );
  }
}
```

### 3.5 Purchase Provider

**File:** `lib/src/providers/purchase_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/purchase_service.dart';
import '../repositories/purchase_repository.dart';

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final service = PurchaseService();
  ref.onDispose(() => service.dispose());
  return service;
});

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  final backend = ref.watch(backendServiceProvider);
  return PurchaseRepository(backend);
});

final voiceMinutesProductProvider = FutureProvider<ProductDetails?>((ref) async {
  final service = ref.watch(purchaseServiceProvider);
  if (!service.isAvailable) return null;
  return service.getVoiceMinutesProduct();
});

final purchaseStreamProvider = StreamProvider<PurchaseResult>((ref) {
  final service = ref.watch(purchaseServiceProvider);
  return service.purchaseStream;
});

// Initialize purchase service with verification callback
Future<void> initializePurchaseService(WidgetRef ref) async {
  final purchaseService = ref.read(purchaseServiceProvider);
  final purchaseRepo = ref.read(purchaseRepositoryProvider);

  await purchaseService.initialize(
    onVerify: (purchase) async {
      final result = await purchaseRepo.verifyPurchase(
        purchaseToken: purchase.verificationData.serverVerificationData,
        productId: purchase.productID,
      );

      if (result.success) {
        purchaseService.emitSuccess(
          minutesAdded: result.minutesAdded,
          totalMinutes: result.totalPurchasedMinutes,
        );
      } else {
        purchaseService.emitError(result.error ?? 'Verification failed');
      }
    },
  );
}
```

### 3.6 Voice Quota Provider Update

**File:** Update `lib/src/providers/voice_provider.dart`

```dart
final voiceQuotaProvider = FutureProvider<VoiceQuota>((ref) async {
  final backend = ref.watch(backendServiceProvider);
  final response = await backend.get('/v1/voice/quota');
  return VoiceQuota.fromJson(response);
});

// Convenience provider for checking if purchase is needed
final needsVoicePurchaseProvider = Provider<bool>((ref) {
  final quotaAsync = ref.watch(voiceQuotaProvider);
  return quotaAsync.when(
    data: (quota) => quota.isEmpty && quota.canPurchase,
    loading: () => false,
    error: (_, __) => false,
  );
});
```

---

## Phase 4: Flutter UI

### 4.1 Low Minutes Warning Widget

**File:** `lib/src/widgets/voice_minutes_warning.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/voice_quota.dart';
import '../providers/purchase_provider.dart';

class VoiceMinutesWarning extends ConsumerWidget {
  final VoiceQuota quota;
  final VoidCallback? onPurchase;

  const VoiceMinutesWarning({
    super.key,
    required this.quota,
    this.onPurchase,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!quota.canPurchase) return const SizedBox.shrink();

    // Different styling based on urgency
    final Color backgroundColor;
    final Color iconColor;
    final IconData icon;
    final String message;

    if (quota.isEmpty) {
      backgroundColor = Colors.red.shade50;
      iconColor = Colors.red;
      icon = Icons.mic_off;
      message = "You're out of voice minutes!";
    } else if (quota.isCritical) {
      backgroundColor = Colors.orange.shade50;
      iconColor = Colors.orange;
      icon = Icons.warning_amber;
      message = "Only ${quota.totalAvailable} minutes remaining";
    } else if (quota.isLow) {
      backgroundColor = Colors.amber.shade50;
      iconColor = Colors.amber.shade700;
      icon = Icons.info_outline;
      message = "Running low: ${quota.totalAvailable} minutes left";
    } else {
      return const SizedBox.shrink();
    }

    final product = ref.watch(voiceMinutesProductProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: iconColor.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          product.when(
            data: (productDetails) => ElevatedButton.icon(
              onPressed: onPurchase,
              icon: const Icon(Icons.add),
              label: Text(
                productDetails != null
                    ? 'Get 10 minutes - ${productDetails.price}'
                    : 'Get 10 minutes - \$4.99',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => ElevatedButton.icon(
              onPressed: onPurchase,
              icon: const Icon(Icons.add),
              label: const Text('Get 10 minutes - \$4.99'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          if (quota.subscription.resetsAt != null && !quota.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Subscription resets ${_formatResetDate(quota.subscription.resetsAt!)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatResetDate(DateTime date) {
    final days = date.difference(DateTime.now()).inDays;
    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    return 'in $days days';
  }
}
```

### 4.2 Purchase Success Dialog

**File:** `lib/src/widgets/purchase_success_dialog.dart`

```dart
import 'package:flutter/material.dart';

class PurchaseSuccessDialog extends StatelessWidget {
  final int minutesAdded;
  final int totalMinutes;
  final VoidCallback? onStartSession;
  final VoidCallback? onDismiss;

  const PurchaseSuccessDialog({
    super.key,
    required this.minutesAdded,
    required this.totalMinutes,
    this.onStartSession,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Success!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$minutesAdded minutes added',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'You now have $totalMinutes minutes available',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onDismiss?.call();
          },
          child: const Text('Done'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            onStartSession?.call();
          },
          icon: const Icon(Icons.mic),
          label: const Text('Start Voice Session'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
```

### 4.3 Voice Bartender Screen Updates

Update `voice_bartender_screen.dart` to integrate purchase flow:

```dart
// In build method, listen to purchase stream
ref.listen<AsyncValue<PurchaseResult>>(purchaseStreamProvider, (prev, next) {
  next.whenData((result) {
    switch (result.status) {
      case PurchaseStatus.success:
        // Refresh quota
        ref.invalidate(voiceQuotaProvider);
        // Show success dialog
        showDialog(
          context: context,
          builder: (_) => PurchaseSuccessDialog(
            minutesAdded: result.minutesAdded ?? 10,
            totalMinutes: result.totalMinutes ?? 10,
            onStartSession: _startVoiceSession,
          ),
        );
        break;
      case PurchaseStatus.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Purchase failed'),
            backgroundColor: Colors.red,
          ),
        );
        break;
      case PurchaseStatus.cancelled:
        // User cancelled, no action needed
        break;
      default:
        break;
    }
  });
});

// Show warning when minutes are low
final quota = ref.watch(voiceQuotaProvider);
quota.when(
  data: (q) => VoiceMinutesWarning(
    quota: q,
    onPurchase: () => ref.read(purchaseServiceProvider).purchaseVoiceMinutes(),
  ),
  loading: () => const SizedBox.shrink(),
  error: (_, __) => const SizedBox.shrink(),
);
```

---

## Phase 5: Testing

### 5.1 Test Environment Setup

1. **Upload APK to Internal Test Track**
   - Build release APK: `flutter build apk --release`
   - Upload to Play Console → Testing → Internal testing
   - Create a release and roll out

2. **Add License Testers**
   - Play Console → Settings → License testing
   - Add your Google account email
   - Purchases made by these accounts won't be charged

3. **Wait for Product Availability**
   - After activating IAP product, wait 1-2 hours
   - Product must propagate to Google's servers

### 5.2 Test Scenarios

| # | Scenario | Expected Result |
|---|----------|-----------------|
| 1 | Happy path purchase | Minutes credited, success dialog shown |
| 2 | User cancels in Play UI | State returns to idle, no error shown |
| 3 | Network fails during verify | Error shown, can retry |
| 4 | Same token sent twice | Second call returns success (idempotent) |
| 5 | Invalid/fake token | Error logged, user sees "Purchase failed" |
| 6 | Backend down during verify | Error shown, purchase pending |
| 7 | App killed mid-purchase | Recovered on next app start |
| 8 | Free user tries to purchase | Button not shown, upgrade CTA shown |
| 9 | Premium user purchases | Works correctly |
| 10 | Pro user purchases | Works correctly |
| 11 | Price localization | Shows correct currency for region |
| 12 | Rapid double-tap purchase | Only one purchase processed |
| 13 | 5 minutes remaining | Low warning shown |
| 14 | 2 minutes remaining | Critical warning shown |
| 15 | 0 minutes remaining | Empty state with purchase CTA |

### 5.3 Automated Tests

```dart
// test/services/purchase_service_test.dart
void main() {
  group('PurchaseService', () {
    test('emits loading state when purchase initiated', () async {
      // ...
    });

    test('handles cancelled purchase correctly', () async {
      // ...
    });
  });
}

// test/deduction_logic_test.dart
void main() {
  group('Voice minute deduction', () {
    test('deducts from subscription first', () {
      // Given: 10 subscription + 5 purchased
      // When: Use 8 minutes
      // Then: 2 subscription + 5 purchased remain
    });

    test('uses purchased after subscription depleted', () {
      // Given: 3 subscription + 10 purchased
      // When: Use 8 minutes
      // Then: 0 subscription + 5 purchased remain
    });

    test('fails if insufficient total minutes', () {
      // Given: 3 subscription + 2 purchased
      // When: Use 10 minutes
      // Then: Error, balances unchanged
    });
  });
}
```

---

## Phase 6: APIM Configuration

Add the new endpoint to API Management.

### 6.1 Import Operation

```bash
# Add voice-purchase operation to existing API
az apim api operation create \
  --resource-group rg-mba-prod \
  --service-name apim-mba-002 \
  --api-id mybartenderai-api \
  --operation-id voice-purchase \
  --display-name "Purchase Voice Minutes" \
  --method POST \
  --url-template "/v1/voice/purchase"
```

### 6.2 Apply JWT Policy

The operation should use the same JWT validation policy as other authenticated endpoints.

---

## Implementation Summary

### Effort Estimates

| Phase | Tasks | Estimated Hours |
|-------|-------|-----------------|
| Phase 1 | Infrastructure setup | 3-4 hours |
| Phase 2 | Backend implementation | 5-6 hours |
| Phase 3 | Flutter core | 4-5 hours |
| Phase 4 | Flutter UI | 3-4 hours |
| Phase 5 | Testing | 3-4 hours |
| Phase 6 | APIM config | 0.5 hours |
| **Total** | | **18-24 hours** |

### Dependencies Graph

```
Phase 1 (all parallel)
├── 1.1 Play Console IAP ──────┐
├── 1.2 Service Account ───────┼──► Phase 2.2 (voice-purchase)
├── 1.3 Play Console Access ───┤
├── 1.4 Key Vault ─────────────┘
└── 1.5 Database ──────────────────► Phase 2.3, 2.4

Phase 2 (sequential)
2.1 npm install ──► 2.2 voice-purchase ──► 2.3 quota ──► 2.4 usage

Phase 3 (sequential, after Phase 2)
3.1 pub get ──► 3.2 service ──► 3.3 repo ──► 3.4 provider

Phase 4 (after Phase 3)
4.1 warning widget ─┬─► 4.3 screen integration
4.2 success dialog ─┘

Phase 5 (after Phase 4)
```

### Risk Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Google Play Console unfamiliar | High | Medium | Follow Google's codelab step-by-step |
| Service Account setup issues | Medium | High | Document every step, test with curl first |
| Purchase verification async complexity | Medium | High | Comprehensive logging, retry mechanisms |
| Race condition bugs | Low | High | Database-level locking, idempotent operations |

---

## Future Enhancements (Phase 2)

- **Bundle discounts:** 30 minutes for $12.99 (save $2)
- **Subscription upsell:** "Upgrade to Pro and get 45 min/month" prompt after 3 purchases
- **Purchase history:** View past purchases in Profile screen
- **Analytics:** Track conversion rates, average purchases per user
- **iOS support:** StoreKit integration when iOS app launches

---

## Related Documentation

- [PRD.md](PRD.md) - Product requirements (Section 7: Voice AI Purchase Option)
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [VOICE_AI_DEPLOYED.md](VOICE_AI_DEPLOYED.md) - Voice AI implementation details
- [Google Play Billing](https://developer.android.com/google/play/billing) - Official documentation

---

**Last Updated:** December 22, 2025
