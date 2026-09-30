import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/restaurant_model.dart';
import '../../branding/app_colors.dart';
import '../../cart/widgets/floating_view_cart_bar.dart';
import '../../common_widgets/smart_image.dart';
import '../../home/viewmodels/home_viewmodel.dart';
import '../../home/widgets/restaurant_card.dart';
import '../../navigation/route_names.dart';

class AllOffersScreen extends ConsumerWidget {
  const AllOffersScreen({super.key});

  static const List<Map<String, String>> _topOfferDishes = [
    {
      'name': 'Biryani',
      'query': 'biryani',
      'fallbackUrl':
          'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=300&auto=format&fit=crop',
    },
    {
      'name': 'Pizza',
      'query': 'pizza',
      'fallbackUrl':
          'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=300&auto=format&fit=crop',
    },
    {
      'name': 'North Indian',
      'query': 'north',
      'fallbackUrl':
          'https://images.unsplash.com/photo-1610192244261-3f33de3f55e4?w=300&auto=format&fit=crop',
    },
    {
      'name': 'Sandwich',
      'query': 'sandwich',
      'fallbackUrl':
          'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=300&auto=format&fit=crop',
    },
    {
      'name': 'Burger',
      'query': 'burger',
      'fallbackUrl':
          'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=300&auto=format&fit=crop',
    },
    {
      'name': 'Chinese',
      'query': 'chinese',
      'fallbackUrl':
          'https://images.unsplash.com/photo-1585032226651-759b368d7246?w=300&auto=format&fit=crop',
    },
    {
      'name': 'Paneer',
      'query': 'paneer',
      'fallbackUrl':
          'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=300&auto=format&fit=crop',
    },
    {
      'name': 'Momo',
      'query': 'momo',
      'fallbackUrl':
          'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=300&auto=format&fit=crop',
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final homeState = ref.watch(homeViewModelProvider);
    final allRestaurants = homeState.nearbyRestaurants.asData?.value ?? [];
    final categories = homeState.categories.asData?.value ?? [];

    // Filter restaurants with offers or top rated
    final offerRestaurants = allRestaurants.isNotEmpty
        ? allRestaurants
        : <RestaurantModel>[];

    // For slideable "BEST OFFERS FOR YOU"
    final bestOffersList = offerRestaurants.isNotEmpty
        ? offerRestaurants
        : <RestaurantModel>[];

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // 1. Top Stylized "GREAT OFFERS" Header Banner
              SliverToBoxAdapter(
                child: _buildHeaderBanner(context, isDark),
              ),

              // 2. "─── BEST OFFERS FOR YOU ───" Section (Slideable)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 8.h),
                    _buildSectionHeader('BEST OFFERS FOR YOU', isDark),
                    SizedBox(height: 12.h),
                    _buildBestOffersSlider(context, bestOffersList, isDark),
                    SizedBox(height: 20.h),
                  ],
                ),
              ),

              // 3. "─── TOP DISHES ON OFFERS ───" Section
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildSectionHeader('TOP DISHES ON OFFERS', isDark),
                    SizedBox(height: 14.h),
                    _buildTopDishesGrid(context, categories, isDark),
                    SizedBox(height: 22.h),
                  ],
                ),
              ),

              // 4. All Restaurants with Offers
              if (offerRestaurants.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${offerRestaurants.length} RESTAURANTS WITH OFFERS',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          'All Great Deals Near You',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 12.h),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final rest = offerRestaurants[index];
                      return RestaurantCard(
                        restaurant: rest,
                        index: index,
                      );
                    },
                    childCount: offerRestaurants.length,
                  ),
                ),
              ],

              // Bottom padding for View Cart Bar
              SliverToBoxAdapter(
                child: SizedBox(height: 100.h),
              ),
            ],
          ),

          // Floating View Cart Bar
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

  // ==================== 1. TOP HEADER BANNER ====================

  Widget _buildHeaderBanner(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  const Color(0xFF1E293B),
                  const Color(0xFF0F172A),
                  AppColors.backgroundDark,
                ]
              : [
                  const Color(0xFFB3D4FE),
                  const Color(0xFFD6E8FD),
                  const Color(0xFFEFF6FF),
                  Colors.white,
                ],
          stops: const [0.0, 0.45, 0.82, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar with Back Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Haptics.light();
                      context.pop();
                    },
                    child: Container(
                      width: 36.r,
                      height: 36.r,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.38),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 20.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stylized "GREAT %FFERS" Title with Sparkles
            Padding(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Top Left Sparkle
                  Positioned(
                    left: 28.w,
                    top: -4.h,
                    child: Icon(
                      Icons.auto_awesome,
                      color: const Color(0xFF3B82F6),
                      size: 20.sp,
                    ),
                  ),

                  // Bottom Right Sparkle
                  Positioned(
                    right: 32.w,
                    bottom: 0,
                    child: Icon(
                      Icons.auto_awesome,
                      color: const Color(0xFF60A5FA),
                      size: 20.sp,
                    ),
                  ),

                  // Title Text Column
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'GREAT',
                        style: TextStyle(
                          fontSize: 40.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.2,
                          color: const Color(0xFF2563EB),
                          shadows: [
                            Shadow(
                              color: const Color(0xFF1D4ED8).withValues(alpha: 0.18),
                              offset: const Offset(0, 3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Stylized % Icon Badge
                          Container(
                            margin: EdgeInsets.only(right: 2.w),
                            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(8.r),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.32),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '%',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 28.sp,
                                height: 1.05,
                              ),
                            ),
                          ),
                          Text(
                            'FFERS',
                            style: TextStyle(
                              fontSize: 44.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.2,
                              color: const Color(0xFF2563EB),
                              shadows: [
                                Shadow(
                                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.18),
                                  offset: const Offset(0, 3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 10.h),
          ],
        ),
      ),
    );
  }

  // ==================== SECTION DIVIDER ====================

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 22.w),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1.2,
              color: isDark ? AppColors.borderDark : const Color(0xFFD1D5DB),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: isDark ? Colors.white70 : const Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1.2,
              color: isDark ? AppColors.borderDark : const Color(0xFFD1D5DB),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 2. BEST OFFERS FOR YOU SLIDER ====================

  Widget _buildBestOffersSlider(
    BuildContext context,
    List<RestaurantModel> restaurants,
    bool isDark,
  ) {
    if (restaurants.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 20.h),
        child: Center(
          child: Text(
            'Finding best offers near you...',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    final columnCount = (restaurants.length / 2).ceil();

    return SizedBox(
      height: 278.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: columnCount,
        itemBuilder: (context, colIndex) {
          final topIndex = colIndex * 2;
          final bottomIndex = topIndex + 1;
          final topRestaurant = restaurants[topIndex];
          final bottomRestaurant =
              bottomIndex < restaurants.length ? restaurants[bottomIndex] : null;

          return Container(
            width: 142.w,
            margin: EdgeInsets.only(right: 12.w),
            child: Column(
              children: [
                _buildOfferCard(context, topRestaurant, topIndex, isDark),
                SizedBox(height: 10.h),
                if (bottomRestaurant != null)
                  _buildOfferCard(context, bottomRestaurant, bottomIndex, isDark)
                else
                  SizedBox(height: 132.h),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOfferCard(
    BuildContext context,
    RestaurantModel r,
    int index,
    bool isDark,
  ) {
    final offerText = r.offerBadges.isNotEmpty
        ? r.offerBadges.first
        : (index % 2 == 0 ? 'Flat ₹100 OFF' : '50% OFF up to ₹100');
    final rating = r.rating > 0 ? r.rating : 4.0;
    final isFast = r.isNearAndFast ||
        r.deliveryTime.contains('10') ||
        r.deliveryTime.contains('15') ||
        r.deliveryTime.contains('20');

    return GestureDetector(
      onTap: () {
        Haptics.light();
        context.push(RouteNames.restaurantDetail, extra: r);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 132.h,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with Offer Badge + Rating Pill
            SizedBox(
              height: 80.h,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(9.r)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SmartImage(
                      url: r.imageUrl.isNotEmpty
                          ? r.imageUrl
                          : (r.coverImages.isNotEmpty ? r.coverImages.first : ''),
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
                              Colors.black.withValues(alpha: 0.35),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.50),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Top Left: Black Offer Badge
                    Positioned(
                      top: 5.h,
                      left: 5.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.80),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          offerText,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),

                    // Bottom Left: Green Rating Pill
                    Positioned(
                      bottom: 5.h,
                      left: 5.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 4.5.w, vertical: 1.5.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F8A43),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              rating.toStringAsFixed(1),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8.5.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 2.w),
                            Icon(
                              Icons.star_rounded,
                              size: 9.sp,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content below image: Restaurant name & Delivery time
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      if (isFast)
                        Icon(
                          Icons.bolt_rounded,
                          size: 12.sp,
                          color: const Color(0xFF0F8A43),
                        )
                      else
                        Icon(
                          Icons.access_time_rounded,
                          size: 10.sp,
                          color: Colors.grey[600],
                        ),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          r.deliveryTime.isNotEmpty ? r.deliveryTime : '25-30 mins',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.w600,
                            color: isFast
                                ? const Color(0xFF0F8A43)
                                : (isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 3. TOP DISHES ON OFFERS ====================

  Widget _buildTopDishesGrid(
    BuildContext context,
    List<CategoryModel> categories,
    bool isDark,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10.w,
          mainAxisSpacing: 18.h,
          childAspectRatio: 0.82,
        ),
        itemCount: _topOfferDishes.length,
        itemBuilder: (context, index) {
          final dish = _topOfferDishes[index];
          final dishName = dish['name']!;
          final query = dish['query']!;

          // Lookup matching category from backend categories
          final matchedCategory = categories.firstWhere(
            (c) => c.name.toLowerCase().contains(query),
            orElse: () => CategoryModel(
              id: '',
              name: dishName,
              imageUrl: dish['fallbackUrl']!,
              slug: query,
            ),
          );

          final imageUrl = matchedCategory.imageUrl.isNotEmpty
              ? matchedCategory.imageUrl
              : dish['fallbackUrl']!;

          return GestureDetector(
            onTap: () {
              Haptics.light();
              context.push(RouteNames.categoryDetails, extra: matchedCategory);
            },
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Circular Dish Image Plate
                Container(
                  width: 62.r,
                  height: 62.r,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: SmartImage(
                      url: imageUrl,
                      category: ImageCategory.category,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                SizedBox(height: 6.h),

                // Dish Name
                Text(
                  dishName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : const Color(0xFF374151),
                    height: 1.15,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
