import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../data/models/delivery_order.dart';

/// What the restaurant is doing with the order, for the rider waiting on it.
///
/// Mirrors the restaurant's own status (accepted -> preparing -> ready for pickup)
/// so the rider knows whether to wait or go in. Hidden once the food has been
/// picked up, when it no longer matters.
class RestaurantStatusChip extends StatelessWidget {
  const RestaurantStatusChip({super.key, required this.order});

  final DeliveryOrder order;

  static ({String label, IconData icon, Color color})? describe(String status) {
    switch (status.toLowerCase()) {
      case 'created':
      case 'pending':
      case 'placed':
        return (
          label: 'Restaurant has the order',
          icon: Icons.receipt_long_outlined,
          color: Colors.blueGrey,
        );
      case 'confirmed':
      case 'accepted':
        return (
          label: 'Restaurant accepted the order',
          icon: Icons.check_circle_outline,
          color: Colors.blue,
        );
      case 'preparing':
        return (
          label: 'Preparing food',
          icon: Icons.soup_kitchen_outlined,
          color: Colors.orange,
        );
      case 'ready':
      case 'ready_for_pickup':
      case 'reached_pickup':
        return (
          label: 'Food is ready for pickup',
          icon: Icons.takeout_dining_outlined,
          color: Colors.green,
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!order.isBeforePickup) return const SizedBox.shrink();
    final info = describe(order.orderStatus);
    if (info == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, size: 15.sp, color: info.color),
          SizedBox(width: 6.w),
          Flexible(
            child: Text(
              info.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: info.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
