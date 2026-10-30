import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Google Analytics for Firebase: the conversion events Google Ads App
/// campaigns import and optimize on. See docs/GOOGLE_ADS_CONVERSION_TRACKING.md
/// for the event list and the console steps (Firebase, Google Ads, Play).
///
/// Every call is fire-and-forget and never throws: analytics must not break a
/// purchase, sign-in or any other user flow. Until Firebase is configured
/// (no `android/app/google-services.json`), [initialize] fails quietly and
/// every log call is a no-op.
///
/// Android only for now. iOS stays off until `GoogleService-Info.plist` is
/// added and the App Store privacy label is updated (see the doc).
///
/// Event names are a contract with the Google Ads conversion actions imported
/// from them. Renaming one silently stops that conversion, so don't.
class AnalyticsService {
  AnalyticsService._internal();
  static final AnalyticsService instance = AnalyticsService._internal();

  // Custom event names (GA4 recommended names are used where one fits).
  static const String eventPaywallView = 'paywall_view';
  static const String eventTrialStart = 'trial_start';
  static const String eventAiChatReply = 'ai_chat_reply';
  static const String eventBarScanComplete = 'bar_scan_complete';
  static const String eventVoiceSessionComplete = 'voice_session_complete';
  static const String eventRecipeCreated = 'recipe_created';

  static const String _signUpLoggedKey = 'analytics_sign_up_logged';
  static const String _signInMethod = 'entra_external_id';

  FirebaseAnalytics? _analytics;

  bool get isEnabled => _analytics != null;

  /// Initialize Firebase. Call once from bootstrap, before runApp().
  Future<void> initialize() async {
    if (_analytics != null) return;
    if (!Platform.isAndroid) {
      debugPrint('[Analytics] Disabled on this platform');
      return;
    }
    try {
      await Firebase.initializeApp();
      _analytics = FirebaseAnalytics.instance;
      debugPrint('[Analytics] Firebase Analytics initialized');
    } catch (e) {
      // Expected until google-services.json is added to android/app/.
      debugPrint('[Analytics] Firebase not configured, analytics disabled: $e');
    }
  }

  /// The GA4 app instance ID, for RevenueCat's Google Analytics integration.
  Future<String?> get appInstanceId async {
    final analytics = _analytics;
    if (analytics == null) return null;
    try {
      return await analytics.appInstanceId;
    } catch (e) {
      debugPrint('[Analytics] appInstanceId failed: $e');
      return null;
    }
  }

  /// Interactive sign-in (`login`), plus `sign_up` the first time on this
  /// install. Entra External ID uses one flow for sign-up and sign-in (with
  /// the 21+ check inside it), so the app can't tell a new account from a
  /// returning one: `sign_up` means "first sign-in on this install", which for
  /// a user fresh from an ad is the sign-up.
  Future<void> logSignIn() async {
    await _log(() => _analytics!.logLogin(loginMethod: _signInMethod));
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_signUpLoggedKey) ?? false) return;
      await prefs.setBool(_signUpLoggedKey, true);
      await _log(() => _analytics!.logSignUp(signUpMethod: _signInMethod));
    } catch (e) {
      debugPrint('[Analytics] sign_up failed: $e');
    }
  }

  Future<void> logPaywallView({required bool trialEligible}) =>
      _logEvent(eventPaywallView, {'trial_eligible': trialEligible ? 1 : 0});

  /// Logs [eventTrialStart] when a paywall purchase started a free trial.
  ///
  /// Paid purchases are not logged here: the Firebase SDK collects
  /// `in_app_purchase` (with price) for Play purchases automatically, and a
  /// manual event would double count them.
  Future<void> logSubscriptionPurchase({
    required Package package,
    required CustomerInfo customerInfo,
    required String entitlementId,
  }) async {
    final entitlement = customerInfo.entitlements.active[entitlementId];
    if (entitlement == null || entitlement.periodType != PeriodType.trial) {
      return;
    }
    final product = package.storeProduct;
    // No `value`: a trial earns nothing until it converts. Give the Google
    // Ads conversion action a static value instead (see the doc).
    await _logEvent(eventTrialStart, {
      'plan': package.packageType.name,
      'product_id': product.identifier,
      'currency': product.currencyCode,
      'price': product.price,
    });
  }

  Future<void> logAiChatReply() => _logEvent(eventAiChatReply);

  Future<void> logBarScanComplete({required int itemsAdded}) =>
      _logEvent(eventBarScanComplete, {'items_added': itemsAdded});

  Future<void> logVoiceSessionComplete({required int durationSeconds}) =>
      _logEvent(eventVoiceSessionComplete, {'duration_sec': durationSeconds});

  Future<void> logRecipeCreated() => _logEvent(eventRecipeCreated);

  Future<void> logRecipeShared({required String cocktailId}) => _log(() =>
      _analytics!.logShare(
          contentType: 'recipe', itemId: cocktailId, method: 'share_sheet'));

  /// Clears this install's analytics data (app instance ID) after account
  /// deletion, so later events are not tied to the deleted user.
  Future<void> resetAfterAccountDeletion() =>
      _log(() => _analytics!.resetAnalyticsData());

  Future<void> _logEvent(String name, [Map<String, Object>? parameters]) =>
      _log(() => _analytics!.logEvent(name: name, parameters: parameters));

  Future<void> _log(Future<void> Function() call) async {
    if (_analytics == null) return;
    try {
      await call();
    } catch (e) {
      debugPrint('[Analytics] Event failed: $e');
    }
  }
}
