import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/backend_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

/// Backend Status Widget
/// Shows the connection status to the Azure backend
class BackendStatus extends ConsumerWidget {
  const BackendStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthCheck = ref.watch(healthCheckProvider);

    return healthCheck.when(
      data: (isHealthy) {
        return _buildStatusChip(
          isHealthy: isHealthy,
          message: isHealthy ? 'Backend Connected' : 'Backend Offline',
        );
      },
      loading: () => _buildStatusChip(
        isHealthy: null,
        message: 'Connecting...',
      ),
      error: (error, stack) => _buildStatusChip(
        isHealthy: false,
        message: 'Connection Error',
      ),
    );
  }

  Widget _buildStatusChip({required bool? isHealthy, required String message}) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    if (isHealthy == null) {
      // Loading
      backgroundColor = AppColors.backgroundSecondary;
      textColor = AppColors.textTertiary;
      icon = Icons.cloud_queue;
    } else if (isHealthy) {
      // Healthy
      backgroundColor = AppColors.success.withOpacity(0.2);
      textColor = AppColors.success;
      icon = Icons.cloud_done;
    } else {
      // Error
      backgroundColor = AppColors.error.withOpacity(0.2);
      textColor = AppColors.error;
      icon = Icons.cloud_off;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.badgeBorderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppSpacing.iconSizeSmall,
            color: textColor,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            message,
            style: AppTypography.badge.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}
