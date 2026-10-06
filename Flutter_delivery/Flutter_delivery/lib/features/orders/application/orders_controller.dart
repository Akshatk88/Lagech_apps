import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/services/socket_service.dart';
import '../data/models/delivery_order.dart';
import '../data/orders_repository.dart';
import 'orders_state.dart';
import 'pending_customer_rating_controller.dart';

class OrdersController extends Notifier<OrdersState> {
  late final OrdersRepository _repository;
  Timer? _pollTimer;
  StreamSubscription? _newOrderSub;
  StreamSubscription? _orderClaimedSub;
  StreamSubscription? _orderDeassignedSub;
  StreamSubscription? _orderStatusSub;
  StreamSubscription? _orderReadySub;
  StreamSubscription? _connectionSub;

  // Socket events (new_order/order_claimed/order_deassigned) and the 15s
  // poll can all ask for the same refresh within milliseconds of each other
  // — coalesce concurrent callers onto one in-flight request instead of
  // firing duplicate GETs and replacing state multiple times in a row.
  Future<void>? _refreshAllInFlight;
  Future<void>? _refreshAvailableInFlight;
  Future<void>? _refreshCurrentInFlight;

  /// Bumped whenever a local mutation (accept/status change/complete) is
  /// applied to state. A refresh whose request started before the bump
  /// carries a server snapshot from *before* that mutation — applying it
  /// would e.g. drop an order the rider just accepted — so it is discarded
  /// and re-fetched instead.
  int _mutationVersion = 0;

  /// Orders whose live-tracking room this rider has joined. Kept in sync with
  /// `activeOrders` by [_setLoaded] so every held delivery is tracked, and
  /// each one is left the moment it stops being active.
  Set<String> _trackedOrderIds = <String>{};

  @override
  OrdersState build() {
    _repository = ref.read(ordersRepositoryProvider);

    final socket = ref.read(socketServiceProvider);
    _newOrderSub = socket.onNewOrderAvailable.listen((_) => refreshAvailable());
    _orderClaimedSub = socket.onOrderClaimed.listen((_) => refreshAvailable());
    // A deassigned order may be one we hold — re-read the active list too
    // (tracking for it is left by the diff in _setLoaded).
    _orderDeassignedSub = socket.onOrderDeassigned.listen((_) => refreshAll());
    _orderStatusSub = socket.onOrderStatusUpdate.listen(
      (_) => refreshCurrent(),
    );
    _orderReadySub = socket.onOrderReady.listen((_) => refreshCurrent());
    // Resume live-location sharing for every active order after a reconnect.
    _connectionSub = socket.onConnectionChange.listen((connected) {
      if (!connected) return;
      for (final id in _trackedOrderIds) {
        socket.joinTracking(id);
      }
    });

    ref.onDispose(() {
      _pollTimer?.cancel();
      _newOrderSub?.cancel();
      _orderClaimedSub?.cancel();
      _orderDeassignedSub?.cancel();
      _orderStatusSub?.cancel();
      _orderReadySub?.cancel();
      _connectionSub?.cancel();
    });

    return const OrdersInitial();
  }

  OrdersLoaded? get _loaded {
    final s = state;
    return s is OrdersLoaded ? s : null;
  }

  /// Replaces state only when something the UI cares about changed (see
  /// [OrdersLoaded.==]) — every poll tick and socket event lands here, and
  /// needless rebuilds of the always-mounted trip screen/GoogleMap were what
  /// made the active-trip flow jank. Also keeps tracking rooms in sync.
  void _setLoaded(OrdersLoaded next) {
    if (state == next) return;
    state = next;
    _syncTracking(next.activeOrders);
  }

  void _syncTracking(List<DeliveryOrder> activeOrders) {
    final socket = ref.read(socketServiceProvider);
    final ids = activeOrders.map((o) => o.id).toSet();
    for (final id in ids.difference(_trackedOrderIds)) {
      socket.joinTracking(id);
    }
    for (final id in _trackedOrderIds.difference(ids)) {
      socket.leaveTracking(id);
    }
    _trackedOrderIds = ids;
  }

