import 'package:flutter/material.dart';

import '../models/user.dart';
import '../theme/theme.dart';

/// Dialog shown when the user needs to re-authenticate after token expiration.
///
/// This provides a friendly "Welcome back" experience instead of just
/// showing the login screen. If we know the user's name/email from the
/// last session, we show it to provide context.
class WelcomeBackDialog extends StatelessWidget {
  final User? lastKnownUser;
  final VoidCallback onContinue;
  final VoidCallback? onSwitchAccount;

  const WelcomeBackDialog({
    super.key,
    this.lastKnownUser,
    required this.onContinue,
    this.onSwitchAccount,
  });

  @override
  Widget build(BuildContext context) {
    final greeting = _buildGreeting();
    final initial = lastKnownUser?.displayName?.substring(0, 1).toUpperCase() ??
        lastKnownUser?.givenName?.substring(0, 1).toUpperCase() ??
        'M';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User avatar with initial
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentBlue,
                  width: 3,
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentBlue,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Greeting text
            Text(
              greeting,
              style: AppTypography.heading3.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Email hint if available
            if (lastKnownUser?.email != null) ...[
              Text(
                lastKnownUser!.email!,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],

            // Explanation text
            Text(
              'Tap below to continue where you left off.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Continue button (prominent)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Switch account option (subtle)
            if (onSwitchAccount != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onSwitchAccount,
                child: Text(
                  'Use a different account',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _buildGreeting() {
    final name = lastKnownUser?.givenName ?? lastKnownUser?.displayName;
    if (name != null && name.isNotEmpty) {
      return 'Welcome back, $name!';
    }
    return 'Welcome back!';
  }

  /// Show the dialog and return the result.
  ///
  /// Returns true if user tapped Continue, false if Switch Account, null if dismissed.
  static Future<bool?> show(
    BuildContext context, {
    User? lastKnownUser,
    VoidCallback? onContinue,
    VoidCallback? onSwitchAccount,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Force user to make a choice
      builder: (context) => WelcomeBackDialog(
        lastKnownUser: lastKnownUser,
        onContinue: () {
          Navigator.of(context).pop(true);
          onContinue?.call();
        },
        onSwitchAccount: () {
          Navigator.of(context).pop(false);
          onSwitchAccount?.call();
        },
      ),
    );
  }
}
