import 'package:flutter/material.dart';
import '../../../services/voice_ai_service.dart';

/// Small chip showing remaining voice minutes
class QuotaChip extends StatelessWidget {
  final VoiceQuota quota;

  const QuotaChip({super.key, required this.quota});

  @override
  Widget build(BuildContext context) {
    if (!quota.hasAccess) {
      return const SizedBox.shrink();
    }

    final remaining = quota.remainingMinutes;
    final color = _getColor(remaining);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            '$remaining min',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(int minutes) {
    if (minutes <= 5) return Colors.red;
    if (minutes <= 10) return Colors.orange;
    return Colors.green;
  }
}

/// Larger quota display widget with progress bar
class QuotaDisplay extends StatelessWidget {
  final VoiceQuota quota;

  const QuotaDisplay({super.key, required this.quota});

  @override
  Widget build(BuildContext context) {
    if (!quota.hasAccess) {
      return _buildNoAccessDisplay();
    }

    final usedMinutes = (quota.monthlyUsedSeconds / 60).round();
    final totalMinutes = (quota.monthlyLimitSeconds / 60).round();
    final remainingMinutes = quota.remainingMinutes;
    final progress = quota.percentUsed / 100;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Voice Minutes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$remainingMinutes min remaining',
                style: TextStyle(
                  color: _getProgressColor(progress),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation(_getProgressColor(progress)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$usedMinutes of $totalMinutes minutes used this month',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
          if (quota.addonSecondsRemaining > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.add_circle, color: Colors.blue.shade400, size: 14),
                const SizedBox(width: 4),
                Text(
                  '+${(quota.addonSecondsRemaining / 60).round()} bonus minutes',
                  style: TextStyle(
                    color: Colors.blue.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoAccessDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700),
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: Colors.amber.shade400),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pro Feature',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Upgrade to Pro for 60 min/month of voice AI',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.9) return Colors.red;
    if (progress >= 0.7) return Colors.orange;
    return Colors.green;
  }
}
