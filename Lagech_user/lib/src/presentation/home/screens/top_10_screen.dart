import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/restaurant_model.dart';
import '../../branding/app_colors.dart';
import '../../cart/widgets/floating_view_cart_bar.dart';
import '../../common_widgets/app_refresh_indicator.dart';
import '../../common_widgets/skeleton_loading.dart';
import '../../navigation/back_navigation.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/restaurant_card.dart';

/// Screen displayed when user taps "Top 10" / "Top Orders".
/// Features the signature warm golden gradient header with "Top 10" headline,
/// subtitle, star location pin badge, and the list of top 10 rated restaurants.
class Top10Screen extends ConsumerWidget {
  const Top10Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final homeState = ref.watch(homeViewModelProvider);
    final restaurantsAsync = homeState.nearbyRestaurants;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          AppRefreshIndicator(
            onRefresh: () async {
              await ref.read(homeViewModelProvider.notifier).loadHomeData(isRefresh: true);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // 1. Signature Golden Header Banner
                SliverToBoxAdapter(
                  child: _buildGoldenHeader(context, isDark),
                ),

                // 2. Top 10 Restaurant Cards List
                restaurantsAsync.when(
                  loading: () => SliverPadding(
                    padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 30.h),
                    sliver: const SliverToBoxAdapter(
                      child: SkeletonRestaurantList(count: 3),
                    ),
                  ),
                  error: (err, stack) => SliverToBoxAdapter(
                    child: _buildErrorState(context, ref, isDark),
                  ),
                  data: (restaurants) {
                    // Sort restaurants by rating descending (highest rated first)
                    final sorted = List<RestaurantModel>.from(restaurants);
                    sorted.sort((a, b) {
                      final cmp = b.rating.compareTo(a.rating);
                      if (cmp != 0) return cmp;
                      return b.reviewCount.compareTo(a.reviewCount);
                    });

                    // Limit to Top 10
                    final top10List = sorted.take(10).toList();

                    if (top10List.isEmpty) {
                      return SliverToBoxAdapter(
                        child: _buildEmptyState(context, ref, isDark),
                      );
                    }

                    return SliverPadding(
                      padding: EdgeInsets.only(top: 14.h, bottom: 90.h),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return RestaurantCard(
                              restaurant: top10List[index],
                              index: index,
                            );
                          },
                          childCount: top10List.length,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Floating View Cart Bar at bottom if cart has items
          FloatingViewCartBar(
            bottomOffset: 16.h,
            onTap: () {
              Haptics.light();
              context.push(RouteNames.cart);
            },
          ),
        ],
      ),
    );
  }

  // ==================== 1. GOLDEN HEADER BANNER ====================

  Widget _buildGoldenHeader(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  const Color(0xFF382912),
                  const Color(0xFF2B1F0E),
                  const Color(0xFF1E160A),
                  AppColors.backgroundDark,
                ]
              : [
                  const Color(0xFFE2A84E),
                  const Color(0xFFE8B964),
                  const Color(0xFFF3D38D),
                  const Color(0xFFFDF7ED),
                  const Color(0xFFF8F9FA),
                ],
          stops: const [0.0, 0.35, 0.65, 0.90, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Back Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              child: GestureDetector(
                onTap: () {
                  Haptics.light();
                  context.backOr();
                },
                child: Container(
                  width: 38.r,
                  height: 38.r,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.38),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 21.sp,
                  ),
                ),
              ),
            ),

            // Content Row: "Top 10" text + Golden Pin graphic
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 4.h, 12.w, 18.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Side: Title & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top 10',
                          style: TextStyle(
                            fontSize: 34.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: isDark
                                ? const Color(0xFFFFF7ED)
                                : const Color(0xFF261805),
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Discover the best local\nrestaurants near you',
                          style: TextStyle(
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFE8D4A8)
                                : const Color(0xFF6E4C14),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right Side: Glowing Circle with Location Star Pin
                  _buildGoldenPinGraphic(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 2. GOLDEN STAR PIN GRAPHIC ====================

  Widget _buildGoldenPinGraphic(bool isDark) {
    return SizedBox(
      width: 145.w,
      height: 130.h,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Outer subtle glowing aura
          Container(
            width: 130.r,
            height: 130.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? const Color(0xFF4C3615).withValues(alpha: 0.5)
                  : const Color(0xFFFDE8A5).withValues(alpha: 0.65),
            ),
          ),

          // Inner brighter glow circle
          Container(
            width: 100.r,
            height: 100.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? const Color(0xFF63471A).withValues(alpha: 0.6)
                  : const Color(0xFFFCE18F).withValues(alpha: 0.9),
            ),
          ),

          // Floating decorative sparkle particles
          Positioned(
            top: 14.h,
            right: 14.w,
            child: Container(
              width: 5.5.r,
              height: 5.5.r,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE5A122),
              ),
            ),
          ),
          Positioned(
            left: 10.w,
            top: 40.h,
            child: Container(
              width: 4.r,
              height: 4.r,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE5A122),
              ),
            ),
          ),
          Positioned(
            bottom: 20.h,
            left: 18.w,
            child: Container(
              width: 6.r,
              height: 6.r,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE5A122),
              ),
            ),
          ),

          // Golden Map Pin with crisp 5-point white star inside
          CustomPaint(
            size: Size(54.r, 68.r),
            painter: _GoldenMapPinPainter(),
          ),
        ],
      ),
    );
  }

  // ==================== 3. EMPTY & ERROR STATES ====================

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 48.h),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 100.r,
              height: 100.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF5A623).withValues(alpha: 0.12),
              ),
              child: Icon(
                Icons.workspace_premium_rounded,
                size: 52.sp,
                color: const Color(0xFFF5A623),
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              'No Top Restaurants Available',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'We couldn\'t find any restaurants in your area right now.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed: () {
                Haptics.light();
                ref.read(homeViewModelProvider.notifier).loadHomeData(isRefresh: true);
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5A623),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 48.h),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 52.sp,
              color: Colors.redAccent,
            ),
            SizedBox(height: 16.h),
            Text(
              'Could not load restaurants',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            SizedBox(height: 16.h),
            TextButton.icon(
              onPressed: () {
                Haptics.light();
                ref.read(homeViewModelProvider.notifier).loadHomeData(isRefresh: true);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the solid golden location pin with a crisp white star inside.
class _GoldenMapPinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w / 2;

    // Pin shape path: round top circle, smooth cubic curves tapering to bottom point
    final path = Path();
    path.moveTo(w / 2, h); // bottom tip
    path.cubicTo(w * 0.12, h * 0.66, 0, h * 0.44, 0, r);
    path.arcToPoint(
      Offset(w, r),
      radius: Radius.circular(r),
      clockwise: true,
    );
    path.cubicTo(w, h * 0.44, w * 0.88, h * 0.66, w / 2, h);
    path.close();

    // Soft drop shadow
    final shadowPaint = Paint()
      ..color = const Color(0xFF8C5807).withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path.shift(const Offset(0, 3)), shadowPaint);

    // Golden Pin Fill Paint with rich vertical gradient
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFF7B733),
          Color(0xFFF5A623),
          Color(0xFFE89510),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, fillPaint);

    // 5-pointed Star inside head center: (w / 2, r)
    _drawStar(canvas, Offset(w / 2, r), r * 0.52, Colors.white);
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final starPath = Path();
    final innerRadius = radius * 0.42;
    const numPoints = 5;
    final angleStep = 3.141592653589793 / numPoints;
    double currentAngle = -3.141592653589793 / 2; // start from top point

    for (int i = 0; i < numPoints * 2; i++) {
      final r = (i % 2 == 0) ? radius : innerRadius;
      final x = center.dx + r * math.cos(currentAngle);
      final y = center.dy + r * math.sin(currentAngle);
      if (i == 0) {
        starPath.moveTo(x, y);
      } else {
        starPath.lineTo(x, y);
      }
      currentAngle += angleStep;
    }
    starPath.close();

    final starPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(starPath, starPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
