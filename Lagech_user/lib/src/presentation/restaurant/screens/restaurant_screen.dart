import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/haptics.dart';
import '../../../domain/service/deep_link_service.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/restaurant_model.dart';
import '../../../domain/model/restaurant_menu_category.dart';
import '../../branding/app_colors.dart';
import '../../cart/utils/cart_restaurant_guard.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';
import '../../cart/widgets/floating_view_cart_bar.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../common_widgets/skeleton_loading.dart';
import '../../common_widgets/smart_image.dart';
import '../../coupons/viewmodels/coupons_viewmodel.dart';
import '../../favorites/viewmodels/favorites_viewmodel.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/restaurant_state.dart';
import '../viewmodels/restaurant_viewmodel.dart';
import '../widgets/food_detail_sheet.dart';
import 'restaurant_reviews_screen.dart';
import 'package:geolocator/geolocator.dart';
import '../../../di/location_providers.dart';

class RestaurantScreen extends ConsumerStatefulWidget {
  final RestaurantModel? restaurant;

  const RestaurantScreen({super.key, this.restaurant});

  @override
  ConsumerState<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends ConsumerState<RestaurantScreen> {

  late final TextEditingController _searchController;
  final GlobalKey<FloatingViewCartBarState> _cartBarKey =
      GlobalKey<FloatingViewCartBarState>();
  final Map<String, GlobalKey> _dishImageKeys = {};

  // ---- Category jump-navigation (chip bar <-> menu sections) ----
  final ScrollController _scrollController = ScrollController();
  final ScrollController _chipScrollController = ScrollController();
  final GlobalKey _topAnchorKey = GlobalKey();
  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, GlobalKey> _chipKeys = {};
  String _activeCategoryId = 'all';
  bool _isAutoScrolling = false;
  List<String> _lastSectionOrder = [];

  // ---- Collapsed categories ----
  final Set<String> _collapsedCategories = {};

  double get _categoryBarHeight => 38.h;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController.addListener(_onMainScroll);

    Future.microtask(() {
      Haptics.light();
      final targetRestaurant = widget.restaurant;
      if (targetRestaurant == null) return;
      ref.read(restaurantViewModelProvider.notifier).loadMenu(targetRestaurant);
    });
  }

  @override
  void didUpdateWidget(covariant RestaurantScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.restaurant != null &&
        widget.restaurant?.id != oldWidget.restaurant?.id) {
      ref.read(restaurantViewModelProvider.notifier).loadMenu(widget.restaurant!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _chipScrollController.dispose();
    super.dispose();
  }

  // ==================== CATEGORY JUMP NAVIGATION ====================

  void _onCategoryChipTap(String categoryId) {
    Haptics.light();
    setState(() => _activeCategoryId = categoryId);

    final targetKey = categoryId == 'all'
        ? _topAnchorKey
        : _sectionKeys[categoryId];
    final targetContext = targetKey?.currentContext;
    if (targetContext != null) {
      _isAutoScrolling = true;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0,
      ).then((_) {
        if (mounted) _isAutoScrolling = false;
      });
    }
    _ensureChipVisible(categoryId);
  }

  void _ensureChipVisible(String categoryId) {
    final chipContext = _chipKeys[categoryId]?.currentContext;
    if (chipContext == null) return;

    // Scope to the horizontal chip Scrollable only. The unscoped
    // Scrollable.ensureVisible() walks every ancestor Scrollable, which
    // would also drag the outer vertical CustomScrollView back toward
    // this pinned header's unpinned position.
    final horizontalScrollable = Scrollable.maybeOf(
      chipContext,
      axis: Axis.horizontal,
    );
    final renderObject = chipContext.findRenderObject();
    if (horizontalScrollable == null || renderObject == null) return;

    horizontalScrollable.position.ensureVisible(
      renderObject,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: 0.5,
    );
  }

  void _onMainScroll() {
    if (_isAutoScrolling || !mounted || _lastSectionOrder.isEmpty) return;

    final topThreshold =
        MediaQuery.of(context).padding.top + 58.h + _categoryBarHeight + 4.h;
    String newActive = 'all';
    for (final id in _lastSectionOrder) {
      final ctx = _sectionKeys[id]?.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top <= topThreshold) {
        newActive = id;
      } else {
        break;
      }
    }

