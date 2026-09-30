import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

// ============================================================
// LAGECH APP THEME
// Red + White design system
// ============================================================

const double _borderRadius = 16.0;
const double _buttonBorderRadius = 30.0;
const double _buttonHeight = 56.0;
const String _fontFamily = 'ManropeVariable';

// ============================================================
// LIGHT THEME
// ============================================================

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  fontFamily: _fontFamily,

  // ----------------------------------------------------------
  // MAIN COLORS
  // ----------------------------------------------------------
  scaffoldBackgroundColor: AppColors.backgroundLight,
  primaryColor: AppColors.primary,

  colorScheme: ColorScheme.light(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.surfaceLight,
    error: AppColors.error,

    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: AppColors.textPrimaryLight,
    onError: Colors.white,
  ),

  // ----------------------------------------------------------
  // TYPOGRAPHY
  // ----------------------------------------------------------
  textTheme:
      TextTheme(
        displayLarge: AppTextStyles.h1,
        displayMedium: AppTextStyles.h2,
        displaySmall: AppTextStyles.h3,
        headlineMedium: AppTextStyles.h4,

        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,

        labelLarge: AppTextStyles.button,
      ).apply(
        fontFamily: _fontFamily,
        bodyColor: AppColors.textPrimaryLight,
        displayColor: AppColors.textPrimaryLight,
      ),

  // ----------------------------------------------------------
  // APP BAR
  // ----------------------------------------------------------
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.backgroundLight,
    foregroundColor: AppColors.textPrimaryLight,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,

    iconTheme: const IconThemeData(color: AppColors.textPrimaryLight),

    titleTextStyle: const TextStyle(
      fontFamily: _fontFamily,
      color: AppColors.textPrimaryLight,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
  ),

  // ----------------------------------------------------------
  // ELEVATED BUTTON
  // ----------------------------------------------------------
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryButton,
      foregroundColor: Colors.white,

      minimumSize: const Size(double.infinity, _buttonHeight),

      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),

      textStyle: AppTextStyles.button.copyWith(
        fontFamily: _fontFamily,
        color: Colors.white,
      ),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonBorderRadius),
      ),

      elevation: 0,
    ),
  ),

  // ----------------------------------------------------------
  // OUTLINED BUTTON
  // ----------------------------------------------------------
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,

      minimumSize: const Size(double.infinity, _buttonHeight),

      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),

      side: const BorderSide(color: AppColors.primary, width: 1.5),

      textStyle: AppTextStyles.buttonSmall.copyWith(fontFamily: _fontFamily),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonBorderRadius),
      ),
    ),
  ),

  // ----------------------------------------------------------
  // TEXT BUTTON
  // ----------------------------------------------------------
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,

      textStyle: AppTextStyles.buttonSmall.copyWith(fontFamily: _fontFamily),
    ),
  ),

  // ----------------------------------------------------------
  // PROGRESS INDICATOR
  // ----------------------------------------------------------
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.primary,
    linearTrackColor: AppColors.neutral200,
  ),

  // ----------------------------------------------------------
  // CARD THEME
  //
  // IMPORTANT:
  // Current Flutter version uses CardThemeData.
  // ----------------------------------------------------------
  cardTheme: CardThemeData(
    color: AppColors.surfaceLight,

    elevation: 2,

    shadowColor: AppColors.shadow1,

    surfaceTintColor: Colors.transparent,

    margin: EdgeInsets.zero,

    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_borderRadius),
    ),

    clipBehavior: Clip.antiAlias,
  ),

  // ----------------------------------------------------------
  // INPUT / TEXT FIELD
  // ----------------------------------------------------------
  inputDecorationTheme: InputDecorationTheme(
    filled: true,

    fillColor: AppColors.surfaceVariantLight,

    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),

    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: BorderSide.none,
    ),

    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: BorderSide.none,
    ),

    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),

    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),

    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),

    hintStyle: AppTextStyles.hint.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.textTertiaryLight,
    ),

    labelStyle: AppTextStyles.label.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.textPrimaryLight,
    ),

    errorStyle: AppTextStyles.error.copyWith(fontFamily: _fontFamily),
  ),

  // ----------------------------------------------------------
  // BOTTOM NAVIGATION
  // ----------------------------------------------------------
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: AppColors.surfaceLight,

    selectedItemColor: AppColors.primary,

    unselectedItemColor: AppColors.textSecondaryLight,

    selectedLabelStyle: AppTextStyles.navigationSelected.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.primary,
    ),

    unselectedLabelStyle: AppTextStyles.navigationUnselected.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.textSecondaryLight,
    ),

    type: BottomNavigationBarType.fixed,

    elevation: 8,
  ),

  // ----------------------------------------------------------
  // CHIP
  // ----------------------------------------------------------
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.primaryTint,

    selectedColor: AppColors.primaryTintStrong,

    labelStyle: AppTextStyles.bodySmall.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.textPrimaryLight,
    ),

    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
    ),

    side: BorderSide.none,
  ),

  // ----------------------------------------------------------
  // DIVIDER
  // ----------------------------------------------------------
  dividerTheme: const DividerThemeData(
    color: AppColors.dividerLight,
    thickness: 1,
    space: 1,
  ),

  // ----------------------------------------------------------
  // SWITCH
  // ----------------------------------------------------------
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.selected)) {
        return Colors.white;
      }

      return AppColors.neutral500;
    }),

    trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.primary;
      }

      return AppColors.neutral300;
    }),

    trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.primary;
      }

      return AppColors.neutral400;
    }),
  ),

  // ----------------------------------------------------------
  // SNACKBAR
  // ----------------------------------------------------------
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,

    backgroundColor: const Color(0xFF1E1E1E),

    elevation: 6,

    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

    contentTextStyle: const TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
  ),
);