  /// Which active order stays focused after the list changes: the one the
  /// rider was already on if it's still active, else [preferredId] (the
  /// backend's most recent `activeOrder`), else the first one.
  String? _selectionFor(List<DeliveryOrder> orders, String? preferredId) {
    if (orders.isEmpty) return null;
    final current = _loaded?.currentOrder?.id;
    if (current != null && orders.any((o) => o.id == current)) return current;
    if (preferredId != null && orders.any((o) => o.id == preferredId)) {
      return preferredId;
    }
    return orders.first.id;
  }

  /// `GET /orders/current` and `GET /orders/available` don't project
  /// `deliveryVerification`, so a routine refresh always reports OTP as
  /// not-required. Never let that silently clear an OTP requirement we
  /// already learned about from reachedDrop/verifyDropOtp responses —
  /// otherwise a background refresh mid-delivery would let the driver
  /// complete the order without ever verifying it.
  DeliveryOrder _preserveOtpState(DeliveryOrder? previous, DeliveryOrder fresh) {
    if (previous == null || previous.id != fresh.id) return fresh;
    if (previous.dropOtpRequired && !fresh.dropOtpRequired) {
      return fresh.copyWith(
        dropOtpRequired: true,
        dropOtpVerified: previous.dropOtpVerified,
      );
    }
    return fresh;
  }

  /// On a fresh app start (or for an order we haven't seen yet) there's no
  /// previous copy to fall back on, so `_preserveOtpState` can't protect
  /// against `/orders/current`'s stripped `deliveryVerification`. If the
  /// order is already at the drop step in that situation, hydrate the real
  /// OTP state from `GET /orders/:orderId`, which returns the full document.
  Future<DeliveryOrder> _hydrateOtpState(
    DeliveryOrder? previous,
    DeliveryOrder fresh,
  ) async {
    if (previous != null && previous.id == fresh.id) {
      return _preserveOtpState(previous, fresh);
    }
    if (fresh.currentPhase == 'at_drop') {
      final detailsResult = await _repository.getOrderDetails(fresh.id);
      return detailsResult.when(
        success: (full) => full,
        failure: (_) => fresh,
      );
    }
    return fresh;
  }

  Future<List<DeliveryOrder>> _hydrateAll(List<DeliveryOrder> fresh) {
    final previous = _loaded;
    return Future.wait(
      fresh.map((o) => _hydrateOtpState(previous?.activeOrderById(o.id), o)),
    );
  }

  void startPolling() {
    _pollTimer?.cancel();
    refreshAll();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => refreshAll(),
    );
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Focus a different active delivery (multi-order switcher). Status
  /// actions always use the id of the order on screen, so this only changes
  /// which order the trip screen / feed card / details show.
  void selectOrder(String orderId) {
    final current = _loaded;
    if (current == null || current.activeOrderById(orderId) == null) return;
    _setLoaded(current.copyWith(selectedOrderId: () => orderId));
  }

  Future<void> refreshAll() {
    return _refreshAllInFlight ??=
        _doRefreshAll().whenComplete(() => _refreshAllInFlight = null);
  }

