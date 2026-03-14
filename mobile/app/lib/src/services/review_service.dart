import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/review_prompt_dialog.dart';

/// Types of win moments that qualify the user for a review prompt.
enum WinMomentType {
  scannerSuccess,
  createStudioSave,
  sharingSuccess,
  favoritesThreshold,
  aiChatSave,
  voiceSessionComplete,
  recipeDetailView,
  canMakeFilterUsed,
  academyLessonComplete,
}

/// Types of unhappy signals that delay review prompts.
enum UnhappySignalType {
  thumbsDown,
  apiErrors,
  paywallAbandonment,
  quotaBlocked,
}

/// Service for managing in-app review prompts.
///
/// Follows the singleton pattern used by [UserSettingsService].
/// Registers as a [WidgetsBindingObserver] to track app sessions
/// independently from [AppLifecycleService].
class ReviewService with WidgetsBindingObserver {
  ReviewService._internal();
  static final ReviewService instance = ReviewService._internal();

  // SharedPreferences keys
  static const String _totalSessionsKey = 'review_total_sessions';
  static const String _firstSessionDateKey = 'review_first_session_date';
  static const String _lastSessionStartKey = 'review_last_session_start';
  static const String _lastPromptAtKey = 'review_last_prompt_at';
  static const String _lifetimePromptsKey = 'review_lifetime_prompts';
  static const String _lastUnhappyAtKey = 'review_last_unhappy_at';
  static const String _winMomentsKey = 'review_win_moments';
  static const String _pendingPromptKey = 'review_pending_prompt';

  // Thresholds
  static const int _minSessions = 2;
  static const int _minDistinctDays = 1; // difference in days from first session
  static const Duration _sessionDebounce = Duration(minutes: 30);
  static const Duration _promptCooldown = Duration(days: 30);
  static const Duration _unhappyCooldown = Duration(days: 60);
  static const int _maxLifetimePrompts = 3;
  static const int _favoritesThreshold = 3;

  bool _isObserving = false;

  /// Initialize the service and start observing app lifecycle.
  void initialize() {
    if (!_isObserving) {
      WidgetsBinding.instance.addObserver(this);
      _isObserving = true;
      _log('Initialized, observing app lifecycle');
      // Record first session on init
      recordSessionStart();
    }
  }

  /// Clean up the observer when no longer needed.
  void dispose() {
    if (_isObserving) {
      WidgetsBinding.instance.removeObserver(this);
      _isObserving = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      recordSessionStart();
    }
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Record a session start (debounced to 30 minutes).
  Future<void> recordSessionStart() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // Check debounce
    final lastStartStr = prefs.getString(_lastSessionStartKey);
    if (lastStartStr != null) {
      final lastStart = DateTime.tryParse(lastStartStr);
      if (lastStart != null && now.difference(lastStart) < _sessionDebounce) {
        return; // Too soon, skip
      }
    }

    // First session ever — set first session date
    if (!prefs.containsKey(_firstSessionDateKey)) {
      await prefs.setString(_firstSessionDateKey, now.toIso8601String());
    }

    // Increment session count
    final totalSessions = (prefs.getInt(_totalSessionsKey) ?? 0) + 1;
    await prefs.setInt(_totalSessionsKey, totalSessions);
    await prefs.setString(_lastSessionStartKey, now.toIso8601String());

    final firstDateStr = prefs.getString(_firstSessionDateKey);
    final distinctDays = firstDateStr != null
        ? now.difference(DateTime.parse(firstDateStr)).inDays
        : 0;

    _log('Session recorded: total=$totalSessions, distinct_days=$distinctDays');
  }

  /// Record a win moment (e.g., scanner success, create studio save).
  Future<void> recordWinMoment(WinMomentType type) async {
    final prefs = await SharedPreferences.getInstance();
    final moments = _getWinMoments(prefs);

    if (!moments.contains(type.name)) {
      moments.add(type.name);
      await prefs.setString(_winMomentsKey, jsonEncode(moments));
      _log('Win moment recorded: type=${type.name}');
    }
  }

