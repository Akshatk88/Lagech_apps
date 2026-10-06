import '../data/models/delivery_order.dart';

sealed class OrdersState {
  const OrdersState();
}

class OrdersInitial extends OrdersState {
  const OrdersInitial();
}

class OrdersLoading extends OrdersState {
  const OrdersLoading();
}

class OrdersLoaded extends OrdersState {
  const OrdersLoaded({
    required this.availableOrders,
    this.activeOrders = const [],
    this.selectedOrderId,
    this.orderLimit,
    this.canAcceptMore,
  });

  final List<DeliveryOrder> availableOrders;

  /// Every delivery the rider currently holds (most recently updated first).
  /// A rider may hold up to the admin's live [orderLimit] at once.
  final List<DeliveryOrder> activeOrders;

  /// The active delivery the rider is focused on — the one the trip screen,
  /// feed card and order details show. Falls back to the first active order
  /// if unset or no longer active.
  final String? selectedOrderId;

  /// Admin's live "Maximum assigned order limit" from `/orders/current`;
  /// null when the backend doesn't report it.
  final int? orderLimit;

  /// Whether the rider may take another order; null when the backend
  /// doesn't report it (then offers are shown exactly as before).
  final bool? canAcceptMore;

  /// The focused active delivery (see [selectedOrderId]).
  DeliveryOrder? get currentOrder {
    if (activeOrders.isEmpty) return null;
    if (selectedOrderId != null) {
      for (final o in activeOrders) {
        if (o.id == selectedOrderId) return o;
      }
    }
    return activeOrders.first;
  }

  bool get hasActiveOrder => activeOrders.isNotEmpty;

  bool get hasMultipleActiveOrders => activeOrders.length > 1;

  DeliveryOrder? activeOrderById(String orderId) {
    for (final o in activeOrders) {
      if (o.id == orderId) return o;
    }
    return null;
  }

  OrdersLoaded copyWith({
    List<DeliveryOrder>? availableOrders,
    List<DeliveryOrder>? activeOrders,
    String? Function()? selectedOrderId,
    int? Function()? orderLimit,
    bool? Function()? canAcceptMore,
  }) {
    return OrdersLoaded(
      availableOrders: availableOrders ?? this.availableOrders,
      activeOrders: activeOrders ?? this.activeOrders,
      selectedOrderId:
          selectedOrderId != null ? selectedOrderId() : this.selectedOrderId,
      orderLimit: orderLimit != null ? orderLimit() : this.orderLimit,
      canAcceptMore:
          canAcceptMore != null ? canAcceptMore() : this.canAcceptMore,
    );
  }

  static bool _sameOrder(DeliveryOrder a, DeliveryOrder b) =>
      a.id == b.id &&
      a.currentPhase == b.currentPhase &&
      a.orderStatus == b.orderStatus &&
      a.paymentStatus == b.paymentStatus &&
      a.dropOtpRequired == b.dropOtpRequired &&
      a.dropOtpVerified == b.dropOtpVerified;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OrdersLoaded) return false;
    if (currentOrder?.id != other.currentOrder?.id) return false;
    if (orderLimit != other.orderLimit ||
        canAcceptMore != other.canAcceptMore) {
      return false;
    }
    if (activeOrders.length != other.activeOrders.length) return false;
    for (int i = 0; i < activeOrders.length; i++) {
      if (!_sameOrder(activeOrders[i], other.activeOrders[i])) return false;
    }
    if (availableOrders.length != other.availableOrders.length) return false;
    for (int i = 0; i < availableOrders.length; i++) {
      if (availableOrders[i].id != other.availableOrders[i].id) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        currentOrder?.id,
        Object.hashAll(activeOrders.map(
          (o) => Object.hash(
            o.id,
            o.currentPhase,
            o.orderStatus,
            o.paymentStatus,
            o.dropOtpRequired,
            o.dropOtpVerified,
          ),
        )),
        orderLimit,
        canAcceptMore,
        availableOrders.length,
      );
}

class OrdersError extends OrdersState {
  const OrdersError(this.message);
  final String message;
}