    if (newActive != _activeCategoryId) {
      setState(() => _activeCategoryId = newActive);
      _ensureChipVisible(newActive);
    }
  }

  int _getQuantity(CartState cartState, String foodId) {
    for (final item in cartState.items) {
      if (item.food.id == foodId) return item.quantity;
    }
    return 0;
  }

  String? _getCartItemId(CartState cartState, String foodId) {
    for (final item in cartState.items) {
      if (item.food.id == foodId) return item.id;
    }
    return null;
  }

  /// Distance to [r] in km, or null when it genuinely cannot be worked out.
  ///
  /// Prefers what the backend measured. Falls back to computing it here from
  /// the restaurant's own coordinates, because distanceKm is only populated
  /// when *that particular request* carried the user's lat/lng — open the same
  /// restaurant from search or a shared link and it arrives as 0 even though
  /// both sets of coordinates are on hand.
  double? _resolvedDistanceKm(RestaurantModel r) {
    if (r.distanceKm > 0) return r.distanceKm;

    final rLat = r.latitude;
    final rLng = r.longitude;
    final me = ref.watch(userLatLngProvider).value;
    if (rLat == null || rLng == null || me == null) return null;

    final km = Geolocator.distanceBetween(me.lat, me.lng, rLat, rLng) / 1000;
    return km > 0 ? km : null;
  }

  /// Zomato-style rating info bottom sheet shown when the green rating badge is tapped.
  void _showRatingInfoSheet(BuildContext context, RestaurantModel restaurant) {
    final rating = restaurant.rating;
    final reviewCount = restaurant.reviewCount;
    final reviewText = reviewCount > 0
        ? '${reviewCount > 999 ? '${(reviewCount / 1000).toStringAsFixed(1)}K' : reviewCount} ratings'
        : 'ratings';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Rating badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF008A45),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: Colors.white, size: 20.sp),
                    SizedBox(width: 6.w),
                    Text(
                      rating.toStringAsFixed(1),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 14.h),

              // Subtitle
              Text(
                'Overall rating by $reviewText for',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: const Color(0xFF6B7280),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                restaurant.name,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 24.h),

              // Info box
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20.w),
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOW IS THIS RATING CALCULATED?',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44.r,
                          height: 44.r,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Icon(
                            Icons.star_outline_rounded,
                            color: const Color(0xFF008A45),
                            size: 24.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'It is calculated using a proprietary algorithm, and is not a simple average of all reviews.\n\nIt factors in recent experiences and filters out spam profiles to keep ratings authentic.',
                            style: TextStyle(
                              fontSize: 12.5.sp,
                              color: const Color(0xFF4B5563),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // Okay button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: SizedBox(
                  width: double.infinity,
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008A45),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: const Text(
                      'Okay',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 24.h),
            ],
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final restaurantState = ref.watch(restaurantViewModelProvider);
    final cartState = ref.watch(cartViewModelProvider);
    final currentRestaurant = restaurantState.restaurant ?? widget.restaurant;

    // Reached only via a restaurant card, so this is defensive rather than a
    // real state — but it must not fabricate a placeholder restaurant.
    if (currentRestaurant == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Restaurant unavailable')),
      );
    }

    final isFavorite = ref.watch(
      favoritesViewModelProvider.select(
        (s) => s.value?.restaurantIds.contains(currentRestaurant.id) ?? false,
      ),
    );

    final groupedByCategory = restaurantState.isLoading
        ? const <String, List<FoodModel>>{}
        : ref
              .read(restaurantViewModelProvider.notifier)
              .groupFilteredByCategory();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final restaurantOffersAsync = ref.watch(restaurantOffersProvider(currentRestaurant.id));
    final restaurantOffers = restaurantOffersAsync.value ?? const [];
    final hasAdminOffers = currentRestaurant.offerBadges.isNotEmpty || restaurantOffers.isNotEmpty;
    final primaryOfferText = currentRestaurant.offerBadges.isNotEmpty
        ? currentRestaurant.offerBadges.first
        : (restaurantOffers.isNotEmpty ? restaurantOffers.first.discountText : '');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
        body: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  // CLEAN TOP APP BAR (Back, Capsule Search, 3-dots More Menu)
                  _buildCleanTopAppBar(
                    context,
                    currentRestaurant,
                    isFavorite,
                    restaurantState,
                  ),

                  // REFRESHABLE MENU CONTENT AREA
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        Haptics.light();
                        await ref
                            .read(restaurantViewModelProvider.notifier)
                            .loadMenu(currentRestaurant, isRefresh: true);
                      },
                      color: AppColors.primary,
                      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          // Restaurant Info Header Card
                          SliverToBoxAdapter(
                            child: _buildCleanRestaurantHeader(
                              context,
                              currentRestaurant,
                              restaurantState: restaurantState,
                              hasAdminOffers: hasAdminOffers,
                              primaryOfferText: primaryOfferText,
                              restaurantOffers: restaurantOffers,
                            ),
                          ),

                          // Sticky Filter Chips Bar
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _StickyFilterAndCategoryBarDelegate(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildFilterChipsRow(context, restaurantState),
                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: isDark ? AppColors.borderDark : Colors.grey.shade100,
                                  ),
                                ],
                              ),
                              height: 38.h,
                            ),
                          ),

                          // Main Content Body
                          SliverToBoxAdapter(
                            child: restaurantState.isLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Column(
                                      children: [
                                        SkeletonFoodItemCard(),
                                        SkeletonFoodItemCard(),
                                        SkeletonFoodItemCard(),
                                      ],
                                    ),
                                  )
                                : Column(
                                    children: [
                                      SizedBox(height: 4.h),
                                      
                                      // Dishes grouped into jump-to category sections
                                      _buildCategorySections(
                                        context,
                                        restaurantState,
                                        restaurantState.categories,
                                        groupedByCategory,
                                        cartState,
                                        hasAdminOffers: hasAdminOffers,
                                        primaryOfferText: primaryOfferText,
                                        restaurantOffers: restaurantOffers,
                                      ),
                                      SizedBox(height: 110.h),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Floating View Cart Bar
              FloatingViewCartBar(
                key: _cartBarKey,
                onTap: () {
                  Haptics.light();
                  context.go(RouteNames.cart);
                },
              ),

              // Floating MENU Button
              Positioned(
                right: 16.w,
                bottom: cartState.items.isNotEmpty ? 90.h : 20.h,
                child: _buildFloatingMenuButton(context, restaurantState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== CLEAN TOP APP BAR ====================

  Widget _buildCleanTopAppBar(
    BuildContext context,
    RestaurantModel restaurant,
    bool isFavorite,
    RestaurantState state,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.backgroundDark : Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 8.h),
      child: Row(
        children: [
          // Circular Back Button
          GestureDetector(
            onTap: () {
              Haptics.light();
              if (state.searchQuery.isNotEmpty) {
                _searchController.clear();
                ref.read(restaurantViewModelProvider.notifier).setSearchQuery('');
                FocusManager.instance.primaryFocus?.unfocus();
              } else if (context.canPop()) {
                context.pop();
              } else {
                context.go(RouteNames.home);
              }
            },
            child: Container(
              width: 38.r,
              height: 38.r,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F3F5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? Colors.white : const Color(0xFF1E232C),
                size: 20.sp,
              ),
            ),
          ),
          SizedBox(width: 10.w),

          // Search Field in Top Bar — pill capsule style matching screenshot
          Expanded(
            child: Container(
              height: 42.h,
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : const Color(0xFFE8E8E8),
                  width: 1,
                ),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF8A8A8A),
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textAlignVertical: TextAlignVertical.center,
                      textInputAction: TextInputAction.search,
                      autocorrect: false,
                      enableSuggestions: false,
                      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                      onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                      onChanged: (val) {
                        ref.read(restaurantViewModelProvider.notifier).setSearchQuery(val);
                      },
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        color: isDark ? AppColors.textPrimaryDark : const Color(0xFF222222),
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search dishes...',
                        hintStyle: TextStyle(
                          fontSize: 13.5.sp,
                          color: isDark ? AppColors.textSecondaryDark : const Color(0xFFAAAAAA),
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        // The theme fills every TextField; here that drew a
                        // second, differently coloured box inside the pill.
                        filled: false,
                        fillColor: Colors.transparent,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        Haptics.light();
                        _searchController.clear();
                        ref.read(restaurantViewModelProvider.notifier).setSearchQuery('');
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      child: Container(
                        padding: EdgeInsets.all(3.r),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : const Color(0xFFE0E0E0),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white70 : const Color(0xFF555555),
                          size: 13.sp,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: 10.w),

          // Circular Three-Dots Menu Button
          Container(
            width: 38.r,
            height: 38.r,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F3F5),
              shape: BoxShape.circle,
            ),
            child: PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.more_vert_rounded,
                color: isDark ? Colors.white : const Color(0xFF1E232C),
                size: 20.sp,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              color: isDark ? AppColors.cardDark : Colors.white,
              onSelected: (value) {
                Haptics.light();
                if (value == 'favorite') {
                  ref.read(favoritesViewModelProvider.notifier).toggle(restaurant.id, restaurant);
                } else if (value == 'share') {
                  final text = DeepLinkService.generateRestaurantShareText(
                    restaurantName: restaurant.name,
                    restaurantId: restaurant.id,
                    cuisines: restaurant.tags.join(', '),
                  );
                  SharePlus.instance.share(ShareParams(text: text));
                } else if (value == 'info') {
                  _showRestaurantInfoSheet(context, restaurant);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'favorite',
                  child: Row(
                    children: [
                      Icon(
                        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFavorite ? const Color(0xFFFF4B72) : (isDark ? Colors.white70 : Colors.black87),
                        size: 18.sp,
                      ),
                      SizedBox(width: 10.w),
                      Text(isFavorite ? 'Favorited' : 'Add to Favorites', style: TextStyle(fontSize: 13.sp)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(
                        Icons.share_outlined,
                        color: isDark ? Colors.white70 : Colors.black87,
                        size: 18.sp,
                      ),
                      SizedBox(width: 10.w),
                      Text('Share Restaurant', style: TextStyle(fontSize: 13.sp)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: isDark ? Colors.white70 : Colors.black87,
                        size: 18.sp,
                      ),
                      SizedBox(width: 10.w),
                      Text('Restaurant Details', style: TextStyle(fontSize: 13.sp)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== RESTAURANT HEADER CARD ====================

  Widget _buildCleanRestaurantHeader(
    BuildContext context,
    RestaurantModel restaurant, {
    RestaurantState? restaurantState,
    bool hasAdminOffers = false,
    String primaryOfferText = '',
    List<CouponModel> restaurantOffers = const [],
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayRating = restaurant.rating > 0
        ? restaurant.rating.toStringAsFixed(1)
        : '4.8';
    final reviewText = restaurant.reviewCount > 0
        ? 'By ${restaurant.reviewCount}+'
        : 'By 1,247+';

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 10.h),
      color: isDark ? AppColors.backgroundDark : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Closed Alert Banner
          if (!restaurant.isOpen) ...[
            Container(
              margin: EdgeInsets.only(bottom: 10.h),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3B1E1E) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.store_mall_directory_outlined,
                    color: Color(0xFFDC2626),
                    size: 22,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Restaurant Currently Closed',
                          style: TextStyle(
                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'This restaurant is not accepting orders at the moment.',
                          style: TextStyle(
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF7F1D1D),
                            fontSize: 11.5.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Pure Veg Indicator matching Screenshot 5 (only if restaurant is pure veg)
          if (restaurant.isPureVeg) ...[
            Row(
              children: [
                Icon(Icons.eco_rounded, color: const Color(0xFF008A45), size: 14.sp),
                SizedBox(width: 4.w),
                Text(
                  'Pure Veg',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF008A45),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
          ],

          // Name & Info icon + Rating pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        restaurant.name,
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF1E232C),
                          letterSpacing: -0.3,
                          height: 1.15,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    GestureDetector(
                      onTap: () => _showRestaurantInfoSheet(context, restaurant),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 18.sp,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              // Green rating pill + review count -> shows rating info popup
              GestureDetector(
                onTap: () {
                  Haptics.light();
                  _showRatingInfoSheet(context, restaurant);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF008A45),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, color: Colors.white, size: 14.sp),
                          SizedBox(width: 3.w),
                          Text(
                            displayRating,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 3.h),
                    GestureDetector(
                      onTap: () {
                        Haptics.light();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => RestaurantReviewsScreen(
                              restaurant: restaurant,
                              menuItems: restaurantState?.allItems ?? const [],
                            ),
                          ),
                        );
                      },
                      child: Text(
                        reviewText,
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 8.h),

          // Locality & distance row: 📍 1.2 km · RNT Marg ˅
          GestureDetector(
            onTap: () => _showRestaurantInfoSheet(context, restaurant),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primary,
                  size: 15.sp,
                ),
                SizedBox(width: 4.w),
                Flexible(
                  child: Text(
                    [
                      if (_resolvedDistanceKm(restaurant) case final km?)
                        '${km.toStringAsFixed(1)} km',
                      if (restaurant.area.isNotEmpty) restaurant.area,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF4A4A4A),
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16.sp,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),

          SizedBox(height: 6.h),

          // Delivery time row matching Screenshot 5: ⚡ 15-20 mins · Schedule for later ˅
          Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                color: const Color(0xFF008A45),
                size: 16.sp,
              ),
              SizedBox(width: 3.w),
              Text(
                restaurant.deliveryTime.isNotEmpty ? '${restaurant.deliveryTime} · Schedule for later' : 'Schedule for later',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF374151),
                ),
              ),
              SizedBox(width: 4.w),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16.sp,
                color: Colors.grey[500],
              ),
            ],
          ),

          SizedBox(height: 8.h),

          // Offers row: only when the restaurant really has offers.
          if (primaryOfferText.isNotEmpty)
          GestureDetector(
            onTap: () => _showOffersSheet(context, restaurant, restaurantOffers),
            child: Container(
              margin: EdgeInsets.only(top: 10.h),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(3.r),
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.percent_rounded, color: Colors.white, size: 11.sp),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      primaryOfferText,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E232C),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${restaurant.offerBadges.length + restaurantOffers.length} offer${restaurant.offerBadges.length + restaurantOffers.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16.sp,
                    color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),

          // Closed banner if not open
          if (!restaurant.isOpen)
            Container(
              margin: EdgeInsets.only(top: 10.h),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_clock_rounded,
                    color: const Color(0xFFD32F2F),
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Currently Closed • Not accepting orders right now',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFC62828),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showRestaurantInfoSheet(BuildContext context, RestaurantModel restaurant) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 28.h),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white30 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                restaurant.name,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E232C),
                ),
              ),
              if (restaurant.tags.isNotEmpty) ...[
                SizedBox(height: 4.h),
                Text(
                  restaurant.tags.join(', '),
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                ),
              ],
              SizedBox(height: 16.h),
              Divider(height: 1, color: isDark ? AppColors.borderDark : Colors.grey.shade200),
              SizedBox(height: 14.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined, size: 18.sp, color: AppColors.primary),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      restaurant.area.isNotEmpty ? restaurant.area : 'Local Area',
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 18.sp, color: Colors.grey[600]),
                  SizedBox(width: 10.w),
                  Text(
                    restaurant.deliveryTime.isNotEmpty ? 'Delivery: ${restaurant.deliveryTime}' : 'Delivery',
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              if (restaurant.isPureVeg) ...[
                SizedBox(height: 12.h),
                Row(
                  children: [
                    _buildVegIcon(size: 14),
                    SizedBox(width: 10.w),
                    Text(
                      'Pure Veg Restaurant',
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFF008A45)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showOffersSheet(
    BuildContext context,
    RestaurantModel restaurant, [
    List<CouponModel> offers = const [],
  ]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 28.h),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white30 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Available Offers',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E232C),
                ),
              ),
              SizedBox(height: 14.h),
              if (offers.isNotEmpty) ...[
                for (final c in offers) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 20.sp),
                    ),
                    title: Text(
                      c.discountText.isNotEmpty ? c.discountText : (c.code.isNotEmpty ? c.code : 'Special Offer'),
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      [
                        if (c.code.isNotEmpty) 'Use code: ${c.code}',
                        if (c.minSpend > 0) 'Min order: ₹${c.minSpend.toStringAsFixed(0)}',
                      ].join(' • '),
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                    ),
                    trailing: c.code.isNotEmpty
                        ? TextButton(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: c.code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Coupon ${c.code} copied!')),
                              );
                            },
                            child: const Text('COPY'),
                          )
                        : null,
                  ),
                  Divider(height: 1, color: isDark ? AppColors.borderDark : Colors.grey.shade200),
                ],
              ] else if (restaurant.offerBadges.isNotEmpty) ...[
                for (final badge in restaurant.offerBadges) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 20.sp),
                    ),
                    title: Text(badge, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700)),
                    subtitle: Text('Valid on this restaurant', style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                  ),
                  Divider(height: 1, color: isDark ? AppColors.borderDark : Colors.grey.shade200),
                ],
              ],
              if (restaurant.isFreeDelivery) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFF008A45).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(Icons.delivery_dining_rounded, color: const Color(0xFF008A45), size: 20.sp),
                  ),
                  title: Text('Free Delivery', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700)),
                  subtitle: Text('Available on this restaurant', style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ==================== FILTER CHIPS ROW ====================

  Widget _buildFilterChipsRow(BuildContext context, RestaurantState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vm = ref.read(restaurantViewModelProvider.notifier);
    final hasAnyFilter = state.isVegOnly ||
        state.isNonVegOnly ||
        state.isBestSellerOnly ||
        state.isRatingSort;

    return SizedBox(
      height: 32.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        children: [
          // Filters ˅ chip
          GestureDetector(
            onTap: () {
              Haptics.light();
              if (hasAnyFilter) {
                if (state.isVegOnly) vm.toggleVegOnly();
                if (state.isNonVegOnly) vm.toggleNonVegOnly();
                if (state.isBestSellerOnly) vm.toggleBestSeller();
                if (state.isRatingSort) vm.toggleRatingSort();
              }
            },
            child: Container(
              margin: EdgeInsets.only(right: 6.w),
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              decoration: BoxDecoration(
                color: hasAnyFilter
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: hasAnyFilter
                      ? AppColors.primary
                      : (isDark ? AppColors.borderDark : const Color(0xFFD1D5DB)),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasAnyFilter ? 'Clear' : 'Filters',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: hasAnyFilter
                          ? AppColors.primary
                          : (isDark ? AppColors.textSecondaryDark : const Color(0xFF1E232C)),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 15.sp,
                    color: hasAnyFilter
                        ? AppColors.primary
                        : (isDark ? Colors.white70 : const Color(0xFF1E232C)),
                  ),
                ],
              ),
            ),
          ),

          // Veg chip: solid green circle dot + "Veg"
          GestureDetector(
            onTap: () {
              Haptics.light();
              if (state.isNonVegOnly) vm.toggleNonVegOnly();
              vm.toggleVegOnly();
            },
            child: Container(
              margin: EdgeInsets.only(right: 6.w),
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              decoration: BoxDecoration(
                color: state.isVegOnly
                    ? const Color(0xFF008A45).withValues(alpha: 0.12)
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: state.isVegOnly
                      ? const Color(0xFF008A45)
                      : (isDark ? AppColors.borderDark : const Color(0xFFD1D5DB)),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7.r,
                    height: 7.r,
                    decoration: const BoxDecoration(
                      color: Color(0xFF008A45),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 5.w),
                  Text(
                    'Veg',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: state.isVegOnly
                          ? const Color(0xFF008A45)
                          : (isDark ? AppColors.textSecondaryDark : const Color(0xFF1E232C)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Non-veg chip: solid brown circle dot + "Non-veg"
          GestureDetector(
            onTap: () {
              Haptics.light();
              if (state.isVegOnly) vm.toggleVegOnly();
              vm.toggleNonVegOnly();
            },
            child: Container(
              margin: EdgeInsets.only(right: 6.w),
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              decoration: BoxDecoration(
                color: state.isNonVegOnly
                    ? const Color(0xFFB45309).withValues(alpha: 0.12)
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: state.isNonVegOnly
                      ? const Color(0xFFB45309)
                      : (isDark ? AppColors.borderDark : const Color(0xFFD1D5DB)),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7.r,
                    height: 7.r,
                    decoration: const BoxDecoration(
                      color: Color(0xFFB45309),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 5.w),
                  Text(
                    'Non-veg',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: state.isNonVegOnly
                          ? const Color(0xFFB45309)
                          : (isDark ? AppColors.textSecondaryDark : const Color(0xFF1E232C)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Spicy chip: flame icon + "Spicy"
          GestureDetector(
            onTap: () {
              Haptics.light();
              vm.toggleBestSeller();
            },
            child: Container(
              margin: EdgeInsets.only(right: 6.w),
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              decoration: BoxDecoration(
                color: state.isBestSellerOnly
                    ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: state.isBestSellerOnly
                      ? const Color(0xFFEF4444)
                      : (isDark ? AppColors.borderDark : const Color(0xFFD1D5DB)),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 14.sp,
                    color: const Color(0xFFEF4444),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'Spicy',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: state.isBestSellerOnly
                          ? const Color(0xFFEF4444)
                          : (isDark ? AppColors.textSecondaryDark : const Color(0xFF1E232C)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Highly reordered chip matching Screenshot 5
          GestureDetector(
            onTap: () {
              Haptics.light();
              vm.toggleRatingSort();
            },
            child: Container(
              margin: EdgeInsets.only(right: 6.w),
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              decoration: BoxDecoration(
                color: state.isRatingSort
                    ? const Color(0xFF008A45).withValues(alpha: 0.12)
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: state.isRatingSort
                      ? const Color(0xFF008A45)
                      : (isDark ? AppColors.borderDark : const Color(0xFFD1D5DB)),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.autorenew_rounded,
                    size: 14.sp,
                    color: const Color(0xFF008A45),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'Top rated',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: state.isRatingSort
                          ? const Color(0xFF008A45)
                          : (isDark ? AppColors.textSecondaryDark : const Color(0xFF1E232C)),
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

  // ==================== CATEGORY SECTIONS (jump-to-section menu) ====================

  Widget _buildCategorySections(
    BuildContext context,
    RestaurantState restaurantState,
    List<RestaurantMenuCategory> categories,
    Map<String, List<FoodModel>> grouped,
    CartState cartState, {
    bool hasAdminOffers = false,
    String primaryOfferText = '',
    List<CouponModel> restaurantOffers = const [],
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sections = <RestaurantMenuCategory>[];

    for (final c in categories) {
      if (c.id != 'all' && (grouped[c.id]?.isNotEmpty ?? false)) {
        sections.add(c);
      }
    }

    // Safety fallback: if grouped has entries not in categories (e.g. 'menu' or extra categories)
    for (final entry in grouped.entries) {
      if (entry.key != 'all' &&
          entry.value.isNotEmpty &&
          !sections.any((s) => s.id == entry.key)) {
        sections.add(RestaurantMenuCategory(
          id: entry.key,
          name: entry.key == 'menu' ? 'Menu' : entry.key,
          itemCount: entry.value.length,
        ));
      }
    }

    // Safety fallback: if sections is empty but filteredItems has dishes, group all into a 'Menu' section
    if (sections.isEmpty && restaurantState.filteredItems.isNotEmpty) {
      grouped['menu'] = restaurantState.filteredItems;
      sections.add(RestaurantMenuCategory(
        id: 'menu',
        name: 'Menu',
        itemCount: restaurantState.filteredItems.length,
      ));
    }

    _lastSectionOrder = sections.map((c) => c.id).toList();

    if (sections.isEmpty) {
      if (restaurantState.errorMessage != null && restaurantState.allItems.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.restaurant_menu_outlined, size: 48.sp, color: Colors.grey[400]),
                SizedBox(height: 12.h),
                Text(
                  restaurantState.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                  ),
                ),
                SizedBox(height: 16.h),
                ElevatedButton.icon(
                  onPressed: () {
                    if (widget.restaurant != null) {
                      ref.read(restaurantViewModelProvider.notifier).loadMenu(widget.restaurant!, isRefresh: true);
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 44.sp, color: Colors.grey[400]),
              SizedBox(height: 10.h),
              Text(
                'No dishes match your filters.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                ),
              ),
              if (restaurantState.allItems.isNotEmpty) ...[
                SizedBox(height: 10.h),
                TextButton(
                  onPressed: () {
                    final vm = ref.read(restaurantViewModelProvider.notifier);
                    if (restaurantState.isVegOnly) vm.toggleVegOnly();
                    if (restaurantState.isNonVegOnly) vm.toggleNonVegOnly();
                    if (restaurantState.isBestSellerOnly) vm.toggleBestSeller();
                    if (restaurantState.isRatingSort) vm.toggleRatingSort();
                    vm.selectCategory('all');
                    _searchController.clear();
                    vm.setSearchQuery('');
                  },
                  child: const Text('Clear all filters'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      key: _topAnchorKey,
      children: [
        for (final category in sections) ...[
          // ---- Category Header ----
          () {
            return GestureDetector(
              onTap: () {
                Haptics.light();
                setState(() {
                  if (_collapsedCategories.contains(category.id)) {
                    _collapsedCategories.remove(category.id);
                  } else {
                    _collapsedCategories.add(category.id);
                  }
                });
              },
              child: Container(
                key: _sectionKeys.putIfAbsent(category.id, () => GlobalKey()),
                margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceDark.withValues(alpha: 0.6)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    // Accent indicator bar
                    Container(
                      width: 4.w,
                      height: 18.h,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    // Category Name
                    Expanded(
                      child: Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1E232C),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    // Items Count Badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        '${grouped[category.id]!.length}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    AnimatedRotation(
                      turns: _collapsedCategories.contains(category.id) ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22.sp,
                        color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }(),

          // ---- Category Items (collapsible) ----
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            crossFadeState: _collapsedCategories.contains(category.id)
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: _buildDishesList(context, grouped[category.id]!, cartState),
            secondChild: const SizedBox.shrink(),
          ),

          // ---- Coupon Banner after recommended category (only if valid in admin for this restaurant) ----
          if (category == sections.first && hasAdminOffers && primaryOfferText.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    primaryOfferText,
                    style: TextStyle(
                      fontSize: 16.5.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E232C),
                    ),
                  ),
                  SizedBox(height: 3.h),
                  GestureDetector(
                    onTap: () {
                      Haptics.light();
                      final currentRest = (ref.read(restaurantViewModelProvider).restaurant ?? widget.restaurant);
                      if (currentRest != null) {
                        _showOffersSheet(context, currentRest, restaurantOffers);
                      }
                    },
                    child: Text(
                      'View coupon details',
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ---- Divider between categories ----
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 4.h),
            child: Divider(
              height: 1,
              thickness: 1,
              color: isDark ? AppColors.borderDark : Colors.grey.shade200,
            ),
          ),
        ],
        SizedBox(height: 8.h),
      ],
    );
  }

  // ==================== DISHES LIST (HORIZONTAL FOOD CARDS) ====================

  Widget _buildDishesList(
    BuildContext context,
    List<FoodModel> dishes,
    CartState cartState,
  ) {
    if (dishes.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.h),
          child: Text(
            'No dishes match your filters.',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: dishes.length,
      separatorBuilder: (context, index) => Divider(
        height: 24.h,
        thickness: 1,
        color: isDark ? AppColors.borderDark : Colors.grey.shade200,
        indent: 16.w,
        endIndent: 16.w,
      ),
      itemBuilder: (context, index) {
        return _buildHorizontalDishCard(context, dishes[index], cartState);
      },
    );
  }

  Widget _buildHorizontalDishCard(
    BuildContext context,
    FoodModel dish,
    CartState cartState,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final quantity = _getQuantity(cartState, dish.id);
    final cartItemId = _getCartItemId(cartState, dish.id);
    final isHighlyReordered = dish.isPopular || dish.rating >= 4.0 || dish.reviewCount > 0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT COLUMN: Details
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Haptics.light();
                final restaurantName = (ref.read(restaurantViewModelProvider).restaurant ??
                        widget.restaurant)
                    ?.name;
                FoodDetailSheet.show(context, dish, restaurantName: restaurantName);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Veg / Non-veg icon
                  dish.isVeg ? _buildVegIcon(size: 13) : _buildNonVegIcon(size: 13),
                  SizedBox(height: 5.h),

                  // Dish Title
                  Text(
                    dish.name,
                    style: TextStyle(
                      fontSize: 15.5.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E232C),
                      height: 1.25,
                    ),
                  ),

                  // Green indicator tag: ━━━━ highly reordered
                  if (isHighlyReordered) ...[
                    SizedBox(height: 4.h),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18.w,
                          height: 2.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF008A45),
                            borderRadius: BorderRadius.circular(1.r),
                          ),
                        ),
                        SizedBox(width: 5.w),
                        Text(
                          'highly reordered',
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF008A45),
                          ),
                        ),
                      ],
                    ),
                  ],

                  SizedBox(height: 6.h),

                  // Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '₹${dish.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14.5.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1E232C),
                        ),
                      ),
                      if (dish.originalPrice != null && dish.originalPrice! > dish.price) ...[
                        SizedBox(width: 6.w),
                        Text(
                          '₹${dish.originalPrice!.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Description
                  if (dish.description.isNotEmpty) ...[
                    SizedBox(height: 5.h),
                    Text(
                      dish.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF757575),
                        height: 1.3,
                      ),
                    ),
                  ],

                  SizedBox(height: 10.h),

                  // Bookmark & Share icons
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Haptics.light();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Saved "${dish.name}" to favorites'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.all(5.r),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark ? AppColors.borderDark : Colors.grey.shade300,
                              width: 0.8,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.bookmark_border_rounded,
                            size: 14.sp,
                            color: isDark ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      GestureDetector(
                        onTap: () {
                          Haptics.light();
                          final text = 'Order ${dish.name} on Lagech App!';
                          SharePlus.instance.share(ShareParams(text: text));
                        },
                        child: Container(
                          padding: EdgeInsets.all(5.r),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark ? AppColors.borderDark : Colors.grey.shade300,
                              width: 0.8,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.share_outlined,
                            size: 14.sp,
                            color: isDark ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(width: 14.w),

          // RIGHT COLUMN: Food image + Overlapping ADD button
          Column(
            children: [
              SizedBox(
                width: 118.w,
                height: 122.h,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    // Image
                    GestureDetector(
                      onTap: () {
                        Haptics.light();
                        final restaurantName = (ref.read(restaurantViewModelProvider).restaurant ??
                                widget.restaurant)
                            ?.name;
                        FoodDetailSheet.show(context, dish, restaurantName: restaurantName);
                      },
                      child: Container(
                        key: _dishImageKeys.putIfAbsent(dish.id, () => GlobalKey()),
                        width: 118.w,
                        height: 105.h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14.r),
                          color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F3F5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: SmartImage(
                          url: dish.imageUrl,
                          category: ImageCategory.food,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    // Overlapping ADD button at bottom center
                    Positioned(
                      bottom: 0,
                      child: _buildOverlapAddButton(context, dish, quantity, cartItemId),
                    ),
                  ],
                ),
              ),

              // "customisable" text
              if (dish.variants.isNotEmpty) ...[
                SizedBox(height: 3.h),
                Text(
                  'customisable',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleFirstAddToCart(FoodModel dish) async {
    final currentRestaurant =
        ref.read(restaurantViewModelProvider).restaurant ?? widget.restaurant;
    if (currentRestaurant != null && !currentRestaurant.isOpen) {
      AppSnackbar.warning(
        context,
        '${currentRestaurant.name} is currently closed and not accepting orders.',
      );
      return;
    }
    Haptics.light();
    await addFoodToCart(context, ref, dish);
  }

  Widget _buildOverlapAddButton(
    BuildContext context,
    FoodModel dish,
    int quantity,
    String? cartItemId,
  ) {
    final currentRestaurant =
        ref.watch(restaurantViewModelProvider).restaurant ?? widget.restaurant;
    final isClosed = currentRestaurant != null && !currentRestaurant.isOpen;

    if (isClosed) {
      return GestureDetector(
        key: const ValueKey('closed_btn'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppSnackbar.warning(
            context,
            '${currentRestaurant.name} is currently closed and not accepting orders.',
          );
        },
        child: Container(
          width: 96.w,
          height: 34.h,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(8.r),
          ),
          alignment: Alignment.center,
          child: Text(
            'CLOSED',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }

    final hasQty = quantity > 0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: !hasQty
          ? GestureDetector(
              key: const ValueKey('add_btn'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _handleFirstAddToCart(dish),
              child: Container(
                width: 96.w,
                height: 34.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFF05151),
                  borderRadius: BorderRadius.circular(8.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF05151).withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.remove_rounded,
                      color: Colors.white70,
                      size: 14.sp,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'ADD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 14.sp,
                    ),
                  ],
                ),
              ),
            )
          : Container(
              key: const ValueKey('stepper_btn'),
              width: 96.w,
              height: 34.h,
              decoration: BoxDecoration(
                color: const Color(0xFFF05151),
                borderRadius: BorderRadius.circular(8.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF05151).withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: cartItemId == null
                        ? null
                        : () {
                            Haptics.light();
                            ref
                                .read(cartViewModelProvider.notifier)
                                .updateQuantity(cartItemId, quantity - 1);
                          },
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      child: Icon(
                        Icons.remove_rounded,
                        color: Colors.white,
                        size: 16.sp,
                      ),
                    ),
                  ),
                  Text(
                    '$quantity',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: cartItemId == null
                        ? null
                        : () {
                            Haptics.light();
                            ref
                                .read(cartViewModelProvider.notifier)
                                .updateQuantity(cartItemId, quantity + 1);
                          },
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      child: Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 16.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ==================== FLOATING MENU BUTTON ====================

  Widget _buildFloatingMenuButton(BuildContext context, RestaurantState state) {
    return GestureDetector(
      onTap: () {
        Haptics.medium();
        _showCategoryBottomSheet(context, state);
      },
      child: Container(
        width: 60.r,
        height: 60.r,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/menuicon.png',
              width: 20.sp,
              height: 20.sp,
              color: Colors.white,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.restaurant_menu, color: Colors.white, size: 20.sp),
            ),
            SizedBox(height: 2.h),
            Text(
              'MENU',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryBottomSheet(BuildContext context, RestaurantState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = state.categories;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24.r),
              topRight: Radius.circular(24.r),
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white30 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Menu Categories',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  separatorBuilder: (context, index) => Divider(
                    color: isDark ? AppColors.borderDark : Colors.grey.shade200,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final category = categories[index];

                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(vertical: 4.h),
                      title: Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E1E1E),
                        ),
                      ),
                      trailing: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          '${category.itemCount}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _onCategoryChipTap(category.id);
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: 10.h),
            ],
          ),
        );
      },
    );
  }


  Widget _buildVegIcon({double size = 10}) {
    return Container(
      width: size.sp,
      height: size.sp,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF008A45), width: 1),
        borderRadius: BorderRadius.circular(2.r),
      ),
      alignment: Alignment.center,
      child: Container(
        width: (size * 0.4).sp,
        height: (size * 0.4).sp,
        decoration: const BoxDecoration(
          color: Color(0xFF008A45),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildNonVegIcon({double size = 10}) {
    return Container(
      width: size.sp,
      height: size.sp,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE23744), width: 1),
        borderRadius: BorderRadius.circular(2.r),
      ),
      alignment: Alignment.center,
      child: CustomPaint(
        size: Size((size * 0.5).sp, (size * 0.5).sp),
        painter: _TrianglePainter(color: const Color(0xFFE23744)),
      ),
    );
  }
}

// Delegate for Sticky Persistent Filter & Category Bar
class _StickyFilterAndCategoryBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyFilterAndCategoryBarDelegate({
    required this.child,
    required this.height,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.backgroundDark : Colors.white,
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _StickyFilterAndCategoryBarDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}