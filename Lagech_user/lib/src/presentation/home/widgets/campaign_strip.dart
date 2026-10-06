import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/campaign_model.dart';
import '../../branding/app_colors.dart';
import '../../cart/utils/cart_restaurant_guard.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../common_widgets/smart_image.dart';
import '../../navigation/route_names.dart';

/// Horizontal strip of running campaigns from `GET /food/public/campaigns`.
///
/// A dish campaign opens a sheet with the dish at its campaign price and an
/// "Add to cart" button (checkout charges the campaign price, priced by the
/// server). A basic campaign opens its only restaurant directly, or lets the
/// user pick when several take part. A campaign with no participating
/// restaurant is shown but inert. Renders nothing for an empty list.
class CampaignStrip extends StatelessWidget {
  final List<CampaignModel> campaigns;

  const CampaignStrip({super.key, required this.campaigns});

  void _openRestaurant(BuildContext context, CampaignRestaurant r) {
    context.push('${RouteNames.restaurantDetail}/${r.id}');
  }

  void _onTap(BuildContext context, CampaignModel c) {
    if (c.restaurants.isEmpty) return;
    Haptics.light();
    if (c.isFood && c.toFoodModel() != null) {
      _showDishSheet(context, c);
      return;
    }
    if (c.restaurants.length == 1) {
      _openRestaurant(context, c.restaurants.first);
      return;
    }
    _showRestaurantPicker(context, c);
  }

  void _showDishSheet(BuildContext context, CampaignModel c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1B1B1B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetCtx) => _CampaignDishSheet(
        campaign: c,
        onViewRestaurant: () {
          Navigator.pop(sheetCtx);
          _openRestaurant(context, c.restaurants.first);
        },
      ),
    );
  }

  void _showRestaurantPicker(BuildContext context, CampaignModel c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1B1B1B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetCtx).size.height * 0.6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
                  child: Text(
                    c.title,
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: c.restaurants
                        .map(
                          (r) => ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8.r),
                              child: SmartImage(
                                url: r.logo.isNotEmpty ? r.logo : r.coverImage,
                                category: ImageCategory.restaurant,
                                width: 44.w,
                                height: 44.w,
                              ),
                            ),
                            title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              [
                                if (r.area.isNotEmpty) r.area,
                                if (r.rating > 0) '★ ${r.rating.toStringAsFixed(1)}',
                                if (!r.isAcceptingOrders) 'Not accepting orders',
                              ].join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              Navigator.pop(sheetCtx);
                              _openRestaurant(context, r);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _money(double v) =>
      v == v.roundToDouble() ? '₹${v.toStringAsFixed(0)}' : '₹${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    if (campaigns.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondary = isDark ? Colors.white60 : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            'ONGOING CAMPAIGNS',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: secondary,
            ),
          ),
        ),
        SizedBox(height: 10.h),
        SizedBox(
          height: 186.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: campaigns.length,
            separatorBuilder: (_, _) => SizedBox(width: 12.w),
            itemBuilder: (context, index) {
              final c = campaigns[index];
              final subtitle = c.isFood
                  ? (c.restaurants.isNotEmpty ? c.restaurants.first.name : '')
                  : (c.restaurants.length > 1
                      ? '${c.restaurants.length} restaurants'
                      : (c.restaurants.isNotEmpty ? c.restaurants.first.name : c.description));
              return GestureDetector(
                onTap: () => _onTap(context, c),
                child: Container(
                  width: 230.w,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B1B1B) : Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: isDark ? const Color(0xFF303030) : const Color(0xFFF0F0F0),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SizedBox(
                          width: double.infinity,
                          child: SmartImage(
                            url: c.image.isNotEmpty
                                ? c.image
                                : (c.restaurants.isNotEmpty ? c.restaurants.first.coverImage : ''),
                            category: c.isFood ? ImageCategory.food : ImageCategory.restaurant,
                            width: 230.w,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 10.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Row(
                              children: [
                                if (c.isFood && c.finalPrice > 0) ...[
                                  Text(
                                    _money(c.finalPrice),
                                    style: TextStyle(
                                      fontSize: 12.5.sp,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                    ),
                                  ),
                                  if (c.hasDiscount) ...[
                                    SizedBox(width: 4.w),
                                    Text(
                                      _money(c.price),
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: secondary,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ],
                                  SizedBox(width: 6.w),
                                ],
                                Expanded(
                                  child: Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11.5.sp, color: secondary),
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
            },
          ),
        ),
      ],
    );
  }
}

/// A food campaign dish: its photo, restaurant and campaign price, with
/// "Add to cart" (through the single-restaurant cart guard) and a link to the
/// restaurant.
class _CampaignDishSheet extends ConsumerStatefulWidget {
  final CampaignModel campaign;
  final VoidCallback onViewRestaurant;

  const _CampaignDishSheet({required this.campaign, required this.onViewRestaurant});

  @override
  ConsumerState<_CampaignDishSheet> createState() => _CampaignDishSheetState();
}

class _CampaignDishSheetState extends ConsumerState<_CampaignDishSheet> {
  bool _adding = false;

  String _money(double v) =>
      v == v.roundToDouble() ? '₹${v.toStringAsFixed(0)}' : '₹${v.toStringAsFixed(2)}';

  Future<void> _add() async {
    final food = widget.campaign.toFoodModel();
    if (food == null || _adding) return;
    setState(() => _adding = true);
    try {
      await addFoodToCart(context, ref, food);
      if (!mounted) return;
      // The guard returns without adding when the restaurant is closed or the
      // customer kept their other cart; only report what actually happened.
      final added = ref.read(cartViewModelProvider).items.any((i) => i.food.id == food.id);
      if (added) {
        AppSnackbar.success(context, '${food.name} added to cart');
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.campaign;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondary = isDark ? Colors.white60 : Colors.black54;
    final restaurant = c.restaurants.first;
    final open = restaurant.isAcceptingOrders;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c.image.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(14.r),
                child: SmartImage(
                  url: c.image,
                  category: ImageCategory.food,
                  width: double.infinity,
                  height: 170.h,
                ),
              ),
            SizedBox(height: 12.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 3.h, right: 6.w),
                  child: Icon(
                    Icons.circle,
                    size: 10.sp,
                    color: c.isVeg ? const Color(0xFF0F8A3B) : const Color(0xFFB3261E),
                  ),
                ),
                Expanded(
                  child: Text(
                    c.title,
                    style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800, color: textColor),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              restaurant.area.isEmpty ? restaurant.name : '${restaurant.name} • ${restaurant.area}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5.sp, color: secondary),
            ),
            if (c.description.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Text(
                c.description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.sp, color: textColor, height: 1.35),
              ),
            ],
            SizedBox(height: 12.h),
            Row(
              children: [
                Text(
                  _money(c.finalPrice),
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: textColor),
                ),
                if (c.hasDiscount) ...[
                  SizedBox(width: 8.w),
                  Text(
                    _money(c.price),
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: secondary,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Campaign price',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ],
            ),
            if (!open) ...[
              SizedBox(height: 6.h),
              Text(
                '${restaurant.name} is not accepting orders right now.',
                style: TextStyle(fontSize: 12.sp, color: const Color(0xFFB3261E)),
              ),
            ],
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onViewRestaurant,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    child: const Text('View restaurant'),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: open && !_adding ? _add : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    child: _adding
                        ? SizedBox(
                            width: 18.r,
                            height: 18.r,
                            child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Add to cart'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
