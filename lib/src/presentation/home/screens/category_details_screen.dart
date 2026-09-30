import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/restaurant_model.dart';
import '../../../di/restaurant_providers.dart';
import '../../branding/app_colors.dart';
import '../../cart/widgets/floating_view_cart_bar.dart';
import '../../home/viewmodels/home_viewmodel.dart';
import '../../navigation/route_names.dart';
import '../../search/widgets/voice_search_dialog.dart';
import '../widgets/recommended_grid_section.dart';
import '../widgets/restaurant_card.dart';

/// Fetches dishes belonging to this category across all restaurants
final categoryFoodsProvider =
    FutureProvider.family<List<FoodModel>, CategoryModel>((
      ref,
      category,
    ) async {
      final repo = ref.watch(restaurantRepositoryProvider);

      if (category.id == 'all') {
        final res = await repo.getPopularFoods();
        return res.data ?? [];
      }

      // 1. Direct query with category id and name
      final res = await repo.getFoodsByCategory(
        category.id,
        categoryName: category.name,
        realCategoryId: category.id,
      );
      if (res.isSuccess && (res.data ?? []).isNotEmpty) {
        return res.data!;
      }

      // 2. Fallback query with category name only
      if (category.name.isNotEmpty) {
        final resByName = await repo.getFoodsByCategory(
          '',
          categoryName: category.name,
        );
        if (resByName.isSuccess && (resByName.data ?? []).isNotEmpty) {
          return resByName.data!;
        }
      }

      // 3. Fallback: Search all foods by keyword (e.g. Pasta, Biryani, Burger)
      try {
        final allFoodsRes = await repo.getPopularFoods();
        if (allFoodsRes.isSuccess && (allFoodsRes.data ?? []).isNotEmpty) {
          final query = category.name.trim().toLowerCase();
          final matched = allFoodsRes.data!.where((f) {
            final name = f.name.toLowerCase();
            final catName = f.categoryName.toLowerCase();
            final desc = f.description.toLowerCase();
            return catName.contains(query) ||
                name.contains(query) ||
                desc.contains(query);
          }).toList();
          if (matched.isNotEmpty) {
            return matched;
          }
        }
      } catch (_) {}

      return res.data ?? [];
    });

/// Fetches restaurants that serve items in this category
final categoryRestaurantsProvider =
    FutureProvider.family<List<RestaurantModel>, CategoryModel>((
      ref,
      category,
    ) async {
      final repo = ref.watch(restaurantRepositoryProvider);

      if (category.id == 'all') {
        final allRes = await repo.getPopularRestaurants();
        return allRes.data ?? [];
      }

      // 1. Direct category query from repository (unified search)
      final res = await repo.getRestaurantsByCategory(category);
      if (res.isSuccess && (res.data ?? []).isNotEmpty) {
        return res.data!;
      }

      // 2. High-precision fallback: Lookup restaurants from the dishes loaded in this category
      try {
        final foodsAsync = await ref.watch(categoryFoodsProvider(category).future);
        if (foodsAsync.isNotEmpty) {
          final restIds = foodsAsync
              .map((f) => f.restaurantId)
              .where((id) => id.isNotEmpty)
              .toSet();

          if (restIds.isNotEmpty) {
            final allRestsRes = await repo.getPopularRestaurants();
            if (allRestsRes.isSuccess && allRestsRes.data != null) {
              final matched = allRestsRes.data!
                  .where((r) => restIds.contains(r.id))
                  .toList();
              if (matched.isNotEmpty) return matched;
            }
          }
        }
      } catch (_) {}

      // 3. Fallback for Italian/cuisines (e.g. Pasta, Biryani, Pizza, Chinese)
      final allRestsRes = await repo.getPopularRestaurants();
      if (allRestsRes.isSuccess && allRestsRes.data != null) {
        final query = category.name.trim().toLowerCase();
        final matched = allRestsRes.data!.where((r) {
          final cuisines = r.tags.map((t) => t.toLowerCase()).toList();
          final rTags = r.restaurantTags.map((t) => t.toLowerCase()).toList();
          final rName = r.name.toLowerCase();
          return cuisines.any((c) => c.contains(query) || query.contains(c)) ||
              rTags.any((t) => t.contains(query) || query.contains(t)) ||
              rName.contains(query);
        }).toList();
        if (matched.isNotEmpty) return matched;
      }

      return res.data ?? [];
    });

class CategoryDetailsScreen extends ConsumerStatefulWidget {
  final CategoryModel category;

  const CategoryDetailsScreen({super.key, required this.category});

