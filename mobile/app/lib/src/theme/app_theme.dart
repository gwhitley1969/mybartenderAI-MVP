import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';

/// MyBartenderAI Theme
/// Complete theme configuration based on design mockups
class AppTheme {
  // Prevent instantiation
  AppTheme._();

  /// Dark theme (primary theme for the app)
  static ThemeData get darkTheme {
    return ThemeData(
      // Color Scheme
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryPurple,
        secondary: AppColors.accentCyan,
        surface: AppColors.backgroundSecondary,
        error: AppColors.error,
        onPrimary: AppColors.textPrimary,
        onSecondary: AppColors.textPrimary,
        onSurface: AppColors.textSecondary,
        onError: AppColors.textPrimary,
      ),

      // Scaffold
      scaffoldBackgroundColor: AppColors.backgroundPrimary,

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: AppSpacing.appBarElevation,
        centerTitle: false,
        titleTextStyle: AppTypography.heading3,
        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
          size: AppSpacing.iconSizeMedium,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: AppSpacing.shadowElevationLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
          side: const BorderSide(
            color: AppColors.cardBorder,
            width: AppSpacing.borderWidthThin,
          ),
        ),
        margin: const EdgeInsets.all(AppSpacing.cardSpacing),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.buttonPrimary,
          foregroundColor: AppColors.textPrimary,
          disabledBackgroundColor: AppColors.buttonDisabled,
          disabledForegroundColor: AppColors.textDisabled,
          elevation: AppSpacing.shadowElevationLow,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPadding,
            vertical: AppSpacing.md,
          ),
          minimumSize: const Size(0, AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonBorderRadius),
          ),
          textStyle: AppTypography.buttonLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryPurple,
          textStyle: AppTypography.buttonMedium,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(
            color: AppColors.cardBorder,
            width: AppSpacing.borderWidthMedium,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPadding,
            vertical: AppSpacing.md,
          ),
          minimumSize: const Size(0, AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonBorderRadius),
          ),
          textStyle: AppTypography.buttonLarge,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputBorderRadius),
          borderSide: const BorderSide(
            color: AppColors.cardBorder,
            width: AppSpacing.borderWidthThin,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputBorderRadius),
          borderSide: const BorderSide(
            color: AppColors.cardBorder,
            width: AppSpacing.borderWidthThin,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputBorderRadius),
          borderSide: const BorderSide(
            color: AppColors.primaryPurple,
            width: AppSpacing.borderWidthMedium,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputBorderRadius),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: AppSpacing.borderWidthThin,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputBorderRadius),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: AppSpacing.borderWidthMedium,
          ),
        ),
        contentPadding: const EdgeInsets.all(AppSpacing.inputPadding),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
        labelStyle: AppTypography.bodyMedium,
        errorStyle: AppTypography.caption.copyWith(
          color: AppColors.error,
        ),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: AppSpacing.iconSizeMedium,
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.cardBorder,
        thickness: AppSpacing.dividerThickness,
        space: AppSpacing.dividerIndent * 2,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cardBackground,
        selectedColor: AppColors.primaryPurple,
        disabledColor: AppColors.buttonDisabled,
        labelStyle: AppTypography.pill,
        secondaryLabelStyle: AppTypography.pill,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.badgeBorderRadius),
          side: const BorderSide(
            color: AppColors.cardBorder,
            width: AppSpacing.borderWidthThin,
          ),
        ),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.backgroundSecondary,
        selectedItemColor: AppColors.primaryPurple,
        unselectedItemColor: AppColors.textTertiary,
        selectedLabelStyle: AppTypography.caption,
        unselectedLabelStyle: AppTypography.caption,
        type: BottomNavigationBarType.fixed,
        elevation: AppSpacing.shadowElevationMedium,
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.textPrimary,
        elevation: AppSpacing.shadowElevationMedium,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardBackground,
        elevation: AppSpacing.shadowElevationHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardLargeBorderRadius),
        ),
        titleTextStyle: AppTypography.heading3,
        contentTextStyle: AppTypography.bodyMedium,
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardBackground,
        contentTextStyle: AppTypography.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        ),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.textPrimary;
          }
          return AppColors.textTertiary;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.primaryPurple;
          }
          return AppColors.buttonSecondary;
        }),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryPurple,
        linearTrackColor: AppColors.buttonSecondary,
        circularTrackColor: AppColors.buttonSecondary,
      ),
    );
  }

  /// Light theme (optional - app is primarily dark themed)
  static ThemeData get lightTheme {
    // For now, return dark theme since app is dark-themed
    // Can implement light theme later if needed
    return darkTheme;
  }
}
