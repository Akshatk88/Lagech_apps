import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/restaurant_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/smart_image.dart';
import '../../navigation/route_names.dart';

class PopularBrandsList extends StatelessWidget {
  final List<RestaurantModel> restaurants;

  const PopularBrandsList({
    super.key,
    required this.restaurants,
  });

  @override
  Widget build(BuildContext context) {
    if (restaurants.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sized to the avatar + two text lines actually rendered — was 88,
    // leaving dead space below every chip before the section gap started.
    return SizedBox(
      height: 82.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: restaurants.length,
        itemBuilder: (context, index) {
          final restaurant = restaurants[index];
          final name = restaurant.name;
          final time = restaurant.deliveryTime;
          final logo = restaurant.imageUrl;

          return GestureDetector(
            onTap: () {
              Haptics.light();
              context.push(RouteNames.restaurantDetail, extra: restaurant);
            },
            child: Container(
              width: 72.w,
              margin: EdgeInsets.only(right: 12.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Circular Brand Logo Avatar Container
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 48.w,
                        height: 48.h,
                        padding: EdgeInsets.all(7.r),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          border: Border.all(
                            color: !restaurant.isOpen
                                ? const Color(0xFFEF4444)
                                : (isDark
                                    ? AppColors.borderDark
                                    : const Color(0xFFEEEEEE)),
                            width: 1.0,
                          ),
                          boxShadow: isDark
                              ? []
                              : [
                                  BoxShadow(
                                    color: AppColors.shadow1,
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: ClipOval(
                          child: SmartImage(
                            url: logo,
                            category: ImageCategory.restaurant,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      if (!restaurant.isOpen)
                        Positioned(
                          bottom: -2.h,
                          right: -2.w,
                          child: Container(
                            padding: EdgeInsets.all(2.5.r),
                            decoration: const BoxDecoration(
                              color: Color(0xFFDC2626),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lock_clock_rounded,
                              size: 10.sp,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4.h),

                  // Brand Title
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 1.h),

                  // Delivery Time or Closed
                  Text(
                    !restaurant.isOpen ? 'Closed' : time,
                    style: TextStyle(
                      fontSize: 9.5.sp,
                      fontWeight: !restaurant.isOpen ? FontWeight.w700 : FontWeight.w500,
                      color: !restaurant.isOpen
                          ? const Color(0xFFEF4444)
                          : (isDark ? AppColors.textSecondaryDark : const Color(0xFF757575)),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
