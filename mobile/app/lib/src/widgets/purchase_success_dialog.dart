import 'package:flutter/material.dart';

/// Dialog displayed after a successful voice minutes purchase
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

  /// Show the success dialog
  static Future<void> show(
    BuildContext context, {
    required int minutesAdded,
    required int totalMinutes,
    VoidCallback? onStartSession,
    VoidCallback? onDismiss,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PurchaseSuccessDialog(
        minutesAdded: minutesAdded,
        totalMinutes: totalMinutes,
        onStartSession: onStartSession,
        onDismiss: onDismiss,
      ),
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
          // Success icon with subtle animation would be nice
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              color: Colors.green.shade600,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You now have $totalMinutes minutes available',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Highlight that purchased minutes don't expire
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.all_inclusive, size: 14, color: Colors.blue.shade700),
                const SizedBox(width: 4),
                Text(
                  'Purchased minutes never expire',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
          icon: const Icon(Icons.mic, size: 18),
          label: const Text('Start Voice Session'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    );
  }
}

/// Snackbar helper for purchase notifications
class PurchaseSnackbars {
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void showCancelled(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('Purchase cancelled'),
          ],
        ),
        backgroundColor: Colors.grey.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void showVerifying(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Verifying purchase...'),
          ],
        ),
        duration: Duration(seconds: 30), // Will be dismissed when verification completes
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
