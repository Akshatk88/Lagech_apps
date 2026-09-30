import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/finance/domain/finance_model.dart';
import 'package:food_user_application/features/finance/domain/subscription_invoice_model.dart';
import 'package:food_user_application/features/finance/domain/withdrawal_model.dart';
import 'package:food_user_application/features/finance/presentation/controllers/finance_controller.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';
import 'package:food_user_application/core/widgets/app_drawer.dart';

class PayoutsScreen extends ConsumerStatefulWidget {
  const PayoutsScreen({super.key, this.initialTab = 'invoices'});

  final String initialTab;

  @override
  ConsumerState<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends ConsumerState<PayoutsScreen> {
  // ---------------------------------------------------------------------------
  // TAB STATE
  // ---------------------------------------------------------------------------

  // 0 = Payouts
  // 1 = Invoices & Taxes
  late int _selectedTabIndex;

  bool get _isPayoutsTab => _selectedTabIndex == 0;

  @override
  void initState() {
    super.initState();

    _selectedTabIndex = widget.initialTab.toLowerCase() == 'payouts' ? 0 : 1;
  }

  @override
  void didUpdateWidget(covariant PayoutsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If GoRouter sends a different initialTab while this same
    // widget instance is alive, update the selected tab.
    if (oldWidget.initialTab != widget.initialTab) {
      final newIndex = widget.initialTab.toLowerCase() == 'payouts' ? 0 : 1;

      if (_selectedTabIndex != newIndex) {
        setState(() {
          _selectedTabIndex = newIndex;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // TAB SELECTOR
  // ---------------------------------------------------------------------------

  void _selectTab(int index) {
    if (_selectedTabIndex == index) {
      return;
    }

    setState(() {
      _selectedTabIndex = index;
    });
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      drawer: const AppDrawer(),
      appBar: _buildAppBar(context),

      body: Stack(
        children: [
          // -------------------------------------------------------------------
          // TOP SOFT BACKGROUND
          // -------------------------------------------------------------------

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 320,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      theme.scaffoldBackgroundColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // -------------------------------------------------------------------
          // CONTENT
          // -------------------------------------------------------------------
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(left: 0, right: 0, bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopTabs(context),

                  const SizedBox(height: 14),

                  // IMPORTANT:
                  // Use Key so Flutter clearly treats each view as a
                  // different content state.
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _isPayoutsTab
                        ? KeyedSubtree(
                            key: const ValueKey('payouts_view'),
                            child: _buildPayoutsView(context),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('invoices_view'),
                            child: _buildInvoicesView(context),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // APP BAR
  // ===========================================================================

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);

    final restaurant = ref.watch(restaurantProfileControllerProvider).value;

    final displayId = restaurant != null
        ? (restaurant.restaurantId.isNotEmpty
              ? restaurant.restaurantId
              : restaurant.id.substring(0, restaurant.id.length.clamp(0, 6)))
        : '--';

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      toolbarHeight: 92,
      leadingWidth: 64,
      titleSpacing: 0,

      title: Padding(
        padding: const EdgeInsets.only(left: 24, right: 70),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              restaurant?.restaurantName ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),

            const SizedBox(height: 4),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'ID: $displayId',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: SizedBox(
              key: ValueKey(
                _isPayoutsTab ? 'wallet_image' : 'calculator_image',
              ),
              width: 92,
              height: 92,
              child: Image.asset(
                _isPayoutsTab
                    ? 'assets/image/wallet.webp'
                    : 'assets/image/calculater.webp',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TOP TABS
  // ===========================================================================

  Widget _buildTopTabs(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // -------------------------------------------------------------------
          // PAYOUTS TAB
          // -------------------------------------------------------------------

          Expanded(
            child: _buildTabButton(
              context,
              label: 'Payouts',
              icon: Icons.account_balance_wallet_outlined,
              isSelected: _selectedTabIndex == 0,
              onTap: () => _selectTab(0),
            ),
          ),

          const SizedBox(width: 12),

          // -------------------------------------------------------------------
          // INVOICES TAB
          // -------------------------------------------------------------------
          Expanded(
            child: _buildTabButton(
              context,
              label: 'Invoices & Taxes',
              icon: Icons.receipt_long_outlined,
              isSelected: _selectedTabIndex == 1,
              onTap: () => _selectTab(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    final selectedColor = AppColors.primary;

    final unselectedColor = theme.colorScheme.onSurface.withValues(alpha: 0.45);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? selectedColor.withValues(alpha: 0.08)
                : theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected
                  ? selectedColor
                  : theme.dividerColor.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? selectedColor : unselectedColor,
                size: 21,
              ),

              const SizedBox(width: 8),

              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isSelected ? selectedColor : unselectedColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // INVOICES VIEW
  // ===========================================================================

  Widget _buildInvoicesView(BuildContext context) {
    final financeAsync = ref.watch(financeControllerProvider);

    return financeAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ),

      error: (error, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: _buildErrorText(
          context,
          error is ApiException
              ? error.message
              : 'Failed to load finance data.',
        ),
      ),

      data: (finance) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInvoiceSummaryCard(context, finance),

            const SizedBox(height: 20),

            if (finance.subscriptionDueAmount > 0)
              _buildSubscriptionDueCard(context, finance),

            if (finance.subscriptionDueAmount > 0) const SizedBox(height: 20),

            _buildOrderInvoiceCard(context, finance),

            const SizedBox(height: 4),

            _buildSubscriptionInvoicesSection(context),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // INVOICE SUMMARY CARD
  // ===========================================================================

  Widget _buildInvoiceSummaryCard(BuildContext context, FinanceModel finance) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invoices & Taxes Summary',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      'Overview of your earnings & taxes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildSummaryGridItem(
                  context,
                  title: 'Orders',
                  value: '${finance.invoiceCount}',
                  icon: Icons.shopping_bag_outlined,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _buildSummaryGridItem(
                  context,
                  title: 'Subtotal',
                  value: '₹${finance.invoiceSubtotal.toStringAsFixed(2)}',
                  icon: Icons.account_balance_wallet_outlined,
                  color: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildSummaryGridItem(
                  context,
                  title: 'Taxes',
                  value: '₹${finance.invoiceTaxes.toStringAsFixed(2)}',
                  icon: Icons.receipt_outlined,
                  color: Colors.purple,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _buildSummaryGridItem(
                  context,
                  title: 'Gross amount',
                  value: '₹${finance.invoiceGross.toStringAsFixed(2)}',
                  icon: Icons.monetization_on_outlined,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUMMARY GRID ITEM
  // ===========================================================================

  Widget _buildSummaryGridItem(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 142),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.16)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -2,
            bottom: -4,
            child: Icon(icon, size: 56, color: color.withValues(alpha: 0.20)),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 19),
              ),

              const SizedBox(height: 10),

              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUBSCRIPTION DUE
  // ===========================================================================

  Widget _buildSubscriptionDueCard(BuildContext context, FinanceModel finance) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline,
              color: AppColors.primary,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              'Subscription due: '
              '₹${finance.subscriptionDueAmount.toStringAsFixed(2)}'
              '${finance.lockedMonths.isNotEmpty ? ' (${finance.lockedMonths})' : ''}',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ORDER INVOICE DETAILS
  // ===========================================================================

  Widget _buildOrderInvoiceCard(BuildContext context, FinanceModel finance) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.primary,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  'Order invoice details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          if (finance.orders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'No orders yet.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < finance.orders.length; i++) ...[
                  _buildInvoiceDetailRow(context, finance.orders[i]),

                  if (i < finance.orders.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        height: 1,
                        color: theme.dividerColor.withValues(alpha: 0.15),
                      ),
                    ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SINGLE ORDER INVOICE ROW
  // ===========================================================================

  Widget _buildInvoiceDetailRow(BuildContext context, FinanceOrderRow order) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.push('/order-details/${order.orderId}');
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: AppColors.primary,
                  size: 21,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order: ${order.orderId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            order.paymentMethod,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.55,
                              ),
                              fontSize: 11.5,
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Text(
                            '•',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                        ),

                        Flexible(
                          child: Text(
                            order.orderStatus,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 90),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${order.totalAmount.toStringAsFixed(2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                            fontSize: 11,
                          ),
                        ),

                        const SizedBox(width: 2),

                        Icon(
                          Icons.chevron_right,
                          size: 15,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
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
      ),
    );
  }

  // ===========================================================================
  // SUBSCRIPTION INVOICES
  // ===========================================================================

  Widget _buildSubscriptionInvoicesSection(BuildContext context) {
    final theme = Theme.of(context);

    final invoicesAsync = ref.watch(subscriptionInvoicesControllerProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subscription invoices',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),

          const SizedBox(height: 14),

          invoicesAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),

            error: (error, _) => _buildErrorText(
              context,
              error is ApiException
                  ? error.message
                  : 'Failed to load subscription invoices.',
            ),

            data: (invoices) {
              if (invoices.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No subscription invoices yet.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < invoices.length; i++) ...[
                    _buildSubscriptionInvoiceRow(context, invoices[i]),

                    if (i < invoices.length - 1) const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionInvoiceRow(
    BuildContext context,
    SubscriptionInvoiceModel invoice,
  ) {
    final theme = Theme.of(context);

    final statusColor = switch (invoice.status) {
      'settled' => AppColors.success,
      'partially_settled' => AppColors.secondary,
      'waived' => AppColors.secondary,
      _ => AppColors.primary,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.billingMonthLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  invoice.planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${invoice.totalAmount.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Container(
                  constraints: const BoxConstraints(maxWidth: 120),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    invoice.status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PAYOUTS VIEW
  // ===========================================================================

  Widget _buildPayoutsView(BuildContext context) {
    final financeAsync = ref.watch(financeControllerProvider);

    final withdrawalsAsync = ref.watch(withdrawalsControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubscriptionModelCard(context),

        const SizedBox(height: 24),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Wallet balance',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),

        const SizedBox(height: 14),

        financeAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),

          error: (error, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildErrorText(
              context,
              error is ApiException ? error.message : 'Failed to load wallet.',
            ),
          ),

          data: (finance) => _buildWalletCard(context, finance),
        ),

        const SizedBox(height: 24),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Withdrawal requests',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              _buildFilterButton(context),
            ],
          ),
        ),

        const SizedBox(height: 14),

        withdrawalsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),

          error: (error, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildErrorText(
              context,
              error is ApiException
                  ? error.message
                  : 'Failed to load withdrawal requests.',
            ),
          ),

          data: (withdrawals) => withdrawals.isEmpty
              ? _buildEmptyWithdrawals(context)
              : _buildRequestsList(context, withdrawals),
        ),
      ],
    );
  }

  // ===========================================================================
  // SUBSCRIPTION MODEL CARD
  // ===========================================================================

  Widget _buildSubscriptionModelCard(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.13),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.primary,
                size: 25,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subscription based model',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'You are on a subscription plan. '
                    'Payouts are processed monthly.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.35,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),

            SizedBox(
              width: 62,
              height: 62,
              child: Image.asset(
                'assets/image/calander.webp',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // FILTER
  // ===========================================================================

  Widget _buildFilterButton(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.filter_alt_outlined,
            size: 16,
            color: theme.colorScheme.onSurface,
          ),

          const SizedBox(width: 4),

          Text(
            'Filter',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EMPTY WITHDRAWALS
  // ===========================================================================

  Widget _buildEmptyWithdrawals(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/image/notification.webp',
            width: 90,
            height: 90,
            fit: BoxFit.contain,
          ),

          const SizedBox(height: 16),

          const Text(
            'No withdrawal requests yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),

          const SizedBox(height: 7),

          Text(
            'Your withdrawal history will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // WALLET CARD
  // ===========================================================================

  Widget _buildWalletCard(BuildContext context, FinanceModel finance) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -25,
              top: -18,
              child: Text(
                '₹',
                style: TextStyle(
                  fontSize: 145,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Available to withdraw',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.visibility_off_outlined,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 7),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '₹ ${finance.netAvailable.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                if (finance.lockedAmount > 0) ...[
                  const SizedBox(height: 7),

                  Text(
                    '₹${finance.lockedAmount.toStringAsFixed(2)} '
                    'locked against subscription dues'
                    '${finance.lockedMonths.isNotEmpty ? ' (${finance.lockedMonths})' : ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () =>
                        _showWithdrawDialog(context, finance.netAvailable),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_balance,
                            color: AppColors.primary,
                            size: 22,
                          ),

                          SizedBox(width: 12),

                          Text(
                            'Withdraw',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),

                          Spacer(),

                          Icon(
                            Icons.chevron_right,
                            color: AppColors.primary,
                            size: 23,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // WITHDRAW DIALOG
  // ===========================================================================

  Future<void> _showWithdrawDialog(
    BuildContext context,
    double netAvailable,
  ) async {
    final amountController = TextEditingController();

    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Withdraw funds'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available to withdraw: '
                '₹${netAvailable.toStringAsFixed(2)}',
              ),

              const SizedBox(height: 16),

              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: const InputDecoration(
                  hintText: 'Amount',
                  prefixText: '₹ ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),

            TextButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text.trim());

                Navigator.pop(dialogContext, amount);
              },
              child: const Text('Withdraw'),
            ),
          ],
        );
      },
    );

    amountController.dispose();

    if (result == null) return;
    if (!context.mounted) return;

    if (result <= 0) {
      _showSnack(context, 'Enter a valid amount.', isError: true);
      return;
    }

    if (result > netAvailable) {
      _showSnack(
        context,
        'Amount exceeds your available balance of '
        '₹${netAvailable.toStringAsFixed(2)}.',
        isError: true,
      );
      return;
    }

    final restaurant = ref.read(restaurantProfileControllerProvider).value;

    try {
      await ref
          .read(withdrawalsControllerProvider.notifier)
          .requestWithdrawal(
            amount: result,
            bankDetails: {
              'accountNumber': restaurant?.accountNumber ?? '',
              'ifscCode': restaurant?.ifscCode ?? '',
              'accountHolderName': restaurant?.accountHolderName ?? '',
            },
          );

      if (context.mounted) {
        _showSnack(context, 'Withdrawal request submitted.');
      }
    } catch (e) {
      if (context.mounted) {
        final message = e is ApiException
            ? e.message
            : 'Failed to submit withdrawal request.';

        _showSnack(context, message, isError: true);
      }
    }
  }

  // ===========================================================================
  // WITHDRAWAL LIST
  // ===========================================================================

  Widget _buildRequestsList(
    BuildContext context,
    List<WithdrawalModel> withdrawals,
  ) {
    final theme = Theme.of(context);

    final dateFormat = DateFormat('d MMM yyyy • h:mm a');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: withdrawals.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: theme.dividerColor.withValues(alpha: 0.15),
        ),
        itemBuilder: (context, index) {
          final withdrawal = withdrawals[index];

          final isPending = withdrawal.status == 'pending';

          final isRejected = withdrawal.status == 'rejected';

          final color = isRejected
              ? Colors.red
              : (isPending ? AppColors.primary : AppColors.success);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),

              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPending
                      ? Icons.pending_actions
                      : (isRejected
                            ? Icons.cancel_outlined
                            : Icons.check_circle_outline),
                  color: color,
                  size: 21,
                ),
              ),

              title: Text(
                'Withdrawal to Bank',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  dateFormat.format(withdrawal.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),

              trailing: SizedBox(
                width: 92,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '- ₹ ${withdrawal.amount.toStringAsFixed(2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      withdrawal.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // ERROR TEXT
  // ===========================================================================

  Widget _buildErrorText(BuildContext context, String message) {
    return Text(
      message,
      style: TextStyle(
        color: Theme.of(context).colorScheme.error,
        fontSize: 13,
      ),
    );
  }

  // ===========================================================================
  // SNACKBAR
  // ===========================================================================

  void _showSnack(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
          backgroundColor: isError ? AppColors.error : null,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }
}
