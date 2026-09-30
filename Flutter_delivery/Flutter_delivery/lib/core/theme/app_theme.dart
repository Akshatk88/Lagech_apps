import 'package:flutter/material.dart';

import 'package:food_user_application/core/constants/app_constants.dart';

class AppTheme {
  // ============================================================
  // CORE COLORS - MATCHING THE SCREENSHOT
  // ============================================================

  // Main brand red
  static const Color primaryColor = Color(0xFFF20D16);

  // Slightly darker red for pressed/active states
  static const Color primaryDark = Color(0xFFD90008);

  // Light red/pink tint used behind icons
  static const Color primaryTint = Color(0xFFFFEFF0);

  // Accent yellow/orange used for offers and special items
  static const Color secondaryColor = Color.fromARGB(255, 246, 29, 32);

  // Light yellow background
  static const Color secondaryTint = Color(0xFFFFF6E3);

  // ------------------------------------------------------------
  // LIGHT MODE
  // ------------------------------------------------------------

  static const Color lightBackground = Color(0xFFFAFAFA);

  static const Color lightCard = Color(0xFFFFFFFF);

  static const Color lightSurface = Color(0xFFFFFFFF);

  static const Color lightText = Color(0xFF111111);

  static const Color lightSecondaryText = Color(0xFF858585);

  static const Color lightBorder = Color(0xFFEDEDED);

  // ------------------------------------------------------------
  // DARK MODE
  // ------------------------------------------------------------

  static const Color darkBackground = Color(0xFF121212);

  static const Color darkCard = Color(0xFF1E1E1E);

  static const Color darkSurface = Color(0xFF242424);

  static const Color darkText = Color(0xFFFFFFFF);

  static const Color darkSecondaryText = Color(0xFFBDBDBD);

  static const Color darkBorder = Color(0xFF333333);

  // Bottom navigation from screenshot
  static const Color lightNavBackground = Color(0xFF111111);

  static const Color darkNavBackground = Color(0xFF080808);

  // ============================================================
  // LIGHT THEME
  // ============================================================

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      fontFamily: AppConstants.appFontFamily,

      brightness: Brightness.light,

      primaryColor: primaryColor,

      scaffoldBackgroundColor: lightBackground,

      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,

        secondary: secondaryColor,
        onSecondary: Colors.white,

        surface: lightSurface,
        onSurface: lightText,

