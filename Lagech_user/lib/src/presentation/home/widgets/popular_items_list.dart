import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/restaurant_model.dart';
import '../../branding/app_colors.dart';
import '../../cart/utils/cart_restaurant_guard.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';
import '../../cart/widgets/floating_view_cart_bar.dart';
import '../../common_widgets/smart_image.dart';
import '../../navigation/route_names.dart';
import '../../restaurant/widgets/food_detail_sheet.dart';

class PopularItemsList extends ConsumerWidget {
  final List<FoodModel> foods;
  final List<RestaurantModel> restaurants;
  final GlobalKey<FloatingViewCartBarState>? cartBarKey;
  final VoidCallback? onAddToCartAnimationComplete;
  final String? overrideTitle;
  final bool is99Store;

  const PopularItemsList({
    super.key,
    required this.foods,
    this.restaurants = const [],
    this.cartBarKey,
    this.onAddToCartAnimationComplete,
    this.overrideTitle,
    this.is99Store = true,
  });


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eligibleFoods = is99Store ? foods.where((f) => f.price <= 99.0).toList() : foods;
    if (eligibleFoods.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (is99Store)
          // Header: Logo 99 STORE + Subtitle + View All
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Container(
                  width: 32.w,
                  height: 32.h,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Center(
                    child: Text(
                      '99',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.sp,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '99 STORE',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 12.sp,
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          'Meals at ₹99 + Free Delivery',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    Haptics.light();
                    context.push(RouteNames.store99);
                  },
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5.sp,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.primary,
                        size: 16.sp,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0.w),
            child: Row(
              children: [
                RichText(
                  text: TextSpan(
                    text: 'Popular ',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      color: isDark ? AppColors.textPrimaryDark : const Color(0xFF1E293B),
                    ),
                    children: [
                      TextSpan(
                        text: 'Dishes',
                        style: TextStyle(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    Haptics.light();
                    context.push(RouteNames.popularDishes);
                  },
                  child: Row(
                    children: [
                      Text(
                        'See All',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey.shade600,
                        size: 16.sp,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: 10.h),

        // Single-row horizontal-scrolling list with 3 cards visible on screen
        SizedBox(
          height: 160.h,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: eligibleFoods.length,
            separatorBuilder: (context, index) => SizedBox(width: 8.w),
            itemBuilder: (context, index) {
              final food = eligibleFoods[index];
              final resName = food.restaurantName.isNotEmpty
                  ? food.restaurantName
                  : (restaurants.where((r) => r.id == food.restaurantId).firstOrNull?.name ?? '');
              return _Home99ProductCard(
                food: food,
                restaurantName: resName,
                isDark: isDark,
                cartBarKey: cartBarKey,
                onAddToCartAnimationComplete: onAddToCartAnimationComplete,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Home99ProductCard extends ConsumerStatefulWidget {
  final FoodModel food;
  final String restaurantName;
  final bool isDark;
  final GlobalKey<FloatingViewCartBarState>? cartBarKey;
  final VoidCallback? onAddToCartAnimationComplete;

  const _Home99ProductCard({
    required this.food,
    this.restaurantName = '',
    required this.isDark,
    this.cartBarKey,
    this.onAddToCartAnimationComplete,
  });

  @override
  ConsumerState<_Home99ProductCard> createState() => _Home99ProductCardState();
}

class _Home99ProductCardState extends ConsumerState<_Home99ProductCard> {
  final GlobalKey _imageKey = GlobalKey();

  Future<void> _handleFirstAddToCart() async {
    Haptics.light();
    await addFoodToCart(context, ref, widget.food);
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartViewModelProvider);

    int quantity = 0;
    String? cartItemId;
    for (final item in cartState.items) {
      if (item.food.id == widget.food.id) {
        quantity = item.quantity;
        cartItemId = item.id;
        break;
      }
    }

    final hasQty = quantity > 0;

    return GestureDetector(
      onTap: () {
        Haptics.light();
        FoodDetailSheet.show(
          context,
          widget.food,
          restaurantName: widget.restaurantName,
        );
      },
      child: Container(
        width: 106.w,
        height: 152.h,
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: widget.isDark
                ? AppColors.borderDark
                : Colors.black.withValues(alpha: 0.04),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: widget.isDark ? 0.3 : 0.06,
              ),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image - properly sized for 3 cards per screen
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(14.r),
              ),
              child: SmartImage(
                key: _imageKey,
                url: widget.food.imageUrl,
                category: ImageCategory.food,
                height: 76.h,
                width: 106.w,
                fit: BoxFit.cover,
              ),
            ),

            // Card details: Name, Restaurant, Price & Orange Circular Add Button
            Padding(
              padding: EdgeInsets.fromLTRB(6.w, 4.h, 6.w, 4.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: Veg indicator + Dish Name
                  Row(
                    children: [
                      if (widget.food.isVeg) ...[
                        Container(
                          margin: EdgeInsets.only(right: 3.w),
                          width: 10.r,
                          height: 10.r,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF008A45),
                              width: 1.1,
                            ),
                            borderRadius: BorderRadius.circular(2.5.r),
                          ),
                          child: Center(
                            child: Container(
                              width: 4.r,
                              height: 4.r,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF008A45),
                              ),
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          widget.food.name,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: widget.isDark
                                ? AppColors.textPrimaryDark
                                : const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 1.5.h),

                  // Row 2: Restaurant Name
                  Text(
                    widget.restaurantName.isNotEmpty
                        ? widget.restaurantName
                        : (widget.food.categoryName.isNotEmpty
                            ? widget.food.categoryName
                            : 'Restaurant'),
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w400,
                      color: widget.isDark
                          ? AppColors.textSecondaryDark
                          : const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 2.5.h),

                  // Row 3: Price + Circular Add Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          '₹${widget.food.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w800,
                            color: widget.isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Add / Stepper Button
                      if (!hasQty)
                        InkWell(
                          key: const ValueKey('popular_add_btn'),
                          onTap: _handleFirstAddToCart,
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            width: 24.r,
                            height: 24.r,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary,
                                width: 1.2,
                              ),
                              color: widget.isDark
                                  ? AppColors.surfaceDark
                                  : Colors.white,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.add,
                                color: AppColors.primary,
                                size: 15,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 24.r,
                          padding: EdgeInsets.symmetric(horizontal: 3.w),
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? AppColors.surfaceDark
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: AppColors.primary,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: cartItemId == null
                                    ? null
                                    : () {
                                        Haptics.light();
                                        ref
                                            .read(
                                              cartViewModelProvider.notifier,
                                            )
                                            .updateQuantity(
                                              cartItemId!,
                                              quantity - 1,
                                            );
                                      },
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 2.w,
                                  ),
                                  child: Icon(
                                    Icons.remove,
                                    color: AppColors.primary,
                                    size: 11,
                                  ),
                                ),
                              ),
                              Text(
                                '$quantity',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                              InkWell(
                                onTap: cartItemId == null
                                    ? null
                                    : () {
                                        Haptics.light();
                                        ref
                                            .read(
                                              cartViewModelProvider.notifier,
                                            )
                                            .updateQuantity(
                                              cartItemId!,
                                              quantity + 1,
                                            );
                                      },
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 2.w,
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    color: AppColors.primary,
                                    size: 11,
                                  ),
                                ),
                              ),
                            ],
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
}
