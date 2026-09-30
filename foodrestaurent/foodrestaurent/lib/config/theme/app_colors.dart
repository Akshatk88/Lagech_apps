import 'package:flutter/material.dart';

/// Lagech design tokens.
///
/// Red & White theme matching the LAGECH profile UI.
class AppColors {
  AppColors._();

  // ==================== BRAND COLORS ====================

  /// Main LAGECH Red
  /// Screenshot ke buttons, active icons aur selected navigation ke liye.
  static const Color primary = Color(0xFFE00000);

  /// Darker red for buttons / strong brand surfaces.
  static const Color primaryButton = Color(0xFFD00000);

  /// Secondary red accent.
  static const Color secondary = Color(0xFFFF3333);

  static const Color secondaryLight = Color(0xFFFF6666);

  /// Light red/pink background used behind guest/profile cards.
  static const Color secondaryTint = Color(0xFFFFE0E3);

  // ==================== SUPPORTING ACCENT ====================

  /// Supporting teal accent for delivery/maps etc.
  static const Color accent = Color(0xFF00B5B8);

  static const Color accentBright = Color(0xFF12CFD2);

  static const Color accentLight = Color(0xFF2ED3D6);

  static const Color accentDeep = Color(0xFF018F91);

  static const Color accentDark = Color(0xFF046F72);

  static const Color accentTint = Color(0xFFE6F8F8);

  static const Color accentTintStrong = Color(0xFFC4EFEF);

  static const Color accentTintDark = Color(0xFF0C2B2C);

  // ==================== BRAND NEUTRAL ====================

  static const Color brandNeutral = Color(0xFF58585B);

  // ==================== BRAND GRADIENT ====================

  static const List<Color> brandGradient = [
    Color(0xFFFF1A1A),
    Color(0xFFE00000),
    Color(0xFFC90000),
  ];

  static const List<Color> brandGradientShort = [
    Color(0xFFE00000),
    Color(0xFFC90000),
  ];

  // ==================== DERIVED BRAND SHADES ====================

  static HSLColor get _hsl => HSLColor.fromColor(primary);

  static Color _shade(double lightness, double saturation) {
    return _hsl.withLightness(lightness).withSaturation(saturation).toColor();
  }

  /// Light red.
  static const Color primaryLight = Color(0xFFFF3333);

  /// Deep red.
  static const Color primaryDeep = Color(0xFFC90000);

  /// Dark red for text.
  static const Color primaryDeepText = Color(0xFF990000);

  /// Very light red tint.
  static const Color primaryTint = Color(0xFFFFF0F1);

  /// Stronger red tint.
  static const Color primaryTintStrong = Color(0xFFFFD6D9);

  /// Soft red.
  static const Color primarySoft = Color(0xFFFF9999);

  /// Dark red tint for dark mode.
  static const Color primaryTintDark = Color(0xFF3D1114);

  /// Strong dark red tint.
  static const Color primaryTintDarkStrong = Color(0xFF65171B);

  /// Primary color with custom opacity.
  static Color primaryAlpha(double alpha) {
    return primary.withValues(alpha: alpha);
  }

  // ==================== NEUTRAL SCALE ====================

  static const Color neutral50 = Color(0xFFFAFAFA);

  static const Color neutral100 = Color(0xFFF5F5F5);

  static const Color neutral200 = Color(0xFFEAEAEA);

  static const Color neutral300 = Color(0xFFD8D8D8);

  static const Color neutral400 = Color(0xFFA6A6A6);

  static const Color neutral500 = Color(0xFF777777);

  static const Color neutral600 = Color(0xFF666666);

  static const Color neutral700 = Color(0xFF444444);

  static const Color neutral900 = Color(0xFF151515);

  // ==================== DARK THEME COLORS ====================

  static const Color backgroundDark = Color(0xFF121212);

  static const Color surfaceDark = Color(0xFF1E1E1E);

  static const Color cardDark = Color(0xFF242424);

  static const Color darkContainer = Color(0xFF2D2D2D);

  static const Color darkBorder = Color(0xFF414141);

  static const Color surfaceVariantDark = Color(0xFF2D2D2D);

  static const Color textPrimaryDark = Color(0xFFFFFFFF);

  static const Color textSecondaryDark = Color(0xFFB5B5B5);

  static const Color borderDark = Color(0xFF383838);

  // ==================== LIGHT THEME COLORS ====================

  /// Screenshot jaisa almost white/light grey background.
  static const Color backgroundLight = Color(0xFFFAFAFA);

  /// Main cards pure white.
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// Light grey containers.
  static const Color secondarySurfaceLight = Color(0xFFF5F5F5);

  static const Color lightContainer = Color(0xFFFAFAFA);

  /// White cards.
  static const Color cardLight = Color(0xFFFFFFFF);

  static const Color lightGreyBg = Color(0xFFF5F5F5);

  /// Light variant for inputs/containers.
  static const Color surfaceVariantLight = Color(0xFFF1F1F1);

  // ==================== LIGHT TEXT ====================

  /// Screenshot ke headings/text jaisa almost black.
  static const Color textPrimaryLight = Color(0xFF171717);

  static const Color textDark = Color(0xFF171717);

  /// Screenshot ke secondary grey text.
  static const Color textSecondaryLight = Color(0xFF777777);

  static const Color textTertiaryLight = Color(0xFF9A9A9A);

  // ==================== LIGHT BORDERS ====================

  static const Color borderLight = Color(0xFFE5E5E5);

  static const Color borderSubtle = Color(0xFFEEEEEE);

  static const Color borderExtraSubtle = Color(0xFFF4F4F4);

  static const Color dividerLight = Color(0xFFEEEEEE);

  // ==================== DISABLED ====================

  static const Color disabled = Color(0xFFD1D1D1);

  static const Color onDisabled = Color(0xFF8A8A8A);

  // ==================== SHADOWS ====================

  static const Color shadow1 = Color(0x14000000);

  static const Color shadow2 = Color(0x0A000000);

  // ==================== STATUS COLORS ====================

  /// Green used for success / vegetarian mode.
  static const Color success = Color(0xFF4ADE80);

  static const Color successDeep = Color(0xFF22C55E);

  static const Color successSoft = Color(0xFFE9FBEF);

  /// Warning.
  static const Color warning = Color(0xFFF59E0B);

  static const Color warningSoft = Color(0xFFFEF4E3);

  /// Screenshot/theme red error.
  static const Color error = Color(0xFFFF6464);

  static const Color errorDeep = Color(0xFFE04444);

  static const Color errorSoft = Color(0xFFFFEEEE);

  // ==================== RATING ====================

  static const Color rating = Color(0xFFFFB01D);

  static const Color ratingStar = Color(0xFFFFB01D);

  // ==================== FOOD COLORS ====================

  static const Color veg = Color(0xFF16A34A);

  static const Color nonVeg = Color(0xFFDC2626);

  // ==================== ACCENT ALIASES ====================

  /// Purple alias mapped to LAGECH Red.
  static const Color accentPurple = secondary;

  /// Pink alias mapped to LAGECH Red.
  static const Color accentPink = Color(0xFFE00000);

  /// Blue/teal alias retained for functional features.
  static const Color accentBlue = accent;
}
