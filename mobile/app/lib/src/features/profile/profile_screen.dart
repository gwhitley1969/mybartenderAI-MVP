import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/notification_service.dart';
import '../../services/user_settings_service.dart';
import '../../theme/theme.dart';
import '../age_verification/age_verification_screen.dart';
import '../home/providers/todays_special_provider.dart';
import 'legal_webview_screen.dart';

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
                  // Account Information Section
                  _buildSectionTitle('Account Information'),
                  SizedBox(height: AppSpacing.md),
                  _buildInfoCard([
                    _buildInfoRow(
                      Icons.person_outline,
                      'Name',
                      user.displayName ?? 'Not provided',
                    ),
                    if (user.givenName != null || user.familyName != null)
                      _buildInfoRow(
                        Icons.badge_outlined,
                        'Full Name',
                        '${user.givenName ?? ''} ${user.familyName ?? ''}'.trim(),
                      ),
                  ]),
                  SizedBox(height: AppSpacing.xl),

                  // Preferences Section
                  _buildSectionTitle('Preferences'),
                  SizedBox(height: AppSpacing.md),
                  _buildMeasurementUnitCard(context, ref),
                  SizedBox(height: AppSpacing.xl),

                  // Notification Settings Section
                  _buildSectionTitle('Notifications'),
                  SizedBox(height: AppSpacing.md),
                  _buildNotificationSettingsCard(context, ref),
                  SizedBox(height: AppSpacing.xl),

                  // Age Verification Section
                  _buildSectionTitle('Verification Status'),
                  SizedBox(height: AppSpacing.md),
                  // Use local age verification OR user profile verification
                  _buildVerificationCard(localAgeVerified || user.ageVerified),
                  SizedBox(height: AppSpacing.xl),

                  // Help & Support Section
                  _buildSectionTitle('Help & Support'),
                  SizedBox(height: AppSpacing.md),
                  _buildHelpSupportCard(context),
                  SizedBox(height: AppSpacing.xl),

                  // Legal Section
                  _buildSectionTitle('Legal'),
                  SizedBox(height: AppSpacing.md),
                  _buildLegalCard(context),
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
            width: 60,
            height: 60,
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
              size: 30,
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

                    // If enabling, reschedule the notification (force to bypass idempotency)
                    if (value) {
                      final todaysSpecial = ref.read(todaysSpecialProvider);
                      todaysSpecial.whenData((cocktail) {
                        if (cocktail != null) {
                          NotificationService.instance.scheduleTodaysSpecialNotification(cocktail, force: true);
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

  Widget _buildMeasurementUnitCard(BuildContext context, WidgetRef ref) {
    final measurementUnit = ref.watch(measurementUnitProvider);

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
      child: measurementUnit.when(
        data: (unit) => Row(
          children: [
            Icon(
              Icons.straighten,
              color: AppColors.iconCircleTeal,
              size: 24,
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Measurement Units',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Choose how recipe measurements are displayed',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            // Toggle buttons for Imperial/Metric
            Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildUnitToggleButton(
                    label: 'oz',
                    isSelected: unit == UserSettingsService.imperial,
                    onTap: () async {
                      await UserSettingsService.instance.setMeasurementUnit(
                        UserSettingsService.imperial,
                      );
                      ref.invalidate(measurementUnitProvider);
                    },
                  ),
                  _buildUnitToggleButton(
                    label: 'ml',
                    isSelected: unit == UserSettingsService.metric,
                    onTap: () async {
                      await UserSettingsService.instance.setMeasurementUnit(
                        UserSettingsService.metric,
                      );
                      ref.invalidate(measurementUnitProvider);
                    },
                  ),
                ],
              ),
            ),
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
            'Unable to load measurement settings',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.error,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnitToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
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

      // Reschedule notification with new time (force to bypass idempotency)
      final todaysSpecial = ref.read(todaysSpecialProvider);
      todaysSpecial.whenData((cocktail) {
        if (cocktail != null) {
          NotificationService.instance.scheduleTodaysSpecialNotification(cocktail, force: true);
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

  Widget _buildHelpSupportCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _launchSupportEmail(context),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
          border: Border.all(
            color: AppColors.cardBorder,
            width: AppSpacing.borderWidthThin,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.email_outlined,
              color: AppColors.iconCircleCyan,
              size: 24,
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Support',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'support@xtend-ai.com',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.iconCircleCyan,
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
    );
  }

  Widget _buildLegalCard(BuildContext context) {
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
        children: [
          // Privacy Policy
          _buildLegalRow(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            url: 'https://www.mybartenderai.com/privacy.html',
          ),
          Divider(
            color: AppColors.cardBorder,
            height: 1,
            indent: AppSpacing.md,
            endIndent: AppSpacing.md,
          ),
          // Terms of Service
          _buildLegalRow(
            context,
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            url: 'https://www.mybartenderai.com/terms.html',
          ),
        ],
      ),
    );
  }

  Widget _buildLegalRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String url,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => LegalWebViewScreen(
              title: title,
              url: url,
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.iconCirclePurple,
              size: 24,
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfo() {
    return Center(
      child: Text(
        'My AI Bartender',
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Future<void> _launchSupportEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@xtend-ai.com',
      queryParameters: {
        'subject': 'My AI Bartender Support',
      },
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No email app found. Please email support@xtend-ai.com'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