// ============================================================
// DARK THEME
// ============================================================

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: _fontFamily,

  // ----------------------------------------------------------
  // MAIN COLORS
  // ----------------------------------------------------------
  scaffoldBackgroundColor: AppColors.backgroundDark,
  primaryColor: AppColors.primary,

  colorScheme: ColorScheme.dark(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.surfaceDark,
    error: AppColors.error,

    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: AppColors.textPrimaryDark,
    onError: Colors.white,
  ),

  // ----------------------------------------------------------
  // TYPOGRAPHY
  // ----------------------------------------------------------
  textTheme:
      TextTheme(
        displayLarge: AppTextStyles.h1,
        displayMedium: AppTextStyles.h2,
        displaySmall: AppTextStyles.h3,
        headlineMedium: AppTextStyles.h4,

        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,

        labelLarge: AppTextStyles.button,
      ).apply(
        fontFamily: _fontFamily,
        bodyColor: AppColors.textPrimaryDark,
        displayColor: AppColors.textPrimaryDark,
      ),

  // ----------------------------------------------------------
  // APP BAR
  // ----------------------------------------------------------
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,

    iconTheme: IconThemeData(color: Colors.white),

    titleTextStyle: TextStyle(
      fontFamily: _fontFamily,
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
  ),

  // ----------------------------------------------------------
  // ELEVATED BUTTON
  // ----------------------------------------------------------
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryButton,
      foregroundColor: Colors.white,

      minimumSize: const Size(double.infinity, _buttonHeight),

      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),

      textStyle: AppTextStyles.button.copyWith(
        fontFamily: _fontFamily,
        color: Colors.white,
      ),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonBorderRadius),
      ),

      elevation: 0,
    ),
  ),

  // ----------------------------------------------------------
  // OUTLINED BUTTON
  // ----------------------------------------------------------
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,

      minimumSize: const Size(double.infinity, _buttonHeight),

      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),

      side: const BorderSide(color: AppColors.primary, width: 1.5),

      textStyle: AppTextStyles.buttonSmall.copyWith(fontFamily: _fontFamily),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonBorderRadius),
      ),
    ),
  ),

  // ----------------------------------------------------------
  // TEXT BUTTON
  // ----------------------------------------------------------
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,

      textStyle: AppTextStyles.buttonSmall.copyWith(fontFamily: _fontFamily),
    ),
  ),

  // ----------------------------------------------------------
  // PROGRESS INDICATOR
  // ----------------------------------------------------------
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.primary,
  ),

  // ----------------------------------------------------------
  // CARD THEME
  // ----------------------------------------------------------
  cardTheme: CardThemeData(
    color: AppColors.surfaceDark,

    elevation: 0,

    surfaceTintColor: Colors.transparent,

    margin: EdgeInsets.zero,

    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_borderRadius),
    ),

    clipBehavior: Clip.antiAlias,
  ),

  // ----------------------------------------------------------
  // INPUT / TEXT FIELD
  // ----------------------------------------------------------
  inputDecorationTheme: InputDecorationTheme(
    filled: true,

    fillColor: AppColors.surfaceVariantDark,

    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),

    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: BorderSide.none,
    ),

    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: BorderSide.none,
    ),

    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),

    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),

    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),

    hintStyle: AppTextStyles.hint.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.textSecondaryDark,
    ),

    labelStyle: AppTextStyles.label.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.textPrimaryDark,
    ),

    errorStyle: AppTextStyles.error.copyWith(fontFamily: _fontFamily),
  ),

  // ----------------------------------------------------------
  // BOTTOM NAVIGATION
  // ----------------------------------------------------------
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: AppColors.surfaceDark,

    selectedItemColor: AppColors.primary,

    unselectedItemColor: AppColors.textSecondaryDark,

    selectedLabelStyle: AppTextStyles.navigationSelected.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.primary,
    ),

    unselectedLabelStyle: AppTextStyles.navigationUnselected.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.textSecondaryDark,
    ),

    type: BottomNavigationBarType.fixed,

    elevation: 8,
  ),

  // ----------------------------------------------------------
  // CHIP
  // ----------------------------------------------------------
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.surfaceVariantDark,

    selectedColor: AppColors.primaryTintDarkStrong,

    labelStyle: AppTextStyles.bodySmall.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.textPrimaryDark,
    ),

    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
    ),

    side: BorderSide.none,
  ),

  // ----------------------------------------------------------
  // DIVIDER
  // ----------------------------------------------------------
  dividerTheme: const DividerThemeData(
    color: AppColors.borderDark,
    thickness: 1,
    space: 1,
  ),

  // ----------------------------------------------------------
  // SWITCH
  // ----------------------------------------------------------
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.selected)) {
        return Colors.white;
      }

      return AppColors.neutral500;
    }),

    trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.primary;
      }

      return AppColors.darkContainer;
    }),

    trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.primary;
      }

      return AppColors.darkBorder;
    }),
  ),

  // ----------------------------------------------------------
  // SNACKBAR
  // ----------------------------------------------------------
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,

    backgroundColor: const Color(0xFF2C2C2C),

    elevation: 6,

    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

    contentTextStyle: const TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
  ),
);
