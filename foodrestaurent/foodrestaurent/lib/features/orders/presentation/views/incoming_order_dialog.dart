import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/core/services/new_order_action_channel.dart';
import 'package:food_user_application/core/services/order_resolution_tracker.dart';
import 'package:food_user_application/core/services/fcm_service.dart';
import 'package:food_user_application/features/business_settings/data/business_settings_repository.dart';
import 'package:food_user_application/features/business_settings/domain/restaurant_business_settings.dart';
import 'package:food_user_application/features/orders/data/order_repository.dart';
import 'package:food_user_application/features/orders/domain/order_model.dart';
import 'package:food_user_application/features/orders/presentation/controllers/live_orders_controller.dart';
import 'package:food_user_application/features/orders/presentation/widgets/order_type_badges.dart';

// A push can arrive more than once in a burst (e.g. connectivity blip causing
// a redundant FCM deliver) — this guards against stacking duplicate dialogs
// on top of each other.
bool _incomingOrderDialogShowing = false;

/// Shown immediately when a `new_order` push/socket event arrives while the
/// app is in the foreground, so the restaurant can accept/reject right away
/// instead of having to notice and tap a system notification first.
Future<void> showIncomingOrderDialog(
  BuildContext context, {
  required String orderId,
}) async {
  if (OrderResolutionTracker.isResolved(orderId)) return;
  if (_incomingOrderDialogShowing) return;
  _incomingOrderDialogShowing = true;
  NewOrderActionChannel.startSound(orderId);
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => IncomingOrderDialog(orderId: orderId),
    );
  } finally {
    _incomingOrderDialogShowing = false;
    NewOrderActionChannel.stopSound(orderId);
  }
}

