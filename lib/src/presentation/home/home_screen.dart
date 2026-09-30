import '../common_widgets/app_refresh_indicator.dart';
import '../common_widgets/skeleton_loading.dart';
import '../common_widgets/exit_confirmation_dialog.dart';
import '../common_widgets/smart_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/haptics.dart';
import '../branding/app_colors.dart';
import '../cart/widgets/floating_view_cart_bar.dart';
import '../navigation/route_names.dart';
import '../../data/models/restaurant_model.dart';
import '../../data/models/food_model.dart';
import '../../data/models/category_model.dart';
import '../orders/viewmodels/active_order_viewmodel.dart';
import 'screens/home_filter_screen.dart';
import 'viewmodels/banners_viewmodel.dart';
import 'viewmodels/home_viewmodel.dart';
import 'viewmodels/home_scroll_provider.dart';
import 'viewmodels/veg_filter_provider.dart';
import 'widgets/category_list.dart';
import 'widgets/home_header_banner.dart';
import 'widgets/restaurant_card.dart';
import 'widgets/explore_more_section.dart';
import 'widgets/home_filter_chips_row.dart';
import 'widgets/home_filter_bottom_sheet.dart';
import 'widgets/recommended_grid_section.dart';
import 'widgets/spotlight_carousel.dart';
import '../restaurant/viewmodels/restaurant_detail_viewmodel.dart';
import 'screens/category_details_screen.dart';

/// TEMP DEBUG WIDGET — shows the exact error inline instead of a blank
/// SizedBox.shrink(). Remove once the root cause of missing data is fixed.
class _DebugErrorBox extends StatelessWidget {
  final String label;
  final Object error;

