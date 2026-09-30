import 'package:flutter_test/flutter_test.dart';
import 'package:food_user_application/features/orders/domain/order_model.dart';

/// Minimal order payload in the shape the restaurant API actually returns:
/// the delivery lifecycle lives in `orderStatus`, while `dispatch.status` only ever
/// holds the assignment state (unassigned/assigned/accepted/...).
Map<String, dynamic> order({
  required String orderStatus,
  String dispatchStatus = 'accepted',
  List<Map<String, dynamic>> history = const [],
}) => {
      '_id': 'o1',
      'order_id': 'FOD-1',
      'orderStatus': orderStatus,
      'dispatch': {'status': dispatchStatus},
      'statusHistory': history,
      'createdAt': '2026-08-19T07:00:00.000Z',
      'items': <dynamic>[],
      'pricing': <String, dynamic>{},
      'payment': <String, dynamic>{},
      'deliveryAddress': <String, dynamic>{},
    };

void main() {
  group('deliveryStepIndex advances through the real lifecycle', () {
    const expected = {
      'confirmed': 0,
      'preparing': 1,
      'ready_for_pickup': 2,
      // Rider is at the restaurant but has not taken the food: still "Ready".
      'reached_pickup': 2,
      'picked_up': 3,
      'reached_drop': 3,
      'delivered': 4,
      'completed': 4,
    };

    expected.forEach((status, step) {
      test('$status -> step $step', () {
        expect(OrderModel.fromJson(order(orderStatus: status)).deliveryStepIndex, step);
      });
    });
  });

  test('picked_up does not depend on dispatch.status (the original bug)', () {
    // dispatch.status is stuck at 'accepted' for the whole delivery — its schema
    // enum has no 'picked_up'. The timeline previously read step 0 here.
    final o = OrderModel.fromJson(
      order(orderStatus: 'picked_up', dispatchStatus: 'accepted'),
    );
    expect(o.deliveryStepIndex, 3);
    expect(o.isPickedUp, isTrue);
    expect(o.isDelivered, isFalse);
  });

  test('never regresses to 0 mid-delivery', () {
    for (final status in ['picked_up', 'reached_drop', 'delivered']) {
      expect(
        OrderModel.fromJson(order(orderStatus: status)).deliveryStepIndex,
        greaterThan(2),
        reason: '$status must not collapse the timeline',
      );
    }
  });

  test('earlier steps stay done once passed', () {
    final o = OrderModel.fromJson(order(orderStatus: 'delivered'));
    expect(o.deliveryStepIndex, 4); // all five steps render as complete
  });

  test('unknown or cancelled status does not read as past every milestone', () {
    expect(OrderModel.fromJson(order(orderStatus: 'cancelled_by_user')).deliveryStepIndex, 0);
    expect(OrderModel.fromJson(order(orderStatus: 'something_new')).deliveryStepIndex, 0);
  });

  test('statusHistory supplies a real time per step', () {
    final o = OrderModel.fromJson(order(
      orderStatus: 'delivered',
      history: [
        {'to': 'preparing', 'at': '2026-08-19T07:01:00.000Z'},
        {'to': 'ready_for_pickup', 'at': '2026-08-19T07:10:00.000Z'},
        {'to': 'picked_up', 'at': '2026-08-19T07:15:00.000Z'},
        {'to': 'delivered', 'at': '2026-08-19T07:40:00.000Z'},
      ],
    ));
    expect(o.pickedUpAt!.toUtc().minute, 15);
    expect(o.deliveredAt!.toUtc().minute, 40);
    expect(o.statusTimes['ready_for_pickup']!.toUtc().minute, 10);
  });

  test('history alone marks a milestone reached', () {
    // reached_drop is current; picked_up already happened and must still count.
    final o = OrderModel.fromJson(order(
      orderStatus: 'reached_drop',
      history: [
        {'to': 'picked_up', 'at': '2026-08-19T07:15:00.000Z'}
      ],
    ));
    expect(o.isPickedUp, isTrue);
    expect(o.pickedUpAt, isNotNull);
  });
}
