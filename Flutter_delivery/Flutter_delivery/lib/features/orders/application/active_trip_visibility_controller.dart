import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/orders/application/orders_controller.dart';
import 'package:food_user_application/features/orders/application/orders_state.dart';

/// Tracks whether the full-screen active-trip overlay should be shown on top
/// of whatever route is currently active. Defaults to visible whenever a new
/// order id comes into focus or another delivery is added (second accept),
/// so a minimized trip re-maximizes automatically when new work arrives.
class ActiveTripVisibilityController extends Notifier<bool> {
  String? _lastOrderId;
  int _lastActiveCount = 0;

  @override
  bool build() {
    ref.listen<OrdersState>(ordersControllerProvider, (previous, next) {
      final nextId = next is OrdersLoaded ? next.currentOrder?.id : null;
      final nextCount = next is OrdersLoaded ? next.activeOrders.length : 0;
      final added = nextCount > _lastActiveCount;
      if (nextId != _lastOrderId || added) {
        _lastOrderId = nextId;
        if (nextId != null) state = true;
      }
      _lastActiveCount = nextCount;
    });
    final current = ref.read(ordersControllerProvider);
    _lastOrderId = current is OrdersLoaded ? current.currentOrder?.id : null;
    _lastActiveCount =
        current is OrdersLoaded ? current.activeOrders.length : 0;
    return true;
  }

  void show() => state = true;
  void hide() => state = false;
}

final activeTripVisibilityControllerProvider =
    NotifierProvider<ActiveTripVisibilityController, bool>(
  ActiveTripVisibilityController.new,
);
