import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/cocktail_provider.dart';
import '../../theme/theme.dart';

/// Initial sync screen shown after first login when database is empty.
/// Automatically downloads the cocktail database and shows progress.
class InitialSyncScreen extends ConsumerStatefulWidget {
  const InitialSyncScreen({super.key});

  @override
  ConsumerState<InitialSyncScreen> createState() => _InitialSyncScreenState();
}

class _InitialSyncScreenState extends ConsumerState<InitialSyncScreen> {
  bool _syncStarted = false;

  @override
  void initState() {
    super.initState();
    // Start sync after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSync();
    });
  }

  Future<void> _startSync() async {
    if (_syncStarted) return;
    setState(() {
      _syncStarted = true;
    });

    await ref.read(snapshotSyncProvider.notifier).syncSnapshot();

    // Check if sync completed successfully
    final syncState = ref.read(snapshotSyncProvider);
    if (syncState.isCompleted && mounted) {
      // Mark sync as completed so router guard knows we're done
      ref.read(initialSyncStatusProvider.notifier).markSyncCompleted();

      // Also invalidate these for good measure
      ref.invalidate(needsInitialSyncProvider);
      ref.invalidate(cocktailCountProvider);

      // Navigate to home
      if (mounted) {
        context.go('/');
      }
    }
  }

  void _retry() {
    ref.read(snapshotSyncProvider.notifier).reset();
    setState(() {
      _syncStarted = false;
    });
    _startSync();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(snapshotSyncProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal * 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // App icon/logo area
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: AppColors.purpleGradient,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_bar,
                  size: 60,
                  color: Colors.white,
                ),
              ),

              SizedBox(height: AppSpacing.xxxl),

              // Title
              Text(
                'Setting Up Your\nCocktail Library',
                style: AppTypography.heading2,
                textAlign: TextAlign.center,
              ),

              SizedBox(height: AppSpacing.lg),

              // Subtitle based on state
              if (syncState.isError)
                Text(
                  'Something went wrong',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.error,
                  ),
                  textAlign: TextAlign.center,
                )
              else
                Text(
                  'Downloading 621 cocktail recipes\nfor offline access',
                  style: AppTypography.bodyLarge,
                  textAlign: TextAlign.center,
                ),

              SizedBox(height: AppSpacing.xxxl),

              // Progress section
              if (syncState.isLoading) ...[
                // Progress bar
                Container(
                  width: double.infinity,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: syncState.progress > 0 ? syncState.progress : null,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryPurple,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: AppSpacing.md),

                // Progress text
                Text(
                  syncState.progress > 0
                      ? 'Downloading: ${(syncState.progress * 100).toStringAsFixed(0)}%'
                      : 'Connecting...',
                  style: AppTypography.caption,
                ),
              ] else if (syncState.isError) ...[
                // Error message
                Container(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 32,
                      ),
                      SizedBox(height: AppSpacing.md),
                      Text(
                        syncState.errorMessage ?? 'Failed to download cocktail database',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.error,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppSpacing.xxl),

                // Retry button
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _retry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.buttonBorderRadius),
                      ),
                    ),
                    child: Text(
                      'Try Again',
                      style: AppTypography.buttonLarge,
                    ),
                  ),
                ),
              ] else if (syncState.isCompleted) ...[
                // Success state (brief, before navigation)
                Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 48,
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'All set! Loading your app...',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ] else ...[
                // Initial/idle state
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Preparing...',
                  style: AppTypography.caption,
                ),
              ],

              const Spacer(flex: 3),

              // Footer hint
              Text(
                'This only happens once',
                style: AppTypography.caption,
              ),

              SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
