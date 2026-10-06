import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/features/business_settings/data/business_settings_repository.dart';
import 'package:food_user_application/features/business_settings/domain/restaurant_business_settings.dart';
import 'package:food_user_application/features/orders/domain/order_model.dart';

/// Lets the restaurant cancel an order it has already accepted — only when the
/// admin allows it (Business Settings → Vendor → "restaurant can cancel
/// order", published as `restaurant.canCancelOrder`). Otherwise renders
/// nothing. Rejecting a new (`created`) order is a separate, always-allowed
/// action and lives with the Accept button.
class CancelAcceptedOrderButton extends ConsumerStatefulWidget {
  const CancelAcceptedOrderButton({
    super.key,
    required this.order,
    required this.onCancel,
  });

  final OrderModel order;

  /// Moves the order to `cancelled_by_restaurant` and reports any failure.
  final Future<void> Function() onCancel;

  /// Statuses the server lets a restaurant cancel from when the setting is
  /// on: anything after `created` that is not yet delivered or cancelled.
  static const cancellableStatuses = {
    'confirmed',
    'preparing',
    'ready_for_pickup',
    'reached_pickup',
    'picked_up',
    'reached_drop',
  };

  @override
  ConsumerState<CancelAcceptedOrderButton> createState() =>
      _CancelAcceptedOrderButtonState();
}

class _CancelAcceptedOrderButtonState
    extends ConsumerState<CancelAcceptedOrderButton> {
  bool _cancelling = false;

  Future<void> _confirmAndCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text(
          'The customer will be notified and refunded per policy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Cancel order',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await widget.onCancel();
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!CancelAcceptedOrderButton.cancellableStatuses.contains(
      widget.order.orderStatus,
    )) {
      return const SizedBox.shrink();
    }
    final settings =
        ref.watch(restaurantBusinessSettingsProvider).value ??
        RestaurantBusinessSettings.fallback;
    if (!settings.canCancelOrder) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: _cancelling ? null : _confirmAndCancel,
          icon: _cancelling
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.error,
                  ),
                )
              : const Icon(Icons.cancel_outlined, size: 18),
          label: const Text(
            'Cancel order',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
        ),
      ),
    );
  }
}
