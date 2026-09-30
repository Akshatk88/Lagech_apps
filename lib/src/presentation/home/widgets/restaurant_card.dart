import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/restaurant_model.dart';
import '../../favorites/viewmodels/favorites_viewmodel.dart';
import '../../navigation/route_names.dart';
import '../../restaurant/viewmodels/restaurant_detail_viewmodel.dart';
import '../viewmodels/home_viewmodel.dart';

class RestaurantCard extends ConsumerStatefulWidget {
  final RestaurantModel restaurant;
  final int index;
  final String? selectedCategory;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.index = 0,
    this.selectedCategory,
  });

  @override
  ConsumerState<RestaurantCard> createState() => _RestaurantCardState();
}

class _SlideItem {
  final String imageUrl;
  final String dishName;
  final double price;
  final bool isVeg;

  const _SlideItem({
    required this.imageUrl,
    required this.dishName,
    required this.price,
    this.isVeg = true,
  });
}

class _RestaurantCardState extends ConsumerState<RestaurantCard> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _slideTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startSlideTimer();
  }

  void _startSlideTimer() {
    final staggerMs = 3200 + (widget.index % 3) * 700;
    _slideTimer = Timer.periodic(Duration(milliseconds: staggerMs), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final slideCount = _getSlides().length;
      if (slideCount <= 1) return;
      final next = (_currentPage + 1) % slideCount;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  List<_SlideItem> _getSlides() {
    final slides = <_SlideItem>[];
    final menuAsync = ref.watch(restaurantMenuProvider(widget.restaurant.id));
    final menu = menuAsync.asData?.value ?? const <FoodModel>[];
    final popularFoods = ref.watch(homeViewModelProvider).popularFoods.asData?.value ?? const <FoodModel>[];
    final allFoods = <FoodModel>[
      ...menu,
      ...popularFoods.where((f) => f.restaurantId == widget.restaurant.id ||
          (f.restaurantName.isNotEmpty &&
           widget.restaurant.name.isNotEmpty &&
           f.restaurantName.trim().toLowerCase() == widget.restaurant.name.trim().toLowerCase())),
    ];

    final isCategorySelected = widget.selectedCategory != null &&
        widget.selectedCategory != 'All' &&
        widget.selectedCategory != 'More';

    // 1. If category selected (e.g. Pizza or Sandwich), strictly show dishes matching that category
    if (isCategorySelected) {
      final q = widget.selectedCategory!.toLowerCase().trim();
      final singular = (q.endsWith('s') && q.length > 3) ? q.substring(0, q.length - 1) : q;
      for (final item in allFoods) {
        final nameOrCat = '${item.name} ${item.categoryName} ${item.description}'.toLowerCase();
        if (nameOrCat.contains(q) || nameOrCat.contains(singular)) {
          final u = item.imageUrl.trim();
          if (u.isNotEmpty &&
              !u.contains('localhost') &&
              !u.contains('127.0.0.1') &&
              (u.startsWith('http://') || u.startsWith('https://')) &&
              !slides.any((s) => s.imageUrl == u)) {
            slides.add(_SlideItem(
              imageUrl: u,
              dishName: item.name,
              price: item.price > 0 ? item.price : 190.0,
              isVeg: item.isVeg,
            ));
          }
        }
      }
    }

    // 2. Genuine menu items belonging to this restaurant (only if category not selected or no category dishes found)
    if (!isCategorySelected || slides.isEmpty) {
      for (final item in allFoods) {
        final u = item.imageUrl.trim();
        if (u.isNotEmpty &&
            !u.contains('localhost') &&
            !u.contains('127.0.0.1') &&
            (u.startsWith('http://') || u.startsWith('https://')) &&
            !slides.any((s) => s.imageUrl == u)) {
          slides.add(_SlideItem(
            imageUrl: u,
            dishName: item.name,
            price: item.price > 0 ? item.price : 190.0,
            isVeg: item.isVeg,
          ));
        }
      }
    }

    // 3. Fallback to restaurant's genuine primary image or menuImages (never Unsplash!)
    if (slides.isEmpty) {
      final primary = widget.restaurant.imageUrl.trim();
      if (primary.isNotEmpty &&
          (primary.startsWith('http://') || primary.startsWith('https://'))) {
        slides.add(_SlideItem(
          imageUrl: primary,
          dishName: widget.restaurant.name,
          price: widget.restaurant.priceForOne > 0
              ? widget.restaurant.priceForOne
              : 150.0,
          isVeg: widget.restaurant.isPureVeg,
        ));
      }
      for (final img in widget.restaurant.menuImages) {
        final u = img.trim();
        if (u.isNotEmpty &&
            (u.startsWith('http://') || u.startsWith('https://')) &&
            !slides.any((s) => s.imageUrl == u)) {
          slides.add(_SlideItem(
            imageUrl: u,
            dishName: widget.restaurant.name,
            price: widget.restaurant.priceForOne > 0
                ? widget.restaurant.priceForOne
                : 150.0,
            isVeg: widget.restaurant.isPureVeg,
          ));
        }
      }
    }

    return slides;
  }

  String _resolveOfferBadge() {
    if (widget.restaurant.offerBadges.isNotEmpty) {
      return widget.restaurant.offerBadges.first;
    }
    final mod = widget.index % 2;
    if (mod == 0) return 'Flat ₹100 OFF above ₹149';
    return '50% OFF up to ₹100';
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurant;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final slides = _getSlides();
    final currentSlide = slides.isNotEmpty
        ? slides[_currentPage % slides.length]
        : null;
    final rating = restaurant.rating > 0 ? restaurant.rating : 4.0;
    final offerBadge = _resolveOfferBadge();

    final isFavorited = ref.watch(
      favoritesViewModelProvider.select(
        (s) => s.value?.restaurantIds.contains(restaurant.id) ?? false,
      ),
    );

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E232C) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Haptics.light();
            context.push(RouteNames.restaurantDetail, extra: restaurant);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP FOOD IMAGE SLIDER (Screenshot exact design)
              SizedBox(
                height: 205.h,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Carousel View
                    if (slides.isNotEmpty)
                      PageView.builder(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: slides.length,
                        onPageChanged: (idx) {
                          setState(() {
                            _currentPage = idx;
                          });
                        },
                        itemBuilder: (context, idx) {
                          final slide = slides[idx % slides.length];
                          return CachedNetworkImage(
                            imageUrl: slide.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, _) => Container(
                              color: isDark
                                  ? const Color(0xFF262C36)
                                  : const Color(0xFFF3F4F6),
                            ),
                            errorWidget: (context, _, error) => Container(
                              color: isDark
                                  ? const Color(0xFF262C36)
                                  : const Color(0xFFF3F4F6),
                              child: Center(
                                child: Icon(
                                  Icons.restaurant_rounded,
                                  color: isDark ? Colors.white24 : Colors.black26,
                                  size: 36.sp,
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        color: isDark
                            ? const Color(0xFF262C36)
                            : const Color(0xFFF3F4F6),
                        child: Center(
                          child: Icon(
                            Icons.restaurant_rounded,
                            color: isDark ? Colors.white24 : Colors.black26,
                            size: 36.sp,
                          ),
                        ),
                      ),

                    // Subtle top & bottom shadow gradients for contrast
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.35),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.35),
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Top-Left: Translucent Pill with Veg Square + Dish Name + Price
                    if (currentSlide != null)
                      Positioned(
                        top: 10.h,
                        left: 10.w,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.5.h),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(5.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Veg / Non-Veg Standard FSSAI Indicator Box
                              Container(
                                width: 12.r,
                                height: 12.r,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: currentSlide.isVeg
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFDC2626),
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(2.5.r),
                                ),
                                alignment: Alignment.center,
                                child: Container(
                                  width: 5.5.r,
                                  height: 5.5.r,
                                  decoration: BoxDecoration(
                                    color: currentSlide.isVeg
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFDC2626),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                '${currentSlide.dishName}${currentSlide.price > 0 ? ' • ₹${currentSlide.price.toStringAsFixed(0)}' : ''}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Top-Right: Bookmark / Favorite Button
                    Positioned(
                      top: 10.h,
                      right: 10.w,
                      child: GestureDetector(
                        onTap: () {
                          Haptics.light();
                          ref.read(favoritesViewModelProvider.notifier).toggle(restaurant.id, restaurant);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: EdgeInsets.all(5.5.r),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorited ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: Colors.white,
                            size: 20.sp,
                          ),
                        ),
                      ),
                    ),

                    // Bottom-Left: RED "FREE delivery" badge (Requested by user in Red theme)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.5.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC80A14), // Red brand color as requested
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(7.r),
                          ),
                        ),
                        child: Text(
                          'FREE delivery',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),

                  ],
                ),
              ),

              // 2. BOTTOM DETAILS (Exact match to screenshot)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Restaurant Name + Green Rating Pill
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            restaurant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17.5.sp,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF1E232C),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: rating >= 4.0 ? const Color(0xFF0F8A43) : const Color(0xFF267E3E),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                rating.toStringAsFixed(1),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              SizedBox(width: 2.w),
                              Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 11.5.sp,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 5.h),

                    // Row 2: ⚡ Near & Fast
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 15.sp,
                          color: const Color(0xFF0F8A43),
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          'Near & Fast',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F8A43),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 5.h),

                    // Row 3: Blue Discount Badge + "Flat ₹100 OFF above ₹149"
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.stars_rounded,
                          size: 15.sp,
                          color: const Color(0xFF2563EB),
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            offerBadge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF374151),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 8.h),

                    // Row 4: 🍃 Pure Veg restaurant tag pill
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.5.h),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF14532D).withValues(alpha: 0.3)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(
                          color: const Color(0xFF86EFAC).withValues(alpha: 0.6),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.eco_rounded,
                            size: 13.sp,
                            color: const Color(0xFF16A34A),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            restaurant.isPureVeg
                                ? 'Pure Veg restaurant'
                                : (restaurant.tags.isNotEmpty ? '${restaurant.tags.first} Special' : 'Pure Veg restaurant'),
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
