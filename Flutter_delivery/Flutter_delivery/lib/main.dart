import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/core/router/app_router.dart';
import 'package:food_user_application/core/services/fcm_service.dart';
import 'package:food_user_application/core/services/new_order_overlay_bridge.dart';
import 'package:food_user_application/core/services/referral_tracking_service.dart';
import 'package:food_user_application/core/theme/app_theme.dart';
import 'package:food_user_application/core/theme/theme_mode_provider.dart';
import 'package:food_user_application/features/orders/application/active_trip_visibility_controller.dart';
import 'package:food_user_application/features/orders/application/incoming_order_controller.dart';
import 'package:food_user_application/features/orders/application/orders_controller.dart';
import 'package:food_user_application/features/orders/application/orders_state.dart';
import 'package:food_user_application/features/orders/application/pending_customer_rating_controller.dart';
import 'package:food_user_application/features/orders/data/orders_repository.dart';
import 'package:food_user_application/features/orders/presentation/screens/active_trip_screen.dart';
import 'package:food_user_application/features/orders/presentation/screens/incoming_order_screen.dart';
import 'package:food_user_application/core/presentation/widgets/no_network_overlay.dart';
import 'package:food_user_application/core/services/network_controller.dart';
import 'package:food_user_application/features/orders/presentation/screens/rate_customer_screen.dart';

import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase.initializeApp error: $e');
  }

  runApp(const ProviderScope(child: FoodDeliveryApp()));
}

class FoodDeliveryApp extends ConsumerStatefulWidget {
  const FoodDeliveryApp({super.key});

  @override
  ConsumerState<FoodDeliveryApp> createState() => _FoodDeliveryAppState();
}

class _FoodDeliveryAppState extends ConsumerState<FoodDeliveryApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      ref.read(fcmServiceProvider).initialize();
      ReferralTrackingService.initialize();
      _consumeOverlayHandoff();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _consumeOverlayHandoff();
      // Re-checks full-screen-intent / overlay permissions on every resume,
      // not just cold start — catches a rider who dismissed the Settings
      // prompt the first time or toggled it manually while the app was
      // backgrounded (see FcmService.ensureAndroidAlertPermissions).
      ref.read(fcmServiceProvider).ensureAndroidAlertPermissions();

      // Re-register the push token on every resume, for the same reason.
      //
      // Registration only happened at launch and login, so a save that failed
      // — or a token FCM rotated while the app was closed — left the rider
      // silently unreachable until the next relaunch. Five of six online riders
      // were in exactly that state: apps running, GPS fresh, no token on the
      // server, and no order offers reaching them.
      //
      // Idempotent server-side ($addToSet), so repeating it is free.
      unawaited(ref.read(fcmServiceProvider).registerToken());
    }
  }

  /// Consumes launch order handoff from the native overlay or fallback notification,
  /// and flushes any pending rejections recorded natively.
  Future<void> _consumeOverlayHandoff() async {
    // 1. Flush any pending rejections recorded by the overlay or notification
    try {
      final rejectedIds = await NewOrderOverlayBridge.takePendingRejections();
      if (rejectedIds.isNotEmpty) {
        debugPrint('[Handoff] Flushing ${rejectedIds.length} pending rejections: $rejectedIds');
        final incoming = ref.read(incomingOrderControllerProvider.notifier);
        final ordersController = ref.read(ordersControllerProvider.notifier);
        for (final id in rejectedIds) {
          incoming.markResolved(id);
          unawaited(ordersController.rejectOrder(id));
        }
      }
    } catch (e) {
      debugPrint('[Handoff] Error taking pending rejections: $e');
    }

    // 2. Consume any launch order from the intent
    try {
      final launchData = await NewOrderOverlayBridge.consumeLaunchOrder();
      if (launchData == null || !mounted) return;

      final orderId = launchData['orderId']?.toString();
      if (orderId == null || orderId.isEmpty) return;

      final autoAccept = launchData['autoAccept'] == true;
      debugPrint('[Handoff] Consumed launch order: orderId=$orderId, autoAccept=$autoAccept');

      final incoming = ref.read(incomingOrderControllerProvider.notifier);

      if (autoAccept) {
        // Accept must never ask twice: do not show the in-app card at all.
        // Mark resolved, call accept directly, let the trip screen appear.
        incoming.markResolved(orderId);
        await ref.read(ordersControllerProvider.notifier).acceptOrder(orderId);
      } else {
        // If not autoAccept (e.g. rider tapped fallback notification body), load details and show card
        final repo = ref.read(ordersRepositoryProvider);
        final result = await repo.getOrderDetails(orderId);
        if (!mounted) return;
        result.when(
          success: (order) {
            incoming.show(order);
          },
          failure: (err) {
            debugPrint('[Handoff] Failed to fetch order details for $orderId: $err');
          },
        );
      }
    } catch (e) {
      debugPrint('[Handoff] Error consuming launch order: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(goRouterProvider);

    final themeMode = ref.watch(themeModeProvider);

    return ScreenUtilInit(
      designSize: const Size(375, 812), // Standard design size
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'Fodron Delivery',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          routerConfig: goRouter,
          builder: (context, routedChild) {
            final isDarkMode = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: isDarkMode
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              child: Stack(
                children: [
                  ?routedChild,
                  Consumer(
                    builder: (context, ref, _) {
                      final hasActiveOrder = ref.watch(
                        ordersControllerProvider.select(
                          (s) => s is OrdersLoaded && s.currentOrder != null,
                        ),
                      );
                      final showTrip = ref.watch(
                        activeTripVisibilityControllerProvider,
                      );
                      if (!hasActiveOrder || !showTrip) {
                        return const SizedBox.shrink();
                      }
                      return const ActiveTripScreen();
                    },
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final incomingOrder = ref.watch(
                        incomingOrderControllerProvider,
                      );
                      if (incomingOrder == null) return const SizedBox.shrink();
                      return IncomingOrderScreen(
                        key: ValueKey(incomingOrder.id),
                        order: incomingOrder,
                      );
                    },
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final pendingRating = ref.watch(
                        pendingCustomerRatingControllerProvider,
                      );
                      if (pendingRating == null) return const SizedBox.shrink();
                      return RateCustomerScreen(
                        key: ValueKey(pendingRating.id),
                        order: pendingRating,
                      );
                    },
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final isOnline = ref.watch(networkControllerProvider);
                      if (isOnline) return const SizedBox.shrink();
                      return const NoNetworkOverlay();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
