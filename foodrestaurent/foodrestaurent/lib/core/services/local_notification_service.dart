import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:food_user_application/core/services/order_notification_action_handler.dart';

/// Displays a system notification for FCM messages that arrive while the
/// app is in the foreground — Android/iOS never auto-display those (only
/// background/terminated pushes with a `notification` block do), so without
/// this the restaurant would never see a "new order" alert while the app is
/// open.
///
/// Every channel the backend can name must be created here. Android silently
/// ignores an unknown channel id and falls back to a low-importance default, so
/// a mismatch looks exactly like the push never arriving. The backend uses
/// `high_importance_channel` for ordinary alerts (FCM_DEFAULT_CHANNEL_ID) and
/// omits the channel entirely for data-only new-order pushes, where the app
/// picks its own — see `Backend/src/core/notifications/firebase.service.js`.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _defaultChannel = AndroidNotificationChannel(
    'default',
    'General notifications',
    description: 'Order updates and general alerts from Fodron Restaurant.',
    importance: Importance.high,
  );

  /// The backend's FCM_DEFAULT_CHANNEL_ID. Order status updates arrive WITH a
  /// notification block, so the OS renders them against this id directly — and
  /// the app previously never created it, leaving those alerts on Android's
  /// fallback channel with no heads-up display.
  static const _highImportanceChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'Order updates',
    description: 'Order status updates and alerts from Fodron Restaurant.',
    importance: Importance.max,
  );

  static final _newOrderChannel = AndroidNotificationChannel(
    'new_order_channel_v3',
    'Order Alerts',
    description: 'High priority alerts for new orders with ringing sound.',
    importance: Importance.max,
    sound: const RawResourceAndroidNotificationSound('tujh_bin'),
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 500, 250, 500, 250, 500]),
  );

  /// Backend explicitly sets androidChannelId: "new_order_channel" in FCM payload.
  static final _backendNewOrderChannel = AndroidNotificationChannel(
    'new_order_channel',
    'New Order Notifications',
    description: 'High priority alerts for new orders with ringing sound.',
    importance: Importance.max,
    sound: const RawResourceAndroidNotificationSound('tujh_bin'),
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 500, 250, 500, 250, 500]),
  );

  /// Channel used by native Kotlin NewOrderNotifier (bumped to v5 — USAGE_ALARM)
  static final _nativeNewOrderChannel = AndroidNotificationChannel(
    'new_order_ringing_v5',
    'New Order Ringing Alerts',
    description: 'High priority alarm alerts for incoming restaurant orders.',
    importance: Importance.max,
    sound: const RawResourceAndroidNotificationSound('tujh_bin'),
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 500, 250, 500, 250, 500]),
  );

  // Accept opens the app: the restaurant has just taken the order and needs to
  // start preparing it, so landing them on the order is the point. Launching also
  // means the tap is delivered to the app's own (main-isolate) response handler.
  static const _acceptOrderAction = AndroidNotificationAction(
    orderAcceptActionId,
    'Accept',
    showsUserInterface: true,
    cancelNotification: true,
  );

  // Reject deliberately does NOT launch the app — declining an order should not
  // drag the restaurant out of whatever they were doing. With
  // `showsUserInterface: false` the OS routes it to
  // `onDidReceiveBackgroundNotificationResponse` when nothing is running, and to
  // the normal response handler when the app is already alive.
  //
  static const _rejectOrderAction = AndroidNotificationAction(
    orderRejectActionId,
    'Reject',
    showsUserInterface: false,
    cancelNotification: true,
  );

  /// [requestPermission] must be false when called from a background isolate.
  ///
  /// There is no Activity there, so asking for the notification permission can
  /// throw or hang — and since the background handler wraps this whole call in a
  /// try/catch, a throw here meant initialization never completed, show() was
  /// never reached, and the failure was swallowed silently. That is what made
  /// new-order notifications vanish whenever the app was closed. The permission
  /// is a startup concern anyway: by the time a push arrives it has already been
  /// granted or denied.
  void Function(NotificationResponse response)? _onResponseCallback;

  Future<void> initialize({
    required void Function(NotificationResponse response) onResponse,
    bool requestPermission = true,
  }) async {
    _onResponseCallback = onResponse;
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        _onResponseCallback?.call(response);
      },
      onDidReceiveBackgroundNotificationResponse:
          notificationBackgroundResponseHandler,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_defaultChannel);
    await androidPlugin?.createNotificationChannel(_highImportanceChannel);
    await androidPlugin?.createNotificationChannel(_newOrderChannel);
    await androidPlugin?.createNotificationChannel(_backendNewOrderChannel);
    await androidPlugin?.createNotificationChannel(_nativeNewOrderChannel);

    // Set once the plugin and channels really exist, and BEFORE the permission
    // request below — that request is optional and must never be able to leave
    // the service permanently uninitialized.
    _initialized = true;

    if (requestPermission) {
      try {
        await androidPlugin?.requestNotificationsPermission();

        // Android 14+ revokes USE_FULL_SCREEN_INTENT by default for apps that are
        // not phone/alarm apps, even with the manifest entry — so a full-screen
        // alert silently downgrades to an ordinary heads-up banner without this
        // explicit grant. No-op on older versions or once already granted.
        await androidPlugin?.requestFullScreenIntentPermission();
      } catch (e) {
        // Never fatal: a denied or unavailable prompt must not stop us posting
        // notifications the user has already allowed.
        if (kDebugMode) debugPrint('requestNotificationsPermission failed: $e');
      }
    }
  }

  /// The interaction that launched the app, if any.
  ///
  /// An Accept press on a terminated app is delivered here rather than through the
  /// live response callback, so the caller must check it or the action is lost.
  Future<NotificationAppLaunchDetails?> launchDetails() =>
      _plugin.getNotificationAppLaunchDetails();

  /// Returns true only if the notification is actually on screen.
  ///
  /// This used to return void and swallow everything, so a failure was
  /// indistinguishable from success. Callers use the result to decide whether to
  /// take down the OS-rendered copy of the same push — and told it had worked
  /// when it had not, they removed the only alert the restaurant had left. In a
  /// release build the swallowed exception is not even printed, which is why
  /// this looked like "works in debug, silent in the APK".
  Future<bool> show({
    required String title,
    required String body,
    String? payload,
    bool isNewOrder = false,
    // Only meaningful when [isNewOrder] is true. A full-screen intent tells
    // Android to launch a full-screen Activity over whatever is currently
    // showing — appropriate when the app is backgrounded/terminated and the
    // screen may be locked, but firing it while the app is already open
    // races the OS's own full-screen takeover against the in-app "new order"
    // dialog this same event triggers, which is what was hanging the app
    // (and sometimes the whole phone) the instant an order came in while the
    // restaurant already had the app open. Foreground callers pass `false`.
    bool fullScreenIntent = true,
  }) async {
    if (!_initialized) {
      if (kDebugMode) {
        debugPrint('[LocalNotification] show() skipped — not initialized');
      }
      return false;
    }

    final channel = isNewOrder ? _backendNewOrderChannel : _defaultChannel;
    final useFullScreen = isNewOrder && fullScreenIntent;

    if (kDebugMode && isNewOrder) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final enabled = await androidPlugin?.areNotificationsEnabled();
      debugPrint(
        '[LocalNotification] about to show new_order notification — '
        'channel: ${channel.id}, sound: tujh_bin, '
        'actions: [Accept($orderAcceptActionId), Reject($orderRejectActionId)], '
        'notificationsEnabledAtOsLevel: $enabled',
      );
    }

    try {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: channel.importance,
            priority: Priority.max,
            fullScreenIntent: useFullScreen,
            ongoing: useFullScreen,
            autoCancel: !useFullScreen,
            sound: isNewOrder
                ? const RawResourceAndroidNotificationSound('tujh_bin')
                : null,
            playSound: true,
            enableVibration: true,
            vibrationPattern: isNewOrder
                ? Int64List.fromList([0, 500, 250, 500, 250, 500])
                : null,
            visibility: NotificationVisibility.public,
            category: isNewOrder ? AndroidNotificationCategory.call : null,
            styleInformation: isNewOrder ? BigTextStyleInformation(body) : null,
            actions: isNewOrder
                ? const [_acceptOrderAction, _rejectOrderAction]
                : null,
          ),
          iOS: DarwinNotificationDetails(
            sound: isNewOrder ? 'tujh_bin.mp3' : null,
            presentSound: true,
            // Cuts through Focus modes and shows on the lock screen at full
            // prominence — matches the Android `max` importance channel.
            interruptionLevel: isNewOrder
                ? InterruptionLevel.timeSensitive
                : InterruptionLevel.active,
          ),
        ),
        payload: payload,
      );
      if (kDebugMode && isNewOrder) {
        debugPrint('[LocalNotification] new_order notification posted OK');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[LocalNotification] show() threw for isNewOrder=$isNewOrder: $e',
        );
      }
      return false;
    }
  }
}