  Future<void> _doRefreshAll() async {
    if (state is OrdersInitial) state = const OrdersLoading();
    for (var attempt = 0; attempt < 3; attempt++) {
      final version = _mutationVersion;
      final tripResult = await _repository.getCurrentTrip();
      final CurrentTrip? trip = tripResult.when(
        success: (t) => t,
        failure: (_) => null,
      );

      // Couldn't reach /current: keep the deliveries we already know about
      // instead of wiping them on a transient network error.
      if (trip == null && (_loaded?.hasActiveOrder ?? false)) return;

      if (trip != null && trip.activeOrders.isNotEmpty) {
        final hydrated = await _hydrateAll(trip.activeOrders);
        if (version != _mutationVersion) continue;
        _setLoaded(
          OrdersLoaded(
            availableOrders: _loaded?.availableOrders ?? const [],
            activeOrders: hydrated,
            selectedOrderId: _selectionFor(hydrated, trip.activeOrder?.id),
            orderLimit: trip.orderLimit,
            canAcceptMore: trip.canAcceptMore,
          ),
        );
        return;
      }

      final availableResult = await _repository.getAvailableOrders();
      if (version != _mutationVersion) continue;
      availableResult.when(
        success: (orders) {
          final prev = _loaded;
          _setLoaded(
            OrdersLoaded(
              availableOrders: orders,
              orderLimit: trip != null ? trip.orderLimit : prev?.orderLimit,
              canAcceptMore:
                  trip != null ? trip.canAcceptMore : prev?.canAcceptMore,
            ),
          );
        },
        failure: (error) {
          if (state is! OrdersLoaded) state = OrdersError(error.message);
        },
      );
      return;
    }
  }

  Future<void> refreshAvailable() {
    return _refreshAvailableInFlight ??=
        _doRefreshAvailable().whenComplete(() => _refreshAvailableInFlight = null);
  }

  Future<void> _doRefreshAvailable() async {
    if (_loaded?.hasActiveOrder ?? false) return;
    final version = _mutationVersion;
    final result = await _repository.getAvailableOrders();
    // An accept may have landed while this was in flight — never let a
    // "no active order" snapshot overwrite the order just accepted.
    if (version != _mutationVersion) return;
    final now = _loaded;
    if (now?.hasActiveOrder ?? false) return;
    result.when(
      success: (orders) {
        _setLoaded(
          OrdersLoaded(
            availableOrders: orders,
            orderLimit: now?.orderLimit,
            canAcceptMore: now?.canAcceptMore,
          ),
        );
      },
      failure: (_) {},
    );
  }

  Future<void> refreshCurrent() {
    return _refreshCurrentInFlight ??=
        _doRefreshCurrent().whenComplete(() => _refreshCurrentInFlight = null);
  }

