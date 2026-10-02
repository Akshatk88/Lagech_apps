import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/restaurant_model.dart';
import '../../../domain/model/search_result.dart';
import '../../../domain/model/store99_product.dart';
import '../../branding/app_colors.dart';
import '../../cart/utils/cart_restaurant_guard.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../common_widgets/skeleton_loading.dart';
import '../../common_widgets/smart_image.dart';
import '../../home/viewmodels/veg_filter_provider.dart';
import '../../navigation/route_names.dart';
import '../../restaurant/widgets/food_detail_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../home/viewmodels/home_viewmodel.dart';
import '../viewmodels/search_state.dart';
import '../viewmodels/search_viewmodel.dart';
import '../widgets/voice_search_dialog.dart';

enum ResultCategoryFilter { all, dishes, restaurants, store99 }

/// Premium Search Screen matching Swiggy, Blinkit & Zepto UI/UX design spec.
class SearchScreen extends ConsumerStatefulWidget {
  final SearchMode initialMode;
  final String? initialQuery;

  const SearchScreen({
    super.key,
    this.initialMode = SearchMode.home,
    this.initialQuery,
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _textController;
  ResultCategoryFilter _categoryFilter = ResultCategoryFilter.all;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialQuery ?? '');
    if (widget.initialMode == SearchMode.store99) {
      _categoryFilter = ResultCategoryFilter.store99;
    }

    Future.microtask(() {
      final vm = ref.read(searchViewModelProvider.notifier);
      vm.setMode(widget.initialMode);
      if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
        developer.log('[VOICE] Search query passed: "${widget.initialQuery}"', name: 'VOICE');
        developer.log('[VOICE] Search started for query: "${widget.initialQuery}"', name: 'VOICE');
        vm.submitQuery(widget.initialQuery!);
      }
    });
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery &&
        widget.initialQuery != null &&
        widget.initialQuery!.isNotEmpty) {
      _textController.text = widget.initialQuery!;
      developer.log('[VOICE] Search query passed: "${widget.initialQuery}"', name: 'VOICE');
      developer.log('[VOICE] Search started for query: "${widget.initialQuery}"', name: 'VOICE');
      ref.read(searchViewModelProvider.notifier).submitQuery(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onResultTap(SearchResult result) {
    Haptics.light();
    ref.read(searchViewModelProvider.notifier).submitQuery(result.title);

    if (result.type == SearchResultType.restaurant &&
        result.rawItem is RestaurantModel) {
      context.push(
        RouteNames.restaurantDetail,
        extra: result.rawItem as RestaurantModel,
      );
      return;
    }

    final FoodModel food;
    if (result.rawItem is FoodModel) {
      food = result.rawItem as FoodModel;
    } else if (result.rawItem is Store99Product) {
      food = (result.rawItem as Store99Product).toFoodModel();
    } else {
      food = FoodModel(
        id: result.id,
        restaurantId: 'r1',
        name: result.title,
        description: result.subtitle,
        price: result.price ?? 99,
        imageUrl: result.imageUrl,
        rating: result.rating ?? 0,
      );
    }

    FoodDetailSheet.show(context, food);
  }

  Future<void> _addDishToCart(SearchResult item) async {
    Haptics.success();
    final FoodModel food;
    if (item.rawItem is FoodModel) {
      food = item.rawItem as FoodModel;
    } else if (item.rawItem is Store99Product) {
      final p = item.rawItem as Store99Product;
      food = FoodModel(
        id: p.id,
        restaurantId: p.restaurantId,
        name: p.name,
        description: p.description,
        price: p.price,
        imageUrl: p.imageUrl,
        rating: p.rating,
        isPopular: true,
      );
    } else {
      food = FoodModel(
        id: item.id,
        restaurantId: 'r1',
        name: item.title,
        description: item.subtitle,
        price: item.price ?? 99,
        imageUrl: item.imageUrl,
        rating: item.rating ?? 0,
      );
    }

    final allowed = await ensureCartRestaurant(context, ref, food.restaurantId);
    if (!allowed || !mounted) return;

    ref.read(cartViewModelProvider.notifier).addItem(food);

    AppSnackbar.success(
      context,
      'Added "${item.title}" to cart!',
      duration: const Duration(seconds: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final searchState = ref.watch(searchViewModelProvider);
    final vm = ref.read(searchViewModelProvider.notifier);

    // Synchronize text field when voice search updates query
    if (searchState.query != _textController.text && !searchState.isSearching) {
      _textController.value = TextEditingController.fromValue(
        TextEditingValue(
          text: searchState.query,
          selection: TextSelection.collapsed(offset: searchState.query.length),
        ),
      ).value;
    }

    final isVegOnly = ref.watch(vegFilterProvider);

    final rawResults = searchState.results;
    var results = isVegOnly
        ? rawResults.where((r) {
            if (r.rawItem is FoodModel) return (r.rawItem as FoodModel).isVeg;
            if (r.rawItem is RestaurantModel) return (r.rawItem as RestaurantModel).isPureVeg;
            if (r.rawItem is Store99Product) return (r.rawItem as Store99Product).isVeg;
            return true;
          }).toList()
        : rawResults;

    if (_categoryFilter == ResultCategoryFilter.dishes) {
      results = results.where((r) => r.type != SearchResultType.restaurant).toList();
    } else if (_categoryFilter == ResultCategoryFilter.restaurants) {
      results = results.where((r) => r.type == SearchResultType.restaurant).toList();
    }

    final categories = ref.watch(homeViewModelProvider).categories.asData?.value ?? [];

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Modern Search Bar Header
            _buildSearchHeader(context, isDark, searchState, vm),

            // 2. Main Results Area
            Expanded(
              child: searchState.isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: SkeletonRestaurantList(count: 3),
                    )
                  : searchState.query.trim().isEmpty
                  ? _buildDefaultState(context, isDark, searchState, vm)
                  : results.isEmpty
                  ? _buildEmptyState(context, isDark, searchState.query)
                  : _buildResultsSection(
                      context,
                      isDark,
                      searchState.query,
                      results,
                      vm,
                      categories,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SEARCH HEADER ====================

  Widget _buildSearchHeader(
    BuildContext context,
    bool isDark,
    SearchState state,
    SearchViewModel vm,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 6.h),
      child: Container(
        height: 48.h,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
            width: 1.0,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Back Chevron Icon (matching screenshot in green)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Haptics.light();
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RouteNames.home);
                }
              },
              child: Padding(
                padding: EdgeInsets.only(left: 12.w, right: 8.w),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: const Color(0xFF0F8A5F),
                  size: 19.sp,
                ),
              ),
            ),

            // Search Text Field
            Expanded(
              child: TextField(
                controller: _textController,
                autofocus: true,
                textAlignVertical: TextAlignVertical.center,
                textInputAction: TextInputAction.search,
                onChanged: vm.onQueryChanged,
                onSubmitted: (q) {
                  vm.submitQuery(q);
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                style: TextStyle(
                  fontSize: 14.5.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  hintText: 'Restaurant name or a dish...',
                  hintStyle: TextStyle(
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w400,
                    color: isDark
                        ? Colors.white38
                        : const Color(0xFF9CA3AF),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),

            // Clear button if query is not empty
            if (state.query.isNotEmpty) ...[
              GestureDetector(
                onTap: () {
                  _textController.clear();
                  vm.clearQuery();
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Icon(
                    Icons.close_rounded,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    size: 19.sp,
                  ),
                ),
              ),
              Container(
                width: 1.w,
                height: 18.h,
                margin: EdgeInsets.symmetric(horizontal: 6.w),
                color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
              ),
            ],

            // Right Green Microphone Icon
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                Haptics.light();
                final query = await VoiceSearchDialog.show(context);
                if (query != null && query.trim().isNotEmpty && context.mounted) {
                  developer.log('[VOICE] Search query passed: "$query"', name: 'VOICE');
                  developer.log('[VOICE] Search started for query: "$query"', name: 'VOICE');
                  _textController.text = query.trim();
                  ref.read(searchViewModelProvider.notifier).submitQuery(query.trim());
                }
              },
              child: Padding(
                padding: EdgeInsets.only(left: 4.w, right: 12.w),
                child: Icon(
                  Icons.mic_none_rounded,
                  color: const Color(0xFF0F8A5F),
                  size: 24.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== DEFAULT DISCOVERY STATE ====================

  static const List<Map<String, String>> _whatsOnYourMindDishes = [
    {
      'name': 'Biryani',
      'query': 'biryani',
      'imageUrl':
          'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400&auto=format&fit=crop',
    },
    {
      'name': 'Pizza',
      'query': 'pizza',
      'imageUrl':
          'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&auto=format&fit=crop',
    },
    {
      'name': 'North Indian',
      'query': 'north indian',
      'imageUrl':
          'https://images.unsplash.com/photo-1610192244261-3f33de3f55e4?w=400&auto=format&fit=crop',
    },
    {
      'name': 'Sandwich',
      'query': 'sandwich',
      'imageUrl':
          'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=400&auto=format&fit=crop',
    },
    {
      'name': 'Burger',
      'query': 'burger',
      'imageUrl':
          'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&auto=format&fit=crop',
    },
    {
      'name': 'Chinese',
      'query': 'chinese',
      'imageUrl':
          'https://images.unsplash.com/photo-1585032226651-759b368d7246?w=400&auto=format&fit=crop',
    },
    {
      'name': 'Paneer',
      'query': 'paneer',
      'imageUrl':
          'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400&auto=format&fit=crop',
    },
    {
      'name': 'Momo',
      'query': 'momo',
      'imageUrl':
          'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=400&auto=format&fit=crop',
    },
    {
      'name': 'Pasta',
      'query': 'pasta',
      'imageUrl':
          'https://images.unsplash.com/photo-1621996346565-e3d5d6281691?w=400&auto=format&fit=crop',
    },
    {
      'name': 'Rolls',
      'query': 'roll',
      'imageUrl':
          'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?w=400&auto=format&fit=crop',
    },
    {
      'name': 'South Indian',
      'query': 'dosa',
      'imageUrl':
          'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=400&auto=format&fit=crop',
    },
    {
      'name': 'Desserts',
      'query': 'dessert',
      'imageUrl':
          'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=400&auto=format&fit=crop',
    },
  ];

  Widget _buildDefaultState(
    BuildContext context,
    bool isDark,
    SearchState state,
    SearchViewModel vm,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. "Think it, search it" conversational chip row
          _buildThinkItSearchIt(context, isDark, vm),

          SizedBox(height: 20.h),

          // 2. "WHAT'S ON YOUR MIND?" 3-column dish grid
          _buildWhatsOnYourMind(context, isDark, vm),

          // 3. Recent searches (if any exist)
          if (state.recentSearches.isNotEmpty) ...[
            SizedBox(height: 24.h),
            _buildRecentSearches(context, isDark, state, vm),
          ],

          SizedBox(height: 80.h),
        ],
      ),
    );
  }

  Widget _buildThinkItSearchIt(
    BuildContext context,
    bool isDark,
    SearchViewModel vm,
  ) {
    const chips = [
      'Desk-friendly options',
      'Crunchy and crispy',
      'Kuch chatpata...',
      'Late night cravings',
      'Guilt-free bites',
      'Sweet tooth',
      'Comfort food',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Think it, search it',
          style: GoogleFonts.caveat(
            fontSize: 21.sp,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            color: const Color(0xFFD64D65),
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 10.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: chips.map((label) {
              return Padding(
                padding: EdgeInsets.only(right: 10.w, bottom: 4.h),
                child: GestureDetector(
                  onTap: () {
                    Haptics.light();
                    _textController.text = label;
                    vm.submitQuery(label);
                  },
                  child: CustomPaint(
                    painter: _SpeechBubblePainter(
                      color: isDark ? const Color(0xFF262C36) : Colors.white,
                      borderColor: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                      borderWidth: 1.0,
                      radius: 14.r,
                      tailWidth: 8.w,
                      tailHeight: 5.h,
                    ),
                    child: Container(
                      padding: EdgeInsets.fromLTRB(10.w, 7.h, 12.w, 11.h),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 13.sp,
                            color: const Color(0xFFBA6880),
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : const Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildWhatsOnYourMind(
    BuildContext context,
    bool isDark,
    SearchViewModel vm,
  ) {
    final categories = ref.watch(homeViewModelProvider).categories.asData?.value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHAT\'S ON YOUR MIND?',
          style: TextStyle(
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
        SizedBox(height: 12.h),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 16.h,
            childAspectRatio: 0.88,
          ),
          itemCount: _whatsOnYourMindDishes.length,
          itemBuilder: (context, index) {
            final dish = _whatsOnYourMindDishes[index];
            final name = dish['name']!;
            final query = dish['query']!;

            // Prefer category image from backend if exists and non-empty
            final matchedCat = categories
                .where((c) => c.name.toLowerCase().contains(query))
                .firstOrNull;
            final imageUrl = (matchedCat != null && matchedCat.imageUrl.isNotEmpty)
                ? matchedCat.imageUrl
                : dish['imageUrl']!;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Haptics.light();
                final catToOpen = matchedCat ??
                    CategoryModel(
                      id: query,
                      name: name,
                      imageUrl: imageUrl,
                      slug: query,
                    );
                context.push(RouteNames.categoryDetails, extra: catToOpen);
              },
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, _) => Container(
                          color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                        ),
                        errorWidget: (context, _, error) => Container(
                          color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                          child: Icon(
                            Icons.restaurant_rounded,
                            color: isDark ? Colors.white24 : Colors.black26,
                            size: 28.sp,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentSearches(
    BuildContext context,
    bool isDark,
    SearchState state,
    SearchViewModel vm,
  ) {
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Searches',
              style: TextStyle(
                fontSize: 13.5.sp,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            GestureDetector(
              onTap: () {
                Haptics.light();
                vm.clearRecentSearches();
              },
              child: Text(
                'Clear All',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFF0F8A5F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: state.recentSearches.map((item) {
            return Chip(
              label: Text(item),
              labelStyle: TextStyle(fontSize: 12.sp, color: textColor),
              backgroundColor: isDark ? AppColors.cardDark : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
                side: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              deleteIcon: Icon(
                Icons.close,
                size: 14.sp,
                color: secondaryTextColor,
              ),
              onDeleted: () {
                Haptics.light();
                vm.removeRecentSearch(item);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==================== EMPTY STATE ====================

  Widget _buildEmptyState(BuildContext context, bool isDark, String query) {
    final secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72.r,
              height: 72.r,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 36.sp,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'We couldn\'t find any matches for "$query". Try searching for another food item or restaurant.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5.sp,
                color: secondaryTextColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== RESULTS SECTION (MATCHING SCREENSHOT 1) ====================

  Widget _buildResultsSection(
    BuildContext context,
    bool isDark,
    String query,
    List<SearchResult> results,
    SearchViewModel vm,
    List<CategoryModel> categories,
  ) {
    final suggestions = _getSuggestions(query, results);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        // 1. Suggestions List (Autocomplete rows with thumbnail, title, and Dish subtitle)
        if (suggestions.isNotEmpty) ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(vertical: 4.h),
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final s = suggestions[index];
              final title = s['title']!;
              final subtitle = s['subtitle']!;
              final imageUrl = s['imageUrl']!;

              return InkWell(
                onTap: () {
                  Haptics.light();
                  // Check if matches a category
                  final matchedCat = categories.where((c) =>
                      c.name.toLowerCase() == title.toLowerCase() ||
                      title.toLowerCase().contains(c.name.toLowerCase())).firstOrNull;

                  if (matchedCat != null) {
                    context.push(RouteNames.categoryDetails, extra: matchedCat);
                  } else {
                    _textController.text = title;
                    vm.submitQuery(title);
                  }
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
                  child: Row(
                    children: [
                      // Circular dish plate / thumbnail
                      ClipOval(
                        child: SizedBox(
                          width: 42.r,
                          height: 42.r,
                          child: SmartImage(
                            url: imageUrl,
                            category: ImageCategory.food,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      SizedBox(width: 14.w),
                      // Title & Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5.sp,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF1F2937),
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w400,
                                color: isDark ? Colors.white54 : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 8.h),
        ],

        // 2. "Showing results for "query""
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : const Color(0xFF374151),
              ),
              children: [
                const TextSpan(text: 'Showing results for '),
                TextSpan(
                  text: '"$query"',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 10.h),

        // 3. Circular Categories Carousel (matching Image 1)
        _buildCircularCategoriesRow(context, isDark, query, categories),

        SizedBox(height: 12.h),

        // 4. Filters Row (Filters v, Hyderabadi, Paneer, with R...)
        _buildFilterChipsRow(isDark, query),

        SizedBox(height: 14.h),

        // 5. Results Cards List
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: results.length,
            separatorBuilder: (context, index) => SizedBox(height: 10.h),
            itemBuilder: (context, index) {
              final item = results[index];
              return _buildResultCard(context, isDark, item);
            },
          ),
        ),

        SizedBox(height: 40.h),
      ],
    );
  }

  // ==================== DISH SUBCATEGORIES FOR SEARCH RESULTS ====================

  List<Map<String, String>> _getDishSubcategories(
    String query,
    List<CategoryModel> categories,
  ) {
    final q = query.toLowerCase().trim();
    if (q.contains('biryani')) {
      return [
        {
          'name': 'Biryani',
          'query': 'biryani',
          'imageUrl': 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=300&auto=format&fit=crop',
        },
        {
          'name': 'Veg',
          'query': 'veg biryani',
          'imageUrl': 'https://images.unsplash.com/photo-1645177628172-a94c1f96e6db?w=300&auto=format&fit=crop',
        },
        {
          'name': 'Paneer',
          'query': 'paneer biryani',
          'imageUrl': 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=300&auto=format&fit=crop',
        },
        {
          'name': 'Dum',
          'query': 'dum biryani',
          'imageUrl': 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=300&auto=format&fit=crop',
        },
        {
          'name': 'Hyderabadi',
          'query': 'hyderabadi biryani',
          'imageUrl': 'https://images.unsplash.com/photo-1633945274405-b6c8069047b0?w=300&auto=format&fit=crop',
        },
        {
          'name': 'Chicken',
          'query': 'chicken biryani',
          'imageUrl': 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?w=300&auto=format&fit=crop',
        },
      ];
    } else if (q.contains('pizza')) {
      return [
        {
          'name': 'Pizza',
          'query': 'pizza',
          'imageUrl': 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=300&auto=format&fit=crop',
        },
        {
          'name': 'Cheesy',
          'query': 'cheese pizza',
          'imageUrl': 'https://images.unsplash.com/photo-1534308983496-4fabb1a015ee?w=300&auto=format&fit=crop',
        },
        {
          'name': 'Veg',
          'query': 'veg pizza',
          'imageUrl': 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=300&auto=format&fit=crop',
        },
        {
          'name': 'Paneer',
          'query': 'paneer pizza',
          'imageUrl': 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=300&auto=format&fit=crop',
        },
        {
          'name': 'Farmhouse',
          'query': 'farmhouse pizza',
          'imageUrl': 'https://images.unsplash.com/photo-1590947132387-155cc02f3212?w=300&auto=format&fit=crop',
        },
      ];
    } else if (q.contains('burger')) {
      return [
        {
          'name': 'Burger',
          'query': 'burger',
          'imageUrl': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=300&auto=format&fit=crop',
        },
        {
          'name': 'Crispy',
          'query': 'crispy burger',
          'imageUrl': 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=300&auto=format&fit=crop',
        },
        {
          'name': 'Cheese',
          'query': 'cheese burger',
          'imageUrl': 'https://images.unsplash.com/photo-1586190848861-99aa4a171e90?w=300&auto=format&fit=crop',
        },
        {
          'name': 'Veg',
          'query': 'veg burger',
          'imageUrl': 'https://images.unsplash.com/photo-1520072959219-c595dc870360?w=300&auto=format&fit=crop',
        },
      ];
    }

    if (categories.isNotEmpty) {
      return categories.take(6).map((c) => {
        'name': c.name,
        'query': c.slug.isNotEmpty ? c.slug : c.name.toLowerCase(),
        'imageUrl': c.imageUrl.isNotEmpty
            ? c.imageUrl
            : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=300&auto=format&fit=crop',
      }).toList();
    }

    return [
      {
        'name': query,
        'query': query,
        'imageUrl': 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=300&auto=format&fit=crop',
      },
    ];
  }

  // ==================== AUTOCOMPLETE SUGGESTIONS ====================

  List<Map<String, String>> _getSuggestions(String query, List<SearchResult> results) {
    final q = query.trim().toLowerCase();
    final list = <Map<String, String>>[];
    final seen = <String>{};

    for (final r in results) {
      if (r.title.toLowerCase().contains(q) && seen.add(r.title.toLowerCase())) {
        list.add({
          'title': r.title,
          'subtitle': r.type == SearchResultType.restaurant ? 'Restaurant' : 'Dish',
          'imageUrl': r.imageUrl,
          'type': r.type.name,
        });
        if (list.length >= 4) break;
      }
    }

    if (list.length < 4) {
      final clean = query.trim();
      final capitalized = clean.isNotEmpty
          ? '${clean[0].toUpperCase()}${clean.substring(1).toLowerCase()}'
          : 'Dish';

      final fallbackItems = [
        {
          'title': capitalized,
          'subtitle': 'Dish',
          'url': 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=300&auto=format&fit=crop',
        },
        {
          'title': '$capitalized Bowl',
          'subtitle': 'Dish',
          'url': 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=300&auto=format&fit=crop',
        },
        {
          'title': '$capitalized Rice',
          'subtitle': 'Dish',
          'url': 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=300&auto=format&fit=crop',
        },
        {
          'title': 'Hyderabadi $capitalized',
          'subtitle': 'Dish',
          'url': 'https://images.unsplash.com/photo-1633945274405-b6c8069047b0?w=300&auto=format&fit=crop',
        },
      ];

      for (final item in fallbackItems) {
        if (seen.add(item['title']!.toLowerCase())) {
          list.add({
            'title': item['title']!,
            'subtitle': item['subtitle']!,
            'imageUrl': item['url']!,
            'type': 'dish',
          });
        }
        if (list.length >= 4) break;
      }
    }

    return list;
  }

  // ==================== CIRCULAR CATEGORIES ROW (IMAGE 1) ====================

  Widget _buildCircularCategoriesRow(
    BuildContext context,
    bool isDark,
    String query,
    List<CategoryModel> categories,
  ) {
    final subcategories = _getDishSubcategories(query, categories);
    final q = query.trim().toLowerCase();

    return SizedBox(
      height: 94.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: subcategories.length,
        separatorBuilder: (_, _) => SizedBox(width: 16.w),
        itemBuilder: (context, index) {
          final item = subcategories[index];
          final name = item['name']!;
          final subQuery = item['query']!;
          final imageUrl = item['imageUrl']!;
          final isSelected = index == 0 || q.contains(name.toLowerCase()) || name.toLowerCase().contains(q);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Haptics.light();
              // Navigate to CategoryDetailsScreen directly
              final matchedCat = categories.where((c) =>
                  c.name.toLowerCase() == subQuery.toLowerCase() ||
                  c.slug.toLowerCase() == subQuery.toLowerCase() ||
                  c.name.toLowerCase() == name.toLowerCase() ||
                  c.name.toLowerCase().contains(subQuery.toLowerCase())).firstOrNull;

              final catToOpen = matchedCat ??
                  CategoryModel(
                    id: subQuery,
                    name: name,
                    imageUrl: imageUrl,
                    slug: subQuery,
                  );

              context.push(RouteNames.categoryDetails, extra: catToOpen);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Circular Image Plate
                Container(
                  width: 54.r,
                  height: 54.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
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

                // Category Name
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),

                SizedBox(height: 3.h),

                // Active Green Underline Indicator
                if (isSelected)
                  Container(
                    height: 2.5.h,
                    width: 28.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F8A5F),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  )
                else
                  SizedBox(height: 2.5.h),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==================== FILTER CHIPS ROW (IMAGE 1) ====================

  Widget _buildFilterChipsRow(bool isDark, String query) {
    final q = query.toLowerCase();
    final isBiryani = q.contains('biryani');
    final isPizza = q.contains('pizza');

    final chips = isBiryani
        ? [
            (label: 'Hyderabadi', icon: '🍛'),
            (label: 'Paneer', icon: '🍲'),
            (label: 'with Raita', icon: '🥟'),
            (label: 'Near & Fast', icon: '⚡'),
            (label: 'Rating 4.0+', icon: '⭐'),
          ]
        : isPizza
        ? [
            (label: 'Cheesy', icon: '🧀'),
            (label: 'Veg Feast', icon: '🍃'),
            (label: 'Paneer Special', icon: '🍕'),
            (label: 'Near & Fast', icon: '⚡'),
            (label: 'Rating 4.0+', icon: '⭐'),
          ]
        : [
            (label: 'Near & Fast', icon: '⚡'),
            (label: 'Rating 4.0+', icon: '⭐'),
            (label: 'Pure Veg', icon: '🌱'),
            (label: 'Offers', icon: '🏷'),
          ];

    return SizedBox(
      height: 34.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        children: [
          // "Filters ▾" pill
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 13.sp,
                  color: isDark ? Colors.white70 : const Color(0xFF374151),
                ),
                SizedBox(width: 4.w),
                Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF374151),
                  ),
                ),
                SizedBox(width: 2.w),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 16.sp,
                  color: isDark ? Colors.white70 : const Color(0xFF374151),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          ...chips.map((c) {
            return Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.icon, style: TextStyle(fontSize: 12.sp)),
                    SizedBox(width: 5.w),
                    Text(
                      c.label,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    bool isDark,
    SearchResult item,
  ) {
    final isRestaurant = item.type == SearchResultType.restaurant;
    final isClosedRest = isRestaurant &&
        item.rawItem is RestaurantModel &&
        !(item.rawItem as RestaurantModel).isOpen;
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return GestureDetector(
      onTap: () => _onResultTap(item),
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
          border: Border.all(
            color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Image Box
            ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: SizedBox(
                width: isRestaurant ? 76.r : 80.r,
                height: isRestaurant ? 76.r : 80.r,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SmartImage(
                      url: item.imageUrl,
                      category: isRestaurant
                          ? ImageCategory.restaurant
                          : ImageCategory.food,
                      fit: BoxFit.cover,
                    ),
                    if (isClosedRest)
                      Container(
                        color: Colors.black.withValues(alpha: 0.52),
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: const Color(0xEFDC2626),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              'CLOSED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8.5.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12.w),

            // Info Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge Row (Type Label + Green Star Rating)
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTintStrong,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          isRestaurant ? 'Restaurant' : 'Dish',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (isClosedRest) ...[
                        SizedBox(width: 5.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6.r),
                            border: Border.all(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'Closed',
                            style: TextStyle(
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                      SizedBox(width: 6.w),
                      Icon(
                        Icons.star_rounded,
                        color: const Color(0xFF16A34A),
                        size: 14.sp,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        (item.rating ?? 0) > 0 ? '${item.rating}' : 'New',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 4.h),

                  // Title & Price Row (if dish)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5.sp,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                      if (!isRestaurant && item.price != null) ...[
                        SizedBox(width: 6.w),
                        Text(
                          '₹${item.price!.toInt()}',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),

                  SizedBox(height: 2.h),

                  // Subtitle
                  Text(
                    item.subtitle,
                    maxLines: isRestaurant ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: secondaryTextColor,
                      height: 1.3,
                    ),
                  ),

                  SizedBox(height: 4.h),

                  // Bottom Detail Row
                  if (isRestaurant && item.rawItem is RestaurantModel) ...[
                    Builder(
                      builder: (context) {
                        final r = item.rawItem as RestaurantModel;
                        final hasTime = r.deliveryTime.isNotEmpty;
                        final hasFee = r.isFreeDelivery || r.deliveryFee >= 0;
                        if (!hasTime && !hasFee) return const SizedBox.shrink();

                        return Row(
                          children: [
                            if (hasTime) ...[
                              Icon(
                                Icons.access_time_rounded,
                                size: 12.sp,
                                color: secondaryTextColor,
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                r.deliveryTime,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                            if (hasTime && hasFee) ...[
                              SizedBox(width: 6.w),
                              Text(
                                '•',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 10.sp,
                                ),
                              ),
                              SizedBox(width: 6.w),
                            ],
                            if (hasFee) ...[
                              Icon(
                                Icons.two_wheeler_rounded,
                                size: 12.sp,
                                color: secondaryTextColor,
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                r.isFreeDelivery || r.deliveryFee == 0
                                    ? 'Free Delivery'
                                    : '₹${r.deliveryFee.toStringAsFixed(0)} Delivery',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ] else if (!isRestaurant) ...[
                    Builder(
                      builder: (context) {
                        final isVeg = (item.rawItem is FoodModel)
                            ? (item.rawItem as FoodModel).isVeg
                            : ((item.rawItem is Store99Product)
                                ? (item.rawItem as Store99Product).isVeg
                                : true);
                        final badgeColor = isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Veg / Non-Veg Tag Icon
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 5.w,
                                vertical: 1.5.h,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: badgeColor,
                                  width: 1.2,
                                ),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5.sp,
                                    height: 5.sp,
                                    decoration: BoxDecoration(
                                      color: badgeColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    isVeg ? 'Veg' : 'Non-Veg',
                                    style: TextStyle(
                                      color: badgeColor,
                                      fontSize: 9.5.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                        // Interactive + Add Button
                        InkWell(
                          onTap: () => _addDishToCart(item),
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  color: AppColors.primary,
                                  size: 15.sp,
                                ),
                                SizedBox(width: 2.w),
                                Text(
                                  'Add',
                                  style: TextStyle(
                                    fontSize: 12.5.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
                ],
              ),
            ),

            if (isRestaurant) ...[
              SizedBox(width: 4.w),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? AppColors.borderDark : const Color(0xFFCBD5E1),
                size: 22.sp,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the speech-bubble shaped chip with a small pointer tail at bottom-left.
class _SpeechBubblePainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final double radius;
  final double tailWidth;
  final double tailHeight;

  _SpeechBubblePainter({
    required this.color,
    required this.borderColor,
    this.borderWidth = 1.0,
    this.radius = 14.0,
    this.tailWidth = 8.0,
    this.tailHeight = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height - tailHeight;
    final r = radius;

    final path = Path();
    path.moveTo(r, 0);
    path.lineTo(w - r, 0);
    path.arcToPoint(Offset(w, r), radius: Radius.circular(r));
    path.lineTo(w, h - r);
    path.arcToPoint(Offset(w - r, h), radius: Radius.circular(r));

    // Tail at bottom left
    const tailStartX = 20.0;
    path.lineTo(tailStartX + tailWidth, h);
    path.lineTo(tailStartX, h + tailHeight);
    path.lineTo(tailStartX + 2.0, h);

    path.lineTo(r, h);
    path.arcToPoint(Offset(0, h - r), radius: Radius.circular(r));
    path.lineTo(0, r);
    path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));
    path.close();

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SpeechBubblePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor;
  }
}
