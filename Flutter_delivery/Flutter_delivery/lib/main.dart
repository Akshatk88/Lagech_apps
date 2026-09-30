import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/core/router/app_router.dart';
import 'package:food_user_application/core/services/fcm_service.dart';
import 'package:food_user_application/core/services/order_overlay_service.dart';
import 'package:food_user_application/core/services/referral_tracking_service.dart';
import 'package:food_user_application/core/theme/app_theme.dart';
import 'package:food_user_application/core/theme/theme_mode_provider.dart';
import 'package:food_user_application/features/orders/application/active_trip_visibility_controller.dart';
import 'package:food_user_application/features/orders/application/incoming_order_controller.dart';
import 'package:food_user_application/features/orders/application/orders_controller.dart';
import 'package:food_user_application/features/orders/application/orders_state.dart';
import 'package:food_user_application/features/orders/application/pending_customer_rating_controller.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';
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

/// Entry point for the overlay bubble's separate Flutter engine — must stay
/// top-level in this file with this exact name/pragma, since the native
/// `OverlayService` resolves "overlayMain" from the app's default
/// entrypoint library (main.dart), not by scanning every file.
@pragma('vm:entry-point')
void overlayMain() {
  runApp(const OrderBubbleApp());
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
      _consumePendingOverlayOrder();
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
      _consumePendingOverlayOrder();
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

  /// Surfaces an order that arrived as a home-screen bubble (app was
  /// backgrounded) into the same in-app IncomingOrderScreen shown for the
  /// foreground/socket path, and dismisses the bubble now that the app is
  /// in front.
  Future<void> _consumePendingOverlayOrder() async {
    await OrderOverlayService.close();
    final data = await OrderOverlayService.consumePendingOrder();
    if (data == null || !mounted) return;
    final order = DeliveryOrder.fromRealtimePayload(data);
    final incomingController = ref.read(
      incomingOrderControllerProvider.notifier,
    );

    incomingController.show(order);
    if (data['autoAccept'] == true) {
      incomingController.accept();
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
