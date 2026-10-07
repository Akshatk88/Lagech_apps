// App Router Configuration
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'route_names.dart';
import '../splash/splash_screen.dart';
import '../auth/screens/login_screen.dart';
import '../auth/screens/otp_screen.dart';
import '../main/main_app_shell.dart';
import '../home/home_screen.dart';
import '../cart/cart_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../restaurant/screens/food_detail_loader_screen.dart';
import '../restaurant/screens/food_detail_screen.dart';
import '../restaurant/screens/restaurant_detail_loader_screen.dart';
import '../restaurant/screens/restaurant_screen.dart';
import '../restaurant/screens/restaurant_reviews_screen.dart';
import '../restaurant/screens/store99_screen.dart';
import '../offers/screens/all_offers_screen.dart';
import '../search/screens/search_screen.dart';
import '../address/screens/add_address_screen.dart';
import '../address/screens/select_location_screen.dart';
import '../../data/models/address_model.dart';
import '../favorites/favorites_screen.dart';
import '../orders/screens/orders_screen.dart';
import '../orders/screens/order_details_screen.dart';
import '../orders/screens/order_tracking_screen.dart';
import '../orders/screens/order_success_screen.dart';
import '../orders/screens/order_delivered_screen.dart';
import '../orders/screens/order_invoice_screen.dart';
import '../orders/screens/order_help_requests_screen.dart';
import '../referral/screens/referral_screen.dart';
import '../referral/screens/referral_ticket_result_screen.dart';
import '../wallet/screens/wallet_screen.dart';
import '../wallet/screens/loyalty_points_screen.dart';
import '../wallet/screens/pay_later_screen.dart';
import '../chat/screens/chat_screen.dart';
import '../home/screens/home_filter_screen.dart';
import '../home/screens/category_details_screen.dart';
import '../home/screens/popular_dishes_screen.dart';
import '../home/screens/top_10_screen.dart';
import '../common/webview_screen.dart';
import '../about/screens/about_screen.dart';
import '../profile/screens/help_support_screen.dart';
import '../profile/screens/privacy_policy_screen.dart';
import '../profile/screens/terms_conditions_screen.dart';
import '../profile/screens/edit_profile_screen.dart';
import '../../data/models/restaurant_model.dart';
import '../../data/models/food_model.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/category_model.dart';
import '../cart/viewmodels/cart_viewmodel.dart';
import '../checkout/viewmodels/checkout_viewmodel.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKeyHome = GlobalKey<NavigatorState>(
  debugLabel: 'shellHome',
);
final shellNavigatorKeyCart = GlobalKey<NavigatorState>(
  debugLabel: 'shellCart',
);
final shellNavigatorKeyStore99 = GlobalKey<NavigatorState>(
  debugLabel: 'shellStore99',
);
final shellNavigatorKeyProfile = GlobalKey<NavigatorState>(
  debugLabel: 'shellProfile',
);

