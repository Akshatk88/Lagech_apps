import 'package:flutter/material.dart';
import 'package:food_user_application/config/theme/app_colors.dart';

/// A red icon on a soft red circle — the app's stand-in for illustrations, so
/// headers and empty states stay in the red & white theme.
class BrandIconBadge extends StatelessWidget {
  const BrandIconBadge({
    super.key,
    required this.icon,
    this.size = 64,
    this.color = AppColors.primary,
  });

  final IconData icon;

  /// Diameter of the circle; the icon is drawn at roughly half of it.
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.primaryTintDarkStrong, AppColors.primaryTintDark]
              : [AppColors.primaryTintStrong, AppColors.primaryTint],
        ),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}
