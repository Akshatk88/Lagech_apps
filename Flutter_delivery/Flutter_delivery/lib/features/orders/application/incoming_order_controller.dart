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

  // Backend keeps re-offering an order to this partner across re-offer
  // rounds even after it's been declined/expired here — track what's
  // already been resolved this session so it isn't shown again.
  final Set<String> _dismissedOrderIds = {};

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
    // FCM data always tags {type: 'new_order'}; non-order push types (e.g.
    // referral_bonus) must be ignored here. Socket order events carry no
    // 'type' field, so absence of the key means "treat as an order".
    // Another rider got there first. Arrives here rather than on the socket
    // stream when the app was backgrounded at the moment of the claim.
    if (data['type'] == 'order_taken') {
      _withdraw(data);
      return;
    }
    if (data['type'] != null && data['type'] != 'new_order') return;
    final orderId =
        (data['orderMongoId'] ?? data['_id'] ?? data['orderId'])?.toString();
    if (orderId == null || orderId.isEmpty) return;
    if (_dismissedOrderIds.contains(orderId)) return;
    if (state != null && state!.id == orderId) return;
    show(DeliveryOrder.fromRealtimePayload(data));
  }

  void _withdraw(Map<String, dynamic> data) {
    final orderId =
        (data['orderMongoId'] ?? data['orderId'] ?? data['_id'] ?? data['id'])
            ?.toString();
    if (orderId == null || orderId.isEmpty) return;

    // Recorded even when the alert is not currently up. The withdrawal can beat
    // the offer here — FCM makes no ordering guarantee and a queued push is
    // delivered on reconnect — and without this the alert would be raised for an
    // order that is already gone.
    _dismissedOrderIds.add(orderId);
    if (state?.id == orderId) state = null;
  }

  void _autoDismissIfMatch(Map<String, dynamic> data) => _withdraw(data);

  void show(DeliveryOrder order) {
    state = order;
  }

  Future<void> accept() async {
    final order = state;
    if (order == null) return;
    _dismissedOrderIds.add(order.id);
    // Don't set state to null yet! Let the IncomingOrderScreen show its loader.
    // Wait for the API to actually complete.
    final result = await ref.read(ordersControllerProvider.notifier).acceptOrder(order.id);
    
    // Once it succeeds (or fails), we can dismiss the incoming order screen.
    // Note: On success, ordersController immediately shows the ActiveTripScreen, 
    // so this transition will be seamless.
    state = null;
  }

  Future<void> decline() async {
    final order = state;
    if (order == null) return;
    _dismissedOrderIds.add(order.id);
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
