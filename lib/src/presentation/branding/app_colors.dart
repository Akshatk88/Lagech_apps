import 'package:flutter/material.dart';

/// Lagech design tokens.
///
/// Customized with Red theme matching the logo.
class AppColors {
  // ==================== BRAND COLORS ====================
  // Mutable (not const): reassigned by ThemeColorNotifier when the user picks
  // an app theme color, so every one of the hundreds of `AppColors.primary`
  // read sites app-wide picks up the new value on the next rebuild without
  // each of them needing to watch a provider individually.
  static Color primary = const Color(0xFFE50914); // Lagech Red
  static Color primaryButton = const Color(
    0xFFB8000C,
  ); // Darker Red for buttons

  /// Secondary accent: wallet, referral, premium/offer surfaces.
  static const Color secondary = Color(0xFFFF3333);
  static const Color secondaryLight = Color(0xFFFF6666);
  static const Color secondaryTint = Color(0xFFFFEEEE);

  /// Supporting accent (kept functional for delivery, maps, etc.)
  static const Color accent = Color(0xFF00B5B8);
  static const Color accentBright = Color(0xFF12CFD2);
  static const Color accentLight = Color(0xFF2ED3D6);
  static const Color accentDeep = Color(0xFF018F91);
  static const Color accentDark = Color(0xFF046F72);
  static const Color accentTint = Color(0xFFE6F8F8);
  static const Color accentTintStrong = Color(0xFFC4EFEF);
  static const Color accentTintDark = Color(0xFF0C2B2C);

  /// Neutral grey of the wordmark.
  static const Color brandNeutral = Color(0xFF58585B);

  /// Brand gradient mapped to red tones.
  static const List<Color> brandGradient = [
    Color(0xFFE50914),
    Color(0xFFFF3333),
    Color(0xFFB8000C),
  ];

  /// Two-stop red ramp for smaller surfaces (buttons, chips, FABs).
  static const List<Color> brandGradientShort = [
    Color(0xFFE50914),
    Color(0xFFB8000C),
  ];

  // ==================== DERIVED BRAND SHADES ====================
  static HSLColor get _hsl => HSLColor.fromColor(primary);

  static Color _shade(double lightness, double saturation) =>
      _hsl.withLightness(lightness).withSaturation(saturation).toColor();

  static Color get primaryLight => _shade(0.62, _hsl.saturation);
  static Color get primaryDeep => _shade(0.42, _hsl.saturation);
  static Color get primaryDeepText =>
      _shade(0.30, (_hsl.saturation * 0.85).clamp(0.0, 0.9));
  static Color get primaryTint =>
      _shade(0.96, (_hsl.saturation * 0.9).clamp(0.0, 1.0));
  static Color get primaryTintStrong =>
      _shade(0.91, (_hsl.saturation * 0.9).clamp(0.0, 1.0));
  static Color get primarySoft =>
      _shade(0.80, (_hsl.saturation * 0.9).clamp(0.0, 1.0));
  static Color get primaryTintDark =>
      _shade(0.12, (_hsl.saturation * 0.35).clamp(0.0, 0.45));
  static Color get primaryTintDarkStrong =>
      _shade(0.20, (_hsl.saturation * 0.4).clamp(0.0, 0.5));

  static Color primaryAlpha(double alpha) => primary.withValues(alpha: alpha);

  // ==================== NEUTRAL SCALE ====================
  static const Color neutral50 = Color(0xFFFAFAFB);
  static const Color neutral100 = Color(0xFFF4F4F7);
  static const Color neutral200 = Color(0xFFE9E9EF);
  static const Color neutral300 = Color(0xFFD8D8E0);
  static const Color neutral400 = Color(0xFFA6A6B4);
  static const Color neutral500 = Color(0xFF74748A);
  static const Color neutral600 = Color(0xFF55556A);
  static const Color neutral700 = Color(0xFF3E3E4E);
  static const Color neutral900 = Color(0xFF16161D);

  // ==================== DARK THEME COLORS ====================
  static const Color backgroundDark = Color(0xFF121118);
  static const Color surfaceDark = Color(0xFF1B1A22);
  static const Color cardDark = Color(0xFF23222C);
  static const Color darkContainer = Color(0xFF2A2934);
  static const Color darkBorder = Color(0xFF3D3B4A);

  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF9E9DAC);
  static const Color borderDark = Color(0xFF302F3B);

  // ==================== LIGHT THEME COLORS ====================
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color secondarySurfaceLight = neutral100;
  static const Color lightContainer = neutral50;
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color lightGreyBg = neutral100;

  static const Color textPrimaryLight = neutral900;
  static const Color textDark = neutral900;
  static const Color textSecondaryLight = neutral500;
  static const Color textTertiaryLight = neutral400;
  static const Color borderLight = neutral200;
  static const Color borderSubtle = neutral200;
  static const Color borderExtraSubtle = neutral100;
  static const Color dividerLight = neutral100;
  static const Color disabled = neutral300;
  static const Color onDisabled = neutral500;
  static const Color shadow1 = Color(0x14000000);
  static const Color shadow2 = Color(0x0A000000);

  // ==================== STATUS & ACCENT COLORS ====================
  static const Color success = Color(0xFF16A34A);
  static const Color successDeep = Color(0xFF0F7A37);
  static const Color successSoft = Color(0xFFE7F7EE);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFEF4E3);
  static const Color error = Color(0xFFE11D48);
  static const Color errorDeep = Color(0xFFBE123C);
  static const Color errorSoft = Color(0xFFFDE9EE);
  static const Color rating = Color(0xFFFFB01D);
  static const Color ratingStar = Color(0xFFFFB01D);
  static const Color veg = Color(0xFF16A34A);
  static const Color nonVeg = Color(0xFFDC2626);

  static const Color accentPurple = secondary;
  static const Color accentPink = Color(0xFFE50914);
  static const Color accentBlue = accent;
}
