import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage battery optimization exemption for background token refresh.
///
/// Android OEMs (Samsung, Xiaomi, Huawei, etc.) aggressively kill background processes
/// to save battery. This service requests exemption from battery optimization to ensure
/// the background token refresh task runs reliably.
///
/// Without this exemption, the WorkManager background task may be delayed or killed,
/// causing the Entra External ID refresh token to expire after 12 hours of inactivity.
class BatteryOptimizationService {
  static final BatteryOptimizationService _instance =
      BatteryOptimizationService._internal();
  factory BatteryOptimizationService() => _instance;
  BatteryOptimizationService._internal();

  static BatteryOptimizationService get instance => _instance;

  // SharedPreferences key to track if we've shown the dialog
  static const String _hasShownDialogKey = 'battery_optimization_dialog_shown';

  /// Check if battery optimization is disabled for this app
  Future<bool> isOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;

    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      return status.isGranted;
    } catch (e) {
      if (kDebugMode) {
        print('[BATTERY-OPT] Error checking status: $e');
      }
      return false;
    }
  }

  /// Request battery optimization exemption (opens system settings dialog)
  Future<bool> requestOptimizationExemption() async {
    if (!Platform.isAndroid) return true;

    try {
      if (kDebugMode) {
        print('[BATTERY-OPT] Requesting battery optimization exemption...');
      }
      final status = await Permission.ignoreBatteryOptimizations.request();
      if (kDebugMode) {
        print('[BATTERY-OPT] Permission result: $status');
      }
      return status.isGranted;
    } catch (e) {
      if (kDebugMode) {
        print('[BATTERY-OPT] Error requesting exemption: $e');
      }
      return false;
    }
  }

  /// Check if we've already shown the dialog to the user
  Future<bool> hasShownDialog() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasShownDialogKey) ?? false;
  }

  /// Mark that we've shown the dialog
  Future<void> markDialogShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasShownDialogKey, true);
  }

  /// Show explanation dialog and request exemption if needed.
  ///
  /// Returns true if:
  /// - Already exempt
  /// - User granted exemption
  /// - Not on Android
  ///
  /// Returns false if user declined.
  ///
  /// Only shows the dialog once per installation (respects user's choice).
  Future<bool> showExemptionDialogIfNeeded(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    // Check if already exempt
    if (await isOptimizationDisabled()) {
      if (kDebugMode) {
        print('[BATTERY-OPT] Already exempt from battery optimization');
      }
      return true;
    }

    // Check if we've already shown the dialog (respect user's previous choice)
    if (await hasShownDialog()) {
      if (kDebugMode) {
        print('[BATTERY-OPT] Dialog already shown previously, not prompting again');
      }
      return false;
    }

    // Show explanation dialog
    final shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Stay Signed In'),
        content: const Text(
          'To keep you signed in automatically, My AI Bartender needs '
          'permission to run briefly in the background.\n\n'
          'This uses minimal battery and only runs when needed to keep '
          'your session active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    // Mark that we've shown the dialog
    await markDialogShown();

    if (shouldRequest == true) {
      return await requestOptimizationExemption();
    }

    return false;
  }

  /// Force show the dialog (for settings screen, ignores hasShownDialog flag)
  Future<bool> forceShowExemptionDialog(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    // Check if already exempt
    if (await isOptimizationDisabled()) {
      // Show a different message if already exempt
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Background sync is already enabled'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    }

    return await requestOptimizationExemption();
  }

  /// Reset the dialog shown flag (for testing)
  Future<void> resetDialogShownFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hasShownDialogKey);
    if (kDebugMode) {
      print('[BATTERY-OPT] Dialog shown flag reset');
    }
  }
}
