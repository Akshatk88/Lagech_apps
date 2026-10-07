import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/constants/app_constants.dart';
import 'package:food_user_application/config/router/app_router.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/core/services/local_notification_service.dart';
import 'package:food_user_application/core/services/order_alert_service.dart';
import 'package:food_user_application/core/services/order_notification_action_handler.dart';
import 'package:food_user_application/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:food_user_application/features/orders/presentation/controllers/live_orders_controller.dart';
import 'package:permission_handler/permission_handler.dart';

const _kNewOrderEventTypes = {
  'new_order',
  'order_created',
  'order_placed',
  'order_received',
  'neworder',
  'new_order_available',
};

const _kOrderNotificationTypes = {
  'new_order',
  'order_status_update',
  'order_cancelled',
  'cancel_order',
  'order_accepted',
  'order_rejected',
};

String _encodeTapPayload({String? type, String? orderId}) =>
    jsonEncode({'type': type, 'orderId': orderId});

Map<String, dynamic>? _decodeTapPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final decoded = jsonDecode(payload);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

String? _orderIdFromData(Map<String, dynamic> data) {
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

  for (final c in candidates) {
    final s = c?.toString().trim();
    if (s != null && s.isNotEmpty) return s;
  }
  return null;
}

String? _nonEmpty(Object? value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}

/// Body text for a new-order notification, composed from the data map when the
/// server did not send a ready-made one.
///
/// A data-only push has no `notification` block, so `message.notification` is
/// null and the only text available is whatever sits in `data`. Falling back to
/// an empty string there produced a notification with a title and no content —
/// which reads as a broken push rather than a missing field. The order details
/// are always present in `data`, so build the text from them instead of
/// depending on the server to pre-format it.
String buildOrderNotificationBody(Map<String, dynamic> data) {
  final provided = _nonEmpty(data['body']);
  if (provided != null) return provided;

  final lines = <String>[];
  final items = _nonEmpty(data['itemsList']);
  // The restaurant's earning after commission; the customer's total only from
  // an older server that does not send it.
  final earning = _nonEmpty(data['restaurantEarning']);
  final total = _nonEmpty(data['total']);
  final customer = _nonEmpty(data['customerName']);
  final address = _nonEmpty(data['address']);
  final payment = _nonEmpty(data['paymentMethod']);

  if (items != null) lines.add(items);
  final amount = earning != null
      ? 'You earn: Rs.$earning'
      : total != null
      ? 'Total: Rs.$total'
      : null;
  if (amount != null) {
    lines.add(payment != null ? '$amount  ·  $payment' : amount);
  }
  if (customer != null) lines.add(customer);
  if (address != null) lines.add(address);

  // Last resort: an order reference beats a blank notification.
  if (lines.isEmpty) {
    final ref = _nonEmpty(data['orderDisplayId']) ?? _nonEmpty(data['orderId']);
    if (ref != null) lines.add('Order #$ref is waiting for review.');
  }
  return lines.join('\n');
}

