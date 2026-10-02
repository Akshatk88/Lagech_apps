import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/restaurant_model.dart';
import '../../common_widgets/smart_image.dart';

class SpotlightCarousel extends StatefulWidget {
  final List<RestaurantModel> restaurants;
  final Function(RestaurantModel) onRestaurantTap;

  const SpotlightCarousel({
    super.key,
    required this.restaurants,
    required this.onRestaurantTap,
  });

  @override
  State<SpotlightCarousel> createState() => _SpotlightCarouselState();
}

class _SpotlightCarouselState extends State<SpotlightCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  List<RestaurantModel> get _spotlightItems {
    if (widget.restaurants.isEmpty) return [];
    // Take up to 5 restaurants with good ratings or offers
    return widget.restaurants.take(5).toList();
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
    _startTimer();
  }

  void _startTimer() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _spotlightItems.length <= 1) return;
      final nextPage = (_currentPage + 1) % _spotlightItems.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _spotlightItems;
    if (items.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            'IN THE SPOTLIGHT',
            style: TextStyle(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
        ),
        SizedBox(height: 10.h),
        SizedBox(
          height: 155.h,
          child: PageView.builder(
            controller: _pageController,
            itemCount: items.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final restaurant = items[index];
              final rating = restaurant.rating;
              final offer = restaurant.offerBadges.isNotEmpty
                  ? restaurant.offerBadges.first
                  : '';

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 5.w),
                child: GestureDetector(
                  onTap: () {
                    Haptics.light();
                    widget.onRestaurantTap(restaurant);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.r),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image
                        SmartImage(
                          url: restaurant.imageUrl.isNotEmpty
                              ? restaurant.imageUrl
                              : (restaurant.coverImages.isNotEmpty
                                  ? restaurant.coverImages.first
                                  : ''),
                          category: ImageCategory.restaurant,
                          fit: BoxFit.cover,
                        ),

                        // Gradient Shade
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.2),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.82),
                                ],
                                stops: const [0.0, 0.35, 1.0],
                              ),
                            ),
                          ),
                        // Closed Overlay
                        if (!restaurant.isOpen)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.52),
                              child: Center(
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                  decoration: BoxDecoration(
                                    color: const Color(0xEFDC2626),
                                    borderRadius: BorderRadius.circular(8.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_clock_rounded, size: 14.sp, color: Colors.white),
                                      SizedBox(width: 5.w),
                                      Text(
                                        'CURRENTLY CLOSED',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5.sp,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Top Row: Crown badge + Bookmark icon
                        Positioned(
                          top: 10.h,
                          left: 12.w,
                          right: 12.w,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: EdgeInsets.all(4.r),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.workspace_premium_rounded,
                                  color: const Color(0xFFFFB800),
                                  size: 16.sp,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.all(4.r),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.bookmark_border_rounded,
                                  color: Colors.white,
                                  size: 16.sp,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Bottom Info: Offer, Rating, Restaurant Name
                        Positioned(
                          left: 14.w,
                          right: 14.w,
                          bottom: 12.h,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      offer,
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F8A43),
                                      borderRadius: BorderRadius.circular(6.r),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          rating > 0 ? rating.toStringAsFixed(1) : 'New',
                                          style: TextStyle(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 2.w),
                                        Icon(
                                          Icons.star_rounded,
                                          size: 10.sp,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                restaurant.name,
                                style: TextStyle(
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
