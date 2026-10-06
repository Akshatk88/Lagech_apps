import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/campaign_model.dart';
import '../../common_widgets/smart_image.dart';
import '../../navigation/route_names.dart';

/// Horizontal strip of running campaigns from `GET /food/public/campaigns`.
///
/// Every card leads to a restaurant: a dish campaign opens its restaurant; a
/// basic campaign opens its only restaurant directly, or lets the user pick
/// when several take part. A campaign with no participating restaurant is
/// shown but inert. Renders nothing for an empty list.
class CampaignStrip extends StatelessWidget {
  final List<CampaignModel> campaigns;

  const CampaignStrip({super.key, required this.campaigns});

  void _openRestaurant(BuildContext context, CampaignRestaurant r) {
    context.push('${RouteNames.restaurantDetail}/${r.id}');
  }

  void _onTap(BuildContext context, CampaignModel c) {
    if (c.restaurants.isEmpty) return;
    Haptics.light();
    if (c.restaurants.length == 1) {
      _openRestaurant(context, c.restaurants.first);
      return;
    }
    _showRestaurantPicker(context, c);
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
