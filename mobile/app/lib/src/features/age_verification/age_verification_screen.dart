import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/theme.dart';

final ageVerificationProvider = StateNotifierProvider<AgeVerificationNotifier, bool>((ref) {
  return AgeVerificationNotifier();
});

class AgeVerificationNotifier extends StateNotifier<bool> {
  AgeVerificationNotifier() : super(false) {
    _loadVerificationStatus();
  }

  static const _ageVerifiedKey = 'age_verified';

  Future<void> _loadVerificationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final verified = prefs.getBool(_ageVerifiedKey) ?? false;
      state = verified;
    } catch (e, stackTrace) {
      developer.log(
        'Error loading age verification status',
        error: e,
        stackTrace: stackTrace,
        name: 'AgeVerification',
      );
      // Default to false for safety
      state = false;
    }
  }

  Future<bool> verifyAge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_ageVerifiedKey, true);
      state = true;
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to persist age verification',
        error: e,
        stackTrace: stackTrace,
        name: 'AgeVerification',
      );
      // Don't set state to true - require successful storage for legal compliance
      // Return false to indicate failure
      return false;
    }
  }

  Future<void> resetVerification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_ageVerifiedKey);
      state = false;
    } catch (e, stackTrace) {
      developer.log(
        'Error resetting age verification',
        error: e,
        stackTrace: stackTrace,
        name: 'AgeVerification',
      );
      state = false;
    }
  }
}

class AgeVerificationScreen extends ConsumerWidget {
  const AgeVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/icon/icon.png',
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(height: AppSpacing.xxl),

              // Title
              Text(
                'Age Verification',
                style: AppTypography.heading1,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.lg),

              // Description
              Text(
                'My AI Bartender is for adults 21 and over.',
                style: AppTypography.bodyLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                'Please confirm you are of legal drinking age in your location.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.xxl * 2),

              // Verification Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    final success = await ref.read(ageVerificationProvider.notifier).verifyAge();
                    if (context.mounted) {
                      if (success) {
                        context.go('/login');
                      } else {
                        // Show error if storage failed
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Unable to save verification. Please check app permissions and try again.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                    ),
                  ),
                  child: Text(
                    'I am 21 or older',
                    style: AppTypography.buttonLarge,
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.lg),

              // Exit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () {
                    // Close the app or show message
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AppColors.cardBackground,
                        title: Text(
                          'Age Requirement',
                          style: AppTypography.heading3,
                        ),
                        content: Text(
                          'You must be 21 or older to use My AI Bartender. Please come back when you reach the legal drinking age.',
                          style: AppTypography.bodyMedium,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'OK',
                              style: AppTypography.buttonMedium.copyWith(
                                color: AppColors.primaryPurple,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(
                      color: AppColors.cardBorder,
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                    ),
                  ),
                  child: Text(
                    'I am under 21',
                    style: AppTypography.buttonLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.xxl),

              // Legal Notice
              Text(
                'By continuing, you agree to use this app responsibly and in accordance with local laws.',
                style: AppTypography.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}