  Future<void> _doRefreshCurrent() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final version = _mutationVersion;
      final result = await _repository.getCurrentTrip();
      final CurrentTrip? trip = result.when(
        success: (t) => t,
        failure: (_) => null,
      );
      if (trip == null) return;
      final hydrated = await _hydrateAll(trip.activeOrders);
      if (version != _mutationVersion) continue;
      _setLoaded(
        OrdersLoaded(
          availableOrders: _loaded?.availableOrders ?? const [],
          activeOrders: hydrated,
          selectedOrderId: _selectionFor(hydrated, trip.activeOrder?.id),
          orderLimit: trip.orderLimit,
          canAcceptMore: trip.canAcceptMore,
        ),
      );
      return;
    }
  }

  Future<Result<DeliveryOrder, AppError>> acceptOrder(String orderId) async {
    final result = await _repository.accept(orderId);
    result.when(
      success: (order) {
        _mutationVersion++;
        final prev = _loaded;
        final existing = prev?.activeOrders ?? const <DeliveryOrder>[];
        final updated = <DeliveryOrder>[
          order,
          ...existing.where((o) => o.id != order.id),
        ];
        final limit = prev?.orderLimit;
        // Keep the rider focused on the delivery they were already working:
        // a second accept adds to the list, it never replaces the order on
        // screen. A first accept focuses the new order, as before.
        _setLoaded(
          OrdersLoaded(
            availableOrders: (prev?.availableOrders ?? const <DeliveryOrder>[])
                .where((o) => o.id != order.id)
                .toList(),
            activeOrders: updated,
            selectedOrderId: prev?.currentOrder?.id ?? order.id,
            orderLimit: limit,
            canAcceptMore:
                limit != null ? updated.length < limit : prev?.canAcceptMore,
          ),
        );
        // Pick up the server's view of the list and capacity.
        unawaited(refreshCurrent());
      },
      failure: (_) {},
    );
    return result;
  }

  Future<Result<DeliveryOrder, AppError>> rejectOrder(String orderId) async {
    final result = await _repository.reject(orderId);
    result.when(success: (_) => refreshAvailable(), failure: (_) {});
    return result;
  }

  Future<Result<DeliveryOrder, AppError>> reachedPickup(String orderId) =>
      _mutateOrder(orderId, () => _repository.reachedPickup(orderId));

  Future<Result<DeliveryOrder, AppError>> confirmPickup(
    String orderId, {
    String? billImageUrl,
  }) => _mutateOrder(
    orderId,
    () => _repository.confirmPickup(orderId, billImageUrl: billImageUrl),
  );

  Future<Result<DeliveryOrder, AppError>> reachedDrop(String orderId) =>
      _mutateOrder(orderId, () => _repository.reachedDrop(orderId));

  Future<Result<DeliveryOrder, AppError>> verifyDropOtp(
    String orderId,
    String otp,
  ) => _mutateOrder(orderId, () => _repository.verifyDropOtp(orderId, otp));

  Future<Result<DeliveryOrder, AppError>> completeOrder(String orderId) async {
    final completedOrder = _loaded?.activeOrderById(orderId);
    final result = await _repository.complete(orderId);
    result.when(
      success: (_) {
        _mutationVersion++;
        final now = _loaded;
        final remaining = (now?.activeOrders ?? const <DeliveryOrder>[])
            .where((o) => o.id != orderId)
            .toList();
        final focused = now?.currentOrder?.id;
        final limit = now?.orderLimit;
        // Leaving the delivered order's tracking room happens in _setLoaded.
        _setLoaded(
          OrdersLoaded(
            availableOrders: remaining.isEmpty
                ? const []
                : (now?.availableOrders ?? const []),
            activeOrders: remaining,
            // Move on to the next delivery the rider still holds, if any.
            selectedOrderId: remaining.isEmpty
                ? null
                : (focused != null &&
                        focused != orderId &&
                        remaining.any((o) => o.id == focused)
                    ? focused
                    : remaining.first.id),
            orderLimit: limit,
            canAcceptMore:
                limit != null ? remaining.length < limit : now?.canAcceptMore,
          ),
        );
        unawaited(refreshAll());
        if (completedOrder != null) {
          ref
              .read(pendingCustomerRatingControllerProvider.notifier)
              .show(completedOrder);
        }
      },
      failure: (_) {},
    );
    return result;
  }

  /// Applies a status-change response to the order it belongs to — never to
  /// whichever order happens to be focused — then re-reads the list.
  Future<Result<DeliveryOrder, AppError>> _mutateOrder(
    String orderId,
    Future<Result<DeliveryOrder, AppError>> Function() action,
  ) async {
    final result = await action();
    result.when(
      success: (order) {
        _mutationVersion++;
        final prev = _loaded;
        final existing = prev?.activeOrders ?? const <DeliveryOrder>[];
        final found = existing.any((o) => o.id == orderId);
        final updated = found
            ? [for (final o in existing) o.id == orderId ? order : o]
            : [order, ...existing];
        _setLoaded(
          OrdersLoaded(
            availableOrders: prev?.availableOrders ?? const [],
            activeOrders: updated,
            selectedOrderId: prev?.currentOrder?.id ?? order.id,
            orderLimit: prev?.orderLimit,
            canAcceptMore: prev?.canAcceptMore,
          ),
        );
        unawaited(refreshCurrent());
      },
      failure: (_) {},
    );
    return result;
  }
}

final ordersControllerProvider =
    NotifierProvider<OrdersController, OrdersState>(OrdersController.new);
