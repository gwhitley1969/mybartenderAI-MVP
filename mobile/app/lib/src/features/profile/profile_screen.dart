import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../services/token_storage_service.dart';
import '../../theme/theme.dart';
import '../age_verification/age_verification_screen.dart';
import '../home/providers/todays_special_provider.dart';

/// User profile screen
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    // Check both user profile AND local age verification status
    final localAgeVerified = ref.watch(ageVerificationProvider);

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
                  // Use local age verification OR user profile verification
                  _buildVerificationCard(localAgeVerified || user.ageVerified),
                  SizedBox(height: AppSpacing.xl),

                  // Notification Settings Section
                  _buildSectionTitle('Notifications'),
                  SizedBox(height: AppSpacing.md),
                  _buildNotificationSettingsCard(context, ref),
                  SizedBox(height: AppSpacing.xl),

                  // Developer Tools Section
                  _buildSectionTitle('Developer Tools'),
                  SizedBox(height: AppSpacing.md),
                  _buildJwtTokenCard(context, ref),
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

  Widget _buildNotificationSettingsCard(BuildContext context, WidgetRef ref) {
    final notificationSettings = ref.watch(notificationSettingsProvider);

    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppSpacing.borderWidthThin,
        ),
      ),
      child: notificationSettings.when(
        data: (settings) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enable/Disable toggle
            Row(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  color: AppColors.iconCirclePurple,
                  size: 24,
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Special Reminder",
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Get daily cocktail inspiration',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: settings.enabled,
                  onChanged: (value) async {
                    await NotificationService.instance.setNotificationEnabled(value);
                    ref.invalidate(notificationSettingsProvider);

                    // If enabling, reschedule the notification
                    if (value) {
                      final todaysSpecial = ref.read(todaysSpecialProvider);
                      todaysSpecial.whenData((cocktail) {
                        if (cocktail != null) {
                          NotificationService.instance.scheduleTodaysSpecialNotification(cocktail);
                        }
                      });
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? 'Daily reminders enabled!'
                                : 'Daily reminders disabled',
                          ),
                          backgroundColor: AppColors.cardBackground,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  activeColor: AppColors.primaryPurple,
                ),
              ],
            ),

            // Time picker (only shown when enabled)
            if (settings.enabled) ...[
              SizedBox(height: AppSpacing.md),
              Divider(color: AppColors.cardBorder),
              SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: () => _showTimePicker(context, ref, settings),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: AppColors.iconCircleTeal,
                      size: 24,
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reminder Time',
                            style: AppTypography.bodyMedium,
                          ),
                          SizedBox(height: 4),
                          Text(
                            settings.formattedTime,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.md),
              Divider(color: AppColors.cardBorder),
              SizedBox(height: AppSpacing.md),
              // Test notification button
              InkWell(
                onTap: () => _sendTestNotification(context, ref),
                child: Row(
                  children: [
                    Icon(
                      Icons.send,
                      color: AppColors.iconCircleOrange,
                      size: 24,
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Test Notification',
                            style: AppTypography.bodyMedium,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Send a test notification now',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        loading: () => Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: CircularProgressIndicator(
              color: AppColors.primaryPurple,
            ),
          ),
        ),
        error: (error, _) => Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Unable to load notification settings',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.error,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendTestNotification(BuildContext context, WidgetRef ref) async {
    final todaysSpecial = ref.read(todaysSpecialProvider);

    todaysSpecial.when(
      data: (cocktail) async {
        if (cocktail != null) {
          await NotificationService.instance.showTestNotification(cocktail);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Test notification sent! Check your notification shade.'),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No cocktail available for test notification.'),
                backgroundColor: AppColors.error,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      },
      loading: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loading cocktail data...'),
            backgroundColor: AppColors.cardBackground,
            duration: Duration(seconds: 2),
          ),
        );
      },
      error: (error, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Could not send test notification.'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
      },
    );
  }

  Future<void> _showTimePicker(
    BuildContext context,
    WidgetRef ref,
    NotificationSettings settings,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.hour, minute: settings.minute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primaryPurple,
              surface: AppColors.backgroundSecondary,
              onSurface: AppColors.textPrimary,
            ),
            dialogBackgroundColor: AppColors.backgroundSecondary,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await NotificationService.instance.setNotificationTime(picked.hour, picked.minute);
      ref.invalidate(notificationSettingsProvider);

      // Reschedule notification with new time
      final todaysSpecial = ref.read(todaysSpecialProvider);
      todaysSpecial.whenData((cocktail) {
        if (cocktail != null) {
          NotificationService.instance.scheduleTodaysSpecialNotification(cocktail);
        }
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reminder time updated to ${NotificationService.instance.formatTime(picked.hour, picked.minute)}',
            ),
            backgroundColor: AppColors.cardBackground,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
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

  Widget _buildJwtTokenCard(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppSpacing.borderWidthThin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.code, color: AppColors.iconCirclePurple, size: 20),
              SizedBox(width: AppSpacing.sm),
              Text(
                'JWT Token',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Copy your JWT token for API testing',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                // Get token from storage
                final tokenStorage = ref.read(tokenStorageServiceProvider);
                final token = await tokenStorage.getAccessToken();

                if (token != null) {
                  // Copy to clipboard
                  await Clipboard.setData(ClipboardData(text: token));

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('JWT token copied to clipboard'),
                        backgroundColor: AppColors.success,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('No JWT token available. Please sign in.'),
                        backgroundColor: AppColors.error,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: AppColors.error,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            icon: Icon(Icons.copy, size: 18),
            label: Text('Copy JWT Token'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: AppColors.textPrimary,
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
