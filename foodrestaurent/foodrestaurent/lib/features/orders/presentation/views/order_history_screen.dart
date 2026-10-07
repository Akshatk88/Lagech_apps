import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/orders/domain/order_model.dart';
import 'package:food_user_application/features/orders/presentation/controllers/order_history_controller.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';
import 'package:food_user_application/core/widgets/app_refresh_indicator.dart';

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(orderHistoryControllerProvider.notifier).search(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final restaurantName =
        ref.watch(restaurantProfileControllerProvider).value?.restaurantName ??
        '—';

    final ordersAsync = ref.watch(orderHistoryControllerProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,

        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            }
          },
        ),

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Showing order history for',
              style: TextStyle(
                color: theme.brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 13,
              ),
            ),

            Text(
              restaurantName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),

        centerTitle: false,
      ),

      body: Column(
        children: [
          _buildSearchBar(context),

          Expanded(
            child: AppRefreshIndicator(
              onRefresh: () {
                return ref
                    .read(orderHistoryControllerProvider.notifier)
                    .refresh();
              },

              child: ordersAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),

                error: (error, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        apiErrorMessage(error, 'Failed to load orders.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),

                data: (page) {
                  if (page.orders.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 80,
                            horizontal: 24,
                          ),
                          child: Center(
                            child: Text(
                              'No orders found.',
                              style: TextStyle(
                                color: theme.brightness == Brightness.dark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),

                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),

                    itemCount: page.orders.length,

                    separatorBuilder: (context, index) {
                      return const SizedBox(height: 16);
                    },

                    itemBuilder: (context, index) {
                      return _buildOrderCard(context, page.orders[index]);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SEARCH BAR
  // ===========================================================================

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);

    final secondaryTextColor = theme.brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,

          textInputAction: TextInputAction.search,

          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.transparent,

            hintText: 'Search by order ID',

            hintStyle: TextStyle(color: secondaryTextColor),

            prefixIcon: Icon(Icons.search, color: AppColors.primary),

            border: InputBorder.none,

            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 4,
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ORDER CARD
  // ===========================================================================

  Widget _buildOrderCard(BuildContext context, OrderModel order) {
    final theme = Theme.of(context);

    final secondaryTextColor = theme.brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: () {
          context.push('/order-details/${order.id}');
        },

        borderRadius: BorderRadius.circular(16),

        child: Container(
          width: double.infinity,

          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.5),
            ),
          ),

          child: Padding(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // =============================================================
                // TOP ROW
                // =============================================================

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // ---------------------------------------------------------
                    // LEFT TAGS
                    // ---------------------------------------------------------

                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,

                        children: [
                          _buildTag(
                            order.orderStatus.toUpperCase(),
                            order.isCancelled
                                ? const Color(0xFF4A5568)
                                : AppColors.primary,
                          ),

                          if (order.sendCutlery)
                            _buildTag('CUTLERY', AppColors.primary),

                          if (order.isAllVeg)
                            _buildTag('VEG ONLY', AppColors.primary),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // ---------------------------------------------------------
                    // DATE
                    // ---------------------------------------------------------
                    Flexible(
                      flex: 0,

                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 82),

                        child: Text(
                          DateFormat(
                            'd MMM,\nh:mm a',
                          ).format(order.createdAt.toLocal()),

                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,

                          textAlign: TextAlign.right,

                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 11,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // =============================================================
                // ORDER ID
                // =============================================================
                Text(
                  order.displayId,

                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 12),

                // =============================================================
                // CUSTOMER
                // =============================================================
                Text(
                  'Ordered by ${order.customerName}',

                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(fontSize: 14, color: secondaryTextColor),
                ),

                const SizedBox(height: 16),

                // =============================================================
                // DIVIDER
                // =============================================================
                Divider(
                  color: theme.dividerColor.withValues(alpha: 0.5),
                  thickness: 1,
                  height: 1,
                ),

                const SizedBox(height: 16),

                // =============================================================
                // ORDER ITEMS
                // =============================================================
                for (final item in order.items) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),

                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          '${item.quantity} x ',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        Expanded(
                          child: Text(
                            item.name,

                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,

                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // =============================================================
                // PAYMENT + TOTAL
                // =============================================================
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,

                  children: [
                    Expanded(
                      child: Text(
                        'Payment: ${order.paymentMethod}',

                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Text(
                      // The restaurant's earning, not the customer's bill.
                      order.restaurantEarning != null
                          ? "You'll receive ₹${order.restaurantEarning!.toStringAsFixed(2)}"
                          : '₹${order.itemTotal.toStringAsFixed(2)}',

                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAG
  // ===========================================================================

  Widget _buildTag(String text, Color color) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 155),

      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),

        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(5),
        ),

        child: Text(
          text,

          maxLines: 1,
          overflow: TextOverflow.ellipsis,

          textAlign: TextAlign.center,

          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
