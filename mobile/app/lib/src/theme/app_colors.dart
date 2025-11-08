import 'package:flutter/material.dart';

/// MyBartenderAI Color Palette
/// Extracted from design mockups for consistent theming across the app
class AppColors {
  // Prevent instantiation
  AppColors._();

  // Background Colors
  static const Color backgroundPrimary = Color(0xFF0F0A1E); // Deep navy purple
  static const Color backgroundSecondary = Color(0xFF1A1333); // Slightly lighter purple
  static const Color cardBackground = Color(0xFF1E1838); // Card background
  static const Color cardBorder = Color(0xFF2D2548); // Subtle card borders

  // Primary Brand Colors
  static const Color primaryPurple = Color(0xFF7C3AED); // Main purple accent
  static const Color primaryPurpleLight = Color(0xFF9F7AEA); // Lighter purple
  static const Color primaryPurpleDark = Color(0xFF6D28D9); // Darker purple

  // Accent Colors
  static const Color accentCyan = Color(0xFF06B6D4); // Teal/cyan for badges and scores
  static const Color accentOrange = Color(0xFFF59E0B); // Orange/amber for Recipe Vault, Pro Tools
  static const Color accentPink = Color(0xFFEC4899); // Pink/magenta for Academy
  static const Color accentTeal = Color(0xFF14B8A6); // Teal for Premium Bar
  static const Color accentBlue = Color(0xFF3B82F6); // Blue for icons
  static const Color accentRed = Color(0xFFEF4444); // Red for favorites
  static const Color electricBlue = Color(0xFF00D9FF); // Electric blue for AI features

  // Status Colors
  static const Color success = Color(0xFF10B981); // Green for success states
  static const Color warning = Color(0xFFF59E0B); // Orange for warnings
  static const Color error = Color(0xFFEF4444); // Red for errors and missing ingredients
  static const Color info = Color(0xFF3B82F6); // Blue for info

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF); // White for headings
  static const Color textSecondary = Color(0xFFE5E7EB); // Light gray for body text
  static const Color textTertiary = Color(0xFF9CA3AF); // Medium gray for hints
  static const Color textDisabled = Color(0xFF6B7280); // Darker gray for disabled

  // Gradient Definitions
  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFF9F7AEA)],
  );

  static const LinearGradient cyanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF06B6D4), Color(0xFF0EA5E9)],
  );

  static const LinearGradient orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
  );

  static const LinearGradient pinkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
  );

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF14B8A6), Color(0xFF2DD4BF)],
  );

  // Badge Colors
  static const Color badgeIntermediate = Color(0xFF7C3AED); // Purple for intermediate
  static const Color badgeElite = Color(0xFFF59E0B); // Orange for elite
  static const Color badgeBackground = Color(0xFF2D2548); // Badge background

  // Button Colors
  static const Color buttonPrimary = primaryPurple;
  static const Color buttonSecondary = Color(0xFF2D2548);
  static const Color buttonDisabled = Color(0xFF374151);

  // Icon Circle Backgrounds (matching mockup)
  static const Color iconCirclePurple = Color(0xFF7C3AED);
  static const Color iconCircleCyan = Color(0xFF06B6D4);
  static const Color iconCircleOrange = Color(0xFFF59E0B);
  static const Color iconCirclePink = Color(0xFFEC4899);
  static const Color iconCircleTeal = Color(0xFF14B8A6);
  static const Color iconCircleBlue = Color(0xFF3B82F6);

  // Overlay Colors
  static const Color overlay = Color(0x80000000); // 50% black
  static const Color overlayLight = Color(0x40000000); // 25% black

  // Special Effects
  static const Color shimmer = Color(0x33FFFFFF); // Shimmer effect overlay
  static const Color glow = Color(0x667C3AED); // Purple glow
}
