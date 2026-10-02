import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/api_config.dart';
import '../../../core/utils/haptics.dart';
import '../../../di/network_providers.dart';
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

/// Real customer reviews for one restaurant, from
/// `GET /food/public/restaurants/:id/reviews`.
final restaurantReviewsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) {
  return ref.watch(apiClientProvider).get<Map<String, dynamic>>(
        ApiPaths.restaurantReviews(id),
        query: {'limit': 50},
        auth: false,
      );
});

class RestaurantReviewsScreen extends ConsumerWidget {
  final RestaurantModel restaurant;
  final List<FoodModel> menuItems;

  const RestaurantReviewsScreen({
    super.key,
    required this.restaurant,
    this.menuItems = const [],
  });

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String _formatDate(Object? raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
  }

  static List<RestaurantReviewItem> _parseReviews(Map<String, dynamic> data) {
    final list = (data['reviews'] as List?) ?? const [];
    return list.whereType<Map>().map((raw) {
      final r = raw.cast<String, dynamic>();
      final image = r['dishImage'] as String?;
      return RestaurantReviewItem(
        userName: (r['userName'] ?? 'Customer').toString(),
        rating: (r['rating'] as num?)?.toDouble() ?? 0,
        date: _formatDate(r['ratedAt']),
        comment: (r['comment'] ?? '').toString(),
        dishName: r['dishName'] as String?,
        dishImageUrl: image == null ? null : ApiConfig.resolveMedia(image),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(restaurantReviewsProvider(restaurant.id));
    final data = async.asData?.value ?? const <String, dynamic>{};
    final summary = (data['summary'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final rating = (summary['rating'] as num?)?.toDouble() ?? restaurant.rating;
    final totalRatings = (summary['totalRatings'] as num?)?.toInt() ?? restaurant.reviewCount;
    final totalReviews = (summary['totalReviews'] as num?)?.toInt() ?? 0;
    final breakdown = <String, int>{
      for (final entry in ((summary['breakdown'] as Map?) ?? const {}).entries)
        entry.key.toString(): (entry.value as num?)?.toInt() ?? 0,
    };
    final reviews = _parseReviews(data);

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
              breakdown: breakdown,
            ),

            SizedBox(height: 8.h),

            // Review List
            if (async.isLoading && reviews.isEmpty)
              Padding(
                padding: EdgeInsets.all(32.h),
                child: const Center(child: CircularProgressIndicator()),
              )
            else if (async.hasError && reviews.isEmpty)
              _buildEmptyState("Couldn't load reviews. Go back and try again.", isDark)
            else if (reviews.isEmpty)
              _buildEmptyState('No reviews yet', isDark)
            else
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
    required Map<String, int> breakdown,
  }) {
    double share(int star) =>
        totalRatings > 0 ? (breakdown['$star'] ?? 0) / totalRatings : 0;
    String pct(int star) => '${(share(star) * 100).round()}%';
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
                _buildRatingBarRow(5, share(5), pct(5), isDark),
                SizedBox(height: 5.h),
                _buildRatingBarRow(4, share(4), pct(4), isDark),
                SizedBox(height: 5.h),
                _buildRatingBarRow(3, share(3), pct(3), isDark),
                SizedBox(height: 5.h),
                _buildRatingBarRow(2, share(2), pct(2), isDark),
                SizedBox(height: 5.h),
                _buildRatingBarRow(1, share(1), pct(1), isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 24.w),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.sp,
            color: isDark ? Colors.white60 : const Color(0xFF6B7280),
          ),
        ),
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
