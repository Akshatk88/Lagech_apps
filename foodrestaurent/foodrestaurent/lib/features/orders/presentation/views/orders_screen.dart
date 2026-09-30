import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:food_user_application/features/orders/domain/order_model.dart';
import 'package:food_user_application/features/orders/presentation/controllers/live_orders_controller.dart';
import 'package:food_user_application/features/orders/presentation/widgets/live_order_card.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';
import 'package:food_user_application/core/widgets/app_refresh_indicator.dart';
import 'package:food_user_application/core/widgets/app_drawer.dart';

class _OrdersTheme {
  static const Color primary = Color(0xFFE30613);
  static const Color primaryDark = Color(0xFFC9000B);

  static const Color pinkLight = Color(0xFFFFE1E5);
  static const Color pinkVeryLight = Color(0xFFFFF4F5);

  static const Color background = Color(0xFFF8F8F8);
  static const Color card = Colors.white;

  static const Color text = Color(0xFF171717);
  static const Color secondaryText = Color(0xFF77727D);
  static const Color border = Color(0xFFEDE8E9);

  static const Color success = Color(0xFF20A464);
  static const Color successLight = Color(0xFFE8F8EF);

  static const Color dangerLight = Color(0xFFFFEFF0);

  static const double cardRadius = 24;
  static const double smallRadius = 16;
}

class _TabConfig {
  final String label;
  final IconData icon;

  const _TabConfig(this.label, this.icon);
}

