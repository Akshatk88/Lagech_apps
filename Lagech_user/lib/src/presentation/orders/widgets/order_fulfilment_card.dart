import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/models/order_model.dart';
import '../../branding/app_colors.dart';

/// "Tue, 6 Oct, 1:00 pm" in the device's time zone.
String formatScheduledTime(DateTime at) =>
    DateFormat('EEE, d MMM, h:mm a').format(at.toLocal()).replaceAll('AM', 'am').replaceAll('PM', 'pm');

/// Takeaway and scheduled-order details for an order: "Takeaway — collect
/// from restaurant", the pickup code to show at the counter (until collected)
/// and "Scheduled for ...". Builds nothing for a plain delivery-now order.
class OrderFulfilmentCard extends StatelessWidget {
  const OrderFulfilmentCard({super.key, required this.order, this.margin});

  final OrderModel order;
  final EdgeInsetsGeometry? margin;

  /// Whether the card has anything to show for [order].
  static bool appliesTo(OrderModel order) =>
      order.isTakeaway || (order.isScheduled && order.scheduledAt != null);

  @override
  Widget build(BuildContext context) {
    if (!appliesTo(order)) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final scheduledAt = order.isScheduled ? order.scheduledAt : null;

    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (order.isTakeaway)
            _InfoLine(
              icon: Icons.storefront_outlined,
              title: 'Takeaway — collect from restaurant',
              subtitle: order.restaurantName.isEmpty
                  ? null
                  : [order.restaurantName, order.restaurantAddress]
                      .where((s) => s.trim().isNotEmpty)
                      .join(', '),
              textColor: textColor,
              secondary: secondary,
            ),
          if (order.isTakeaway && scheduledAt != null) const SizedBox(height: 12),
          if (scheduledAt != null)
            _InfoLine(
              icon: Icons.event_available_outlined,
              title: 'Scheduled for ${formatScheduledTime(scheduledAt)}',
              subtitle: order.isActive && order.isAwaitingAcceptance
                  ? 'We will send it to the restaurant ahead of your slot'
                  : null,
              textColor: textColor,
              secondary: secondary,
            ),
          if (order.showPickupCode) ...[
            const SizedBox(height: 14),
            _PickupCode(code: order.pickupCode),
          ],
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.title,
    required this.textColor,
    required this.secondary,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color textColor;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: TextStyle(fontSize: 12, color: secondary, height: 1.3)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The 4-digit code the restaurant enters to hand the order over.
class _PickupCode extends StatelessWidget {
  const _PickupCode({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PICKUP CODE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Show this code at the counter',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              code,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
