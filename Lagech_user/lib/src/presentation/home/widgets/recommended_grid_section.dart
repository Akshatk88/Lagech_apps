import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/restaurant_model.dart';
import '../../restaurant/viewmodels/restaurant_detail_viewmodel.dart';
import '../viewmodels/home_viewmodel.dart';

class RecommendedGridSection extends StatefulWidget {
  final List<RestaurantModel> restaurants;
  final Function(RestaurantModel) onRestaurantTap;
  final String title;
  final bool showTitle;
  final EdgeInsetsGeometry? padding;
  final String selectedCategory;
  final List<FoodModel> categoryDishes;

  const RecommendedGridSection({
    super.key,
    required this.restaurants,
    required this.onRestaurantTap,
    this.title = 'RECOMMENDED FOR YOU',
    this.showTitle = true,
    this.padding,
    this.selectedCategory = 'All',
    this.categoryDishes = const [],
  });

  @override
  State<RecommendedGridSection> createState() => _RecommendedGridSectionState();
}

class _RecommendedGridSectionState extends State<RecommendedGridSection> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<RestaurantModel> _getCleanList() {
    // Only return genuine restaurants passed to this section
    return widget.restaurants;
  }

  List<List<RestaurantModel>> _buildPages(List<RestaurantModel> allItems) {
    if (allItems.isEmpty) return [];
    final pages = <List<RestaurantModel>>[];
    for (var i = 0; i < allItems.length; i += 6) {
      final end = (i + 6 < allItems.length) ? i + 6 : allItems.length;
      final chunk = allItems.sublist(i, end);
      pages.add(chunk);
    }
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    final allItems = _getCleanList();
    if (allItems.isEmpty) return const SizedBox.shrink();

    final pages = _buildPages(allItems);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: widget.padding ?? EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showTitle) ...[
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: 8.h),
          ],

          // Horizontal Slidable Pages of 6 Cards (2 rows x 3 columns)
          SizedBox(
            height: 290.h,
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              itemCount: pages.length,
              itemBuilder: (context, pageIndex) {
                final pageItems = pages[pageIndex];
                final row1 = pageItems.take(3).toList();
                final row2 = pageItems.skip(3).take(3).toList();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row 1 (3 items)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int c = 0; c < 3; c++) ...[
                          if (c > 0) SizedBox(width: 8.w),
                          Expanded(
                            child: c < row1.length
                                ? RecommendedMiniCard(
                                    restaurant: row1[c],
                                    index: pageIndex * 6 + c,
                                    selectedCategory: widget.selectedCategory,
                                    categoryDishes: widget.categoryDishes,
                                    onTap: () {
                                      Haptics.light();
                                      widget.onRestaurantTap(row1[c]);
                                    },
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),

                    if (row2.isNotEmpty) ...[
                      SizedBox(height: 10.h),

                      // Row 2 (3 items)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int c = 0; c < 3; c++) ...[
                            if (c > 0) SizedBox(width: 8.w),
                            Expanded(
                              child: c < row2.length
                                  ? RecommendedMiniCard(
                                      restaurant: row2[c],
                                      index: pageIndex * 6 + 3 + c,
                                      selectedCategory: widget.selectedCategory,
                                      categoryDishes: widget.categoryDishes,
                                      onTap: () {
                                        Haptics.light();
                                        widget.onRestaurantTap(row2[c]);
                                      },
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class RecommendedMiniCard extends ConsumerStatefulWidget {
  final RestaurantModel restaurant;
  final int index;
  final VoidCallback onTap;
  final String selectedCategory;
  final List<FoodModel> categoryDishes;

  const RecommendedMiniCard({
    super.key,
    required this.restaurant,
    required this.index,
    required this.onTap,
    this.selectedCategory = 'All',
    this.categoryDishes = const [],
  });

  @override
  ConsumerState<RecommendedMiniCard> createState() => _RecommendedMiniCardState();
}

class _RecommendedMiniCardState extends ConsumerState<RecommendedMiniCard> {
  late final PageController _imagePageController;
  Timer? _slideTimer;
  int _currentImageIndex = 0;
  bool _showNearAndFast = false;
  List<String> _images = [];

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController();
    _showNearAndFast = widget.index % 2 == 1;
    _initImages();
    _startSlideTimer();
  }

  @override
  void didUpdateWidget(covariant RecommendedMiniCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory ||
        oldWidget.restaurant.id != widget.restaurant.id ||
        oldWidget.categoryDishes != widget.categoryDishes) {
      _initImages();
      _slideTimer?.cancel();
      _currentImageIndex = 0;
      if (_imagePageController.hasClients) {
        _imagePageController.jumpToPage(0);
      }
      _startSlideTimer();
    }
  }

  void _initImages() {
    final foodList = <String>[];

    // 1. If category selected (e.g. Pizza or Sandwich), show dishes matching this category first
    if (widget.selectedCategory != 'All' && widget.selectedCategory != 'More') {
      final q = widget.selectedCategory.toLowerCase().trim();
      final singular = q.endsWith('s') ? q.substring(0, q.length - 1) : q;

      // Check matching dishes passed from parent categoryDishes
      for (final f in widget.categoryDishes) {
        final matchesRest = f.restaurantId == widget.restaurant.id ||
            (f.restaurantName.isNotEmpty &&
                widget.restaurant.name.isNotEmpty &&
                f.restaurantName.trim().toLowerCase() == widget.restaurant.name.trim().toLowerCase());
        final u = f.imageUrl.trim();
        if (matchesRest &&
            u.isNotEmpty &&
            !u.contains('localhost') &&
            !u.contains('127.0.0.1') &&
            (u.startsWith('http://') || u.startsWith('https://')) &&
            !foodList.contains(u)) {
          foodList.add(u);
        }
      }

      // Check matching popularFoods
      final popularFoods = ref.read(homeViewModelProvider).popularFoods.asData?.value ?? [];
      for (final f in popularFoods) {
        final matchesRest = f.restaurantId == widget.restaurant.id ||
            (f.restaurantName.isNotEmpty &&
                widget.restaurant.name.isNotEmpty &&
                f.restaurantName.trim().toLowerCase() == widget.restaurant.name.trim().toLowerCase());
        final nameOrCat = '${f.name} ${f.categoryName}'.toLowerCase();
        if (matchesRest && (nameOrCat.contains(q) || nameOrCat.contains(singular))) {
          final u = f.imageUrl.trim();
          if (u.isNotEmpty &&
              !u.contains('localhost') &&
              !u.contains('127.0.0.1') &&
              (u.startsWith('http://') || u.startsWith('https://')) &&
              !foodList.contains(u)) {
            foodList.add(u);
          }
        }
      }
    }

    // 2. Real menu items belonging to this restaurant
    final isCategorySelected = widget.selectedCategory != 'All' && widget.selectedCategory != 'More';
    if (!isCategorySelected || foodList.isEmpty) {
      final menuAsync = ref.read(restaurantMenuProvider(widget.restaurant.id));
      final menuItems = menuAsync.asData?.value ?? [];
      for (final item in menuItems) {
        if (isCategorySelected) {
          final q = widget.selectedCategory.toLowerCase().trim();
          final singular = (q.endsWith('s') && q.length > 3) ? q.substring(0, q.length - 1) : q;
          final nameOrCat = '${item.name} ${item.categoryName} ${item.description}'.toLowerCase();
          if (!nameOrCat.contains(q) && !nameOrCat.contains(singular)) {
            continue; // Prioritize selected category
          }
        }
        final u = item.imageUrl.trim();
        if (u.isNotEmpty &&
            !u.contains('localhost') &&
            !u.contains('127.0.0.1') &&
            (u.startsWith('http://') || u.startsWith('https://')) &&
            !foodList.contains(u)) {
          foodList.add(u);
        }
      }
    }

    // 3. Restaurant menuImages (only if not filtered by category or foodList still empty)
    if (!isCategorySelected || foodList.isEmpty) {
      for (final img in widget.restaurant.menuImages) {
        final u = img.trim();
        if (u.isNotEmpty &&
            !u.contains('localhost') &&
            !u.contains('127.0.0.1') &&
            (u.startsWith('http://') || u.startsWith('https://')) &&
            !foodList.contains(u)) {
          foodList.add(u);
        }
      }
    }

    // 4. Restaurant primary image if no dish images
    final primaryImg = widget.restaurant.imageUrl.trim();
    if (foodList.isEmpty &&
        primaryImg.isNotEmpty &&
        !primaryImg.contains('localhost') &&
        !primaryImg.contains('127.0.0.1') &&
        (primaryImg.startsWith('http://') || primaryImg.startsWith('https://'))) {
      foodList.add(primaryImg);
    }

    // ONLY genuine images - zero arbitrary Unsplash fallbacks!
    _images = foodList;
  }

  void _startSlideTimer() {
    if (_images.length <= 1) return;
    final staggerMs = 2800 + (widget.index % 3) * 600;
    _slideTimer = Timer.periodic(Duration(milliseconds: staggerMs), (_) {
      if (!mounted) return;
      if (_images.length > 1 && _imagePageController.hasClients) {
        _currentImageIndex++;
        _imagePageController.animateToPage(
          _currentImageIndex,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic,
        );
      }
      setState(() {
        _showNearAndFast = !_showNearAndFast;
      });
    });
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _imagePageController.dispose();
    super.dispose();
  }

  bool _isWithin20Mins(String timeStr) {
    if (timeStr.isEmpty) return false;
    final lower = timeStr.toLowerCase().trim();
    if (lower.contains('near') || lower.contains('fast')) return true;
    final numbers = RegExp(r'\d+')
        .allMatches(lower)
        .map((m) => int.tryParse(m.group(0) ?? '') ?? 0)
        .where((n) => n > 0)
        .toList();
    if (numbers.isEmpty) return false;
    return numbers.first <= 20;
  }

  String _resolveOfferBadge() {
    if (widget.restaurant.offerBadges.isNotEmpty) {
      return widget.restaurant.offerBadges.first;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<FoodModel>>>(
      restaurantMenuProvider(widget.restaurant.id),
      (_, next) {
        if (next.hasValue && mounted) {
          final hadMultiple = _images.length > 1;
          setState(() {
            _initImages();
          });
          if (!hadMultiple && _images.length > 1) {
            _slideTimer?.cancel();
            _startSlideTimer();
          }
        }
      },
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rating = widget.restaurant.rating;
    final offerText = _resolveOfferBadge();

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with auto-slide + top-left offer badge + overhanging bottom-left rating pill
          Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Food Image with auto-slide
              AspectRatio(
                aspectRatio: 1.12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_images.length > 1)
                        IgnorePointer(
                          child: PageView.builder(
                            controller: _imagePageController,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              final img = _images[index % _images.length];
                              return CachedNetworkImage(
                                imageUrl: img,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                fadeInDuration: const Duration(milliseconds: 150),
                                fadeOutDuration: const Duration(milliseconds: 100),
                                placeholder: (context, _) => Container(
                                  color: isDark ? const Color(0xFF262C36) : const Color(0xFFF3F4F6),
                                ),
                                errorWidget: (context, _, error) => Container(
                                  color: isDark ? const Color(0xFF262C36) : const Color(0xFFF3F4F6),
                                  child: Center(
                                    child: Icon(
                                      Icons.restaurant_rounded,
                                      color: isDark ? Colors.white24 : Colors.black26,
                                      size: 24.sp,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      else if (_images.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: _images.first,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          fadeInDuration: const Duration(milliseconds: 150),
                          fadeOutDuration: const Duration(milliseconds: 100),
                          placeholder: (context, _) => Container(
                            color: isDark ? const Color(0xFF262C36) : const Color(0xFFF3F4F6),
                          ),
                          errorWidget: (context, _, error) => Container(
                            color: isDark ? const Color(0xFF262C36) : const Color(0xFFF3F4F6),
                            child: Center(
                              child: Icon(
                                Icons.restaurant_rounded,
                                color: isDark ? Colors.white24 : Colors.black26,
                                size: 24.sp,
                              ),
                            ),
                          ),
                        )
                      else if (widget.restaurant.imageUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: widget.restaurant.imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          fadeInDuration: const Duration(milliseconds: 150),
                          fadeOutDuration: const Duration(milliseconds: 100),
                          placeholder: (context, _) => Container(
                            color: isDark ? const Color(0xFF262C36) : const Color(0xFFF3F4F6),
                          ),
                          errorWidget: (context, _, error) => Container(
                            color: isDark ? const Color(0xFF262C36) : const Color(0xFFF3F4F6),
                            child: Center(
                              child: Icon(
                                Icons.restaurant_rounded,
                                color: isDark ? Colors.white24 : Colors.black26,
                                size: 24.sp,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          color: isDark ? const Color(0xFF262C36) : const Color(0xFFF3F4F6),
                          child: Center(
                            child: Icon(
                              Icons.restaurant_rounded,
                              color: isDark ? Colors.white24 : Colors.black26,
                              size: 24.sp,
                            ),
                          ),
                        ),

                      // Subtle gradient for contrast
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.3),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.2),
                                ],
                                stops: const [0.0, 0.45, 1.0],
                              ),
                            ),
                          ),
                      // Closed Overlay
                      if (!widget.restaurant.isOpen)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.52),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Center(
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.5.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xEFDC2626),
                                  borderRadius: BorderRadius.circular(5.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_clock_rounded,
                                      size: 10.sp,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 3.w),
                                    Text(
                                      'CLOSED',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 2. Top-left offer badge: only for a real offer.
              if (offerText.isNotEmpty && widget.restaurant.isOpen)
              Positioned(
                top: 4.h,
                left: 4.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.5.w, vertical: 1.5.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                  child: Text(
                    offerText,
                    style: TextStyle(
                      fontSize: 8.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ),

              // 3. Overhanging Bottom-Left Rating Pill (Screenshot style)
              Positioned(
                bottom: -6.h,
                left: 5.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: rating >= 4.0 ? const Color(0xFF0F8A43) : const Color(0xFF267E3E),
                    borderRadius: BorderRadius.circular(4.5.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        rating > 0 ? rating.toStringAsFixed(1) : 'New',
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
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
              ),
            ],
          ),

          SizedBox(height: 7.h),

          // Restaurant Title
          Text(
            widget.restaurant.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E232C),
              letterSpacing: -0.2,
            ),
          ),

          SizedBox(height: 2.h),

          // Delivery info or Closed:
          if (!widget.restaurant.isOpen)
            SizedBox(
              height: 18.5.h,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cancel_outlined,
                    size: 12.sp,
                    color: const Color(0xFFDC2626),
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    'Closed',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 18.5.h,
              child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.25),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _showNearAndFast
                  ? Row(
                      key: const ValueKey('near_and_fast'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 15.sp,
                          color: const Color(0xFF0F8A43),
                        ),
                        SizedBox(width: 2.5.w),
                        Flexible(
                          child: Text(
                            'Near & Fast',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F8A43),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      key: const ValueKey('time'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 13.5.sp,
                          color: () {
                            final timeText = widget.restaurant.deliveryTime.isNotEmpty &&
                                    widget.restaurant.deliveryTime.toLowerCase() != 'near & fast'
                                ? widget.restaurant.deliveryTime
                                : '15-30 min';
                            final isFast = _isWithin20Mins(timeText);
                            return isFast
                                ? const Color(0xFF0F8A43)
                                : (isDark ? Colors.white : const Color(0xFF1E232C));
                          }(),
                        ),
                        SizedBox(width: 3.w),
                        Flexible(
                          child: Builder(
                            builder: (context) {
                              final timeText = widget.restaurant.deliveryTime.isNotEmpty &&
                                      widget.restaurant.deliveryTime.toLowerCase() != 'near & fast'
                                  ? widget.restaurant.deliveryTime
                                  : '15-30 min';
                              final isFast = _isWithin20Mins(timeText);
                              final color = isFast
                                  ? const Color(0xFF0F8A43)
                                  : (isDark ? Colors.white : const Color(0xFF1E232C));
                              return Text(
                                timeText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5.sp,
                                  fontWeight: isFast ? FontWeight.w700 : FontWeight.w600,
                                  color: color,
                                ),
                              );
                            },
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
}
