import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/food_model.dart';
import '../../../di/catalog_providers.dart';
import '../../../domain/model/store99_product.dart';
import '../../branding/app_colors.dart';
import '../../cart/utils/cart_restaurant_guard.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';
import '../../cart/widgets/floating_view_cart_bar.dart';
import '../../common_widgets/app_refresh_indicator.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../common_widgets/smart_image.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/store99_viewmodel.dart';
import '../widgets/food_detail_sheet.dart';

/// The 99 Store promo screen, redesigned to match the Restaurant UI.
class Store99Screen extends ConsumerStatefulWidget {
  const Store99Screen({super.key});

  @override
  ConsumerState<Store99Screen> createState() => _Store99ScreenState();
}

class _Store99ScreenState extends ConsumerState<Store99Screen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<FloatingViewCartBarState> _cartBarKey =
      GlobalKey<FloatingViewCartBarState>();
  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, GlobalKey> _dishImageKeys = {};
  final Set<String> _collapsedCategories = {};

  bool _isSearchExpanded = false;
  String _searchQuery = '';
  bool _isVegOnly = false;
  bool _isNonVegOnly = false;
  bool _isQuickDeliveryOnly = false;
  bool _isRatingSort = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(store99ViewModelProvider.notifier).loadMoreProducts();
    }
  }

  Future<void> _handleFirstAddToCart(FoodModel food) async {
    final restaurant = ref.read(restaurantByIdProvider(food.restaurantId)).asData?.value;
    if (restaurant != null && !restaurant.isOpen) {
      AppSnackbar.warning(
        context,
        '${restaurant.name} is currently closed and not accepting orders.',
      );
      return;
    }
    Haptics.light();
    await addFoodToCart(context, ref, food);
  }

  int _getQuantity(CartState cartState, String productId) {
    for (final item in cartState.items) {
      if (item.food.id == productId) return item.quantity;
    }
    return 0;
  }

  String? _getCartItemId(CartState cartState, String productId) {
    for (final item in cartState.items) {
      if (item.food.id == productId) return item.id;
    }
    return null;
  }

  void _onProductTap(Store99Product product) {
    Haptics.light();
    FoodDetailSheet.show(
      context,
      product.toFoodModel(),
      restaurantName: product.restaurantName.isNotEmpty
          ? product.restaurantName
          : '₹99 Store',
    );
  }

  void _scrollToSection(String categoryId) {
    final key = _sectionKeys[categoryId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        alignment: 0.08,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final storeState = ref.watch(store99ViewModelProvider);
    final cartState = ref.watch(cartViewModelProvider);

    // Combine trending and explore dishes (deduped by ID)
    final allProductsMap = <String, Store99Product>{};
    for (final dish in storeState.trendingDishes) {
      allProductsMap[dish.id] = dish;
    }
    for (final dish in storeState.exploreDishes) {
      allProductsMap[dish.id] = dish;
    }

    var productList = allProductsMap.values.toList();

    // Filters
    if (_isVegOnly) {
      productList = productList.where((p) => p.isVeg).toList();
    }
    if (_isNonVegOnly) {
      productList = productList.where((p) => !p.isVeg).toList();
    }
    if (_isQuickDeliveryOnly) {
      productList = productList.where((p) => p.isQuickDelivery).toList();
    }
    if (_isRatingSort) {
      productList.sort((a, b) => b.rating.compareTo(a.rating));
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      productList = productList
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q) ||
              p.restaurantName.toLowerCase().contains(q))
          .toList();
    }

    // Group items into categories matching restaurant style
    final Map<String, List<Store99Product>> grouped = {};
    final List<_StoreCategoryItem> categories = [];

    // 1. Group by primary food categories (Pizza, Burger, etc.) matching the screenshot
    final Map<String, List<Store99Product>> primaryGroups = {
      'Pizza': [],
      'Burger': [],
      'Biryani': [],
      'Sandwiches & Snacks': [],
      'Beverages & Shakes': [],
      'Combos & Meals': [],
    };

    final assignedIds = <String>{};

    for (final p in productList) {
      final name = p.name.toLowerCase();
      final cuisine = p.cuisineId.toLowerCase();
      if (name.contains('pizza') || cuisine.contains('pizza')) {
        primaryGroups['Pizza']!.add(p);
        assignedIds.add(p.id);
      } else if (name.contains('burger') || cuisine.contains('burger')) {
        primaryGroups['Burger']!.add(p);
        assignedIds.add(p.id);
      } else if (name.contains('biryani') || cuisine.contains('biryani')) {
        primaryGroups['Biryani']!.add(p);
        assignedIds.add(p.id);
      } else if (name.contains('sandwich') ||
          name.contains('roll') ||
          name.contains('snack') ||
          name.contains('fries') ||
          name.contains('nuggets')) {
        primaryGroups['Sandwiches & Snacks']!.add(p);
        assignedIds.add(p.id);
      } else if (name.contains('shake') ||
          name.contains('tea') ||
          name.contains('coffee') ||
          name.contains('drink') ||
          name.contains('beverage') ||
          name.contains('juice')) {
        primaryGroups['Beverages & Shakes']!.add(p);
        assignedIds.add(p.id);
      } else if (name.contains('combo') ||
          name.contains('meal') ||
          name.contains('thali') ||
          name.contains('rice') ||
          name.contains('noodles')) {
        primaryGroups['Combos & Meals']!.add(p);
        assignedIds.add(p.id);
      }
    }

    primaryGroups.forEach((name, items) {
      if (items.isNotEmpty) {
        final id = name.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
        grouped[id] = items;
        categories.add(_StoreCategoryItem(id: id, name: name, count: items.length));
      }
    });

    // 2. Add any remaining cuisines from storeState
    final remainingProducts = productList.where((p) => !assignedIds.contains(p.id)).toList();
    if (remainingProducts.isNotEmpty) {
      if (storeState.cuisines.isNotEmpty) {
        for (final cuisine in storeState.cuisines) {
          if (cuisine.id == 'all') continue;
          final matched = remainingProducts.where((p) {
            final matchesCuisine = p.cuisineId.toLowerCase() == cuisine.id.toLowerCase() ||
                p.cuisineId.toLowerCase() == cuisine.label.toLowerCase();
            final matchesName = p.name.toLowerCase().contains(cuisine.label.toLowerCase());
            return matchesCuisine || matchesName;
          }).toList();

          if (matched.isNotEmpty && !grouped.containsKey(cuisine.id)) {
            grouped[cuisine.id] = matched;
            categories.add(
              _StoreCategoryItem(id: cuisine.id, name: cuisine.label, count: matched.length),
            );
            for (final m in matched) {
              assignedIds.add(m.id);
            }
          }
        }
      }

      final stillRemaining = productList.where((p) => !assignedIds.contains(p.id)).toList();
      if (stillRemaining.isNotEmpty) {
        grouped['deals'] = stillRemaining;
        categories.add(
          _StoreCategoryItem(id: 'deals', name: '₹99 Deals', count: stillRemaining.length),
        );
      }
    }

    // 3. Fallback: if completely empty but products exist, create a default category
    if (categories.isEmpty && productList.isNotEmpty) {
      grouped['all_99'] = productList;
      categories.add(
        _StoreCategoryItem(
          id: 'all_99',
          name: '₹99 Store Specials',
          count: productList.length,
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Top App Bar
                  _buildCleanTopAppBar(context, isDark),

                  // Scrollable Body
                  Expanded(
                    child: storeState.isLoading && productList.isEmpty
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          )
                        : AppRefreshIndicator(
                            onRefresh: () async {
                              await ref
                                  .read(store99ViewModelProvider.notifier)
                                  .loadInitialData();
                            },
                            child: ListView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.only(bottom: 120.h),
                              children: [
                                // Store Header Info
                                _buildStoreHeader(context, isDark),

                                SizedBox(height: 10.h),

                                // Filter Chips Row
                                _buildFilterChipsRow(context, isDark),

                                SizedBox(height: 12.h),

                                // Dishes grouped into highlighted category sections
                                if (categories.isEmpty)
                                  Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 24.w),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.search_off_rounded, size: 44.sp, color: Colors.grey[400]),
                                          SizedBox(height: 10.h),
                                          Text(
                                            storeState.errorMessage ?? 'No dishes match your filters.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14.sp,
                                              color: isDark
                                                  ? AppColors.textSecondaryDark
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                          SizedBox(height: 12.h),
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _isVegOnly = false;
                                                _isNonVegOnly = false;
                                                _isQuickDeliveryOnly = false;
                                                _isRatingSort = false;
                                                _searchQuery = '';
                                                _searchController.clear();
                                              });
                                              ref.read(store99ViewModelProvider.notifier).loadInitialData();
                                            },
                                            child: const Text('Reset filters / Try again'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  for (final cat in categories) ...[
                                    // Highlighted Category Header
                                    _buildCategoryHeader(
                                      cat,
                                      grouped[cat.id]!.length,
                                      isDark,
                                    ),

                                    // Category Items (Collapsible)
                                    AnimatedCrossFade(
                                      duration:
                                          const Duration(milliseconds: 280),
                                      crossFadeState: _collapsedCategories
                                              .contains(cat.id)
                                          ? CrossFadeState.showSecond
                                          : CrossFadeState.showFirst,
                                      firstChild: _buildDishesList(
                                        context,
                                        grouped[cat.id]!,
                                        cartState,
                                        isDark,
                                      ),
                                      secondChild: const SizedBox.shrink(),
                                    ),

                                    // Divider between categories
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(
                                          16.w, 10.h, 16.w, 4.h),
                                      child: Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: isDark
                                            ? AppColors.borderDark
                                            : Colors.grey.shade200,
                                      ),
                                    ),
                                  ],
                              ],
                            ),
                          ),
                  ),
                ],
              ),

              // Floating Menu Button (Red circular button at bottom right)
              if (categories.isNotEmpty)
                Positioned(
                  right: 16.w,
                  bottom: cartState.items.isNotEmpty ? 90.h : 20.h,
                  child: _buildFloatingMenuButton(context, categories, isDark),
                ),

              // Floating View Cart Bar
              FloatingViewCartBar(
                key: _cartBarKey,
                onTap: () {
                  Haptics.light();
                  context.push(RouteNames.cart);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== TOP APP BAR ====================

  Widget _buildCleanTopAppBar(BuildContext context, bool isDark) {
    return Container(
      color: isDark ? AppColors.backgroundDark : Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: Row(
        children: [
          // Circular Back Button
          GestureDetector(
            onTap: () {
              Haptics.light();
              if (_isSearchExpanded && _searchQuery.isEmpty) {
                setState(() => _isSearchExpanded = false);
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

          if (!_isSearchExpanded && _searchQuery.isEmpty) ...[
            const Spacer(),
            // Search Capsule Pill on Right
            GestureDetector(
              onTap: () {
                Haptics.light();
                setState(() => _isSearchExpanded = true);
              },
              child: Container(
                height: 36.h,
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.surfaceDark : const Color(0xFFF5F6F8),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color:
                        isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : Colors.grey[700],
                      size: 17.sp,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Search',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : const Color(0xFF374151),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 8.w),
            // Share Button
            GestureDetector(
              onTap: () {
                Haptics.light();
                SharePlus.instance.share(
                  ShareParams(
                    text: 'Order delicious meals at ₹99 on Lagech App!',
                  ),
                );
              },
              child: Container(
                width: 38.r,
                height: 38.r,
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.surfaceDark : const Color(0xFFF1F3F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.share_outlined,
                  color: isDark ? Colors.white : const Color(0xFF1E232C),
                  size: 18.sp,
                ),
              ),
            ),
          ] else ...[
            SizedBox(width: 10.w),
            // Expanded Search TextField
            Expanded(
              child: Container(
                height: 40.h,
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.surfaceDark : const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color:
                        isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : Colors.grey[600],
                      size: 18.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: _isSearchExpanded,
                        textAlignVertical: TextAlignVertical.center,
                        textInputAction: TextInputAction.search,
                        autocorrect: false,
                        enableSuggestions: false,
                        spellCheckConfiguration:
                            const SpellCheckConfiguration.disabled(),
                        onSubmitted: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        onChanged: (val) {
                          setState(() => _searchQuery = val.trim());
                        },
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search ₹99 deals...',
                          hintStyle: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          filled: false, // theme fills every field; the pill draws the background
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Haptics.light();
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _isSearchExpanded = false;
                        });
                      },
                      child: Icon(
                        Icons.close_rounded,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : Colors.grey[600],
                        size: 18.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== STORE HEADER ====================

  Widget _buildStoreHeader(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 10.h),
      color: isDark ? AppColors.backgroundDark : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹99 STORE',
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1E232C),
                        letterSpacing: -0.3,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'Pocket-friendly meals & snacks at ₹99 or less',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              // Rating pill
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF008A45),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '5.0',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Icon(Icons.star_rounded, color: Colors.white, size: 13.sp),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 10.h),

          // Delivery info row
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 14.sp,
                color: const Color(0xFF008A45),
              ),
              SizedBox(width: 4.w),
              Text(
                '15-30 min',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF1E232C),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                '•',
                style: TextStyle(color: Colors.grey[400], fontSize: 12.sp),
              ),
              SizedBox(width: 8.w),
              Text(
                'Free delivery on qualifying orders',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== FILTER CHIPS ROW ====================

  Widget _buildFilterChipsRow(BuildContext context, bool isDark) {
    final hasAnyFilter = _isVegOnly ||
        _isNonVegOnly ||
        _isQuickDeliveryOnly ||
        _isRatingSort;

    return SizedBox(
      height: 32.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        children: [
          // Filters Reset / Indicator chip
          GestureDetector(
            onTap: () {
              Haptics.light();
              if (hasAnyFilter) {
                setState(() {
                  _isVegOnly = false;
                  _isNonVegOnly = false;
                  _isQuickDeliveryOnly = false;
                  _isRatingSort = false;
                });
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
                      : (isDark
                          ? AppColors.borderDark
                          : const Color(0xFFD1D5DB)),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: hasAnyFilter
                          ? AppColors.primary
                          : (isDark
                              ? AppColors.textSecondaryDark
                              : const Color(0xFF1E232C)),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Icon(
                    hasAnyFilter
                        ? Icons.close_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 14.sp,
                    color: hasAnyFilter
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : const Color(0xFF1E232C)),
                  ),
                ],
              ),
            ),
          ),

          // Veg chip
          GestureDetector(
            onTap: () {
              Haptics.light();
              setState(() {
                _isVegOnly = !_isVegOnly;
                if (_isVegOnly) _isNonVegOnly = false;
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: 6.w),
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              decoration: BoxDecoration(
                color: _isVegOnly
                    ? const Color(0xFF008A45).withValues(alpha: 0.12)
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: _isVegOnly
                      ? const Color(0xFF008A45)
                      : (isDark
                          ? AppColors.borderDark
                          : const Color(0xFFD1D5DB)),
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
                      color: _isVegOnly
                          ? const Color(0xFF008A45)
                          : (isDark
                              ? AppColors.textSecondaryDark
                              : const Color(0xFF1E232C)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Non-veg chip
          GestureDetector(
            onTap: () {
              Haptics.light();
              setState(() {
                _isNonVegOnly = !_isNonVegOnly;
                if (_isNonVegOnly) _isVegOnly = false;
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: 6.w),
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              decoration: BoxDecoration(
                color: _isNonVegOnly
                    ? const Color(0xFFB45309).withValues(alpha: 0.12)
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: _isNonVegOnly
                      ? const Color(0xFFB45309)
                      : (isDark
                          ? AppColors.borderDark
                          : const Color(0xFFD1D5DB)),
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
                      color: _isNonVegOnly
                          ? const Color(0xFFB45309)
                          : (isDark
                              ? AppColors.textSecondaryDark
                              : const Color(0xFF1E232C)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quick Delivery chip
          GestureDetector(
            onTap: () {
              Haptics.light();
              setState(() {
                _isQuickDeliveryOnly = !_isQuickDeliveryOnly;
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: 6.w),
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              decoration: BoxDecoration(
                color: _isQuickDeliveryOnly
                    ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: _isQuickDeliveryOnly
                      ? const Color(0xFFEF4444)
                      : (isDark
                          ? AppColors.borderDark
                          : const Color(0xFFD1D5DB)),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 14.sp,
                    color: const Color(0xFFEF4444),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'Quick Delivery',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: _isQuickDeliveryOnly
                          ? const Color(0xFFEF4444)
                          : (isDark
                              ? AppColors.textSecondaryDark
                              : const Color(0xFF1E232C)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Highly Rated chip
          GestureDetector(
            onTap: () {
              Haptics.light();
              setState(() {
                _isRatingSort = !_isRatingSort;
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: 6.w),
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              decoration: BoxDecoration(
                color: _isRatingSort
                    ? const Color(0xFF008A45).withValues(alpha: 0.12)
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: _isRatingSort
                      ? const Color(0xFF008A45)
                      : (isDark
                          ? AppColors.borderDark
                          : const Color(0xFFD1D5DB)),
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
                    'Highly Rated',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: _isRatingSort
                          ? const Color(0xFF008A45)
                          : (isDark
                              ? AppColors.textSecondaryDark
                              : const Color(0xFF1E232C)),
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

  // ==================== HIGHLIGHTED CATEGORY HEADER ====================

  Widget _buildCategoryHeader(
    _StoreCategoryItem category,
    int count,
    bool isDark,
  ) {
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
            // Left primary accent bar
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
            // Item Count Badge
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
                '$count',
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
  }

  // ==================== DISHES LIST ====================

  Widget _buildDishesList(
    BuildContext context,
    List<Store99Product> dishes,
    CartState cartState,
    bool isDark,
  ) {
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
        return _buildHorizontalDishCard(
          context,
          dishes[index],
          cartState,
          isDark,
        );
      },
    );
  }

  // ==================== HORIZONTAL DISH CARD (RESTAURANT UI MATCH) ====================

  Widget _buildHorizontalDishCard(
    BuildContext context,
    Store99Product dish,
    CartState cartState,
    bool isDark,
  ) {
    final quantity = _getQuantity(cartState, dish.id);
    final cartItemId = _getCartItemId(cartState, dish.id);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT COLUMN: Details
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onProductTap(dish),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Veg / Non-veg icon
                  dish.isVeg ? _buildVegIcon(size: 14) : _buildNonVegIcon(size: 14),
                  SizedBox(height: 5.h),

                  // Dish Title
                  Text(
                    dish.name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E232C),
                      height: 1.25,
                    ),
                  ),

                  SizedBox(height: 4.h),

                  // Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '₹${dish.price.toInt()}',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1E232C),
                        ),
                      ),
                      if (dish.originalPrice != null &&
                          dish.originalPrice! > dish.price) ...[
                        SizedBox(width: 6.w),
                        Text(
                          '₹${dish.originalPrice!.toInt()}',
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

                  // Description or Restaurant name
                  if (dish.description.isNotEmpty ||
                      dish.restaurantName.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      dish.description.isNotEmpty
                          ? dish.description
                          : 'By ${dish.restaurantName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : const Color(0xFF757575),
                        height: 1.3,
                      ),
                    ),
                  ],

                  SizedBox(height: 10.h),

                  // Bookmark & Share icons (matching screenshot rounded pills)
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
                          padding: EdgeInsets.all(6.r),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderDark
                                  : const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(
                            Icons.bookmark_border_rounded,
                            size: 16.sp,
                            color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      GestureDetector(
                        onTap: () {
                          Haptics.light();
                          SharePlus.instance.share(
                            ShareParams(
                              text:
                                  'Order ${dish.name} for ₹${dish.price.toInt()} on Lagech App!',
                            ),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderDark
                                  : const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(
                            Icons.share_outlined,
                            size: 16.sp,
                            color: isDark ? Colors.white70 : const Color(0xFF6B7280),
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
                width: 114.w,
                height: 122.h,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    // Image
                    GestureDetector(
                      onTap: () => _onProductTap(dish),
                      child: Container(
                        key: _dishImageKeys.putIfAbsent(
                            dish.id, () => GlobalKey()),
                        width: 114.w,
                        height: 104.h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16.r),
                          color: isDark
                              ? AppColors.surfaceDark
                              : const Color(0xFFF1F3F5),
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
                      child: _buildOverlapAddButton(
                        context,
                        dish,
                        quantity,
                        cartItemId,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== OVERLAPPING ADD BUTTON ====================

  Widget _buildOverlapAddButton(
    BuildContext context,
    Store99Product dish,
    int quantity,
    String? cartItemId,
  ) {
    final restaurant = ref.watch(restaurantByIdProvider(dish.restaurantId)).asData?.value;
    final isClosed = restaurant != null && !restaurant.isOpen;

    if (isClosed) {
      return GestureDetector(
        key: const ValueKey('closed_btn'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppSnackbar.warning(
            context,
            '${restaurant.name} is currently closed and not accepting orders.',
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
              onTap: () => _handleFirstAddToCart(dish.toFoodModel()),
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
                        fontSize: 13.5.sp,
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
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
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
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
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

  Widget _buildFloatingMenuButton(
    BuildContext context,
    List<_StoreCategoryItem> categories,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () {
        Haptics.medium();
        _showCategoryBottomSheet(context, categories, isDark);
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

  void _showCategoryBottomSheet(
    BuildContext context,
    List<_StoreCategoryItem> categories,
    bool isDark,
  ) {
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
                          color:
                              isDark ? Colors.white : const Color(0xFF1E1E1E),
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
                          '${category.count}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _scrollToSection(category.id);
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

  // ==================== ICONS ====================

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
        painter: _StoreTrianglePainter(color: const Color(0xFFE23744)),
      ),
    );
  }
}

class _StoreCategoryItem {
  final String id;
  final String name;
  final int count;

  _StoreCategoryItem({
    required this.id,
    required this.name,
    required this.count,
  });
}

class _StoreTrianglePainter extends CustomPainter {
  final Color color;
  _StoreTrianglePainter({required this.color});

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