  @override
  ConsumerState<CategoryDetailsScreen> createState() =>
      _CategoryDetailsScreenState();
}

class _CategoryDetailsScreenState extends ConsumerState<CategoryDetailsScreen> {
  late CategoryModel _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<FloatingViewCartBarState> _cartBarKey =
      GlobalKey<FloatingViewCartBarState>();
  String _searchQuery = '';
  String? _selectedSuggestion;



  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.category;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getCategoryFallbackImage(String name) {
    final n = name.toLowerCase();
    if (n.contains('biryani')) {
      return 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=300&auto=format&fit=crop';
    }
    if (n.contains('pizza')) {
      return 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=300&auto=format&fit=crop';
    }
    if (n.contains('north') || n.contains('thali')) {
      return 'https://images.unsplash.com/photo-1610192244261-3f33de3f55e4?w=300&auto=format&fit=crop';
    }
    if (n.contains('burger')) {
      return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=300&auto=format&fit=crop';
    }
    if (n.contains('south') || n.contains('dosa')) {
      return 'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=300&auto=format&fit=crop';
    }
    if (n.contains('cake') || n.contains('dessert')) {
      return 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=300&auto=format&fit=crop';
    }
    if (n.contains('sandwich')) {
      return 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=300&auto=format&fit=crop';
    }
    return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=300&auto=format&fit=crop';
  }

  String _getPromoBannerLeftImage(String name) {
    final n = name.toLowerCase();
    if (n.contains('biryani')) {
      return 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=500&auto=format&fit=crop';
    }
    if (n.contains('pizza')) {
      return 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500&auto=format&fit=crop';
    }
    if (n.contains('burger')) {
      return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&auto=format&fit=crop';
    }
    if (n.contains('sandwich')) {
      return 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=500&auto=format&fit=crop';
    }
    if (n.contains('dosa') || n.contains('south')) {
      return 'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=500&auto=format&fit=crop';
    }
    return 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=500&auto=format&fit=crop';
  }

  String _getPromoBannerRightImage(String name) {
    final n = name.toLowerCase();
    if (n.contains('biryani')) {
      return 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=500&auto=format&fit=crop';
    }
    if (n.contains('pizza')) {
      return 'https://images.unsplash.com/photo-1590947132387-155cc02f3212?w=500&auto=format&fit=crop';
    }
    if (n.contains('burger')) {
      return 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=500&auto=format&fit=crop';
    }
    if (n.contains('sandwich')) {
      return 'https://images.unsplash.com/photo-1621996346565-e3d5d6281691?w=500&auto=format&fit=crop';
    }
    if (n.contains('dosa') || n.contains('south')) {
      return 'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=500&auto=format&fit=crop';
    }
    return 'https://images.unsplash.com/photo-1631515243349-e0cb75fb8d3a?w=500&auto=format&fit=crop';
  }

  List<RestaurantModel> _buildCategoryRecommendedList(List<RestaurantModel> apiRestaurants) {
    return apiRestaurants;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final homeCategories =
        ref.watch(homeViewModelProvider).categories.asData?.value ?? const [];

    // Construct full categories list with "All" prepended
    final allCategory = const CategoryModel(
      id: 'all',
      name: 'All',
      imageUrl: '',
      slug: 'all',
    );

    final displayCategories = <CategoryModel>[
      allCategory,
      ...homeCategories.where((c) => c.name.toLowerCase() != 'all'),
    ];

    final restaurantsAsync =
        ref.watch(categoryRestaurantsProvider(_selectedCategory));

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Bar: Back Arrow + Search Input (with mic)
                _buildTopSearchBar(context, isDark),

                // 2. Horizontal Circular Categories List (matching Screenshot 1)
                _buildCircularCategoriesRow(
                  displayCategories,
                  isDark,
                ),

                // 3. Main Scrollable Content matching Screenshot
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 8.h),

                        // Two-row Quick Filter Chips
                        _buildFilterChipsRow(isDark),

                        SizedBox(height: 10.h),

                        // FREE Delivery Banner (light blue with gift box)
                        _buildFreeDeliveryBanner(isDark),

                        SizedBox(height: 14.h),

