import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/auth_state.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';

/// Login screen for Entra External ID authentication
/// Supports Email, Google, and Facebook sign-in
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo/Branding
              Icon(
                Icons.local_bar,
                size: 80,
                color: AppColors.primaryPurple,
              ),
              SizedBox(height: AppSpacing.lg),
              Text(
                'MyBartenderAI',
                style: AppTypography.appTitle.copyWith(fontSize: 32),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                'Your AI-Powered Cocktail Companion',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.xl * 2),

              // Loading or error state
              authState.when(
                initial: () => const SizedBox.shrink(),
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                authenticated: (_) => const SizedBox.shrink(),
                unauthenticated: () => _buildSignInButton(context, ref),
                error: (message) => Column(
                  children: [
                    Text(
                      'Authentication Error',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      message,
                      style: AppTypography.caption,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppSpacing.md),
                    _buildSignInButton(context, ref),
                  ],
                ),
              ),

              SizedBox(height: AppSpacing.xl),

              // Age restriction notice
              Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                  border: Border.all(
                    color: AppColors.primaryPurple.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primaryPurple,
                      size: 20,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'You must be 21 years or older to use this app',
                      style: AppTypography.caption,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      'Age verification will be required during signup',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () async {
        // Clear any previous error state before attempting sign in
        ref.read(authNotifierProvider.notifier).clearError();
        await ref.read(authNotifierProvider.notifier).signIn();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.textPrimary,
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        ),
      ),
      child: Text(
        'Sign In / Sign Up',
        style: AppTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
