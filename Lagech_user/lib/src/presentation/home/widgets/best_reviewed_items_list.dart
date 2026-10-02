import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/food_model.dart';
import '../../branding/app_colors.dart';
import '../../cart/utils/cart_restaurant_guard.dart';
import '../../common_widgets/smart_image.dart';
import '../../restaurant/widgets/food_detail_sheet.dart';

class BestReviewedItemsList extends ConsumerWidget {
  final List<FoodModel> foods;

  const BestReviewedItemsList({super.key, required this.foods});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (foods.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              RichText(
                text: TextSpan(
                  text: 'Best ',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                    color: isDark ? AppColors.textPrimaryDark : const Color(0xFF1E293B),
                  ),
                  children: [
                    TextSpan(
                      text: 'Reviewed',
                      style: TextStyle(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            'Top rated dishes loved by everyone',
            style: TextStyle(
              fontSize: 12.sp,
              color: isDark ? AppColors.textSecondaryDark : Colors.grey.shade600,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        SizedBox(height: 10.h),
        SizedBox(
          height: 190.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: foods.length,
            separatorBuilder: (context, index) => SizedBox(width: 14.w),
            itemBuilder: (context, index) {
              return _BestReviewedCard(
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

class _BestReviewedCard extends ConsumerWidget {
  final FoodModel food;
  final bool isDark;

  const _BestReviewedCard({required this.food, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        width: 144.w,
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
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
                  child: SmartImage(
                    url: food.imageUrl,
                    category: ImageCategory.food,
                    height: 90.h,
                    width: 144.w,
                    fit: BoxFit.cover,
                  ),
                ),
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, color: Colors.white, size: 14.sp),
                        SizedBox(width: 4.w),
                        Text(
                          food.rating > 0 ? food.rating.toStringAsFixed(1) : '4.5',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    food.restaurantName.isNotEmpty
                        ? food.restaurantName
                        : 'Cafe & Restaurant',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '₹${food.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          Haptics.light();
                          await addFoodToCart(context, ref, food);
                        },
                        borderRadius: BorderRadius.circular(16.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 5.h,
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
                              fontSize: 12.sp,
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