/// Drops focus on every route change, so the keyboard never survives a
/// navigation and end up floating over the screen the user just opened.
///
/// An observer rather than an unfocus call at each `context.push` site: those
/// are scattered across dozens of screens and any new one would have to
/// remember. This catches pushes, pops and replacements alike.
class _DismissKeyboardOnNavigate extends NavigatorObserver {
  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _unfocus();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _unfocus();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _unfocus();
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    observers: [_DismissKeyboardOnNavigate()],
    initialLocation: RouteNames.splash,
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) {
          final fromPath =
              state.uri.queryParameters['from'] ??
              (state.extra is String ? state.extra as String : null);
          return LoginScreen(fromPath: fromPath);
        },
      ),
      GoRoute(
        path: RouteNames.otp,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final phone =
              extra?['phone']?.toString() ??
              state.uri.queryParameters['phone'] ??
              '';
          final fromPath =
              extra?['from']?.toString() ?? state.uri.queryParameters['from'];
          return OtpScreen(
            phoneNumber: phone,
            devOtp: extra?['devOtp']?.toString(),
            fromPath: fromPath,
          );
        },
      ),
      GoRoute(
        path: RouteNames.restaurantDetail,
        builder: (context, state) {
          // `extra` is not guaranteed. A shared link carries only the id, and an
          // unconditional cast threw on arrival; the favourites screen also
          // already pushes '/restaurant-detail/<id>', which never matched this
          // route at all. Both now resolve through the loader.
          final restaurant =
              state.extra is RestaurantModel ? state.extra as RestaurantModel : null;
          if (restaurant != null) {
            return RestaurantScreen(restaurant: restaurant);
          }
          return RestaurantDetailLoaderScreen(
            restaurantId: state.uri.queryParameters['id'] ??
                state.uri.queryParameters['restaurantId'] ??
                '',
          );
        },
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final restaurant = state.extra is RestaurantModel
                  ? state.extra as RestaurantModel
                  : null;
              if (restaurant != null) {
                return RestaurantScreen(restaurant: restaurant);
              }
              return RestaurantDetailLoaderScreen(
                restaurantId: state.pathParameters['id'] ?? '',
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.restaurantReviews,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          RestaurantModel? restaurant;
          List<FoodModel> menuItems = const [];
          if (extra is RestaurantModel) {
            restaurant = extra;
          } else if (extra is Map<String, dynamic>) {
            restaurant = extra['restaurant'] as RestaurantModel?;
            menuItems = (extra['menuItems'] as List<FoodModel>?) ?? const [];
          }
          if (restaurant != null) {
            return RestaurantReviewsScreen(
              restaurant: restaurant,
              menuItems: menuItems,
            );
          }
          final restaurantId = state.uri.queryParameters['id'] ?? '';
          return RestaurantDetailLoaderScreen(restaurantId: restaurantId);
        },
      ),
      GoRoute(
        path: RouteNames.foodDetail,
        builder: (context, state) {
          final extraFood = state.extra is FoodModel ? state.extra as FoodModel : null;
          final foodId = state.uri.queryParameters['id'] ?? state.uri.queryParameters['productId'] ?? '';
          final restaurantId = state.uri.queryParameters['restaurantId'] ?? state.uri.queryParameters['rId'] ?? '';

          if (extraFood != null) {
            return FoodDetailScreen(food: extraFood);
          }
          return FoodDetailLoaderScreen(
            foodId: foodId,
            restaurantId: restaurantId,
          );
        },
      ),
      GoRoute(
        path: '/food',
        builder: (context, state) {
          final extraFood = state.extra is FoodModel ? state.extra as FoodModel : null;
          final foodId = state.uri.queryParameters['id'] ?? state.uri.queryParameters['productId'] ?? '';
          final restaurantId = state.uri.queryParameters['restaurantId'] ?? state.uri.queryParameters['rId'] ?? '';

          if (extraFood != null) {
            return FoodDetailScreen(food: extraFood);
          }
          return FoodDetailLoaderScreen(
            foodId: foodId,
            restaurantId: restaurantId,
          );
        },
      ),
      GoRoute(
        path: RouteNames.search,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final query = state.extra is String
              ? state.extra as String
              : state.uri.queryParameters['q'];
          return SearchScreen(initialQuery: query);
        },
      ),
      GoRoute(
        path: RouteNames.orders,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OrdersScreen(),
      ),
      GoRoute(
        path: RouteNames.notifications,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/orders/details/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OrderDetailsScreen(orderId: id);
        },
      ),
      GoRoute(
        path: '/orders/track/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final paramId = state.pathParameters['id'] ?? '';
          final fragmentId = state.uri.fragment;
          final resolvedId = (paramId.isNotEmpty ? paramId : fragmentId).replaceAll('#', '').trim();
          return OrderTrackingScreen(orderId: resolvedId);
        },
      ),
      GoRoute(
        path: '/orders/track',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final fragmentId = state.uri.fragment.replaceAll('#', '').trim();
          return OrderTrackingScreen(orderId: fragmentId);
        },
      ),
      GoRoute(
        path: '/orders/delivered/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OrderDeliveredScreen(orderId: id);
        },
      ),
      GoRoute(
        path: RouteNames.orderInvoice,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OrderInvoiceScreen(orderId: id);
        },
      ),
      GoRoute(
        path: RouteNames.orderHelpRequests,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OrderHelpRequestsScreen(),
      ),
      GoRoute(
        path: RouteNames.chat,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final args = state.extra as ChatArgs? ?? const ChatArgs(
            orderId: '',
            peerName: 'Support',
            peerRole: 'ADMIN',
          );
          return ChatScreen(args: args);
        },
      ),
      GoRoute(
        path: RouteNames.homeFilter,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            HomeFilterScreen(args: state.extra as HomeFilterArgs),
      ),
      GoRoute(
        path: RouteNames.categoryDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final category = state.extra as CategoryModel;
          return CategoryDetailsScreen(category: category);
        },
      ),
      GoRoute(
        path: RouteNames.popularDishes,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PopularDishesScreen(),
      ),
      GoRoute(
        path: RouteNames.top10,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const Top10Screen(),
      ),
      GoRoute(
        path: '/orders/success/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OrderSuccessScreen(orderId: id);
        },
      ),
      GoRoute(
        path: RouteNames.referral,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ReferralScreen(),
      ),
      GoRoute(
        path: RouteNames.referralTicket,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ReferralTicketResultScreen(),
      ),
      GoRoute(
        path: RouteNames.favorites,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: RouteNames.addAddress,
        parentNavigatorKey: rootNavigatorKey,
        // `extra` carries an address when this opens to edit one.
        builder: (context, state) => AddAddressScreen(
          editAddress: state.extra is AddressModel ? state.extra as AddressModel : null,
        ),
      ),
      GoRoute(
        path: RouteNames.selectLocation,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SelectLocationScreen(),
      ),
      GoRoute(
        path: RouteNames.allOffers,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AllOffersScreen(),
      ),
      GoRoute(
        path: RouteNames.wallet,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: RouteNames.loyaltyPoints,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LoyaltyPointsScreen(),
      ),
      GoRoute(
        path: RouteNames.payLater,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PayLaterScreen(),
      ),
      GoRoute(
        path: RouteNames.webView,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extraMap = state.extra as Map<String, dynamic>?;
          final title =
              extraMap?['title']?.toString() ??
              state.uri.queryParameters['title'] ??
              'Web View';
          final url =
              extraMap?['url']?.toString() ??
              state.uri.queryParameters['url'] ??
              '';
          return WebViewScreen(title: title, url: url);
        },
      ),
      GoRoute(
        path: RouteNames.about,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: RouteNames.helpSupport,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: RouteNames.privacyPolicy,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: RouteNames.termsConditions,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const TermsConditionsScreen(),
      ),
      GoRoute(
        path: RouteNames.editProfile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: RouteNames.buyAgain,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final items = state.extra as List<CartItemModel>;
          return ProviderScope(
            overrides: [
              cartViewModelProvider.overrideWith(
                () => CartViewModel(initialItems: items, syncEnabled: false),
              ),
              checkoutViewModelProvider.overrideWith(CheckoutViewModel.new),
            ],
            child: const CartScreen(),
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainAppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: shellNavigatorKeyHome,
            routes: [
              GoRoute(
                path: RouteNames.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellNavigatorKeyCart,
            routes: [
              GoRoute(
                path: RouteNames.cart,
                builder: (context, state) => const CartScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellNavigatorKeyStore99,
            routes: [
              GoRoute(
                path: RouteNames.store99,
                builder: (context, state) => const Store99Screen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellNavigatorKeyProfile,
            routes: [
              GoRoute(
                path: RouteNames.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
