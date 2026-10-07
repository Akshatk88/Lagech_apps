import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/config/router/app_router.dart';
import 'package:food_user_application/core/services/local_notification_service.dart';
import 'package:food_user_application/core/services/new_order_action_channel.dart';
import 'package:food_user_application/features/business_settings/data/business_settings_repository.dart';
import 'package:food_user_application/features/orders/presentation/controllers/live_orders_controller.dart';
import 'package:food_user_application/features/orders/presentation/views/incoming_order_dialog.dart';

/// Central service responsible for handling new incoming order alerts
/// across all transports (Socket.IO, FCM push, or order polling).
///
/// Ensures:
/// 1. Instant heads-up system notification outside the app with Accept/Reject actions.
/// 2. Loud looping ringtone alarm that rings until accepted or rejected.
/// 3. In-app incoming order dialog popup when app is open.
/// 4. Deduplication so that simultaneous Socket and FCM events don't double-alert.
class OrderAlertService {
  OrderAlertService(this._ref);

  final Ref _ref;
  final Map<String, DateTime> _recentAlerts = {};
  String? _currentlyRingingOrderId;

  String? get currentlyRingingOrderId => _currentlyRingingOrderId;

  static const _validNewOrderTypes = {
  'new_order',
  'order_created',
  'order_placed',
  'order_received',
  'neworder',
  'new_order_available',
};

/// Handles an incoming order alert from Socket.IO, FCM, or polling.
  Future<void> handleNewOrder(Map<String, dynamic> rawData) async {
    final type = (rawData['type'] ?? rawData['eventType'] ?? rawData['event'])?.toString().toLowerCase().trim();
    if (type != null && type.isNotEmpty && !_validNewOrderTypes.contains(type)) {
      if (kDebugMode) {
        debugPrint('[OrderAlertService] Skipped: non-new-order type $type');
      }
      return;
    }

    // A scheduled order is held until its release time (~40 min before the
    // slot); the server only alerts from then on. Never ring for one early.
    if (_isHeldScheduledOrder(rawData)) {
      if (kDebugMode) {
        debugPrint('[OrderAlertService] Skipped: scheduled order not released yet');
      }
      return;
    }

    final allIds = _extractAllOrderIds(rawData);
    if (allIds.isEmpty) {
      if (kDebugMode) {
        debugPrint('[OrderAlertService] Skipped: no valid orderId in $rawData');
      }
      return;
    }

    // Deduplicate: if ANY candidate ID was alerted in the last 30 seconds, ignore duplicate event
    final now = DateTime.now();
    final isDuplicate = allIds.any((id) {
      final lastAlert = _recentAlerts[id];
      return lastAlert != null && now.difference(lastAlert).inSeconds < 30;
    });

    if (isDuplicate) {
      if (kDebugMode) {
        debugPrint('[OrderAlertService] Deduplicated alert for order IDs: $allIds');
      }
      return;
    }

    for (final id in allIds) {
      _recentAlerts[id] = now;
    }
    _cleanOldAlerts();

    final orderId = allIds.first;
    _currentlyRingingOrderId = orderId;
    if (kDebugMode) {
      debugPrint('[OrderAlertService] Triggering new order alert for: $orderId (aliases: $allIds)');
    }

    final stringData = <String, String>{};
    rawData.forEach((k, v) {
      if (v != null) stringData[k] = v.toString();
    });
    stringData['orderId'] = orderId;
    stringData['type'] = 'new_order';

    // The socket payload carries the earning inside `finance`; the native alert
    // reads the flat `restaurantEarning` key, as on the FCM push.
    final finance = rawData['finance'];
    if ((stringData['restaurantEarning'] ?? '').isEmpty && finance is Map) {
      final netPayout = finance['netPayout'];
      if (netPayout != null) stringData['restaurantEarning'] = '$netPayout';
    }

    // "Confirmed by deliveryman": a delivery order arrives already confirmed,
    // so there is nothing to accept or reject — a plain alert, and the in-app
    // dialog offers "Start preparing" instead.
    final arrivesConfirmed = _arrivesConfirmed(rawData);

    final title = stringData['title']?.isNotEmpty == true
        ? stringData['title']!
        : 'New Order Received!';
    final customerName = stringData['customerName'];
    final earning = stringData['restaurantEarning'];
    final total = stringData['total'] ?? stringData['amount'];
    final body = stringData['body']?.isNotEmpty == true
        ? stringData['body']!
        : [
            if (customerName != null && customerName.isNotEmpty) 'Customer: $customerName',
            if (earning != null && earning.isNotEmpty)
              'You earn: Rs.$earning'
            else if (total != null && total.isNotEmpty)
              'Total: Rs.$total',
            arrivesConfirmed
                ? 'Confirmed — tap to start preparing'
                : 'Tap or choose Accept/Reject',
          ].join(' · ');

    stringData['title'] = title;
    stringData['body'] = body;

    // 1. Show real system notification outside app and start alarm sound
    if (arrivesConfirmed) {
      // No Accept/Reject actions and no alarm that only an answer stops.
      await LocalNotificationService.instance.show(
        title: title,
        body: body,
        payload: '{"type":"new_order","orderId":"$orderId"}',
      );
    } else if (Platform.isAndroid) {
      try {
        await NewOrderActionChannel.showAlert(stringData);
      } catch (_) {
        await LocalNotificationService.instance.show(
          title: title,
          body: body,
          payload: '{"type":"new_order","orderId":"$orderId"}',
          isNewOrder: true,
          fullScreenIntent: true,
        );
        await NewOrderActionChannel.startSound(orderId, ringMillis: 60000);
      }
    } else {
      await LocalNotificationService.instance.show(
        title: title,
        body: body,
        payload: '{"type":"new_order","orderId":"$orderId"}',
        isNewOrder: true,
        fullScreenIntent: true,
      );
      await NewOrderActionChannel.startSound(orderId, ringMillis: 60000);
    }

    // 3. Refresh live orders list immediately
    try {
      unawaited(_ref.read(liveOrdersControllerProvider.notifier).refresh());
    } catch (_) {}

    // 4. If in foreground, pop up the in-app incoming order dialog
    final context = rootNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      unawaited(showIncomingOrderDialog(context, orderId: orderId));
    }
  }

  /// Stop ringing sound and dismiss system notification for an order.
  Future<void> stopAlert([String? orderId]) async {
    _currentlyRingingOrderId = null;
    await NewOrderActionChannel.stopSound();
    if (orderId != null && orderId.isNotEmpty) {
      await NewOrderActionChannel.dismiss(orderId);
    }
  }

  /// True when Business Settings have delivery orders confirmed by the
  /// deliveryman and this is a delivery order (takeaway orders still wait for
  /// the restaurant). Reads `orderStatus` when the payload carries it (the
  /// socket event sends the whole order), otherwise `orderType` (the push).
  ///
  /// The push's `needsAcceptance` ("true"/"false") is the server's own answer
  /// and wins when present; without it (older server, socket event) this falls
  /// back to the settings + status/type check.
  bool _arrivesConfirmed(Map<String, dynamic> data) {
    final needsAcceptance =
        data['needsAcceptance']?.toString().trim().toLowerCase();
    if (needsAcceptance == 'false') return true;
    if (needsAcceptance == 'true') return false;
    final settings = _ref.read(restaurantBusinessSettingsProvider).value;
    if (settings == null || !settings.confirmedByDeliveryman) return false;
    Map<String, dynamic>? asMap(dynamic val) {
      if (val is Map) return Map<String, dynamic>.from(val);
      if (val is String && val.trim().startsWith('{')) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
      return null;
    }

    String? status;
    String? type;
    for (final map in [data, asMap(data['order']), asMap(data['data'])]) {
      final s = map?['orderStatus']?.toString().trim().toLowerCase();
      final t = map?['orderType']?.toString().trim().toLowerCase();
      if (status == null && s != null && s.isNotEmpty) status = s;
      if (type == null && t != null && t.isNotEmpty) type = t;
    }
    if (type == 'takeaway') return false;
    return status == null || status == 'confirmed';
  }

  /// True when the payload (or its nested `order`/`data` map) carries a
  /// `releaseAt` that is still clearly in the future.
  bool _isHeldScheduledOrder(Map<String, dynamic> data) {
    Map<String, dynamic>? asMap(dynamic val) {
      if (val is Map) return Map<String, dynamic>.from(val);
      if (val is String && val.trim().startsWith('{')) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
      return null;
    }

    // A little slack for a device clock running behind the server's, so the
    // push sent right at release time is never mistaken for an early one.
    final now = DateTime.now().add(const Duration(minutes: 2));
    for (final map in [data, asMap(data['order']), asMap(data['data'])]) {
      final releaseAt = DateTime.tryParse((map?['releaseAt'] ?? '').toString());
      if (releaseAt != null && releaseAt.isAfter(now)) return true;
    }
    return false;
  }

  void _cleanOldAlerts() {
    final threshold = DateTime.now().subtract(const Duration(minutes: 5));
    _recentAlerts.removeWhere((_, time) => time.isBefore(threshold));
  }

  Set<String> _extractAllOrderIds(Map<String, dynamic> data) {
    Map<String, dynamic>? tryParseMap(dynamic val) {
      if (val is Map) return Map<String, dynamic>.from(val);
      if (val is String && val.trim().startsWith('{') && val.trim().endsWith('}')) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
      return null;
    }

    final orderMap = tryParseMap(data['order']);
    final dataMap = tryParseMap(data['data']);

    final candidates = [
      data['orderMongoId'],
      data['orderId'],
      data['order_id'],
      data['_id'],
      data['id'],
      data['orderDisplayId'],
      data['orderNumber'],
      data['order_number'],
      if (orderMap != null) ...[
        orderMap['_id'],
        orderMap['id'],
        orderMap['orderId'],
        orderMap['order_id'],
        orderMap['orderMongoId'],
        orderMap['orderDisplayId'],
        orderMap['orderNumber'],
      ],
      if (dataMap != null) ...[
        dataMap['_id'],
        dataMap['id'],
        dataMap['orderId'],
        dataMap['order_id'],
        dataMap['orderMongoId'],
        dataMap['orderDisplayId'],
        dataMap['orderNumber'],
      ],
    ];

    final ids = <String>{};
    for (final c in candidates) {
      final s = c?.toString().trim();
      if (s != null && s.isNotEmpty) ids.add(s);
    }
    return ids;
  }
}

final orderAlertServiceProvider = Provider<OrderAlertService>((ref) {
  return OrderAlertService(ref);
});