class IncomingOrderDialog extends ConsumerStatefulWidget {
  const IncomingOrderDialog({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<IncomingOrderDialog> createState() =>
      _IncomingOrderDialogState();
}

class _IncomingOrderDialogState extends ConsumerState<IncomingOrderDialog> {
  OrderModel? _order;
  bool _loading = true;
  bool _acting = false;

  /// Shown inside the dialog: a SnackBar would render behind the dialog's barrier,
  /// so a refused Accept looked like the button did nothing.
  String? _error;

  /// Several paths close this dialog (the response, the live-orders listener
  /// seeing a cancellation, the initial load). Popping twice removed the page
  /// underneath it — that was the crash after Reject.
  bool _closed = false;

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  RestaurantBusinessSettings get _settings =>
      ref.read(restaurantBusinessSettingsProvider).value ??
      RestaurantBusinessSettings.fallback;

  /// With Business Settings' "confirmed by deliveryman", a delivery order
  /// arrives already `confirmed`: there is nothing to accept, only "Start
  /// preparing" (and a reject only if the restaurant may cancel accepted
  /// orders). Takeaway orders are still accepted as usual.
  bool _isPreConfirmed(OrderModel order) =>
      _settings.confirmedByDeliveryman &&
      !order.isTakeaway &&
      order.orderStatus == 'confirmed';

  /// The status this dialog is waiting on the restaurant to move the order
  /// out of.
  String get _awaitedStatus =>
      _order != null && _isPreConfirmed(_order!) ? 'confirmed' : 'created';

  @override
  void initState() {
    super.initState();
    if (OrderResolutionTracker.isResolved(widget.orderId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _close());
      return;
    }
    _load();
  }

  @override
  void dispose() {
    NewOrderActionChannel.stopSound(widget.orderId);
    super.dispose();
  }

  Future<void> _load() async {
    final cached = ref.read(liveOrdersControllerProvider).value;
    final match = cached?.where(
      (o) => o.id == widget.orderId || o.displayId == widget.orderId,
    );
    OrderModel? order = (match != null && match.isNotEmpty)
        ? match.first
        : null;

    // A push can beat the order being readable from the API by a beat
    // (replication/eventual-consistency lag) — a couple of quick retries
    // avoids dropping to the reduced fallback view for a purely timing issue.
    for (var attempt = 0; order == null && attempt < 3; attempt++) {
      if (attempt > 0) await Future.delayed(const Duration(milliseconds: 700));
      try {
        order = await ref.read(orderRepositoryProvider).getById(widget.orderId);
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'IncomingOrderDialog: fetch order failed (attempt $attempt): $e',
          );
        }
      }
    }
    // Only orders still waiting for the restaurant's answer. The 'new' bucket
    // also holds 'confirmed', so an order already accepted on the overlay or the
    // notification re-opened this dialog, and its Accept then failed.
    final isNewOrPending = order != null &&
        !order.isCancelled &&
        (const {'created', 'placed', 'pending'}.contains(order.orderStatus) ||
            _isPreConfirmed(order));

    // A scheduled order before its release time must not ring; it is not
    // resolved either, so it is offered normally once released.
    if (order != null && order.isAwaitingRelease) {
      NewOrderActionChannel.stopSound(widget.orderId);
      _close();
      return;
    }

    if (order != null && !isNewOrPending) {
      OrderResolutionTracker.markResolved(widget.orderId);
      NewOrderActionChannel.stopSound(widget.orderId);
      NewOrderActionChannel.dismiss(widget.orderId);
      cancelFcmTrayCopy(widget.orderId);
      if (mounted && !_closed && order.isCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order was cancelled.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      _close();
      return;
    }
    setState(() {
      _order = order;
      _loading = false;
    });
  }

  Future<void> _respond(String orderStatus) async {
    // Silence first; the order is only marked handled once the server agrees, so a
    // refused response does not stop it from being offered again.
    await NewOrderActionChannel.stopSound(widget.orderId);
    if (!mounted) return;

    if (orderStatus == 'cancelled_by_restaurant') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject this order?'),
          content: const Text(
            'The customer will be notified and refunded per policy.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Reject',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (!mounted) return;
    }

    setState(() {
      _acting = true;
      _error = null;
    });
    try {
      await ref
          .read(liveOrdersControllerProvider.notifier)
          .updateStatus(widget.orderId, orderStatus);
      OrderResolutionTracker.markResolved(widget.orderId);
      await NewOrderActionChannel.dismiss(widget.orderId);
      await cancelFcmTrayCopy(widget.orderId);
      _close();
    } catch (e, st) {
      debugPrint('IncomingOrderDialog: $orderStatus failed for ${widget.orderId}: $e\n$st');
      if (!mounted || _closed) return;

      // Already answered elsewhere (overlay, notification, another device)?
      // Then there is nothing left to do here — close instead of showing an error.
      try {
        final latest =
            await ref.read(orderRepositoryProvider).getById(widget.orderId);
        if (latest.orderStatus != _awaitedStatus && mounted && !_closed) {
          OrderResolutionTracker.markResolved(widget.orderId);
          await NewOrderActionChannel.dismiss(widget.orderId);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                latest.isCancelled
                    ? 'This order was cancelled.'
                    : _awaitedStatus == 'confirmed'
                    ? 'This order was already updated.'
                    : 'This order was already accepted.',
              ),
            ),
          );
          unawaited(ref.read(liveOrdersControllerProvider.notifier).refresh());
          _close();
          return;
        }
      } catch (_) {
        // Fall through to showing the original error.
      }
      if (!mounted || _closed) return;
      setState(() {
        _acting = false;
        _error = apiErrorMessage(e, 'Failed to update order. Please try again.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<OrderModel>>>(liveOrdersControllerProvider, (prev, next) {
      if (next.hasValue) {
        final orders = next.value!;
        final match = orders.where(
          (o) => o.id == widget.orderId || o.displayId == widget.orderId,
        );
        // Skipped while this dialog's own request is in flight: a Reject comes
        // back as a cancellation, and _respond closes the dialog itself.
        if (match.isNotEmpty && match.first.isCancelled && !_acting && !_closed) {
          OrderResolutionTracker.markResolved(widget.orderId);
          NewOrderActionChannel.dismiss(widget.orderId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order was cancelled or updated.'),
              duration: Duration(seconds: 3),
            ),
          );
          _close();
        }
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loading
              ? const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                )
              : _order == null
              ? _buildFallback(context)
              : _buildOrder(context, _order!),
        ),
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.notifications_active,
          color: AppColors.primary,
          size: 40,
        ),
        const SizedBox(height: 12),
        const Text(
          'New order received',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text(
          "Couldn't load full details, but you can still respond.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _buildActionButtons(
          context,
          detailsOrderId: widget.orderId,
          deadline: null,
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context, {
    required String detailsOrderId,
    required DateTime? deadline,
    bool preConfirmed = false,
  }) {
    // A pre-confirmed order can only be rejected as a cancellation of an
    // accepted order, which needs "restaurant can cancel order".
    final showReject = !preConfirmed || _settings.canCancelOrder;
    return Column(
      children: [
        if (_error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showReject) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _acting
                    ? null
                    : () => _respond('cancelled_by_restaurant'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Reject',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _acting
                          ? null
                          : () => _respond(
                              preConfirmed ? 'preparing' : 'confirmed',
                            ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.primaryButton,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _acting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  preConfirmed
                                      ? Icons.soup_kitchen
                                      : Icons.check_circle,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    preConfirmed ? 'Start preparing' : 'Accept',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (deadline != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _DialogAcceptanceCountdown(deadline: deadline),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _acting
                ? null
                : () {
                    final router = GoRouter.of(context);
                    _close();
                    router.push('/order-details/$detailsOrderId');
                  },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 16,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 6),
                Text(
                  'View full details',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.primaryDark,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBillRow(String title, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.black87, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildOrder(BuildContext context, OrderModel order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.show_chart,
                      size: 6,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'New Order!',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
          ],
        ),
        Container(
          margin: const EdgeInsets.only(top: 20, bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryAlpha(0.20), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ORDER ID',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.formattedDisplayId,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: AppColors.primaryAlpha(0.20),
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 12,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd MMM, yyyy').format(order.createdAt.toLocal()),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '•',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.access_time, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('h:mm a').format(order.createdAt.toLocal()),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (OrderTypeBadges.hasAny(order))
                  OrderTypeBadges(
                    order: order,
                    padding: const EdgeInsets.only(bottom: 12),
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryTint,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: AppColors.primaryDark,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.customerPhone,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryTint,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.phone_outlined,
                          color: AppColors.primaryDark,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!order.isTakeaway &&
                    order.deliveryAddress.fullAddress.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.primaryDark,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Delivery address',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryTint,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    order.deliveryAddress.label.isEmpty
                                        ? 'Other'
                                        : order.deliveryAddress.label,
                                    style: const TextStyle(
                                      color: AppColors.primaryDeep,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              order.deliveryAddress.fullAddress,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                Divider(color: Colors.grey.shade200, height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shopping_bag,
                        color: AppColors.primaryDark,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Items',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...order.items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: item.isVeg
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${item.quantity} x ${item.name}',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '₹${item.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Divider(color: Colors.grey.shade200, height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: AppColors.primaryDark,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bill details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildBillRow('Subtotal', order.pricing.subtotal),
                          _buildBillRow(
                            'Delivery fee',
                            order.pricing.deliveryFee,
                          ),
                          _buildBillRow(
                            'Platform fee',
                            order.pricing.platformFee,
                          ),
                          _buildBillRow('Tax', order.pricing.tax),
                          if (order.pricing.riderTip > 0)
                            _buildBillRow(
                            'Rider tip (for delivery partner)',
                            order.pricing.riderTip,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        color: AppColors.primaryDark,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Total',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        '₹${order.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.primaryDeep,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        _buildActionButtons(
          context,
          detailsOrderId: order.id,
          // No acceptance timer runs for an order that arrived confirmed.
          deadline: _isPreConfirmed(order) ? null : order.acceptanceDeadlineAt,
          preConfirmed: _isPreConfirmed(order),
        ),
      ],
    );
  }
}

class _DialogAcceptanceCountdown extends StatefulWidget {
  const _DialogAcceptanceCountdown({required this.deadline});
  final DateTime deadline;
  @override
  State<_DialogAcceptanceCountdown> createState() =>
      _DialogAcceptanceCountdownState();
}

class _DialogAcceptanceCountdownState
    extends State<_DialogAcceptanceCountdown> {
  late Duration _remaining = widget.deadline.difference(DateTime.now());

  @override
  void initState() {
    super.initState();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _remaining = widget.deadline.difference(DateTime.now()));
      return !_remaining.isNegative;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative) return const SizedBox.shrink();
    final minutes = _remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = _remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Accept within',
              style: TextStyle(color: Colors.black87, fontSize: 9),
            ),
            Text(
              '$minutes:$seconds',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
