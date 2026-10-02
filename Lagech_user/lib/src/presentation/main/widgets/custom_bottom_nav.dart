import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';
import '../../navigation/route_names.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Detect current path for non-branch routes (e.g. Orders)
    final currentPath = GoRouter.of(context)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;
    final isOrdersActive = currentPath == RouteNames.orders ||
        currentPath.startsWith('/orders');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 1. Home — Branch 0
              _buildNavItem(
                context: context,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                isSelected: currentIndex == 0 && !isOrdersActive,
                isDark: isDark,
                onItemTap: () => onTap(0),
              ),

              // 2. 99 Store — Branch 2
              _buildNavItem(
                context: context,
                icon: Icons.local_offer_outlined,
                activeIcon: Icons.local_offer_rounded,
                label: '99 Store',
                isSelected: currentIndex == 2,
                isDark: isDark,
                onItemTap: () => onTap(2),
              ),

              // 3. Orders — pushed route (not a shell branch)
              _buildNavItem(
                context: context,
                icon: Icons.restaurant_outlined,
                activeIcon: Icons.restaurant_rounded,
                label: 'Orders',
                isSelected: isOrdersActive,
                isDark: isDark,
                onItemTap: () => context.push(RouteNames.orders),
              ),

              // 4. Profile — Branch 3
              _buildNavItem(
                context: context,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                isSelected: currentIndex == 3 && !isOrdersActive,
                isDark: isDark,
                onItemTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onItemTap,
  }) {
    final activeColor = AppColors.primary;
    final unselectedColor = isDark
        ? AppColors.textSecondaryDark
        : const Color(0xFF9CA3AF);

    return GestureDetector(
      onTap: () {
        Haptics.light();
        onItemTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? activeColor : unselectedColor,
            size: 26.sp,
          ),
          SizedBox(height: 3.h),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? activeColor : unselectedColor,
              fontSize: 10.5.sp,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
