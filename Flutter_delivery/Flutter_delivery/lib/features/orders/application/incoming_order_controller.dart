import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/fcm_service.dart';
import '../../../core/services/socket_service.dart';
import '../data/models/delivery_order.dart';
import 'orders_controller.dart';

/// Single source of truth for the full-screen incoming-order alert.
/// `null` means no active alert; non-null means "show it now" — regardless
/// of whether the order arrived via Socket.IO (app open) or FCM (app
/// backgrounded/foregrounded), both transports funnel into this state.
class IncomingOrderController extends Notifier<DeliveryOrder?> {
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  StreamSubscription<Map<String, dynamic>>? _fcmReceivedSub;
  StreamSubscription<Map<String, dynamic>>? _fcmTapSub;
  StreamSubscription<Map<String, dynamic>>? _orderClaimedSub;
  StreamSubscription<Map<String, dynamic>>? _orderDeassignedSub;

  // Track orders declined recently by this rider so they aren't immediately
  // re-shown within 20s, but allow re-offers and resend notifications to surface.
  final Map<String, DateTime> _recentlyDeclinedOrderTimes = {};

  @override
  DeliveryOrder? build() {
    final socket = ref.read(socketServiceProvider);
    _socketSub = socket.onNewOrderAvailable.listen(_onRealtimePayload);
    _orderClaimedSub = socket.onOrderClaimed.listen(_autoDismissIfMatch);
    _orderDeassignedSub = socket.onOrderDeassigned.listen(_autoDismissIfMatch);

    final fcm = ref.read(fcmServiceProvider);
    _fcmReceivedSub = fcm.onNotificationReceived.listen(_onRealtimePayload);
    _fcmTapSub = fcm.onNotificationTap.listen(_onRealtimePayload);

    ref.onDispose(() {
      _socketSub?.cancel();
      _fcmReceivedSub?.cancel();
      _fcmTapSub?.cancel();
      _orderClaimedSub?.cancel();
      _orderDeassignedSub?.cancel();
    });

    return null;
  }

  void _onRealtimePayload(Map<String, dynamic> data) {
    if (data['type'] == 'order_taken') {
      _withdraw(data);
      return;
    }
    // Accept new_order, new_order_available, or empty type (direct socket payload)
    if (data['type'] != null &&
        data['type'] != 'new_order' &&
        data['type'] != 'new_order_available') {
      return;
    }
    final orderId =
        (data['orderMongoId'] ?? data['id'] ?? data['_id'] ?? data['orderId'])
            ?.toString();
    if (orderId == null || orderId.isEmpty) return;

    final declinedAt = _recentlyDeclinedOrderTimes[orderId];
    if (declinedAt != null &&
        DateTime.now().difference(declinedAt).inSeconds < 20) {
      return;
    }

    if (state != null && state!.id == orderId) return;
    show(DeliveryOrder.fromRealtimePayload(data));
  }

  void _withdraw(Map<String, dynamic> data) {
    final orderId =
        (data['orderMongoId'] ?? data['id'] ?? data['orderId'] ?? data['_id'])
            ?.toString();
    if (orderId == null || orderId.isEmpty) return;

    _recentlyDeclinedOrderTimes[orderId] = DateTime.now();
    if (state?.id == orderId) state = null;
  }

  void _autoDismissIfMatch(Map<String, dynamic> data) => _withdraw(data);

  void show(DeliveryOrder order) {
    state = order;
  }

  Future<void> accept() async {
    final order = state;
    if (order == null) return;
    _recentlyDeclinedOrderTimes.remove(order.id);
    await ref
        .read(ordersControllerProvider.notifier)
        .acceptOrder(order.id);
    state = null;
  }

  Future<void> decline() async {
    final order = state;
    if (order == null) return;
    _recentlyDeclinedOrderTimes[order.id] = DateTime.now();
    state = null;
    await ref.read(ordersControllerProvider.notifier).rejectOrder(order.id);
  }

  /// Countdown ran out client-side — best-effort notify the backend so it
  /// can reassign sooner. The BullMQ `processDispatchTimeout` job remains
  /// the authoritative fallback if this call never arrives.
  Future<void> expire() => decline();

  void dismiss() {
    state = null;
  }
}

final incomingOrderControllerProvider =
    NotifierProvider<IncomingOrderController, DeliveryOrder?>(
  IncomingOrderController.new,
);
