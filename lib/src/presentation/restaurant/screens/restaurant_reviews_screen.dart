import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/restaurant_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/smart_image.dart';

class RestaurantReviewItem {
  final String userName;
  final double rating;
  final String date;
  final String comment;
  final String? dishName;
  final String? dishImageUrl;

  const RestaurantReviewItem({
    required this.userName,
    required this.rating,
    required this.date,
    required this.comment,
    this.dishName,
    this.dishImageUrl,
  });
}

class RestaurantReviewsScreen extends StatelessWidget {
  final RestaurantModel restaurant;
  final List<FoodModel> menuItems;

  const RestaurantReviewsScreen({
    super.key,
    required this.restaurant,
    this.menuItems = const [],
  });

  List<RestaurantReviewItem> _buildReviews() {
    final dishes = menuItems.isNotEmpty
        ? menuItems
        : [
            FoodModel(
              id: '1',
              restaurantId: restaurant.id,
              name: 'Cheesy fries',
              description: 'Crispy fries loaded with melted cheese',
              price: 120,
              imageUrl: '',
              categoryName: 'Snacks',
              rating: 4.5,
              reviewCount: 12,
            ),
            FoodModel(
              id: '2',
              restaurantId: restaurant.id,
              name: 'Veg cheese roll',
              description: 'Fresh veggies and cheese roll',
              price: 150,
              imageUrl: '',
              categoryName: 'Rolls',
              rating: 4.8,
              reviewCount: 20,
            ),
            FoodModel(
              id: '3',
              restaurantId: restaurant.id,
              name: 'Cheesy paneer burger',
              description: 'Delicious paneer burger',
              price: 180,
              imageUrl: '',
              categoryName: 'Burgers',
              rating: 4.3,
              reviewCount: 15,
            ),
            FoodModel(
              id: '4',
              restaurantId: restaurant.id,
              name: 'Maxicana pizza',
              description: 'Spicy mexican style pizza',
              price: 260,
              imageUrl: '',
              categoryName: 'Pizza',
              rating: 4.7,
              reviewCount: 30,
            ),
            FoodModel(
              id: '5',
              restaurantId: restaurant.id,
              name: 'Maharaja burger',
              description: 'Grand burger with double patty',
              price: 220,
              imageUrl: '',
              categoryName: 'Burgers',
              rating: 5.0,
              reviewCount: 45,
            ),
          ];

    final sampleData = [
      (
        name: 'Sarthak Sonwalkar',
        rating: 1.0,
        date: '24 Sep 2026',
        comment: "Didn't recieve this item",
        dishIndex: 0,
      ),
      (
        name: 'Sagar Nimbalkar',
        rating: 1.0,
        date: '12 Sep 2026',
        comment: '',
        dishIndex: 1,
      ),
      (
        name: 'Sagar Nimbalkar',
        rating: 1.0,
        date: '12 Sep 2026',
        comment: '',
        dishIndex: 2,
      ),
      (
        name: 'Sagar Nimbalkar',
        rating: 1.0,
        date: '12 Sep 2026',
        comment: '',
        dishIndex: 3,
      ),
      (
        name: 'Prathamesh Chavan',
        rating: 5.0,
        date: '08 Sep 2026',
        comment: 'Amazing taste and super fast delivery! Highly recommended.',
        dishIndex: 4,
      ),
      (
        name: 'Aakash Verma',
        rating: 4.5,
        date: '02 Sep 2026',
        comment: 'Great quality packaging and food arrived steaming hot.',
        dishIndex: 0,
      ),
      (
        name: 'Pooja Sharma',
        rating: 5.0,
        date: '28 Aug 2026',
        comment: 'Best food experience in the area. Loved the flavours.',
        dishIndex: 1,
      ),
      (
        name: 'Rohan Mehta',
        rating: 4.0,
        date: '20 Aug 2026',
        comment: 'Portion size was generous and worth the price.',
        dishIndex: 2,
      ),
    ];

    return sampleData.map((e) {
      final dish = dishes[e.dishIndex % dishes.length];
      return RestaurantReviewItem(
        userName: e.name,
        rating: e.rating,
        date: e.date,
        comment: e.comment,
        dishName: dish.name,
        dishImageUrl: dish.imageUrl,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rating = restaurant.rating > 0 ? restaurant.rating : 4.3;
    final totalRatings = restaurant.reviewCount > 0 ? restaurant.reviewCount : 67;
    final totalReviews = max(19, (totalRatings * 0.28).round());

    final reviews = _buildReviews();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
        appBar: AppBar(
          backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.chevron_left_rounded,
              color: isDark ? Colors.white : Colors.black,
              size: 28.sp,
            ),
            onPressed: () {
              Haptics.light();
              if (context.canPop()) {
                context.pop();
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
          title: Text(
            restaurant.name,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
        ),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            // Top Summary Rating Card
            _buildRatingSummaryCard(
              context: context,
              isDark: isDark,
              rating: rating,
              totalRatings: totalRatings,
              totalReviews: totalReviews,
            ),

            SizedBox(height: 8.h),

            // Review List
            ...reviews.map((review) => _buildReviewRow(context, review, isDark)),

            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSummaryCard({
    required BuildContext context,
    required bool isDark,
    required double rating,
    required int totalRatings,
    required int totalReviews,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFF1F3F5),
          width: 1.2,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Big Score & Count Badges
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 30.sp,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF1E232C),
                        ),
                      ),
                      TextSpan(
                        text: '/5',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white70 : const Color(0xFF1E232C),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: const Color(0xFFFFB800),
                      size: 20.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '${rating.toStringAsFixed(1)} ($totalRatings)',
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Wrap(
                  spacing: 6.w,
                  runSpacing: 6.h,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        '$totalRatings Ratings',
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        '$totalReviews Reviews',
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Vertical divider line
          Container(
            width: 1,
            height: 94.h,
            color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE),
            margin: EdgeInsets.symmetric(horizontal: 12.w),
          ),

          // Right: Star Percentage Bars
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildRatingBarRow(5, 0.66, '66%', isDark),
                SizedBox(height: 5.h),
                _buildRatingBarRow(4, 0.19, '19%', isDark),
                SizedBox(height: 5.h),
                _buildRatingBarRow(3, 0.03, '3%', isDark),
                SizedBox(height: 5.h),
                _buildRatingBarRow(2, 0.03, '3%', isDark),
                SizedBox(height: 5.h),
                _buildRatingBarRow(1, 0.10, '10%', isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBarRow(int star, double progress, String label, bool isDark) {
    return Row(
      children: [
        Text(
          '$star',
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : const Color(0xFF374151),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4.5.h,
              backgroundColor: isDark ? Colors.white12 : const Color(0xFFEDEDED),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE23744)),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        SizedBox(
          width: 28.w,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(BuildContext context, RestaurantReviewItem review, bool isDark) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: User Name, Star, Date, Review Comment
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E232C),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: const Color(0xFFFFB800),
                          size: 15.sp,
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          review.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF1E232C),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      review.date,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w400,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF9CA3AF),
                      ),
                    ),
                    if (review.comment.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      Text(
                        review.comment,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: isDark ? Colors.white70 : const Color(0xFF374151),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Right: Dish Pill Card (if present)
              if (review.dishName != null && review.dishName!.isNotEmpty) ...[
                SizedBox(width: 12.w),
                Container(
                  constraints: BoxConstraints(maxWidth: 130.w),
                  padding: EdgeInsets.fromLTRB(8.w, 4.h, 4.w, 4.h),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          review.dishName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF1E232C),
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6.r),
                        child: (review.dishImageUrl != null && review.dishImageUrl!.isNotEmpty)
                            ? SmartImage(
                                url: review.dishImageUrl!,
                                category: ImageCategory.food,
                                width: 34.r,
                                height: 34.r,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 34.r,
                                height: 34.r,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Icon(
                                  Icons.image_outlined,
                                  color: isDark ? Colors.white30 : const Color(0xFF9CA3AF),
                                  size: 18.sp,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: isDark ? AppColors.borderDark : const Color(0xFFF1F3F5),
        ),
      ],
    );
  }
}
