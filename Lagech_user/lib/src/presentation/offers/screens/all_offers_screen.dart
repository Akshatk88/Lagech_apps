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

import '../../coupons/viewmodels/coupons_viewmodel.dart';

class AllOffersScreen extends ConsumerStatefulWidget {
  const AllOffersScreen({super.key});

  @override
  ConsumerState<AllOffersScreen> createState() => _AllOffersScreenState();
}

class _AllOffersScreenState extends ConsumerState<AllOffersScreen> {
  String? _selectedOfferTag;

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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final homeState = ref.watch(homeViewModelProvider);
    final allRestaurants = homeState.nearbyRestaurants.asData?.value ?? [];
    final categories = homeState.categories.asData?.value ?? [];
    final adminCoupons = ref.watch(couponsProvider).value ?? const <CouponModel>[];

    // Filter restaurants with offers or top rated
    final offerRestaurants = allRestaurants.isNotEmpty
        ? allRestaurants
        : <RestaurantModel>[];

    // Dynamic hanging offer tags from admin and curated templates
    final tags = _getHangingOfferTags(adminCoupons);

    // Active offer filter logic
    HangingOfferTag? activeTag;
    List<RestaurantModel> displayedRestaurants = List.from(offerRestaurants);

    if (_selectedOfferTag != null) {
      activeTag = tags.where((t) => t.id == _selectedOfferTag).firstOrNull;
      if (activeTag != null) {
        final filtered = offerRestaurants
            .where((r) => activeTag!.matches(r, adminCoupons))
            .toList();
        if (filtered.isNotEmpty) {
          displayedRestaurants = filtered;
        }
      }
    }

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
                    SizedBox(height: 20.h),
                  ],
                ),
              ),

              // 4. "─── MORE OFFERS ───" Section (Slidable 3D Hanging Tags)
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildSectionHeader('MORE OFFERS', isDark),
                    SizedBox(height: 14.h),
                    _buildMoreOffersHangingSlider(context, tags, isDark),
                    SizedBox(height: 22.h),
                  ],
                ),
              ),

              // 5. All Restaurants with Offers (filtered by active offer tag)
              if (displayedRestaurants.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Active filter badge if selected
                        if (activeTag != null) ...[
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 4.5.h,
                                ),
                                decoration: BoxDecoration(
                                  color: activeTag.bgColorStart,
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: activeTag.borderColor,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${activeTag.prefix} ${activeTag.mainText.replaceAll('\n', ' ')}',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w800,
                                        color: activeTag.textColor,
                                      ),
                                    ),
                                    SizedBox(width: 6.w),
                                    GestureDetector(
                                      onTap: () {
                                        Haptics.light();
                                        setState(() => _selectedOfferTag = null);
                                      },
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 14.sp,
                                        color: activeTag.textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                        ],
                        Text(
                          '${displayedRestaurants.length} RESTAURANTS WITH OFFERS',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          activeTag != null
                              ? 'Deals for "${activeTag.prefix} ${activeTag.mainText.replaceAll('\n', ' ')}"'
                              : 'All Great Deals Near You',
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
                      final rest = displayedRestaurants[index];
                      return RestaurantCard(
                        restaurant: rest,
                        index: index,
                      );
                    },
                    childCount: displayedRestaurants.length,
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
        : '';
    final rating = r.rating;
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

                    // Top left: the real offer, if any.
                    if (offerText.isNotEmpty)
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
                              rating > 0 ? rating.toStringAsFixed(1) : 'New',
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
                          r.deliveryTime,
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

  // ==================== 4. MORE OFFERS HANGING TAGS SLIDER ====================

  Widget _buildMoreOffersHangingSlider(
    BuildContext context,
    List<HangingOfferTag> tags,
    bool isDark,
  ) {
    if (tags.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 126.h,
      child: Stack(
        children: [
          // Continuous horizontal guide line across
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 1.2,
              color: isDark ? Colors.white12 : const Color(0xFFD1D5DB),
            ),
          ),

          // Slidable list of hanging 3D tags
          ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 18.w),
            itemCount: tags.length,
            separatorBuilder: (_, _) => SizedBox(width: 14.w),
            itemBuilder: (context, index) {
              final tag = tags[index];
              final isSelected = _selectedOfferTag == tag.id;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Haptics.light();
                  setState(() {
                    if (_selectedOfferTag == tag.id) {
                      _selectedOfferTag = null; // Toggle off filter
                    } else {
                      _selectedOfferTag = tag.id; // Apply offer filter
                    }
                  });
                },
                child: AnimatedScale(
                  scale: isSelected ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  child: SizedBox(
                    width: 88.w,
                    height: 122.h,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        // Vertical blue hanging string
                        Positioned(
                          top: 0,
                          child: Container(
                            width: 1.8.w,
                            height: 16.h,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0F8A5F)
                                  : const Color(0xFF3B82F6),
                              borderRadius: BorderRadius.circular(1.r),
                            ),
                          ),
                        ),

                        // The 3D Tag Body
                        Positioned(
                          top: 14.h,
                          child: CustomPaint(
                            size: Size(88.w, 98.h),
                            painter: HangingTagShapePainter(
                              bgColorStart: tag.bgColorStart,
                              bgColorEnd: tag.bgColorEnd,
                              borderColor: tag.borderColor,
                              shadowColor: tag.shadowColor,
                              isSelected: isSelected,
                              isDark: isDark,
                            ),
                            child: SizedBox(
                              width: 88.w,
                              height: 98.h,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(height: 14.h), // Clearance for hole cutout
                                  Text(
                                    tag.prefix,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.1,
                                      color: tag.textColor.withValues(alpha: 0.85),
                                    ),
                                  ),
                                  SizedBox(height: 3.h),
                                  Text(
                                    tag.mainText,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w900,
                                      height: 1.08,
                                      letterSpacing: -0.4,
                                      color: tag.textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==================== DYNAMIC HANGING OFFER TAGS ====================

  List<HangingOfferTag> _getHangingOfferTags(List<CouponModel> adminCoupons) {
    final list = <HangingOfferTag>[
      // 1. Blue Tag: meals UNDER ₹250
      HangingOfferTag(
        id: 'under250',
        prefix: 'meals',
        mainText: 'UNDER\n₹250',
        bgColorStart: const Color(0xFFE8F1FC),
        bgColorEnd: const Color(0xFFD3E4F8),
        borderColor: const Color(0xFFB3D1F5),
        textColor: const Color(0xFF1B498C),
        shadowColor: const Color(0xFF3366BB).withValues(alpha: 0.18),
        matches: (r, _) =>
            r.priceForOne <= 250 ||
            r.offerBadges.any((b) => b.contains('250')) ||
            r.tags.any((t) => t.toLowerCase().contains('budget') || t.toLowerCase().contains('snack')),
      ),

      // 2. Coral Tag: get up to 60% OFF
      HangingOfferTag(
        id: '60off',
        prefix: 'get up to',
        mainText: '60%\nOFF',
        bgColorStart: const Color(0xFFFDE8E8),
        bgColorEnd: const Color(0xFFFBD3D3),
        borderColor: const Color(0xFFF7B4B4),
        textColor: const Color(0xFF8B1E1E),
        shadowColor: const Color(0xFFE53935).withValues(alpha: 0.18),
        matches: (r, _) =>
            r.offerBadges.any((b) => b.contains('60%') || b.toLowerCase().contains('60')) ||
            r.tags.any((t) => t.contains('60')),
      ),

      // 3. Pink Tag: items at 50% OFF
      HangingOfferTag(
        id: '50off',
        prefix: 'items at',
        mainText: '50%\nOFF',
        bgColorStart: const Color(0xFFFDE8F1),
        bgColorEnd: const Color(0xFFFCD3E5),
        borderColor: const Color(0xFFF8B5D4),
        textColor: const Color(0xFF7A1545),
        shadowColor: const Color(0xFFD81B60).withValues(alpha: 0.18),
        matches: (r, _) =>
            r.offerBadges.any((b) => b.contains('50%') || b.toLowerCase().contains('50')),
      ),

      // 4. Amber Tag: minimum ₹150 OFF
      HangingOfferTag(
        id: '150off',
        prefix: 'minimum',
        mainText: '₹150\nOFF',
        bgColorStart: const Color(0xFFFDF0E2),
        bgColorEnd: const Color(0xFFFCE0C6),
        borderColor: const Color(0xFFF8C99B),
        textColor: const Color(0xFF6E2D0E),
        shadowColor: const Color(0xFFD35400).withValues(alpha: 0.18),
        matches: (r, _) =>
            r.offerBadges.any((b) => b.contains('150') || b.contains('120') || b.contains('100')),
      ),

      // 5. Gold Tag: unlock GOLD OFFERS
      HangingOfferTag(
        id: 'gold',
        prefix: 'unlock',
        mainText: 'GOLD\nOFFERS',
        bgColorStart: const Color(0xFFFCF6E5),
        bgColorEnd: const Color(0xFFFBEBC2),
        borderColor: const Color(0xFFF5DC8C),
        textColor: const Color(0xFF66440C),
        shadowColor: const Color(0xFFD4AF37).withValues(alpha: 0.22),
        matches: (r, _) =>
            r.rating >= 4.2 ||
            r.isFeatured ||
            r.isFreeDelivery,
      ),
    ];

    // Dynamically include any additional coupons configured by admin
    final palette = [
      (start: const Color(0xFFE8F8F5), end: const Color(0xFFD1F2EB), border: const Color(0xFFA2E4D4), text: const Color(0xFF0E6251)),
      (start: const Color(0xFFF4ECF7), end: const Color(0xFFE8DAEF), border: const Color(0xFFD2B4DE), text: const Color(0xFF512E5F)),
      (start: const Color(0xFFFEF9E7), end: const Color(0xFFFCF3CF), border: const Color(0xFFF9E79F), text: const Color(0xFF7D6608)),
    ];

    int colorIdx = 0;
    for (final coupon in adminCoupons) {
      final text = coupon.discountText.trim();
      if (text.isEmpty) continue;
      // Skip if already in preset list
      if (list.any((t) => t.mainText.replaceAll('\n', ' ').toLowerCase() == text.toLowerCase())) {
        continue;
      }

      final theme = palette[colorIdx % palette.length];
      colorIdx++;

      final lines = text.split(' ');
      final mainFormatted = lines.length >= 2 ? '${lines[0]}\n${lines.sublist(1).join(' ')}' : text;

      list.add(
        HangingOfferTag(
          id: 'coupon_${coupon.id}',
          prefix: coupon.minSpend > 0 ? 'above ₹${coupon.minSpend.toInt()}' : 'special',
          mainText: mainFormatted,
          bgColorStart: theme.start,
          bgColorEnd: theme.end,
          borderColor: theme.border,
          textColor: theme.text,
          shadowColor: theme.text.withValues(alpha: 0.15),
          matches: (r, _) =>
              coupon.restaurantId == null ||
              coupon.restaurantId!.isEmpty ||
              r.id == coupon.restaurantId ||
              r.offerBadges.any((b) =>
                  b.toLowerCase().contains(coupon.code.toLowerCase()) ||
                  b.toLowerCase().contains(text.toLowerCase())),
        ),
      );
    }

    return list;
  }
}

/// Model representing a 3D hanging luggage offer tag
class HangingOfferTag {
  final String id;
  final String prefix;
  final String mainText;
  final Color bgColorStart;
  final Color bgColorEnd;
  final Color borderColor;
  final Color textColor;
  final Color shadowColor;
  final bool Function(RestaurantModel restaurant, List<CouponModel> coupons) matches;

  const HangingOfferTag({
    required this.id,
    required this.prefix,
    required this.mainText,
    required this.bgColorStart,
    required this.bgColorEnd,
    required this.borderColor,
    required this.textColor,
    required this.shadowColor,
    required this.matches,
  });
}

/// Custom painter for the 3D luggage/price tag shape with punch hole
class HangingTagShapePainter extends CustomPainter {
  final Color bgColorStart;
  final Color bgColorEnd;
  final Color borderColor;
  final Color shadowColor;
  final bool isSelected;
  final bool isDark;

  HangingTagShapePainter({
    required this.bgColorStart,
    required this.bgColorEnd,
    required this.borderColor,
    required this.shadowColor,
    required this.isSelected,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const shoulderY = 16.0;
    const r = 12.0;

    final path = Path();
    path.moveTo(w * 0.32, 0);
    path.lineTo(w * 0.68, 0);
    path.lineTo(w, shoulderY);
    path.lineTo(w, h - r);
    path.arcToPoint(Offset(w - r, h), radius: const Radius.circular(r));
    path.lineTo(r, h);
    path.arcToPoint(Offset(0, h - r), radius: const Radius.circular(r));
    path.lineTo(0, shoulderY);
    path.close();

    // Soft drop shadow
    final shadowPaint = Paint()
      ..color = isSelected
          ? const Color(0xFF0F8A5F).withValues(alpha: 0.35)
          : shadowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isSelected ? 8 : 5);
    canvas.drawPath(path.shift(const Offset(0, 3)), shadowPaint);

    // Tag body gradient
    final rect = Rect.fromLTWH(0, 0, w, h);
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [bgColorStart, bgColorEnd],
      ).createShader(rect);
    canvas.drawPath(path, bodyPaint);

    // Border
    final borderPaint = Paint()
      ..color = isSelected ? const Color(0xFF0F8A5F) : borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.0 : 1.0;
    canvas.drawPath(path, borderPaint);

    // Circular hole cutout near top
    const holeRadius = 3.5;
    final holeCenter = Offset(w / 2, 8.5);
    final holeBgPaint = Paint()
      ..color = isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB);
    final holeBorderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(holeCenter, holeRadius, holeBgPaint);
    canvas.drawCircle(holeCenter, holeRadius, holeBorderPaint);
  }

  @override
  bool shouldRepaint(covariant HangingTagShapePainter oldDelegate) {
    return oldDelegate.isSelected != isSelected ||
        oldDelegate.bgColorStart != bgColorStart ||
        oldDelegate.isDark != isDark;
  }
}
