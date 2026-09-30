import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ============================================================
/// APP TEXT STYLES
/// ============================================================
/// Centralized typography configuration for the Lagech app.
///
/// Design:
/// - Strong black headings
/// - Soft grey secondary text
/// - Red brand accents
/// - Bold white primary buttons
/// - Clean mobile-friendly typography
/// ============================================================

class AppTextStyles {
  AppTextStyles._();

  // ============================================================
  // HEADINGS
  // ============================================================

  /// Main page heading.
  /// Example: Profile, Orders, Explore
  static final TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimaryLight,
    height: 1.15,
    letterSpacing: -0.5,
  );

  /// Section heading.
  static final TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimaryLight,
    height: 1.2,
    letterSpacing: -0.3,
  );

  /// Card / section title.
  static final TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
    height: 1.25,
  );

  /// Smaller heading.
  static final TextStyle h4 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
    height: 1.25,
  );

  // ============================================================
  // BODY TEXT
  // ============================================================

  /// Large body text.
  static final TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimaryLight,
    height: 1.45,
  );

  /// Standard body text.
  static final TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryLight,
    height: 1.4,
  );

  /// Small body / helper text.
  static final TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryLight,
    height: 1.35,
  );

  // ============================================================
  // COMPONENT TEXT
  // ============================================================

  /// Primary button text.
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.2,
    height: 1.2,
  );

  /// Large button text.
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.2,
    height: 1.2,
  );

  /// Small button / outlined button text.
  static final TextStyle buttonSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
    letterSpacing: 0.2,
    height: 1.2,
  );

  /// Caption / very small information.
  static final TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryLight,
    letterSpacing: 0.2,
    height: 1.3,
  );

  /// Label used above input fields.
  static final TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
    height: 1.2,
  );

  /// Input text.
  static final TextStyle input = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimaryLight,
    height: 1.3,
  );

  /// Hint text inside input fields.
  static final TextStyle hint = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryLight,
    height: 1.3,
  );

  // ============================================================
  // BRAND TEXT
  // ============================================================

  /// Red highlighted text.
  static final TextStyle brand = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
    height: 1.3,
  );

  /// Large red highlighted text.
  static final TextStyle brandLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
    height: 1.2,
  );

  // ============================================================
  // CARD / LIST TEXT
  // ============================================================

  /// Main title inside cards and list tiles.
  static final TextStyle cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
    height: 1.25,
  );

  /// Secondary information inside cards.
  static final TextStyle cardSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryLight,
    height: 1.35,
  );

  /// Important value such as balance, price or count.
  static final TextStyle cardValue = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimaryLight,
    height: 1.2,
  );

  /// Price / amount highlighted in Lagech red.
  static final TextStyle price = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
    height: 1.2,
  );

  // ============================================================
  // NAVIGATION
  // ============================================================

  /// Bottom navigation selected item.
  static final TextStyle navigationSelected = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
    height: 1.2,
  );

  /// Bottom navigation unselected item.
  static final TextStyle navigationUnselected = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondaryLight,
    height: 1.2,
  );

  // ============================================================
  // STATUS TEXT
  // ============================================================

  /// Success text.
  ///
  /// Kept independent from AppColors so this file does not
  /// depend on a possibly missing AppColors.success property.
  static const TextStyle success = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Color(0xFF16A34A),
    height: 1.3,
  );

  /// Warning text.
  static const TextStyle warning = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Color(0xFFF59E0B),
    height: 1.3,
  );

  /// Error text.
  static final TextStyle error = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.error,
    height: 1.3,
  );
}
