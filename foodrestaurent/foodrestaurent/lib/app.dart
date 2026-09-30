import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/config/theme/app_theme.dart';
import 'package:food_user_application/core/services/fcm_service.dart';
import 'package:food_user_application/core/services/new_order_action_channel.dart';
import 'package:food_user_application/core/services/order_notification_action_handler.dart';
import 'package:food_user_application/config/router/app_router.dart';
import 'package:food_user_application/features/orders/presentation/controllers/live_orders_controller.dart';
import 'package:food_user_application/config/theme/theme_mode_provider.dart';
import 'package:food_user_application/core/services/network_controller.dart';
import 'package:food_user_application/core/widgets/no_network_overlay.dart';

class FoodUserApplication extends ConsumerStatefulWidget {
  const FoodUserApplication({super.key});

  @override
  ConsumerState<FoodUserApplication> createState() =>
      _FoodUserApplicationState();
}

class _FoodUserApplicationState extends ConsumerState<FoodUserApplication>
    with WidgetsBindingObserver {
  StreamSubscription<NewOrderAction>? _orderActionSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Attached before anything else can produce a decision.
    NewOrderActionChannel.initialize();
    _orderActionSub = NewOrderActionChannel.onAction.listen(_handleOrderAction);

    // Ensure notification permission is requested and token saved on startup
    unawaited(ref.read(fcmServiceProvider).requestPermission().then((_) {
      ref.read(fcmServiceProvider).saveTokenToServer();
    }));

    // Cold start after Accept was pressed on the lock screen: the decision was made
    // before this engine existed, so it is waiting in native rather than arriving as
    // an event.
    unawaited(_consumePendingOrderAction());
  }

  @override
  void dispose() {
    _orderActionSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Carry out a decision made on the native new-order alert.
  ///
  /// Kotlin deliberately records the decision without acting on it: the status update
  /// needs the auth token, which lives on this side. This is the single place that
  /// turns a notification button press into a real accept or reject.
  Future<void> _handleOrderAction(NewOrderAction action) async {
    await submitOrderDecision(
      orderId: action.orderId,
      accepted: action.accepted,
    );
    // Clear the alert and stop ringing either way
    await NewOrderActionChannel.stopSound(action.orderId);
    await NewOrderActionChannel.dismiss(action.orderId);
    if (!mounted) return;
    ref.read(liveOrdersControllerProvider.notifier).refresh();
  }

  Future<void> _consumePendingOrderAction() async {
    final action = await NewOrderActionChannel.consumePendingAction();
    if (action == null) return;
    await _handleOrderAction(action);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from background/lock screen is exactly when a push could
    // have been missed (OS throttling, no connectivity, app killed) — refresh
    // straight from the API so no order is ever silently missed.
    if (state == AppLifecycleState.resumed) {
      ref.read(liveOrdersControllerProvider.notifier).refresh();

      // The app being killed is the normal case for a phone locked on a counter, so
      // a decision made on the notification usually predates this engine. Checked on
      // every resume, not just cold start, because the app can also be backgrounded.
      unawaited(_consumePendingOrderAction());

      // Re-register the push token on every resume.
      //
      // Registration used to happen only at launch and at login, so a token
      // that failed to save — or that FCM rotated while the app was closed —
      // left the restaurant silently unreachable until someone happened to
      // relaunch. That is exactly how five of six restaurants ended up with no
      // token at all while their apps were running fine.
      //
      // The call is cheap, idempotent server-side ($addToSet), and reports its
      // own failures, so running it on every resume costs nothing and closes
      // the window to a single resume.
      unawaited(ref.read(fcmServiceProvider).saveTokenToServer());
    }
  }

  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(goRouterProvider);
    final currentThemeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: currentThemeMode,
      routerConfig: goRouter,
      builder: (context, child) {
        return Stack(
          children: [
            ?child,
            Consumer(
              builder: (context, ref, _) {
                final isOnline = ref.watch(networkControllerProvider);
                if (isOnline) return const SizedBox.shrink();
                return const NoNetworkOverlay();
              },
            ),
          ],
        );
      },
    );
  }
}