/// Must stay top-level (not a class method) — Firebase invokes this in a
/// separate background isolate that has no access to app state, so it needs
/// its own Firebase configuration before touching any Firebase API.
///
/// `new_order` pushes to the restaurant are sent `dataOnly` (no
/// `notification` block) precisely so the OS never auto-displays a plain
/// alert here — that path can't carry the Accept/Reject action buttons. This
/// handler builds that local notification itself instead. Other push types
/// still include a `notification` block and are shown by the OS as before,
/// so nothing else needs to happen here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      if (Platform.isAndroid) {
        await Firebase.initializeApp();
      } else {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: AppConstants.firbaseApiKey,
            appId: AppConstants.firebaseAppId,
            messagingSenderId: AppConstants.firebasemessagingSenderId,
            projectId: AppConstants.firebaseProjectId,
          ),
        );
      }
    }
  } catch (_) {
    // Best-effort — the OS-rendered notification doesn't depend on this.
  }

  if (kDebugMode) {
    debugPrint('[FCM background] push received: data=${message.data}, notification=${message.notification?.title}');
  }

  final rawType = (message.data['type'] ?? message.data['eventType'] ?? message.data['event'])?.toString().toLowerCase().trim();
  final orderId = _orderIdFromData(message.data);
  final isNewOrder = _kNewOrderEventTypes.contains(rawType);

  if (!isNewOrder) {
    if (kDebugMode) {
      debugPrint('[FCM background] processing non-new_order push: type=$rawType, orderId=$orderId');
    }
    try {
      await LocalNotificationService.instance.initialize(
        onResponse: (_) {},
        requestPermission: false,
      );
      final title = _nonEmpty(message.notification?.title) ??
          _nonEmpty(message.data['title']) ??
          'Lagech Restaurant Alert';
      final body = _nonEmpty(message.notification?.body) ??
          _nonEmpty(message.data['body']) ??
          'You have a new update';

      await LocalNotificationService.instance.show(
        title: title,
        body: body,
        payload: _encodeTapPayload(type: rawType, orderId: orderId),
        isNewOrder: false,
        fullScreenIntent: false,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM background] non-new_order handling threw: $e');
      }
    }
    return;
  }

  // On Android the native NewOrderMessagingService already put up the overlay
  // or its own Accept/Reject notification (with a fallback of its own). The
  // plugin's receiver still wakes this isolate for the same push, and a second
  // alert here lingered after the order was answered on the overlay.
  if (Platform.isAndroid) {
    if (kDebugMode) {
      debugPrint('[FCM background] new_order $orderId handled natively — skipping');
    }
    // The plain OS copy from the push's notification leg is still removed: the
    // native alert replaces it, exactly as this handler's own alert used to.
    try {
      await LocalNotificationService.instance.initialize(
        onResponse: (_) {},
        requestPermission: false,
      );
      await cancelFcmTrayCopy(orderId);
    } catch (_) {
      // Worst case the plain copy stays — a duplicate, not a missed order.
    }
    return;
  }

  if (kDebugMode) {
    debugPrint('[FCM background] new_order push processing for orderId: $orderId');
  }

  try {
    // Fresh isolate — this instance hasn't been initialized yet. The
    // `onResponse` callback given here only fires for the plain-tap case
    // (never for the Accept/Reject actions, which always route through
    // `notificationBackgroundResponseHandler` regardless of app state), and
    // this isolate is torn down right after this function returns, so there
    // is nothing useful to do with a tap here.
    // requestPermission: false — no Activity exists in this isolate, and asking
    // there can throw and abort the whole handler before show() runs.
    await LocalNotificationService.instance.initialize(
      onResponse: (_) {},
      requestPermission: false,
    );
    // Already confirmed by the delivery partner: a plain alert, without the
    // Accept/Reject actions and the ringing new-order sound. Missing = "true".
    final needsAcceptance =
        message.data['needsAcceptance']?.toString().trim().toLowerCase() != 'false';
    final shown = await LocalNotificationService.instance.show(
      title: _nonEmpty(message.notification?.title) ?? _nonEmpty(message.data['title']) ?? 'New order received',
      body: _nonEmpty(message.notification?.body) ?? buildOrderNotificationBody(message.data),
      payload: _encodeTapPayload(type: 'new_order', orderId: orderId),
      isNewOrder: needsAcceptance,
      fullScreenIntent: needsAcceptance,
    );

    if (kDebugMode) {
      debugPrint(
        '[FCM background] LocalNotificationService.show() returned $shown',
      );
    }

    // Only take down the OS-rendered copy once ours is provably on screen.
    // Ordering alone was not enough: show() used to report success even when it
    // had failed or was never initialized, so this ran anyway and removed the
    // only alert left. The tag is set by the backend and the two must agree.
    if (shown) await cancelFcmTrayCopy(orderId);
  } catch (e) {
    // Deliberately leaves the OS tray copy in place — it is the only thing
    // left telling the restaurant an order arrived.
    if (kDebugMode) {
      debugPrint('[FCM background] new_order handling threw: $e');
    }
  }
}

