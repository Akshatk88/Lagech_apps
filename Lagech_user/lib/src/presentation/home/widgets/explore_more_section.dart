import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';

class ExploreMoreSection extends StatelessWidget {
  final VoidCallback onOffersTap;
  final VoidCallback onGourmetTap; // Used for Top Hotels
  final VoidCallback onTop10Tap; // Used for New on LAGECH
  final VoidCallback onCollectionsTap; // Used for Popular
  final VoidCallback? onSeeAllTap;

  const ExploreMoreSection({
    super.key,
    required this.onOffersTap,
    required this.onGourmetTap,
    required this.onTop10Tap,
    required this.onCollectionsTap,
    this.onSeeAllTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Subtitle matching screenshot: "EXPLORE MORE"
          Text(
            'EXPLORE MORE',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: 8.h),

          // 4 Cards Row: Offers, Gourmet, Top 10, Collections
          Row(
            children: [
              // Card 1: Offers
              Expanded(
                child: _buildExploreCard(
                  isDark: isDark,
                  bgColor: const Color(0xFFFFF5F5),
                  borderColor: const Color(0xFFFFE4E6),
                  iconWidget: _buildOffersIcon(),
                  title: 'Offers',
                  onTap: onOffersTap,
                ),
              ),
              SizedBox(width: 6.w),

              // Card 2: Gourmet
              Expanded(
                child: _buildExploreCard(
                  isDark: isDark,
                  bgColor: const Color(0xFFFFFDF5),
                  borderColor: const Color(0xFFFEF3C7),
                  iconWidget: _buildTopHotelsIcon(),
                  title: 'Gourmet',
                  onTap: onGourmetTap,
                ),
              ),
              SizedBox(width: 6.w),

              // Card 3: Top 10
              Expanded(
                child: _buildExploreCard(
                  isDark: isDark,
                  bgColor: isDark ? const Color(0xFF281E10) : const Color(0xFFFFFBEB),
                  borderColor: isDark ? const Color(0xFF4A3618) : const Color(0xFFFDE68A),
                  iconWidget: _buildTop10Icon(),
                  title: 'Top 10',
                  onTap: onTop10Tap,
                ),
              ),
              SizedBox(width: 6.w),

              // Card 4: Collections
              Expanded(
                child: _buildExploreCard(
                  isDark: isDark,
                  bgColor: const Color(0xFFFFF5F5),
                  borderColor: const Color(0xFFFFE4E6),
                  iconWidget: _buildPopularIcon(),
                  title: 'Collections',
                  onTap: onCollectionsTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExploreCard({
    required bool isDark,
    required Color bgColor,
    required Color borderColor,
    required Widget iconWidget,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        Haptics.light();
        onTap();
      },
      child: Container(
        height: 76.h,
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : bgColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isDark ? AppColors.borderDark : borderColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon
            SizedBox(
              height: 30.h,
              child: Center(child: iconWidget),
            ),
            SizedBox(height: 4.h),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Offers Icon: 3D Red Discount Tag with % and Sparkles
  Widget _buildOffersIcon() {
    return SizedBox(
      width: 38.w,
      height: 38.h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 1.h,
            right: 2.w,
            child: Icon(
              Icons.auto_awesome,
              size: 10.sp,
              color: const Color(0xFFE50914).withValues(alpha: 0.85),
            ),
          ),
          Positioned(
            bottom: 4.h,
            left: 2.w,
            child: Container(
              width: 3.r,
              height: 3.r,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE50914),
              ),
            ),
          ),
          Transform.rotate(
            angle: -0.26,
            child: Container(
              width: 27.w,
              height: 29.h,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF2A3A),
                    Color(0xFFDC0914),
                    Color(0xFFB0030C),
                  ],
                ),
                borderRadius: BorderRadius.circular(6.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC0914).withValues(alpha: 0.35),
                    blurRadius: 5,
                    offset: const Offset(1, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 4.r,
                    height: 4.r,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    '%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Top Hotels Icon: 3D Golden Trophy Cup with Star Badge
  Widget _buildTopHotelsIcon() {
    return SizedBox(
      width: 38.w,
      height: 38.h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Golden trophy icon
          Icon(
            Icons.emoji_events_rounded,
            size: 34.sp,
            color: const Color(0xFFF59E0B),
          ),
          // Star badge in center of cup
          Positioned(
            top: 10.h,
            child: Container(
              padding: EdgeInsets.all(1.5.r),
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star_rounded,
                size: 7.5.sp,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Top 10 Icon: Golden Location Pin with Star Badge
  Widget _buildTop10Icon() {
    return SizedBox(
      width: 38.w,
      height: 38.h,
      child: Center(
        child: Container(
          width: 32.w,
          height: 32.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFCD34D),
                Color(0xFFF59E0B),
                Color(0xFFD97706),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 22.sp,
                color: Colors.white,
              ),
              Positioned(
                top: 4.h,
                child: Icon(
                  Icons.star_rounded,
                  size: 11.sp,
                  color: const Color(0xFFD97706),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 4. Popular Icon: 3D Fire Flame with Gradient
  Widget _buildPopularIcon() {
    return SizedBox(
      width: 38.w,
      height: 38.h,
      child: Center(
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFDE047), // Bright yellow
              Color(0xFFF97316), // Orange
              Color(0xFFEF4444), // Vibrant red
            ],
          ).createShader(bounds),
          child: Icon(
            Icons.local_fire_department_rounded,
            size: 34.sp,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