  const _DebugErrorBox({required this.label, required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red, width: 1),
      ),
      child: Text(
        '[$label] $error',
        style: const TextStyle(color: Colors.red, fontSize: 11),
      ),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<FloatingViewCartBarState> _cartBarKey =
      GlobalKey<FloatingViewCartBarState>();
  final ScrollController _scrollController = ScrollController();
  String _selectedCategory = 'All';
  RestaurantFilterCriteria _filterCriteria = const RestaurantFilterCriteria();
  // Flips once the sticky header has mostly collapsed, so the status bar
  // icon color can switch from light (over the banner) to dark (over the
  // plain background) — only triggers a rebuild on the threshold crossing,
  // not on every scroll frame.
  bool _headerCollapsed = false;



  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(activeOrderViewModelProvider.notifier).fetchActiveOrder();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    // Collapse flag flips after scrolling 180px — approximate point
    // where the banner is fully off screen and categories are pinned.
    const threshold = 180.0;
    final collapsed = _scrollController.offset > threshold;
    if (collapsed != _headerCollapsed) {
      setState(() => _headerCollapsed = collapsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeScrollToTopProvider, (_, _) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    final homeState = ref.watch(homeViewModelProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allCategories = homeState.categories.asData?.value ?? const <CategoryModel>[];
    final activeCategoryModel = (_selectedCategory == 'All' || _selectedCategory == 'More')
        ? null
        : (allCategories.where((c) => c.name.toLowerCase() == _selectedCategory.toLowerCase()).firstOrNull ??
            CategoryModel(id: '', name: _selectedCategory, imageUrl: '', slug: _selectedCategory.toLowerCase()));

    final categoryDishes = activeCategoryModel != null
        ? (ref.watch(categoryFoodsProvider(activeCategoryModel)).asData?.value ?? const <FoodModel>[])
        : const <FoodModel>[];

    final categoryRests = activeCategoryModel != null
        ? (ref.watch(categoryRestaurantsProvider(activeCategoryModel)).asData?.value ?? const <RestaurantModel>[])
        : const <RestaurantModel>[];

    final popularFoods = homeState.popularFoods.asData?.value ?? const <FoodModel>[];
    final activeCatQuery = _selectedCategory.toLowerCase().trim();
    final activeCatSingular = (activeCatQuery.endsWith('s') && activeCatQuery.length > 3)
        ? activeCatQuery.substring(0, activeCatQuery.length - 1)
        : activeCatQuery;

    final matchingDishes = <FoodModel>[
      ...categoryDishes,
      if (_selectedCategory != 'All' && _selectedCategory != 'More')
        ...popularFoods.where((f) {
          final text = '${f.name} ${f.categoryName} ${f.description}'.toLowerCase();
          return text.contains(activeCatQuery) || text.contains(activeCatSingular);
        })
      else
        ...popularFoods,
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showExitConfirmationDialog(context);
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (_headerCollapsed && !isDark)
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: isDark
              ? AppColors.backgroundDark
              : AppColors.backgroundLight,
          body: SafeArea(
            top: false,
            child: Stack(
              children: [
                AppRefreshIndicator(
                  onRefresh: () async {
                    String? activeCategorySlug;
                    if (_selectedCategory != 'All' &&
                        _selectedCategory != 'More') {
                      final categories =
                          homeState.categories.asData?.value ?? [];
                      final cat = categories
                          .where((c) => c.name == _selectedCategory)
                          .firstOrNull;
                      activeCategorySlug = cat?.slug;
                    }

                    await ref
                        .read(homeViewModelProvider.notifier)
                        .loadHomeData(
                          isRefresh: true,
                          categoryId: activeCategorySlug,
                        );
                    await ref
                        .read(activeOrderViewModelProvider.notifier)
                        .fetchActiveOrder(isRefresh: true);
                    // Banners are their own provider, so loadHomeData does not
                    // touch them — without this a banner the admin just published
                    // would not appear until the app was restarted.
                    ref.invalidate(promoBannersProvider);
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // 1. Top Header Banner
                      const SliverToBoxAdapter(
                        child: HomeHeaderBanner(),
                      ),

                      // 2. Sticky Pinned Categories Row (Pizza, Burger, Sandwich stays fixed when scrolling)
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _StickyCategoryHeaderDelegate(
                          height: 76.h,
                          child: Container(
                            height: 76.h,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.backgroundDark : Colors.white,
                              border: Border(
                                bottom: BorderSide(
                                  color: isDark
                                      ? AppColors.borderDark.withValues(alpha: 0.5)
                                      : const Color(0xFFE5E7EB),
                                  width: 0.8,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 3,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: CategoryList(
                              categories: homeState.categories.asData?.value ?? const [],
                              selectedCategoryName: _selectedCategory,
                              onMealsUnder200Tap: () {
                                Haptics.light();
                                context.push(RouteNames.store99);
                              },
                              onAllCategoriesTap: () {
                                _showCategoryFilterSheet(
                                  context,
                                  isDark,
                                  homeState.categories.asData?.value ?? const [],
                                );
                              },
                              onCategorySelected: (catName) {
                                Haptics.light();
                                final categories = homeState.categories.asData?.value ?? const [];
                                final cat = categories
                                    .where((c) => c.name.toLowerCase() == catName.toLowerCase())
                                    .firstOrNull ??
                                    CategoryModel(
                                      id: '',
                                      name: catName,
                                      imageUrl: '',
                                      slug: catName.toLowerCase(),
                                    );
                                context.push(RouteNames.categoryDetails, extra: cat);
                              },
                            ),
                          ),
                        ),
                      ),

                      // 3. Rest of Feed
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 10.h),

                            // Active category pill if category selected
                            if (_selectedCategory != 'All') ...[
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 2.h),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFC80A14).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20.r),
                                        border: Border.all(color: const Color(0xFFC80A14), width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Category: $_selectedCategory',
                                            style: TextStyle(
                                              color: const Color(0xFFC80A14),
                                              fontSize: 11.5.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(width: 6.w),
                                          GestureDetector(
                                            onTap: () {
                                              Haptics.light();
                                              setState(() {
                                                _selectedCategory = 'All';
                                              });
                                            },
                                            child: Icon(
                                              Icons.close_rounded,
                                              size: 14.sp,
                                              color: const Color(0xFFC80A14),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () {
                                        Haptics.light();
                                        final categories = homeState.categories.asData?.value ?? [];
                                        final cat = categories
                                            .where((c) => c.name.toLowerCase() == _selectedCategory.toLowerCase())
                                            .firstOrNull;
                                        if (cat != null) {
                                          context.push(RouteNames.categoryDetails, extra: cat);
                                        }
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Explore all $_selectedCategory',
                                            style: TextStyle(
                                              color: const Color(0xFFC80A14),
                                              fontSize: 11.5.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            size: 14.sp,
                                            color: const Color(0xFFC80A14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 6.h),
                            ],

                            // 3. Filter Chips Row: Filters, Under 30 mins, Under 45 mins, Under 1km
                            HomeFilterChipsRow(
                              activeFilter: _filterCriteria.deliveryTime == '30mins'
                                  ? '30mins'
                                  : (_filterCriteria.deliveryTime == '45mins'
                                      ? '45mins'
                                      : (_filterCriteria.distance == '1km' ? '1km' : null)),
                              activeFiltersCount: _filterCriteria.activeFiltersCount,
                              onFiltersTap: () {
                                HomeFilterBottomSheet.show(
                                  context,
                                  initialCriteria: _filterCriteria,
                                  categories: homeState.categories.asData?.value ?? const [],
                                  onApply: (newCriteria) {
                                    setState(() {
                                      _filterCriteria = newCriteria;
                                    });
                                  },
                                );
                              },
                              onUnder30MinsTap: () {
                                setState(() {
                                  final isCurrent = _filterCriteria.deliveryTime == '30mins';
                                  _filterCriteria = _filterCriteria.copyWith(
                                    deliveryTime: isCurrent ? 'any' : '30mins',
                                  );
                                });
                              },
                              onUnder45MinsTap: () {
                                setState(() {
                                  final isCurrent = _filterCriteria.deliveryTime == '45mins';
                                  _filterCriteria = _filterCriteria.copyWith(
                                    deliveryTime: isCurrent ? 'any' : '45mins',
                                  );
                                });
                              },
                              onUnder1KmTap: () {
                                setState(() {
                                  final isCurrent = _filterCriteria.distance == '1km';
                                  _filterCriteria = _filterCriteria.copyWith(
                                    distance: isCurrent ? 'any' : '1km',
                                  );
                                });
                              },
                            ),

                             SizedBox(height: 12.h),

                            // 3.5. RECOMMENDED FOR YOU — filtered by selected category
                            homeState.nearbyRestaurants.maybeWhen(
                              data: (allRestaurants) {
                                if (allRestaurants.isEmpty) return const SizedBox.shrink();
                                final filtered = _filterRestaurants(
                                  allRestaurants,
                                  matchingDishes: matchingDishes,
                                  categoryRestaurants: categoryRests,
                                );
                                final displayList = _selectedCategory == 'All'
                                    ? (filtered.isNotEmpty ? filtered : allRestaurants)
                                    : filtered;
                                if (displayList.isEmpty) return const SizedBox.shrink();

                                return Column(
                                  children: [
                                    RecommendedGridSection(
                                      key: ValueKey('$_selectedCategory-${displayList.length}'),
                                      restaurants: displayList,
                                      selectedCategory: _selectedCategory,
                                      categoryDishes: matchingDishes,
                                      title: _selectedCategory == 'All'
                                          ? 'RECOMMENDED FOR YOU'
                                          : '${_selectedCategory.toUpperCase()} NEAR YOU',
                                      onRestaurantTap: (rest) {
                                        context.push(RouteNames.restaurantDetail, extra: rest);
                                      },
                                    ),
                                    SizedBox(height: 10.h),
                                  ],
                                );
                              },
                              orElse: () => const SizedBox.shrink(),
                            ),

                            // 4. Explore More Section: Offers, Gourmet, Top 10, Collections
                            ExploreMoreSection(
                              // Offers → Opens the full Offers/Store99 deals screen
                              onOffersTap: () {
                                Haptics.light();
                                context.push(RouteNames.allOffers);
                              },
                              // Gourmet → Top Hotels (rating >= 4.0, sorted best first)
                              onGourmetTap: () => _openFilter(
                                title: 'Gourmet & Top Hotels',
                                emptyMessage: 'No top rated restaurants found in your area right now',
                                emptyIcon: Icons.emoji_events_rounded,
                                matches: (r) => r.rating >= 4.0,
                              ),
                              // Top 10 / Top Orders → Signature Top 10 Screen with Golden Banner
                              onTop10Tap: () {
                                Haptics.light();
                                context.push(RouteNames.top10);
                              },
                              // Collections → Popular restaurants (most ordered / well rated)
                              onCollectionsTap: () => _openFilter(
                                title: 'Popular Near You',
                                emptyMessage: 'No popular restaurants found in your area right now',
                                emptyIcon: Icons.local_fire_department_rounded,
                                matches: (r) => r.rating >= 3.8 || r.offerBadges.isNotEmpty,
                              ),
                              onSeeAllTap: () => context.push(RouteNames.allOffers),
                            ),

                            // 4.5. IN THE SPOTLIGHT (Screenshot 3: spotlight carousel with indicator dots)
                            homeState.nearbyRestaurants.maybeWhen(
                              data: (allRestaurants) {
                                if (allRestaurants.isEmpty) return const SizedBox.shrink();
                                return Column(
                                  children: [
                                    SizedBox(height: 8.h),
                                    SpotlightCarousel(
                                      restaurants: allRestaurants,
                                      onRestaurantTap: (rest) {
                                        context.push(RouteNames.restaurantDetail, extra: rest);
                                      },
                                    ),
                                    SizedBox(height: 10.h),
                                  ],
                                );
                              },
                              orElse: () => const SizedBox.shrink(),
                            ),

                            SizedBox(height: 4.h),

                            // 5. Featured Restaurants Section (Matching Screenshot)
                            homeState.nearbyRestaurants.when(
                              data: (allRestaurants) {
                                final restaurants = _filterRestaurants(
                                  allRestaurants,
                                  matchingDishes: matchingDishes,
                                  categoryRestaurants: categoryRests,
                                );
                                if (restaurants.isEmpty) {
                                  return Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 28.h),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.filter_list_off_rounded,
                                            size: 46.sp,
                                            color: isDark ? Colors.white38 : Colors.grey.shade400,
                                          ),
                                          SizedBox(height: 10.h),
                                          Text(
                                            'No restaurants match your selected filters',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: isDark ? Colors.white70 : Colors.black87,
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (!_filterCriteria.isDefault) ...[
                                            SizedBox(height: 12.h),
                                            TextButton.icon(
                                              onPressed: () {
                                                Haptics.light();
                                                setState(() {
                                                  _filterCriteria = const RestaurantFilterCriteria();
                                                  _selectedCategory = 'All';
                                                });
                                              },
                                              icon: const Icon(Icons.refresh_rounded, color: Color(0xFFC80A14)),
                                              label: const Text(
                                                'Clear Filters',
                                                style: TextStyle(
                                                  color: Color(0xFFC80A14),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Subtitle & Title matching screenshot:
                                    // "13 RESTAURANTS DELIVERING TO YOU"
                                    // "Featured"
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${restaurants.length} RESTAURANTS DELIVERING TO YOU',
                                            style: TextStyle(
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.9,
                                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                            ),
                                          ),
                                          SizedBox(height: 3.h),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Restaurants near you',
                                                style: TextStyle(
                                                  fontSize: 22.sp,
                                                  fontWeight: FontWeight.w900,
                                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                                ),
                                              ),
                                              if (!_filterCriteria.isDefault)
                                                InkWell(
                                                  onTap: () {
                                                    Haptics.light();
                                                    setState(() {
                                                      _filterCriteria = const RestaurantFilterCriteria();
                                                    });
                                                  },
                                                  child: Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.close_rounded, size: 14.sp, color: const Color(0xFFC80A14)),
                                                        SizedBox(width: 3.w),
                                                        Text(
                                                          'Clear filters',
                                                          style: TextStyle(
                                                            fontSize: 12.sp,
                                                            fontWeight: FontWeight.w700,
                                                            color: const Color(0xFFC80A14),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    SizedBox(height: 12.h),

                                    // Restaurant Cards
                                    ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: restaurants.length,
                                      itemBuilder: (context, index) {
                                        return RestaurantCard(
                                          restaurant: restaurants[index],
                                          index: index,
                                          selectedCategory: _selectedCategory,
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                              loading: () => const SkeletonRestaurantList(count: 3),
                              error: (err, stack) => _DebugErrorBox(
                                label: 'restaurantsList',
                                error: err,
                              ),
                            ),

                            SizedBox(height: 100.h),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Floating View Cart Bar
                FloatingViewCartBar(
                  key: _cartBarKey,
                  onTap: () {
                    Haptics.light();
                    context.go(RouteNames.cart);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  void _openFilter({
    required String title,
    required String emptyMessage,
    required IconData emptyIcon,
    required bool Function(RestaurantModel) matches,
  }) {
    Haptics.light();
    context.push(
      RouteNames.homeFilter,
      extra: HomeFilterArgs(
        title: title,
        emptyMessage: emptyMessage,
        emptyIcon: emptyIcon,
        matches: matches,
      ),
    );
  }



  List<RestaurantModel> _filterRestaurants(
    List<RestaurantModel> restaurants, {
    required List<FoodModel> matchingDishes,
    required List<RestaurantModel> categoryRestaurants,
  }) {
    final isVegOnly = ref.watch(vegFilterProvider);
    var filtered = RestaurantFilterCriteria.apply(
      restaurants: restaurants,
      criteria: _filterCriteria,
      isGlobalVegMode: isVegOnly,
      selectedCategory: 'All', // Menu-level strict filtering below
    );

    if (_selectedCategory != 'All' && _selectedCategory != 'More') {
      final q = _selectedCategory.toLowerCase().trim();
      final singular = (q.endsWith('s') && q.length > 3) ? q.substring(0, q.length - 1) : q;

      bool foodMatches(FoodModel f) {
        final text = '${f.name} ${f.categoryName} ${f.description}'.toLowerCase();
        return text.contains(q) || text.contains(singular);
      }

      final matchedRestIds = matchingDishes
          .where(foodMatches)
          .map((f) => f.restaurantId)
          .where((id) => id.isNotEmpty)
          .toSet();

      final matchedRestNames = matchingDishes
          .where(foodMatches)
          .map((f) => f.restaurantName.trim().toLowerCase())
          .where((n) => n.isNotEmpty)
          .toSet();

      matchedRestIds.addAll(categoryRestaurants.map((r) => r.id));

      for (final r in restaurants) {
        final menu = ref.read(restaurantMenuProvider(r.id)).asData?.value;
        if (menu != null && menu.any(foodMatches)) {
          matchedRestIds.add(r.id);
        }
      }

      filtered = filtered.where((r) {
        if (matchedRestIds.contains(r.id)) return true;
        if (matchedRestNames.contains(r.name.trim().toLowerCase())) return true;
        final rName = r.name.toLowerCase();
        final rTags = r.tags.map((t) => t.toLowerCase()).toList();
        final rRestTags = r.restaurantTags.map((t) => t.toLowerCase()).toList();
        return rTags.any((t) => t.contains(q) || t.contains(singular)) ||
            rRestTags.any((t) => t.contains(q) || t.contains(singular)) ||
            rName.contains(q) ||
            rName.contains(singular);
      }).toList();
    }

    return filtered;
  }

  void _showCategoryFilterSheet(
    BuildContext context,
    bool isDark,
    List<CategoryModel> categories,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: 0.85.sh),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'All Categories',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  children: [
                    if (categories.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        child: Text(
                          'No cuisines found',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 10.w,
                          mainAxisSpacing: 20.h,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: categories.length,
                        itemBuilder: (context, idx) {
                          final cat = categories[idx];
                          return InkWell(
                            borderRadius: BorderRadius.circular(16.r),
                            onTap: () {
                              Navigator.pop(ctx);
                              context.push(
                                RouteNames.categoryDetails,
                                extra: cat,
                              );
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Container(
                                  width: 60.r,
                                  height: 60.r,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: SmartImage(
                                      url: cat.imageUrl,
                                      category: ImageCategory.category,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  cat.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    SizedBox(height: 20.h),

                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Delegate for Sticky Persistent Category Bar on Home Screen
class _StickyCategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyCategoryHeaderDelegate({
    required this.child,
    required this.height,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: height,
      child: child,
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _StickyCategoryHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}


