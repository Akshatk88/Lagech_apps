import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/features/orders/domain/order_model.dart';

/// "Scheduled for (slot)" and "Takeaway" chips for an order. Renders nothing
/// for a regular delivery order placed for now.
class OrderTypeBadges extends StatelessWidget {
  const OrderTypeBadges({super.key, required this.order, this.padding});

  final OrderModel order;
  final EdgeInsetsGeometry? padding;

  static bool hasAny(OrderModel order) =>
      order.isTakeaway || (order.isScheduled && order.scheduledAt != null);

  /// e.g. "Today, 7:30 PM", "Tomorrow, 1:00 PM" or "Sat 12 Oct, 8:00 PM".
  static String formatSlot(DateTime at) {
    final local = at.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final time = DateFormat('h:mm a').format(local);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today, $time';
    if (diff == 1) return 'Tomorrow, $time';
    return '${DateFormat('EEE d MMM').format(local)}, $time';
  }

  @override
  Widget build(BuildContext context) {
    if (!hasAny(order)) return const SizedBox.shrink();
    final chips = <Widget>[
      if (order.isScheduled && order.scheduledAt != null)
        _Chip(
          icon: Icons.event_outlined,
          label: 'Scheduled for ${formatSlot(order.scheduledAt!)}',
          color: AppColors.warning,
          background: AppColors.warningSoft,
        ),
      if (order.isTakeaway)
        const _Chip(
          icon: Icons.shopping_bag_outlined,
          label: 'Takeaway',
          color: AppColors.primaryDark,
          background: AppColors.primaryTint,
        ),
    ];
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Wrap(spacing: 8, runSpacing: 6, children: chips),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