                        // 3-column Grid of RECOMMENDED FOR YOU (RecommendedGridSection)
                        restaurantsAsync.when(
                          data: (restaurants) {
                            final nearby = ref.watch(homeViewModelProvider).nearbyRestaurants.asData?.value ?? [];
                            var list = restaurants.isNotEmpty ? restaurants : nearby;

                            final recommendedList = _buildCategoryRecommendedList(list);

                            // Apply filters for vertical restaurant list
                            var deliveringList = List<RestaurantModel>.from(recommendedList);
                            if (_searchQuery.isNotEmpty) {
                              deliveringList = deliveringList
                                  .where((r) => r.name.toLowerCase().contains(_searchQuery.toLowerCase()))
                                  .toList();
                            }
                            if (_selectedSuggestion != null && _selectedSuggestion!.isNotEmpty) {
                              final s = _selectedSuggestion!.toLowerCase();
                              if (s == 'near & fast') {
                                deliveringList = deliveringList.where((r) =>
                                  r.isNearAndFast ||
                                  r.deliveryTime.toLowerCase().contains('20') ||
                                  r.deliveryTime.toLowerCase().contains('15') ||
                                  r.deliveryTime.toLowerCase().contains('25')).toList();
                              } else if (s == 'highly reordered') {
                                deliveringList.sort((a, b) => b.rating.compareTo(a.rating));
                              } else if (s == 'meals under ₹250') {
                                deliveringList = deliveringList.where((r) =>
                                  r.offerBadges.isNotEmpty ||
                                  r.tags.any((t) => t.toLowerCase().contains('snack') || t.toLowerCase().contains('fast'))).toList();
                              } else {
                                deliveringList = deliveringList.where((r) =>
                                    r.name.toLowerCase().contains(s) ||
                                    r.tags.any((t) => t.toLowerCase().contains(s))).toList();
                              }
                              if (deliveringList.isEmpty) deliveringList = recommendedList;
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // RECOMMENDED FOR YOU Section
                                RecommendedGridSection(
                                  title: 'RECOMMENDED FOR YOU',
                                  showTitle: true,
                                  selectedCategory: _selectedCategory.name,
                                  categoryDishes: ref.watch(categoryFoodsProvider(_selectedCategory)).asData?.value ?? const [],
                                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                                  restaurants: recommendedList,
                                  onRestaurantTap: (rest) {
                                    context.push(RouteNames.restaurantDetail, extra: rest);
                                  },
                                ),

                                SizedBox(height: 14.h),

                                // Category Promo Banner: [CATEGORY] UNDER ₹250
                                _buildCategoryPromoBanner(context, isDark),

                                SizedBox(height: 16.h),

                                // Section Header for All Restaurants
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                                  child: Text(
                                    'ALL RESTAURANTS DELIVERING TO YOU',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ),

                                // Vertical list of Restaurant Cards
                                _buildRestaurantsDeliveringList(deliveringList, isDark),
                              ],
                            );
                          },
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(color: Color(0xFFC80A14)),
                            ),
                          ),
                          error: (_, _) {
                            final nearby = ref.watch(homeViewModelProvider).nearbyRestaurants.asData?.value ?? [];
                            final recommendedList = _buildCategoryRecommendedList(nearby);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RecommendedGridSection(
                                  title: 'RECOMMENDED FOR YOU',
                                  showTitle: true,
                                  selectedCategory: _selectedCategory.name,
                                  categoryDishes: ref.watch(categoryFoodsProvider(_selectedCategory)).asData?.value ?? const [],
                                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                                  restaurants: recommendedList,
                                  onRestaurantTap: (rest) {
                                    context.push(RouteNames.restaurantDetail, extra: rest);
                                  },
                                ),
                                SizedBox(height: 14.h),
                                _buildCategoryPromoBanner(context, isDark),
                                SizedBox(height: 16.h),
                                _buildRestaurantsDeliveringList(recommendedList, isDark),
                              ],
                            );
                          },
                        ),

                        SizedBox(height: 90.h),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Floating View Cart Bar
            FloatingViewCartBar(
              key: _cartBarKey,
              bottomOffset: 12.h,
              onTap: () {
                Haptics.light();
                context.push(RouteNames.cart);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 1. TOP SEARCH BAR ====================

  Widget _buildTopSearchBar(BuildContext context, bool isDark) {
    return Container(
      color: isDark ? AppColors.backgroundDark : Colors.white,
      padding: EdgeInsets.fromLTRB(4.w, 6.h, 16.w, 8.h),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : const Color(0xFF1E232C),
              size: 24.sp,
            ),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Haptics.light();
                context.push(RouteNames.search);
              },
              child: Container(
                height: 44.h,
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                    width: 1.0,
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
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 20.sp,
                      color: isDark ? Colors.white60 : Colors.grey[600],
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'Restaurant name or a dish...',
                        style: TextStyle(
                          fontSize: 13.5.sp,
                          color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        Haptics.light();
                        final query = await VoiceSearchDialog.show(context);
                        if (query != null && query.trim().isNotEmpty && context.mounted) {
                          context.push(RouteNames.search, extra: query.trim());
                        }
                      },
                      child: Padding(
                        padding: EdgeInsets.only(left: 6.w),
                        child: Icon(
                          Icons.mic_none_rounded,
                          size: 21.sp,
                          color: isDark ? Colors.white70 : const Color(0xFF0F8A5F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 2. CIRCULAR CATEGORIES ROW ====================

  Widget _buildCircularCategoriesRow(
    List<CategoryModel> categories,
    bool isDark,
  ) {
    return Container(
      color: isDark ? AppColors.backgroundDark : Colors.white,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      height: 98.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: categories.length,
        separatorBuilder: (_, _) => SizedBox(width: 14.w),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected =
              _selectedCategory.id.toLowerCase() == cat.id.toLowerCase() ||
              _selectedCategory.name.toLowerCase() == cat.name.toLowerCase();

          final imgUrl = cat.id == 'all'
              ? 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=300&auto=format&fit=crop'
              : (cat.imageUrl.isNotEmpty ? cat.imageUrl : _getCategoryFallbackImage(cat.name));

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Haptics.light();
              setState(() {
                _selectedCategory = cat;
                _selectedSuggestion = null;
                _searchQuery = '';
                _searchController.clear();
              });
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Circular Image
                Container(
                  width: 54.r,
                  height: 54.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF008A45)
                          : Colors.transparent,
                      width: 2.2,
                    ),
                  ),
                  padding: EdgeInsets.all(2.r),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: imgUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F3F5),
                        child: Icon(
                          Icons.restaurant_rounded,
                          size: 24.sp,
                          color: isSelected ? const Color(0xFF008A45) : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 5.h),

                // Category Name
                Text(
                  cat.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFF1E232C))
                        : (isDark ? AppColors.textSecondaryDark : Colors.grey[600]),
                  ),
                ),

                // Green Underline Bar for selected category (matching Screenshot)
                if (isSelected) ...[
                  SizedBox(height: 3.h),
                  Container(
                    width: 28.w,
                    height: 2.8.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF008A45),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ==================== 3. TWO-ROW FILTER CHIPS (Screenshot) ====================

  Widget _buildFilterChipsRow(bool isDark) {
    final catName = _selectedCategory.name.toLowerCase();

    // Row 1: Filters & Specific Dish/Style tags
    final row1Chips = <Map<String, dynamic>>[
      {'label': 'Filters', 'icon': Icons.tune_rounded, 'hasArrow': true},
      if (catName.contains('biryani')) ...[
        {'label': 'Hyderabadi', 'icon': Icons.lunch_dining_rounded},
        {'label': 'Paneer', 'icon': Icons.set_meal_rounded},
        {'label': 'with Raita', 'icon': Icons.rice_bowl_rounded},
        {'label': 'Dum Biryani', 'icon': Icons.dinner_dining_rounded},
      ] else if (catName.contains('pizza')) ...[
        {'label': 'Cheesy', 'icon': Icons.local_pizza_rounded},
        {'label': 'Veg Feast', 'icon': Icons.eco_rounded},
        {'label': 'Paneer Special', 'icon': Icons.dinner_dining_rounded},
      ] else if (catName.contains('burger')) ...[
        {'label': 'Veg Crispy', 'icon': Icons.lunch_dining_rounded},
        {'label': 'Cheese Burst', 'icon': Icons.local_pizza_rounded},
        {'label': 'Spicy Peri Peri', 'icon': Icons.whatshot_rounded},
      ] else ...[
        {'label': 'Special', 'icon': Icons.star_rounded},
        {'label': 'Veg Only', 'icon': Icons.eco_rounded},
        {'label': 'North Indian', 'icon': Icons.restaurant_rounded},
      ],
    ];

    // Row 2: Sort, Near & Fast, and Meals under ₹250
    final row2Chips = <Map<String, dynamic>>[
      {'label': 'Highly reordered', 'icon': Icons.autorenew_rounded},
      {'label': 'Near & Fast', 'icon': Icons.bolt_rounded, 'color': const Color(0xFF0F8A43)},
      {'label': 'Meals under ₹250', 'icon': null},
    ];

    Widget buildChipList(List<Map<String, dynamic>> list) {
      return SizedBox(
        height: 34.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          itemCount: list.length,
          separatorBuilder: (_, _) => SizedBox(width: 8.w),
          itemBuilder: (context, i) {
            final item = list[i];
            final label = item['label'] as String;
            final isSelected = _selectedSuggestion == label;
            final IconData? icon = item['icon'] as IconData?;
            final bool hasArrow = item['hasArrow'] == true;

            return GestureDetector(
              onTap: () {
                Haptics.light();
                setState(() {
                  _selectedSuggestion = isSelected ? null : label;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF008A45).withValues(alpha: 0.12)
                      : (isDark ? AppColors.surfaceDark : Colors.white),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF008A45)
                        : (isDark ? AppColors.borderDark : const Color(0xFFE5E7EB)),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 13.sp,
                        color: item['color'] ?? (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                      ),
                      SizedBox(width: 4.w),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF008A45)
                            : (isDark ? Colors.white : const Color(0xFF374151)),
                      ),
                    ),
                    if (hasArrow) ...[
                      SizedBox(width: 2.w),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14.sp,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildChipList(row1Chips),
        SizedBox(height: 8.h),
        buildChipList(row2Chips),
      ],
    );
  }

  // ==================== 4. FREE DELIVERY BANNER ====================

  Widget _buildFreeDeliveryBanner(bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 2.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFBAE6FD),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FREE Delivery',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1D4ED8),
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Exclusively for you on your first order',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
          // 3D Gift Box illustration
          Container(
            width: 36.r,
            height: 36.r,
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8),
              borderRadius: BorderRadius.circular(8.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(width: 7.w, height: 36.r, color: const Color(0xFFFBBF24)),
                Container(width: 36.r, height: 7.h, color: const Color(0xFFFBBF24)),
                Positioned(
                  top: 2.h,
                  child: Container(
                    width: 10.r,
                    height: 10.r,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFF59E0B),
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

  // ==================== 5. CATEGORY PROMO BANNER ====================

  Widget _buildCategoryPromoBanner(BuildContext context, bool isDark) {
    final catName = _selectedCategory.name;
    final displayTitle = catName.toLowerCase() == 'all'
        ? 'MEALS UNDER ₹250'
        : '${catName.toUpperCase()} UNDER ₹250';

    final leftImg = _getPromoBannerLeftImage(catName);
    final rightImg = _getPromoBannerRightImage(catName);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      height: 122.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFFEF3C7).withValues(alpha: 0.55), const Color(0xFFE0F2FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFBAE6FD),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Stack(
          children: [
            // Background decorative festive party flags / bunting at top
            Positioned(
              top: -2.h,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(8, (i) => Icon(
                  Icons.change_history_rounded,
                  size: 14.sp,
                  color: (i % 2 == 0 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)).withValues(alpha: 0.25),
                )),
              ),
            ),

            // Top Left hanging discount tag
            Positioned(
              top: 6.h,
              left: 14.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  '%',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 9.sp,
                  ),
                ),
              ),
            ),

            // Top Right hanging discount tag
            Positioned(
              top: 6.h,
              right: 14.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  '%',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 9.sp,
                  ),
                ),
              ),
            ),

            // Left Dish Image (positioned in bottom-left corner with crisp white rim)
            Positioned(
              left: -12.w,
              bottom: -10.h,
              child: Container(
                width: 94.r,
                height: 94.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(2, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: leftImg,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: Colors.white24),
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

            // Right Dish Image (positioned in bottom-right corner with crisp white rim)
            Positioned(
              right: -12.w,
              bottom: -10.h,
              child: Container(
                width: 94.r,
                height: 94.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(-2, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: rightImg,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: Colors.white24),
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

            // Center Cream Parchment Box (cleanly centered without getting squeezed)
            Center(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 76.w),
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.95)
                      : const Color(0xFFFFFBEB).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFFDE68A),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      displayTitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E3A8A),
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.5.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC80A14),
                        borderRadius: BorderRadius.circular(3.5.r),
                      ),
                      child: Text(
                        'FINAL PRICE, BEST OFFER APPLIED',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 7.2.sp,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    GestureDetector(
                      onTap: () {
                        Haptics.light();
                        setState(() {
                          _selectedSuggestion = 'Meals under ₹250';
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Order now',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 2.w),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 13.sp,
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
          ],
        ),
      ),
    );
  }

  // ==================== 6. RESTAURANTS DELIVERING LIST ====================

  Widget _buildRestaurantsDeliveringList(List<RestaurantModel> restaurants, bool isDark) {
    if (restaurants.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 30.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_outlined, size: 45.sp, color: Colors.grey[400]),
              SizedBox(height: 8.h),
              Text(
                'No restaurants found for ${_selectedCategory.name}',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(top: 4.h, bottom: 20.h),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: restaurants.length,
      itemBuilder: (context, index) {
        return RestaurantCard(
          restaurant: restaurants[index],
          index: index,
          selectedCategory: _selectedCategory.name,
        );
      },
    );
  }
}
