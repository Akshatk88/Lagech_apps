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
  StreamSubscription<Map<String, dynamic>>? _autoAcceptSub;
  final Set<String> _processingAcceptOrderIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NewOrderOverlayBridge.initialize();
    _autoAcceptSub = NewOrderOverlayBridge.onAutoAccept.listen((data) {
      final orderId = data['orderId']?.toString();
      if (orderId != null && orderId.isNotEmpty) {
        _handleAutoAccept(orderId);
      }
    });

    Future.microtask(() {
      ref.read(fcmServiceProvider).initialize();
      ReferralTrackingService.initialize();
      _consumeOverlayHandoff();
    });
  }

  @override
  void dispose() {
    _autoAcceptSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _consumeOverlayHandoff();

      // Re-register the push token on every resume.
      unawaited(ref.read(fcmServiceProvider).registerToken());
    }
  }

  Future<void> _handleAutoAccept(String orderId) async {
    if (_processingAcceptOrderIds.contains(orderId)) return;
    _processingAcceptOrderIds.add(orderId);
    // Allow re-accepting after 15 seconds if failed or new order
    Future.delayed(const Duration(seconds: 15), () => _processingAcceptOrderIds.remove(orderId));

    debugPrint('[Handoff] Auto-accepting order directly: orderId=$orderId');
    final incoming = ref.read(incomingOrderControllerProvider.notifier);
    incoming.markResolved(orderId);
    ref.read(activeTripVisibilityControllerProvider.notifier).show();
    await ref.read(ordersControllerProvider.notifier).acceptOrder(orderId);
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

      if (autoAccept) {
        // Accept must never ask twice: do not show the in-app card at all.
        await _handleAutoAccept(orderId);
      } else {
        // If not autoAccept (e.g. rider tapped fallback notification body), load details and show card
        final incoming = ref.read(incomingOrderControllerProvider.notifier);
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
          title: 'Lagech Delivery',
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
