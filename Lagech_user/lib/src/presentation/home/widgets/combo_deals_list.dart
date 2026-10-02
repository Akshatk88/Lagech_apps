import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/food_model.dart';
import '../../branding/app_colors.dart';
import '../../cart/utils/cart_restaurant_guard.dart';
import '../../common_widgets/smart_image.dart';
import '../../restaurant/widgets/food_detail_sheet.dart';

class ComboDealsList extends ConsumerWidget {
  final List<FoodModel> foods;

  const ComboDealsList({super.key, required this.foods});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (foods.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            'Discounts, combos and free items on dishes',
            style: TextStyle(
              fontSize: 12.sp,
              color: isDark ? AppColors.textSecondaryDark : Colors.grey.shade600,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        SizedBox(height: 10.h),
        SizedBox(
          height: 275.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: foods.length,
            separatorBuilder: (context, index) => SizedBox(width: 14.w),
            itemBuilder: (context, index) {
              return _ComboDealCard(
                food: foods[index],
                isDark: isDark,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ComboDealCard extends ConsumerWidget {
  final FoodModel food;
  final bool isDark;

  const _ComboDealCard({required this.food, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double originalPrice = (food.originalPrice != null && food.originalPrice! > food.price)
        ? food.originalPrice!
        : (food.price * 1.2).roundToDouble();
    final double savings = originalPrice - food.price;
    final int discountPercent = originalPrice > 0
        ? ((savings / originalPrice) * 100).round()
        : 15;

    return GestureDetector(
      onTap: () {
        Haptics.light();
        FoodDetailSheet.show(
          context,
          food,
          restaurantName: food.restaurantName,
        );
      },
      child: Container(
        width: 290.w,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: isDark
                ? AppColors.borderDark
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with COMBO badge and 15% OFF badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
                  child: SmartImage(
                    url: food.imageUrl,
                    category: ImageCategory.food,
                    height: 140.h,
                    width: 290.w,
                    fit: BoxFit.cover,
                  ),
                ),

                // Orange COMBO pill badge
                Positioned(
                  top: 10.h,
                  left: 10.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 3.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      'COMBO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),

                // White 15% OFF rounded pill badge
                Positioned(
                  bottom: 10.h,
                  right: 10.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 3.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      '$discountPercent% OFF',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                // Pagination dots simulation
                Positioned(
                  bottom: 8.h,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 5.r,
                        height: 5.r,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Container(
                        width: 4.r,
                        height: 4.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Container(
                        width: 4.r,
                        height: 4.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Details
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    food.name,
                    style: TextStyle(
                      fontSize: 16.5.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Restaurant
                  Text(
                    food.restaurantName.isNotEmpty
                        ? food.restaurantName
                        : 'Cafe & Restaurant',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Description
                  if (food.description.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      food.description,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  SizedBox(height: 6.h),

                  // Price Row + Add Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '₹${food.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                              if (originalPrice > food.price) ...[
                                SizedBox(width: 5.w),
                                Text(
                                  '₹${originalPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (savings > 0)
                            Text(
                              'Save ₹${savings.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),

                      // Add + Button
                      InkWell(
                        onTap: () async {
                          Haptics.light();
                          await addFoodToCart(context, ref, food);
                        },
                        borderRadius: BorderRadius.circular(16.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 6.5.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'Add +',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
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
}
