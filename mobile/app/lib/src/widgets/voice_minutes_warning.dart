import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/voice_ai_service.dart';
import '../providers/purchase_provider.dart';

/// Warning widget displayed when voice minutes are low or exhausted
///
/// Shows different states:
/// - Empty (0 minutes): Red warning with purchase CTA
/// - Critical (1-2 minutes): Orange warning with purchase suggestion
/// - Low (3-5 minutes): Amber info with optional purchase
class VoiceMinutesWarning extends ConsumerWidget {
  final VoiceQuota quota;
  final VoidCallback? onPurchase;
  final bool compact;

  const VoiceMinutesWarning({
    super.key,
    required this.quota,
    this.onPurchase,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only show for Premium and Pro tiers
    if (quota.tier != 'premium' && quota.tier != 'pro') {
      return const SizedBox.shrink();
    }

    // Determine warning level and styling
    final WarningLevel level = _getWarningLevel();
    if (level == WarningLevel.none) {
      return const SizedBox.shrink();
    }

    final styling = _getStyling(level);
    final product = ref.watch(voiceMinutesProductProvider);

    if (compact) {
      return _buildCompactWarning(context, styling, product);
    }

    return _buildFullWarning(context, styling, product);
  }

  WarningLevel _getWarningLevel() {
    final totalMinutes = quota.remainingMinutes + (quota.addonSecondsRemaining ~/ 60);

    if (totalMinutes == 0) return WarningLevel.empty;
    if (totalMinutes <= 2) return WarningLevel.critical;
    if (totalMinutes <= 5) return WarningLevel.low;
    return WarningLevel.none;
  }

  _WarningStyling _getStyling(WarningLevel level) {
    switch (level) {
      case WarningLevel.empty:
        return _WarningStyling(
          backgroundColor: Colors.red.shade50,
          borderColor: Colors.red.shade200,
          iconColor: Colors.red,
          textColor: Colors.red.shade900,
          icon: Icons.mic_off,
          message: "You're out of voice minutes!",
          buttonText: 'Get 10 minutes',
        );
      case WarningLevel.critical:
        return _WarningStyling(
          backgroundColor: Colors.orange.shade50,
          borderColor: Colors.orange.shade200,
          iconColor: Colors.orange,
          textColor: Colors.orange.shade900,
          icon: Icons.warning_amber,
          message: 'Only ${quota.remainingMinutes} minutes remaining',
          buttonText: 'Get more',
        );
      case WarningLevel.low:
        return _WarningStyling(
          backgroundColor: Colors.amber.shade50,
          borderColor: Colors.amber.shade200,
          iconColor: Colors.amber.shade700,
          textColor: Colors.amber.shade900,
          icon: Icons.info_outline,
          message: 'Running low: ${quota.remainingMinutes} minutes left',
          buttonText: 'Top up',
        );
      case WarningLevel.none:
        return _WarningStyling(
          backgroundColor: Colors.transparent,
          borderColor: Colors.transparent,
          iconColor: Colors.grey,
          textColor: Colors.grey,
          icon: Icons.check,
          message: '',
          buttonText: '',
        );
    }
  }

  Widget _buildFullWarning(
    BuildContext context,
    _WarningStyling styling,
    AsyncValue<ProductDetails?> product,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: styling.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: styling.borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(styling.icon, color: styling.iconColor, size: 32),
          const SizedBox(height: 8),
          Text(
            styling.message,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: styling.textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          product.when(
            data: (productDetails) => ElevatedButton.icon(
              onPressed: onPurchase,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                productDetails != null
                    ? '${styling.buttonText} - ${productDetails.price}'
                    : '${styling.buttonText} - \$4.99',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            loading: () => const SizedBox(
              height: 36,
              width: 36,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => ElevatedButton.icon(
              onPressed: onPurchase,
              icon: const Icon(Icons.add, size: 18),
              label: Text('${styling.buttonText} - \$4.99'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          if (quota.tier == 'pro' && quota.remainingMinutes > 0) ...[
            const SizedBox(height: 8),
            Text(
              _getResetText(),
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

  Widget _buildCompactWarning(
    BuildContext context,
    _WarningStyling styling,
    AsyncValue<ProductDetails?> product,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: styling.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: styling.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(styling.icon, color: styling.iconColor, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              styling.message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: styling.textColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          product.when(
            data: (productDetails) => TextButton(
              onPressed: onPurchase,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                productDetails != null ? productDetails.price : '\$4.99',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
            loading: () => const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => TextButton(
              onPressed: onPurchase,
              child: const Text(
                '\$4.99',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getResetText() {
    // This would ideally come from the quota.resetsAt field
    // For now, show a generic message
    return 'Subscription minutes reset monthly';
  }
}

enum WarningLevel { none, low, critical, empty }

class _WarningStyling {
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;
  final IconData icon;
  final String message;
  final String buttonText;

  const _WarningStyling({
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.textColor,
    required this.icon,
    required this.message,
    required this.buttonText,
  });
}
