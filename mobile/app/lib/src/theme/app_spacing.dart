/// MyBartenderAI Spacing System
/// Consistent spacing and sizing values across the app
class AppSpacing {
  // Prevent instantiation
  AppSpacing._();

  // Base spacing unit (4px)
  static const double unit = 4.0;

  // Spacing Scale
  static const double xs = unit; // 4
  static const double sm = unit * 2; // 8
  static const double md = unit * 3; // 12
  static const double lg = unit * 4; // 16
  static const double xl = unit * 5; // 20
  static const double xxl = unit * 6; // 24
  static const double xxxl = unit * 8; // 32

  // Screen Padding
  static const double screenPaddingHorizontal = lg; // 16
  static const double screenPaddingVertical = lg; // 16
  static const double screenPaddingTop = xxl; // 24
  static const double screenPaddingBottom = xxl; // 24

  // Card Spacing
  static const double cardPadding = lg; // 16
  static const double cardSpacing = md; // 12
  static const double cardBorderRadius = md; // 12
  static const double cardLargeBorderRadius = lg; // 16

  // Button Spacing
  static const double buttonPadding = lg; // 16
  static const double buttonHeight = 48.0;
  static const double buttonHeightSmall = 40.0;
  static const double buttonHeightLarge = 56.0;
  static const double buttonBorderRadius = xxl; // 24 (pill shape)
  static const double buttonBorderRadiusSmall = lg; // 16

  // Icon Sizes
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeXLarge = 48.0;

  // Icon Circle Sizes (from mockup)
  static const double iconCircleSmall = 40.0;
  static const double iconCircleMedium = 56.0;
  static const double iconCircleLarge = 64.0;

  // Badge Spacing
  static const double badgePaddingHorizontal = md; // 12
  static const double badgePaddingVertical = sm; // 8
  static const double badgeBorderRadius = lg; // 16 (pill shape)
  static const double badgeSpacing = sm; // 8

  // Pill Button Spacing
  static const double pillPaddingHorizontal = lg; // 16
  static const double pillPaddingVertical = sm; // 8
  static const double pillBorderRadius = xl; // 20 (pill shape)

  // Section Spacing
  static const double sectionSpacing = xxxl; // 32
  static const double sectionTitleSpacing = lg; // 16

  // Grid Spacing
  static const double gridSpacing = md; // 12
  static const double gridItemSpacing = md; // 12

  // List Item Spacing
  static const double listItemPadding = lg; // 16
  static const double listItemSpacing = sm; // 8

  // Input Field Spacing
  static const double inputPadding = lg; // 16
  static const double inputBorderRadius = md; // 12
  static const double inputHeight = 48.0;

  // Divider
  static const double dividerThickness = 1.0;
  static const double dividerIndent = lg; // 16

  // Shadow Elevation
  static const double shadowElevationLow = 2.0;
  static const double shadowElevationMedium = 4.0;
  static const double shadowElevationHigh = 8.0;

  // Border Width
  static const double borderWidthThin = 1.0;
  static const double borderWidthMedium = 2.0;
  static const double borderWidthThick = 3.0;

  // Avatar Sizes
  static const double avatarSmall = 32.0;
  static const double avatarMedium = 48.0;
  static const double avatarLarge = 64.0;
  static const double avatarXLarge = 96.0;

  // App Bar
  static const double appBarHeight = 56.0;
  static const double appBarElevation = 0.0;

  // Bottom Navigation
  static const double bottomNavHeight = 72.0;

  // Floating Action Button
  static const double fabSize = 56.0;
  static const double fabSizeMini = 40.0;

  // Match Score Badge (circular badge on recipe cards)
  static const double matchBadgeSize = 44.0;
  static const double matchBadgeBorderRadius = 22.0;

  // Voice Button (large circular button)
  static const double voiceButtonSize = 80.0;
  static const double voiceButtonSizeLarge = 120.0;
}
