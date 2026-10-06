import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/cart_item_model.dart';
import '../../../data/models/food_model.dart';
import '../../branding/app_colors.dart';
import '../../cart/utils/cart_restaurant_guard.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';
import '../../common_widgets/smart_image.dart';
import 'food_diet_info.dart';

/// Quick preview bottom sheet for food items matching Screenshot 2.
///
/// Features:
/// - Floating dark circular close button at top
/// - Card with rounded top corners
/// - Full-width food image with rounded corners
/// - Floating bookmark & share buttons at bottom-right of food image
/// - Veg / Non-veg symbol + bold item name
/// - Description text
/// - Green "━━━━ highly reordered" indicator
/// - "NOT ELIGIBLE FOR COUPONS"
/// - Price & coral/red ADD button with quantity stepper
class FoodDetailSheet {
  const FoodDetailSheet._();

  static Future<void> show(
    BuildContext context,
    FoodModel food, {
    VoidCallback? onAdded,
    String? restaurantName,
    CartItemModel? existingCartItem,
    bool autoScrollToOptions = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FoodQuickDetailSheet(
        food: food,
        onAdded: onAdded,
        restaurantName: restaurantName,
        existingCartItem: existingCartItem,
      ),
    );
  }
}

class _FoodQuickDetailSheet extends ConsumerStatefulWidget {
  final FoodModel food;
  final VoidCallback? onAdded;
  final String? restaurantName;
  final CartItemModel? existingCartItem;

  const _FoodQuickDetailSheet({
    required this.food,
    this.onAdded,
    this.restaurantName,
    this.existingCartItem,
  });

  @override
  ConsumerState<_FoodQuickDetailSheet> createState() =>
      _FoodQuickDetailSheetState();
}

class _FoodQuickDetailSheetState extends ConsumerState<_FoodQuickDetailSheet> {
  Future<void> _handleAddToCart() async {
    Haptics.light();
    await addFoodToCart(context, ref, widget.food);
    widget.onAdded?.call();
  }

  Widget _buildVegIcon({double size = 16}) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(2.5 * (size / 16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3.r),
        border: Border.all(color: const Color(0xFF008A45), width: 1.5),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF008A45),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildNonVegIcon({double size = 16}) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(2.5 * (size / 16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3.r),
        border: Border.all(color: const Color(0xFFB45309), width: 1.5),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFB45309),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E232C);
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF757575);

    final cartState = ref.watch(cartViewModelProvider);
    int quantity = 0;
    String? cartItemId;
    for (final item in cartState.items) {
      if (item.food.id == food.id) {
        quantity = item.quantity;
        cartItemId = item.id;
        break;
      }
    }
    final hasQty = quantity > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Floating Dark Circular Close Button above sheet
        GestureDetector(
          onTap: () {
            Haptics.light();
            Navigator.of(context).pop();
          },
          child: Container(
            width: 38.r,
            height: 38.r,
            margin: EdgeInsets.only(bottom: 10.h),
            decoration: const BoxDecoration(
              color: Color(0xFF2C3E50),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 20.sp,
            ),
          ),
        ),

        // 2. White Sheet Card Container
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Full-width Food Image with Bookmark & Share in bottom right
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18.r),
                        child: SmartImage(
                          url: food.imageUrl,
                          category: ImageCategory.food,
                          width: double.infinity,
                          height: 240.h,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Floating Bookmark & Share overlay buttons on bottom-right of image
                      Positioned(
                        right: 12.w,
                        bottom: 12.h,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Haptics.light();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Saved "${food.name}" to favorites'),
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: Container(
                                width: 36.r,
                                height: 36.r,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.bookmark_border_rounded,
                                  size: 20.sp,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            GestureDetector(
                              onTap: () {
                                Haptics.light();
                                final text = 'Order ${food.name} on Lagech App!';
                                SharePlus.instance.share(ShareParams(text: text));
                              },
                              child: Container(
                                width: 36.r,
                                height: 36.r,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.share_outlined,
                                  size: 18.sp,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16.h),

                  // Veg/Non-veg icon + Dish Title
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 3.h),
                        child: food.isVeg
                            ? _buildVegIcon(size: 16)
                            : _buildNonVegIcon(size: 16),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          food.name,
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Description
                  if (food.description.isNotEmpty) ...[
                    SizedBox(height: 6.h),
                    Text(
                      food.description,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: secondaryTextColor,
                        height: 1.35,
                      ),
                    ),
                  ],

                  FoodDietInfo(food: food),

                  // "━━━━ highly reordered" indicator
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 2.5.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF008A45),
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'highly reordered',
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF008A45),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 12.h),

                  // Coupon Eligibility
                  Text(
                    'NOT ELIGIBLE FOR COUPONS',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Bottom Price & Coral/Red ADD button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${food.price.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          if (food.originalPrice != null &&
                              food.originalPrice! > food.price) ...[
                            Text(
                              '₹${food.originalPrice!.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 13.sp,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Coral Red ADD Button with white text & stepper
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 38.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF05151),
                              borderRadius: BorderRadius.circular(10.r),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF05151)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: !hasQty
                                ? GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: _handleAddToCart,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16.w),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.remove_rounded,
                                            color: Colors.white70,
                                            size: 16.sp,
                                          ),
                                          SizedBox(width: 8.w),
                                          Text(
                                            'ADD',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          SizedBox(width: 8.w),
                                          Icon(
                                            Icons.add_rounded,
                                            color: Colors.white,
                                            size: 16.sp,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: cartItemId == null
                                            ? null
                                            : () {
                                                Haptics.light();
                                                ref
                                                    .read(cartViewModelProvider
                                                        .notifier)
                                                    .updateQuantity(
                                                      cartItemId!,
                                                      quantity - 1,
                                                    );
                                              },
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 10.w, vertical: 6.h),
                                          child: Icon(
                                            Icons.remove_rounded,
                                            color: Colors.white,
                                            size: 16.sp,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 4.w),
                                        child: Text(
                                          '$quantity',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: cartItemId == null
                                            ? null
                                            : () {
                                                Haptics.light();
                                                ref
                                                    .read(cartViewModelProvider
                                                        .notifier)
                                                    .updateQuantity(
                                                      cartItemId!,
                                                      quantity + 1,
                                                    );
                                              },
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 10.w, vertical: 6.h),
                                          child: Icon(
                                            Icons.add_rounded,
                                            color: Colors.white,
                                            size: 16.sp,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          if (food.variants.isNotEmpty) ...[
                            SizedBox(height: 3.h),
                            Text(
                              'customisable',
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