const _tabs = [
  _TabConfig('New Orders', Icons.receipt_long_outlined),
  _TabConfig('All', Icons.layers_outlined),
  _TabConfig('Preparing', Icons.soup_kitchen_outlined),
  _TabConfig('Ready', Icons.shopping_bag_outlined),
  _TabConfig('Out for delivery', Icons.delivery_dining_outlined),
  _TabConfig('Completed', Icons.check_circle_outline),
  _TabConfig('Cancelled', Icons.cancel_outlined),
];

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(liveOrdersControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: isDark
            ? Theme.of(context).scaffoldBackgroundColor
            : _OrdersTheme.background,
        drawer: const AppDrawer(),
        appBar: _buildAppBar(context),
        body: Column(
          children: [
            _buildTabBar(context),
            Expanded(
              child: ordersAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: _OrdersTheme.primary),
                ),
                error: (error, _) => _buildErrorState(context, error),
                data: (orders) => _buildTabViews(context, orders),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(_OrdersTheme.cardRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: _OrdersTheme.pinkLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: _OrdersTheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Unable to load orders',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                error is ApiException
                    ? error.message
                    : 'Failed to load orders. Please try again.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: _OrdersTheme.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabViews(BuildContext context, List<OrderModel> orders) {
    final restaurant = ref.watch(restaurantProfileControllerProvider).value;

    final isOffline = restaurant?.isAcceptingOrders == false;

    final newOrders =
        orders
            .where(
              (o) => [
                'new',
                'preparing',
                'ready',
                'out_for_delivery',
              ].contains(o.restaurantBucket),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final all = [...orders]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final preparing = orders
        .where((o) => o.restaurantBucket == 'preparing')
        .toList();

    final ready = orders.where((o) => o.restaurantBucket == 'ready').toList();

    final outForDelivery = orders
        .where((o) => o.restaurantBucket == 'out_for_delivery')
        .toList();

    final completed = orders
        .where((o) => o.restaurantBucket == 'completed')
        .toList();

    final cancelled = orders
        .where((o) => o.restaurantBucket == 'cancelled')
        .toList();

    return TabBarView(
      children: [
        _buildLiveOrderList(
          context,
          newOrders,
          emptyImage: isOffline
              ? 'assets/image/closestore.gif'
              : 'assets/image/online.gif',
          emptyText: isOffline
              ? 'Make Online for New Order'
              : 'You are Online\nWaiting for Orders',
        ),

        _buildOrderList(context, all, emptyText: 'No orders yet'),

        _buildOrderList(
          context,
          preparing,
          emptyText: 'No orders being prepared',
        ),

        _buildOrderList(
          context,
          ready,
          emptyText: 'No orders ready for pickup',
        ),

        _buildOrderList(
          context,
          outForDelivery,
          emptyText: 'No orders out for delivery',
        ),

        _buildOrderList(
          context,
          completed,
          emptyText: 'No completed orders yet',
        ),

        _buildOrderList(context, cancelled, emptyText: 'No cancelled orders'),
      ],
    );
  }

  Widget _buildLiveOrderList(
    BuildContext context,
    List<OrderModel> orders, {
    required String emptyText,
    String? emptyImage,
  }) {
    return AppRefreshIndicator(
      onRefresh: () =>
          ref.read(liveOrdersControllerProvider.notifier).refresh(),
      child: orders.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 60,
                    horizontal: 20,
                  ),
                  child: _buildEmptyState(
                    context,
                    text: emptyText,
                    image: emptyImage,
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              itemCount: orders.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const _LiveOrderHeader();
                }

                return LiveOrderCard(order: orders[index - 1]);
              },
            ),
    );
  }

  Widget _buildOrderList(
    BuildContext context,
    List<OrderModel> orders, {
    required String emptyText,
    String? headerCount,
    String? emptyImage,
  }) {
    return AppRefreshIndicator(
      onRefresh: () =>
          ref.read(liveOrdersControllerProvider.notifier).refresh(),
      child: orders.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (headerCount != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Text(
                      headerCount,
                      style: const TextStyle(
                        color: _OrdersTheme.secondaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 60,
                    horizontal: 20,
                  ),
                  child: _buildEmptyState(
                    context,
                    text: emptyText,
                    image: emptyImage,
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              itemCount: orders.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (index == orders.length) {
                  return const _DeliveryBanner();
                }

                return _OrderCard(order: orders[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required String text,
    String? image,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (image != null) ...[
          ClipOval(
            child: Image.asset(
              image,
              width: 220,
              height: 220,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 24),
        ] else ...[
          Container(
            width: 92,
            height: 92,
            decoration: const BoxDecoration(
              color: _OrdersTheme.pinkLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: _OrdersTheme.primary,
              size: 44,
            ),
          ),
          const SizedBox(height: 22),
        ],
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            height: 1.35,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : _OrdersTheme.text,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pull down to refresh',
          style: TextStyle(fontSize: 13, color: _OrdersTheme.secondaryText),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final restaurant = ref.watch(restaurantProfileControllerProvider).value;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDarkMode
        ? Theme.of(context).appBarTheme.backgroundColor
        : Colors.white;

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: backgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 16,
      toolbarHeight: 72,
      title: GestureDetector(
        onTap: () => context.push('/restaurant-status'),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _OrdersTheme.pinkLight,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.hardEdge,
              child: restaurant?.profileImage.isNotEmpty == true
                  ? CachedNetworkImage(
                      imageUrl: restaurant!.profileImage,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const Icon(
                        Icons.storefront_outlined,
                        color: _OrdersTheme.primary,
                        size: 24,
                      ),
                    )
                  : const Icon(
                      Icons.storefront_outlined,
                      color: _OrdersTheme.primary,
                      size: 24,
                    ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Hello, ${restaurant?.restaurantName ?? '—'} 👋',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isDarkMode ? Colors.white : _OrdersTheme.text,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: _OrdersTheme.secondaryText,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          restaurant?.fullAddress.isNotEmpty == true
                              ? restaurant!.fullAddress
                              : 'Address not set',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: _OrdersTheme.secondaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      actions: [
        const _AvailabilityToggle(),

        const SizedBox(width: 2),

        Builder(
          builder: (context) {
            final unreadCount =
                ref.watch(notificationsControllerProvider).value?.unreadCount ??
                0;

            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: isDarkMode ? Colors.white : _OrdersTheme.text,
                    size: 25,
                  ),
                  onPressed: () => context.push('/notifications'),
                ),

                if (unreadCount > 0)
                  Positioned(
                    right: 7,
                    top: 7,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 17,
                        minHeight: 17,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: const BoxDecoration(
                        color: _OrdersTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      color: isDarkMode
          ? Theme.of(context).scaffoldBackgroundColor
          : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,

        splashFactory: NoSplash.splashFactory,

        overlayColor: WidgetStateProperty.all(Colors.transparent),

        dividerColor: Colors.transparent,

        indicator: BoxDecoration(
          color: _OrdersTheme.primary,
          borderRadius: BorderRadius.circular(24),
        ),

        indicatorSize: TabBarIndicatorSize.tab,

        labelColor: Colors.white,

        unselectedLabelColor: isDarkMode
            ? Colors.white70
            : _OrdersTheme.secondaryText,

        labelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),

        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),

        padding: EdgeInsets.zero,

        labelPadding: const EdgeInsets.symmetric(horizontal: 14),

        tabs: _tabs
            .map(
              (tab) => Tab(
                height: 40,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tab.icon, size: 17),
                    const SizedBox(width: 6),
                    Text(tab.label),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Online / Offline control
class _AvailabilityToggle extends ConsumerStatefulWidget {
  const _AvailabilityToggle();

  @override
  ConsumerState<_AvailabilityToggle> createState() =>
      _AvailabilityToggleState();
}

class _AvailabilityToggleState extends ConsumerState<_AvailabilityToggle> {
  bool _isSaving = false;

  Future<void> _toggle(bool value) async {
    setState(() => _isSaving = true);

    try {
      await ref
          .read(restaurantProfileControllerProvider.notifier)
          .updateAvailability(value);
    } catch (e) {
      if (context.mounted) {
        final message = e is ApiException
            ? e.message
            : 'Failed to update status. Please try again.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: _OrdersTheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = ref.watch(restaurantProfileControllerProvider).value;

    final isOnline = restaurant?.isAcceptingOrders ?? false;

    return Container(
      height: 38,
      padding: const EdgeInsets.only(left: 11, right: 2),
      decoration: BoxDecoration(
        color: isOnline
            ? _OrdersTheme.successLight
            : Colors.grey.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isOnline
              ? _OrdersTheme.success.withValues(alpha: 0.35)
              : Colors.grey.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              color: isOnline ? _OrdersTheme.success : Colors.grey.shade600,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),

          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _OrdersTheme.primary,
                ),
              ),
            )
          else
            Transform.scale(
              scale: 0.62,
              child: Switch(
                value: isOnline,
                onChanged: _toggle,
                activeThumbColor: Colors.white,
                activeTrackColor: _OrdersTheme.success,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.grey.shade400,
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final isCancelled =
        order.orderStatus == 'cancelled' ||
        order.orderStatus == 'cancelled_by_restaurant';

    final cardColor = isDarkMode ? AppColors.surfaceDark : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(_OrdersTheme.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.18 : 0.045),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_OrdersTheme.cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(_OrdersTheme.cardRadius),
          onTap: () => context.push('/order-details/${order.id}'),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderHeader(context, isCancelled),

                const SizedBox(height: 17),

                _buildCustomerInfo(context, isCancelled),

                const SizedBox(height: 17),

                const _DashedDivider(),

                const SizedBox(height: 17),

                _buildAmountSection(context, isCancelled),

                const SizedBox(height: 16),

                _buildActions(context, ref, order),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderHeader(BuildContext context, bool isCancelled) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: isCancelled
                ? Colors.grey.withValues(alpha: 0.10)
                : _OrdersTheme.pinkLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.receipt_long_rounded,
            color: isCancelled ? Colors.grey : _OrdersTheme.primary,
            size: 23,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'FOD-${order.displayId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : _OrdersTheme.text,
                      ),
                    ),
                  ),

                  if (order.restaurantBucket == 'new') ...[
                    const SizedBox(width: 7),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _OrdersTheme.pinkLight,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color: _OrdersTheme.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 4),

              Text(
                DateFormat(
                  'd MMM  •  h:mm a',
                ).format(order.createdAt.toLocal()),
                style: const TextStyle(
                  color: _OrdersTheme.secondaryText,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const Icon(
          Icons.chevron_right_rounded,
          color: _OrdersTheme.secondaryText,
          size: 24,
        ),
      ],
    );
  }

  Widget _buildCustomerInfo(BuildContext context, bool isCancelled) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isCancelled
                ? Colors.grey.withValues(alpha: 0.10)
                : _OrdersTheme.pinkLight,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person_outline_rounded,
            color: isCancelled ? Colors.grey : _OrdersTheme.primary,
            size: 23,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: isDarkMode ? Colors.white : _OrdersTheme.text,
                  fontWeight: FontWeight.w800,
                ),
              ),

              if (order.customerPhone.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  order.customerPhone,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _OrdersTheme.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),

        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFF8F7F7),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            Icons.phone_outlined,
            size: 19,
            color: isDarkMode ? Colors.white70 : _OrdersTheme.text,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountSection(BuildContext context, bool isCancelled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: isCancelled
            ? _OrdersTheme.dangerLight
            : _OrdersTheme.pinkVeryLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isCancelled
                  ? Colors.white.withValues(alpha: 0.55)
                  : Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              isCancelled ? Icons.cancel_outlined : Icons.payments_outlined,
              color: isCancelled ? _OrdersTheme.primary : _OrdersTheme.primary,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order Amount',
                  style: TextStyle(
                    fontSize: 11,
                    color: _OrdersTheme.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  '₹${order.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                    color: _OrdersTheme.text,
                  ),
                ),
              ],
            ),
          ),

          if (!isCancelled)
            Image.asset(
              'assets/image/neworder.webp',
              height: 50,
              fit: BoxFit.contain,
            )
          else
            Image.asset(
              'assets/image/cancled.webp',
              height: 50,
              fit: BoxFit.contain,
            ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref, OrderModel order) {
    Future<void> updateStatus(String newStatus) async {
      try {
        await ref
            .read(liveOrdersControllerProvider.notifier)
            .updateStatus(order.id, newStatus);
      } catch (e) {
        if (context.mounted) {
          final message = e is ApiException
              ? e.message
              : 'Failed to update order. Please try again.';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: _OrdersTheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        }
      }
    }

    switch (order.orderStatus) {
      case 'created':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      title: const Text(
                        'Reject this order?',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      content: const Text(
                        'The customer will be notified and refunded per policy.',
                        style: TextStyle(color: _OrdersTheme.secondaryText),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: _OrdersTheme.secondaryText),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Reject',
                            style: TextStyle(
                              color: _OrdersTheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await updateStatus('cancelled_by_restaurant');
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: _OrdersTheme.primary,
                  side: const BorderSide(
                    color: _OrdersTheme.primary,
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close_rounded, size: 19),
                    SizedBox(width: 7),
                    Text(
                      'Reject',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: ElevatedButton(
                onPressed: () => updateStatus('confirmed'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: _OrdersTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 19),
                    SizedBox(width: 7),
                    Text(
                      'Accept',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

      case 'confirmed':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => updateStatus('preparing'),
            icon: const Icon(Icons.soup_kitchen_outlined, size: 20),
            label: const Text(
              'Start Preparing',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: _OrdersTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        );

      case 'preparing':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => updateStatus('ready_for_pickup'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: _OrdersTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text(
              'Mark Ready for Pickup',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        );

      case 'ready_for_pickup':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _OrdersTheme.pinkVeryLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: _OrdersTheme.pinkLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  order.dispatchStatus == 'unassigned'
                      ? Icons.hourglass_top_rounded
                      : Icons.delivery_dining_outlined,
                  size: 19,
                  color: _OrdersTheme.primary,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  order.dispatchStatus == 'unassigned'
                      ? 'Waiting for a delivery partner'
                      : 'Delivery partner assigned',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _OrdersTheme.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              if (order.dispatchStatus == 'unassigned')
                TextButton(
                  onPressed: () async {
                    try {
                      await ref
                          .read(liveOrdersControllerProvider.notifier)
                          .resendNotification(order.id);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Notified delivery partners again.'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        final message = e is ApiException
                            ? e.message
                            : 'Failed to resend notification.';

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message),
                            backgroundColor: _OrdersTheme.primary,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text(
                    'Resend',
                    style: TextStyle(
                      color: _OrdersTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        );

      case 'reached_pickup':
      case 'picked_up':
      case 'reached_drop':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _OrdersTheme.pinkVeryLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.delivery_dining_outlined,
                size: 21,
                color: _OrdersTheme.primary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  switch (order.orderStatus) {
                    'reached_pickup' => 'Rider at restaurant',
                    'reached_drop' => 'Rider reached the customer',
                    _ => 'On the way to the customer',
                  },
                  style: const TextStyle(
                    fontSize: 13,
                    color: _OrdersTheme.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

      case 'delivered':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 15),
          decoration: BoxDecoration(
            color: _OrdersTheme.successLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 21,
                color: _OrdersTheme.success,
              ),
              SizedBox(width: 8),
              Text(
                'Delivered',
                style: TextStyle(
                  color: _OrdersTheme.success,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );

      case 'cancelled':
      case 'cancelled_by_restaurant':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 15),
          decoration: BoxDecoration(
            color: _OrdersTheme.dangerLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.cancel_outlined,
                color: _OrdersTheme.primary,
                size: 21,
              ),
              SizedBox(width: 8),
              Text(
                'Cancelled',
                style: TextStyle(
                  color: _OrdersTheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );

      default:
        return Text(
          order.cancellationReason.isNotEmpty
              ? 'Cancelled: ${order.cancellationReason}'
              : 'Cancelled',
          style: const TextStyle(
            color: _OrdersTheme.primary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        );
    }
  }
}

class _CountdownText extends StatefulWidget {
  const _CountdownText({required this.deadline, required this.onExpired});

  final DateTime deadline;
  final VoidCallback onExpired;

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  Timer? _timer;

  late Duration _remaining = widget.deadline.difference(DateTime.now());

  bool _hasExpired = false;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = widget.deadline.difference(DateTime.now());

      if (remaining.isNegative) {
        _timer?.cancel();

        if (!_hasExpired) {
          _hasExpired = true;
          widget.onExpired();
        }
      }

      if (mounted) {
        setState(() {
          _remaining = remaining;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative) {
      return const Text(
        'Expired',
        style: TextStyle(
          color: _OrdersTheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
      );
    }

    final minutes = _remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    final seconds = _remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    return Text(
      '$minutes:$seconds',
      style: TextStyle(
        color: _remaining.inSeconds < 60
            ? _OrdersTheme.primary
            : _OrdersTheme.primary,
        fontWeight: FontWeight.w900,
        fontSize: 17,
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();

        const dashWidth = 5.0;
        const dashHeight = 1.0;

        final dashCount = (boxWidth / (2 * dashWidth)).floor();

        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.grey.shade700
                      : const Color(0xFFE8E4E5),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _DeliveryBanner extends StatelessWidget {
  const _DeliveryBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _OrdersTheme.pinkVeryLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _OrdersTheme.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: _OrdersTheme.pinkLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delivery_dining_outlined,
              color: _OrdersTheme.primary,
              size: 27,
            ),
          ),

          const SizedBox(width: 13),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivering happiness',
                  style: TextStyle(
                    color: _OrdersTheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Fast  •  Reliable  •  Always',
                  style: TextStyle(
                    color: _OrdersTheme.secondaryText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'Learn More',
              style: TextStyle(
                color: _OrdersTheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveOrderHeader extends StatelessWidget {
  const _LiveOrderHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: _OrdersTheme.pinkLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sensors_rounded,
              color: _OrdersTheme.primary,
              size: 24,
            ),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Order Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _OrdersTheme.text,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Track accepted orders in real-time',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _OrdersTheme.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: _OrdersTheme.successLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BlinkingDot(),
                SizedBox(width: 5),
                Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 10,
                    color: _OrdersTheme.success,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: const Icon(Icons.circle, size: 7, color: _OrdersTheme.success),
    );
  }
}