        error: primaryColor,
        onError: Colors.white,
      ),

      // --------------------------------------------------------
      // APP BAR
      // --------------------------------------------------------
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,

        centerTitle: false,

        iconTheme: IconThemeData(color: lightText, size: 26),

        titleTextStyle: TextStyle(
          color: lightText,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),

      // --------------------------------------------------------
      // CARD
      // --------------------------------------------------------
      cardTheme: const CardThemeData(
        color: lightCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),

      // --------------------------------------------------------
      // ICON THEME
      // --------------------------------------------------------
      iconTheme: const IconThemeData(color: lightText, size: 24),

      // --------------------------------------------------------
      // INPUT FIELDS
      // --------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightCard,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: lightBorder),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: lightBorder),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),

        hintStyle: const TextStyle(color: lightSecondaryText, fontSize: 14),

        labelStyle: const TextStyle(color: lightSecondaryText, fontSize: 14),
      ),

      // --------------------------------------------------------
      // ELEVATED BUTTON
      // --------------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,

          elevation: 0,

          minimumSize: const Size(double.infinity, 52),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),

          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      // --------------------------------------------------------
      // TEXT BUTTON
      // --------------------------------------------------------
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,

          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // --------------------------------------------------------
      // OUTLINED BUTTON
      // --------------------------------------------------------
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,

          side: const BorderSide(color: primaryColor, width: 1.2),

          minimumSize: const Size(double.infinity, 52),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),

          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      // --------------------------------------------------------
      // BOTTOM NAVIGATION
      // Screenshot: black rounded navigation bar
      // --------------------------------------------------------
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightNavBackground,

        selectedItemColor: Colors.white,

        unselectedItemColor: Colors.white,

        type: BottomNavigationBarType.fixed,

        elevation: 0,

        selectedLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),

        unselectedLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),

      // --------------------------------------------------------
      // DIVIDER
      // --------------------------------------------------------
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),

      // --------------------------------------------------------
      // CHIP
      // --------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: primaryTint,

        selectedColor: primaryColor,

        disabledColor: lightBorder,

        labelStyle: const TextStyle(
          color: lightText,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),

        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),

        side: BorderSide.none,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // --------------------------------------------------------
      // SWITCH
      // --------------------------------------------------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }

          return Colors.grey.shade500;
        }),

        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }

          return const Color(0xFFE0E0E0);
        }),

        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      // --------------------------------------------------------
      // CHECKBOX
      // --------------------------------------------------------
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }

          return Colors.transparent;
        }),

        checkColor: const WidgetStatePropertyAll(Colors.white),

        side: const BorderSide(color: lightSecondaryText, width: 1.5),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),

      // --------------------------------------------------------
      // RADIO
      // --------------------------------------------------------
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }

          return lightSecondaryText;
        }),
      ),

      // --------------------------------------------------------
      // PROGRESS INDICATOR
      // --------------------------------------------------------
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: primaryTint,
      ),

      // --------------------------------------------------------
      // FLOATING ACTION BUTTON
      // --------------------------------------------------------
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 3,
      ),

      // --------------------------------------------------------
      // SNACKBAR
      // --------------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF222222),

        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),

        behavior: SnackBarBehavior.floating,

        elevation: 4,
      ),
    );
  }

  // ============================================================
  // DARK THEME
  // ============================================================

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,

      fontFamily: AppConstants.appFontFamily,

      brightness: Brightness.dark,

      primaryColor: primaryColor,

      scaffoldBackgroundColor: darkBackground,

      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        onPrimary: Colors.white,

        secondary: secondaryColor,
        onSecondary: Colors.white,

        surface: darkSurface,
        onSurface: darkText,

        error: primaryColor,
        onError: Colors.white,
      ),

      // --------------------------------------------------------
      // APP BAR
      // --------------------------------------------------------
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,

        centerTitle: false,

        iconTheme: IconThemeData(color: darkText, size: 26),

        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),

      // --------------------------------------------------------
      // CARD
      // --------------------------------------------------------
      cardTheme: const CardThemeData(
        color: darkCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),

      // --------------------------------------------------------
      // ICON
      // --------------------------------------------------------
      iconTheme: const IconThemeData(color: darkText, size: 24),

      // --------------------------------------------------------
      // INPUT
      // --------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,

        fillColor: darkCard,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkBorder),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkBorder),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),

        hintStyle: const TextStyle(color: darkSecondaryText, fontSize: 14),

        labelStyle: const TextStyle(color: darkSecondaryText, fontSize: 14),
      ),

      // --------------------------------------------------------
      // ELEVATED BUTTON
      // --------------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,

          elevation: 0,

          minimumSize: const Size(double.infinity, 52),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),

          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      // --------------------------------------------------------
      // TEXT BUTTON
      // --------------------------------------------------------
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,

          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // --------------------------------------------------------
      // OUTLINED BUTTON
      // --------------------------------------------------------
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,

          side: const BorderSide(color: primaryColor, width: 1.2),

          minimumSize: const Size(double.infinity, 52),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),

          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      // --------------------------------------------------------
      // BOTTOM NAVIGATION
      // --------------------------------------------------------
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkNavBackground,

        selectedItemColor: Colors.white,

        unselectedItemColor: Colors.white,

        type: BottomNavigationBarType.fixed,

        elevation: 0,

        selectedLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),

        unselectedLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),

      // --------------------------------------------------------
      // DIVIDER
      // --------------------------------------------------------
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),

      // --------------------------------------------------------
      // CHIP
      // --------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF3A2020),

        selectedColor: primaryColor,

        disabledColor: darkBorder,

        labelStyle: const TextStyle(
          color: darkText,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),

        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),

        side: BorderSide.none,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // --------------------------------------------------------
      // SWITCH
      // --------------------------------------------------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }

          return Colors.grey.shade500;
        }),

        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }

          return const Color(0xFF444444);
        }),

        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      // --------------------------------------------------------
      // CHECKBOX
      // --------------------------------------------------------
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }

          return Colors.transparent;
        }),

        checkColor: const WidgetStatePropertyAll(Colors.white),

        side: const BorderSide(color: darkSecondaryText, width: 1.5),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),

      // --------------------------------------------------------
      // RADIO
      // --------------------------------------------------------
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }

          return darkSecondaryText;
        }),
      ),

      // --------------------------------------------------------
      // PROGRESS
      // --------------------------------------------------------
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: Color(0xFF3A2020),
      ),

      // --------------------------------------------------------
      // FAB
      // --------------------------------------------------------
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 3,
      ),

      // --------------------------------------------------------
      // SNACKBAR
      // --------------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2A2A2A),

        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),

        behavior: SnackBarBehavior.floating,

        elevation: 4,
      ),
    );
  }
}