  /// Mark that a review prompt should be shown at the next safe opportunity.
  /// Used by triggers in providers/dispose where no BuildContext is available,
  /// or by triggers that navigate away (Navigator.pop) immediately after.
  Future<void> setPendingPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingPromptKey, true);
    _log('Pending prompt flag set');
  }

  /// Check and consume the pending prompt flag.
  /// Call from a screen with a stable BuildContext (e.g., HomeScreen).
  /// Returns true if a prompt was shown.
  Future<bool> checkPendingPrompt(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(_pendingPromptKey) ?? false;
    if (!pending) return false;

    // Clear the flag first (even if prompt doesn't show, don't retry endlessly)
    await prefs.setBool(_pendingPromptKey, false);
    _log('Pending prompt flag consumed');

    if (!context.mounted) return false;
    return maybePromptForReview(context, reason: 'deferred');
  }

  /// Record an unhappy signal (delays future review prompts by 60 days).
  Future<void> recordUnhappySignal(UnhappySignalType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastUnhappyAtKey, DateTime.now().toIso8601String());
    _log('Unhappy signal recorded: type=${type.name}');
  }

  /// Check eligibility and show the pre-prompt dialog if conditions are met.
  ///
  /// Returns `true` if the dialog was shown, `false` otherwise.
  Future<bool> maybePromptForReview(BuildContext context, {String? reason}) async {
    final eligible = await isEligible();
    if (!eligible) return false;

    if (!context.mounted) return false;

    _log('Pre-prompt shown');
    final userSaidYes = await ReviewPromptDialog.show(context);

    if (userSaidYes == true) {
      _log('User response: yes');
      await _requestOsReview();
    } else if (userSaidYes == false) {
      _log('User response: not_really');
      await _openFeedbackEmail();
      // Treat "Not really" as a mild unhappy signal
      await recordUnhappySignal(UnhappySignalType.thumbsDown);
    }
    // null means dialog was dismissed without choosing

    // Record that we prompted
    final prefs = await SharedPreferences.getInstance();
    final lifetimePrompts = (prefs.getInt(_lifetimePromptsKey) ?? 0) + 1;
    await prefs.setInt(_lifetimePromptsKey, lifetimePrompts);
    await prefs.setString(_lastPromptAtKey, DateTime.now().toIso8601String());

    return true;
  }

  /// Check if the user meets all eligibility conditions for a review prompt.
  Future<bool> isEligible() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // 1. >= 2 sessions
    final totalSessions = prefs.getInt(_totalSessionsKey) ?? 0;
    if (totalSessions < _minSessions) {
      _log('Eligibility check: eligible=false, reason=sessions($totalSessions < $_minSessions)');
      return false;
    }

    // 2. >= 2 distinct calendar days
    final firstDateStr = prefs.getString(_firstSessionDateKey);
    if (firstDateStr != null) {
      final firstDate = DateTime.parse(firstDateStr);
      if (now.difference(firstDate).inDays < _minDistinctDays) {
        _log('Eligibility check: eligible=false, reason=distinct_days');
        return false;
      }
    } else {
      _log('Eligibility check: eligible=false, reason=no_first_session');
      return false;
    }

    // 3. >= 1 win moment
    final moments = _getWinMoments(prefs);
    if (moments.isEmpty) {
      _log('Eligibility check: eligible=false, reason=no_win_moments');
      return false;
    }

    // 4. Lifetime prompts <= 3
    final lifetimePrompts = prefs.getInt(_lifetimePromptsKey) ?? 0;
    if (lifetimePrompts >= _maxLifetimePrompts) {
      _log('Eligibility check: eligible=false, reason=lifetime_cap($lifetimePrompts)');
      return false;
    }

    // 5. 30-day cooldown since last prompt
    final lastPromptStr = prefs.getString(_lastPromptAtKey);
    if (lastPromptStr != null) {
      final lastPrompt = DateTime.parse(lastPromptStr);
      if (now.difference(lastPrompt) < _promptCooldown) {
        _log('Eligibility check: eligible=false, reason=prompt_cooldown');
        return false;
      }
    }

    // 6. 60-day cooldown after unhappy signal
    final lastUnhappyStr = prefs.getString(_lastUnhappyAtKey);
    if (lastUnhappyStr != null) {
      final lastUnhappy = DateTime.parse(lastUnhappyStr);
      if (now.difference(lastUnhappy) < _unhappyCooldown) {
        _log('Eligibility check: eligible=false, reason=unhappy_cooldown');
        return false;
      }
    }

    _log('Eligibility check: eligible=true');
    return true;
  }

  /// The minimum number of favorites required to trigger the win moment.
  int get favoritesThreshold => _favoritesThreshold;

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  List<String> _getWinMoments(SharedPreferences prefs) {
    final json = prefs.getString(_winMomentsKey);
    if (json == null) return [];
    try {
      return List<String>.from(jsonDecode(json) as List);
    } catch (_) {
      return [];
    }
  }

  Future<void> _requestOsReview() async {
    _log('OS review dialog requested');
    final inAppReview = InAppReview.instance;
    if (await inAppReview.isAvailable()) {
      await inAppReview.requestReview();
    } else {
      // Fall back to opening the store listing
      await inAppReview.openStoreListing(
        appStoreId: '6758023541',
      );
    }
  }

  Future<void> _openFeedbackEmail() async {
    _log('Feedback email opened');
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@xtend-ai.com',
      queryParameters: {
        'subject': 'My AI Bartender Feedback',
      },
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  void _log(String message) {
    developer.log('[REVIEW] $message', name: 'ReviewService');
  }

  /// Clear all review state (useful for testing or account reset).
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_totalSessionsKey);
    await prefs.remove(_firstSessionDateKey);
    await prefs.remove(_lastSessionStartKey);
    await prefs.remove(_lastPromptAtKey);
    await prefs.remove(_lifetimePromptsKey);
    await prefs.remove(_lastUnhappyAtKey);
    await prefs.remove(_winMomentsKey);
    await prefs.remove(_pendingPromptKey);
  }
}
