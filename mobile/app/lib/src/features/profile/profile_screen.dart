import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';

/// User profile screen
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Profile', style: AppTypography.appTitle),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Header
                  _buildProfileHeader(user.displayName ?? user.email),
                  SizedBox(height: AppSpacing.xl),

                  // Account Information Section
                  _buildSectionTitle('Account Information'),
                  SizedBox(height: AppSpacing.md),
                  _buildInfoCard([
                    _buildInfoRow(
                      Icons.person_outline,
                      'Name',
                      user.displayName ?? 'Not provided',
                    ),
                    _buildInfoRow(
                      Icons.email_outlined,
                      'Email',
                      user.email,
                    ),
                    if (user.givenName != null || user.familyName != null)
                      _buildInfoRow(
                        Icons.badge_outlined,
                        'Full Name',
                        '${user.givenName ?? ''} ${user.familyName ?? ''}'.trim(),
                      ),
                  ]),
                  SizedBox(height: AppSpacing.xl),

                  // Age Verification Section
                  _buildSectionTitle('Verification Status'),
                  SizedBox(height: AppSpacing.md),
                  _buildVerificationCard(user.ageVerified),
                  SizedBox(height: AppSpacing.xl),

                  // Sign Out Button
                  _buildSignOutButton(context, ref),
                  SizedBox(height: AppSpacing.xl),

                  // App Info
                  _buildAppInfo(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader(String name) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppSpacing.borderWidthThin,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryPurple,
                width: 2,
              ),
            ),
            child: Icon(
              Icons.person,
              size: 40,
              color: AppColors.primaryPurple,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            name,
            style: AppTypography.heading2,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTypography.heading3,
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppSpacing.borderWidthThin,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: AppColors.iconCirclePurple, size: 24),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard(bool isVerified) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isVerified
            ? AppColors.success.withOpacity(0.1)
            : AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        border: Border.all(
          color: isVerified ? AppColors.success : AppColors.error,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isVerified ? Icons.verified : Icons.warning,
            color: isVerified ? AppColors.success : AppColors.error,
            size: 24,
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Age Verification',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  isVerified
                      ? 'Verified (21+)'
                      : 'Not Verified',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          if (isVerified)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'VERIFIED',
                style: AppTypography.caption.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () async {
        // Show confirmation dialog
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.backgroundSecondary,
            title: Text('Sign Out?', style: AppTypography.heading3),
            content: Text(
              'Are you sure you want to sign out?',
              style: AppTypography.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Sign Out',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        );

        if (confirmed == true && context.mounted) {
          await ref.read(authNotifierProvider.notifier).signOut();
          // Router will auto-redirect to login screen
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.error,
        foregroundColor: AppColors.textPrimary,
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.logout),
          SizedBox(width: AppSpacing.sm),
          Text(
            'Sign Out',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfo() {
    return Center(
      child: Column(
        children: [
          Text(
            'MyBartenderAI',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Version 1.0.0',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
