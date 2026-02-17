import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// Pre-prompt dialog: "Are you enjoying My AI Bartender?"
///
/// Returns `true` if the user taps "Yes!", `false` if "Not really",
/// or `null` if dismissed without choosing.
///
/// Follows the [PurchaseSuccessDialog] pattern (static `show()` method,
/// `AlertDialog` with rounded corners).
class ReviewPromptDialog extends StatelessWidget {
  const ReviewPromptDialog({super.key});

  /// Show the review pre-prompt dialog.
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ReviewPromptDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_bar,
              color: AppColors.primaryPurple,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Are you enjoying\nMy AI Bartender?',
            style: AppTypography.heading3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your feedback helps us improve!',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Not really',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: Colors.white,
          ),
          child: const Text('Yes!'),
        ),
      ],
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    );
  }
}
