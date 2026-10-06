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
    required this.currentOrder,
  });

  final List<DeliveryOrder> availableOrders;
  final DeliveryOrder? currentOrder;

  bool get hasActiveOrder => currentOrder != null;

  OrdersLoaded copyWith({
    List<DeliveryOrder>? availableOrders,
    DeliveryOrder? Function()? currentOrder,
  }) {
    return OrdersLoaded(
      availableOrders: availableOrders ?? this.availableOrders,
      currentOrder: currentOrder != null ? currentOrder() : this.currentOrder,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OrdersLoaded) return false;
    if (currentOrder?.id != other.currentOrder?.id ||
        currentOrder?.currentPhase != other.currentOrder?.currentPhase ||
        currentOrder?.orderStatus != other.currentOrder?.orderStatus ||
        currentOrder?.paymentStatus != other.currentOrder?.paymentStatus ||
        currentOrder?.dropOtpVerified != other.currentOrder?.dropOtpVerified) {
      return false;
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
        currentOrder?.currentPhase,
        currentOrder?.orderStatus,
        currentOrder?.paymentStatus,
        currentOrder?.dropOtpVerified,
        availableOrders.length,
      );
}

class OrdersError extends OrdersState {
  const OrdersError(this.message);
  final String message;
}