/// Removes the OS-rendered copy of the new-order push.
///
/// The push is hybrid: FCM posts a tray notification itself, tagged
/// `order_<id>` by the backend, so ROMs that refuse to start the app in the
/// background still alert the restaurant. Wherever the app's own alert does
/// show, this takes the tray copy down so only one is visible. FCM posts
/// tagged notifications under id 0.
Future<void> cancelFcmTrayCopy(String? orderId) async {
  if (orderId == null || orderId.isEmpty) return;
  try {
    await FlutterLocalNotificationsPlugin().cancel(0, tag: 'order_$orderId');
  } catch (_) {
    // Worst case the tray copy stays — a duplicate, not a missed order.
  }
}

/// Wraps device push-token registration against the two endpoints the
/// backend exposes for restaurant partners: `/fcm-tokens/mobile/save` and
/// `/fcm-tokens/remove`. Token saves are best-effort — a failure here should
/// never block login or app startup.
class FcmService {
  FcmService(this._dio, this._ref);

  final Dio _dio;
  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _foregroundHandlingWired = false;

  Future<void> requestPermission() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (_) {
      // Permission prompt failing (e.g. unsupported platform) shouldn't crash startup.
    }
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      }
    } catch (_) {}
  }

  /// Why the last registration attempt failed, for the diagnostics screen.
  static String? lastRegistrationError;

  Future<String?> currentToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        lastRegistrationError = 'FCM returned no token for this device';
      }
      return token;
    } catch (e) {
      lastRegistrationError = 'FCM getToken failed: $e';
      if (kDebugMode) debugPrint('[FCM] getToken failed: $e');
      return null;
    }
  }

  Future<bool> saveTokenToServer() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(seconds: attempt * 2));
      }

      final token = await currentToken();
      if (token == null || token.isEmpty) continue;

      try {
        await _dio.post(
          '/fcm-tokens/mobile/save',
          data: {'token': token, 'platform': 'mobile'},
        );
        lastRegistrationError = null;
        if (kDebugMode) debugPrint('[FCM] token registered successfully: $token');
        return true;
      } catch (e) {
        lastRegistrationError = 'Token save failed: $e';
        if (kDebugMode) {
          debugPrint('[FCM] save attempt ${attempt + 1} failed: $e');
        }
      }
    }
    return false;
  }

  Future<void> removeTokenFromServer() async {
    final token = await currentToken();
    if (token == null || token.isEmpty) return;
    try {
      await _dio.delete(
        '/fcm-tokens/remove',
        data: {'token': token, 'platform': 'mobile'},
      );
    } catch (_) {
      // Best-effort — logging out should proceed regardless.
    }
  }

  void listenForTokenRefresh(void Function() onRefresh) {
    _messaging.onTokenRefresh.listen((_) => onRefresh());
  }

  /// Sets up everything needed for a push to actually be *visible*
  Future<void> initForegroundHandling() async {
    if (_foregroundHandlingWired) return;
    _foregroundHandlingWired = true;

    await requestPermission();

    await LocalNotificationService.instance.initialize(
      onResponse: _handleNotificationResponse,
    );

    // The OS can rotate the FCM token at any time (rare, but it happens) —
    // keep the backend's copy in sync or pushes silently stop working.
    listenForTokenRefresh(saveTokenToServer);

    // Explicitly save the token on initialization in case it wasn't saved yet
    await saveTokenToServer();

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      final type = (message.data['type'] ?? message.data['eventType'] ?? message.data['event'])?.toString().toLowerCase().trim();
      final orderId = _orderIdFromData(message.data);
      final isNewOrder = _kNewOrderEventTypes.contains(type);

      if (kDebugMode) {
        debugPrint('[FCM onMessage] received: data=${message.data}, notification=${notification?.title}, isNewOrder=$isNewOrder');
      }

      if (isNewOrder) {
        final orderData = Map<String, dynamic>.from(message.data);
        if (!orderData.containsKey('title') && notification?.title != null) {
          orderData['title'] = notification!.title;
        }
        if (!orderData.containsKey('body') && notification?.body != null) {
          orderData['body'] = notification!.body;
        }
        if (orderId != null && !orderData.containsKey('orderId')) {
          orderData['orderId'] = orderId;
        }
        _ref.read(orderAlertServiceProvider).handleNewOrder(orderData);
        return;
      }

      final orderStatus = (message.data['orderStatus'] ?? message.data['status'])?.toString().toLowerCase();
      if (type == 'order_cancelled' ||
          type == 'cancel_order' ||
          type == 'order_rejected' ||
          type?.contains('cancel') == true ||
          orderStatus?.contains('cancel') == true ||
          orderStatus?.contains('reject') == true) {
        _ref.read(orderAlertServiceProvider).stopAlert(orderId);
      }

      final title =
          _nonEmpty(notification?.title) ??
          _nonEmpty(message.data['title']) ??
          'Lagech Restaurant';
      final body =
          _nonEmpty(notification?.body) ??
          _nonEmpty(message.data['body']) ??
          '';

      LocalNotificationService.instance.show(
        title: title,
        body: body,
        payload: _encodeTapPayload(type: type, orderId: orderId),
        isNewOrder: false,
        fullScreenIntent: false,
      );

      if (_kOrderNotificationTypes.contains(type)) {
        _ref.read(liveOrdersControllerProvider.notifier).refresh();
      } else {
        _ref.read(notificationsControllerProvider.notifier).refresh();
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _navigateForType(
        message.data['type']?.toString(),
        _orderIdFromData(message.data),
      );
    });

    // Accept launches the app, so when it was TERMINATED the button press arrives
    // here rather than at onResponse — flutter_local_notifications delivers the
    // launching interaction through getNotificationAppLaunchDetails, not the live
    // callback. Without this the app simply opened and the order was never
    // accepted.
    final launchDetails = await LocalNotificationService.instance
        .launchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if ((launchDetails?.didNotificationLaunchApp ?? false) &&
        launchResponse != null) {
      _handleNotificationResponse(launchResponse);
    }

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      final type = initialMessage.data['type']?.toString();
      final orderId = _orderIdFromData(initialMessage.data);
      // This runs inside the same login/session-restore chain that the
      // splash screen awaits before doing its own default `go('/orders')` —
      // deferring a beat lets our deep link win that race instead of being
      // immediately overwritten.
      Future.delayed(const Duration(milliseconds: 400), () {
        _navigateForType(type, orderId);
      });
    }
  }

  /// Routes an Accept/Reject action button or a plain notification tap.
  ///
  /// Shared by the live-tap callback and the cold-start path, because which of the
  /// two fires depends only on whether the app happened to be running — and both
  /// have to perform the action, not merely open the order.
  ///
  /// The action is delegated to [notificationBackgroundResponseHandler] so there is
  /// exactly one implementation: it is self-contained (reads the token from secure
  /// storage, uses its own Dio) and behaves identically in either isolate.
  void _handleNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId;
    final isAccept = actionId == orderAcceptActionId;
    final isReject = actionId == orderRejectActionId;

    if (isAccept || isReject) {
      unawaited(
        notificationBackgroundResponseHandler(response).then((_) {
          // The order list is stale the moment the status changes.
          _ref.read(liveOrdersControllerProvider.notifier).refresh();

          // Accept opens the app, so land on the order just taken on. Reject
          // stays put — there is nothing left to look at.
          if (isAccept) {
            final decoded = _decodeTapPayload(response.payload);
            _navigateForType('new_order', decoded?['orderId'] as String?);
          }
        }),
      );
      return;
    }

    final decoded = _decodeTapPayload(response.payload);
    _navigateForType(
      decoded?['type'] as String?,
      decoded?['orderId'] as String?,
    );
  }

  void _navigateForType(String? type, String? orderId) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    if (_kOrderNotificationTypes.contains(type)) {
      if (orderId != null && orderId.isNotEmpty) {
        GoRouter.of(context).push('/order-details/$orderId');
      } else {
        GoRouter.of(context).go('/orders');
      }
    } else {
      GoRouter.of(context).go('/notifications');
    }
  }
}

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(ref.watch(dioProvider), ref);
});
