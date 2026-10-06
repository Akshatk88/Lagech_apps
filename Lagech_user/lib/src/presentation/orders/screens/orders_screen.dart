import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/order_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_refresh_indicator.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/active_order_viewmodel.dart';
import '../viewmodels/orders_viewmodel.dart';
import '../../../core/utils/localizations.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _activeScrollController = ScrollController();
  final ScrollController _pastScrollController = ScrollController();
  Timer? _pollingTimer;
  String _selectedFilter = 'All'; // 'All', 'Delivered', 'Cancelled'
  bool _hasAutoSelectedTab = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _activeScrollController.addListener(_onActiveScroll);
    _pastScrollController.addListener(_onPastScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ordersViewModelProvider.notifier).refresh();
      ref.read(activeOrderViewModelProvider.notifier).fetchActiveOrder();
    });
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        final hasActive = ref.read(ordersViewModelProvider).active.isNotEmpty;
        if (hasActive) {
          ref.read(ordersViewModelProvider.notifier).refresh(isRefresh: true);
          ref.read(activeOrderViewModelProvider.notifier).fetchActiveOrder(isRefresh: true);
        }
      }
    });
  }

  void _onActiveScroll() {
    if (_activeScrollController.hasClients &&
        _activeScrollController.position.pixels >=
            _activeScrollController.position.maxScrollExtent - 200) {
      ref.read(ordersViewModelProvider.notifier).loadMore();
    }
  }

  void _onPastScroll() {
    if (_pastScrollController.hasClients &&
        _pastScrollController.position.pixels >=
            _pastScrollController.position.maxScrollExtent - 200) {
      ref.read(ordersViewModelProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    _activeScrollController.dispose();
    _pastScrollController.dispose();
    super.dispose();
  }

  void _showFilterModal() {
    Haptics.light();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final filters = ['All', 'Delivered', 'Cancelled'];

        return Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Orders 🔍',
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12.h),
              ...filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return ListTile(
                  title: Text(
                    filter,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected ? AppColors.primary : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () {
                    Haptics.light();
                    setState(() => _selectedFilter = filter);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : const Color(0xFF1E1E1E);
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : const Color(0xFF6B7280);
    final backgroundColor = isDark
        ? AppColors.backgroundDark
        : const Color(0xFFF4F6F8);

    final ordersState = ref.watch(ordersViewModelProvider);

    List<OrderModel> activeList = ordersState.active;
    List<OrderModel> pastList = ordersState.past;

    if (!_hasAutoSelectedTab && !ordersState.isLoading) {
      _hasAutoSelectedTab = true;
      if (activeList.isNotEmpty) {
        _tabController.index = 0;
      }
    }

    // Apply Filter
    if (_selectedFilter == 'Delivered') {
      pastList = pastList
          .where((o) => o.isDelivered || o.orderStatus == 'delivered')
          .toList();
    } else if (_selectedFilter == 'Cancelled') {
      pastList = pastList
          .where((o) => o.isCancelled || o.orderStatus.contains('cancelled'))
          .toList();
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // 1. CLEAN WHITE HEADER WITH TAB BAR (Screenshot 3)
          Container(
            width: double.infinity,
            color: isDark ? AppColors.surfaceDark : Colors.white,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // App Bar Row
                  Padding(
                    padding: EdgeInsets.fromLTRB(8.w, 4.h, 16.w, 8.h),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: textColor,
                            size: 24.sp,
                          ),
                          onPressed: () {
                            Haptics.light();
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(RouteNames.home);
                            }
                          },
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            context.l10n.myOrders,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.tune_rounded,
                            color: textColor,
                            size: 22.sp,
                          ),
                          onPressed: _showFilterModal,
                        ),
                      ],
                    ),
                  ),

                  // TabBar
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3.h,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.normal,
                    ),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_bag_outlined, size: 16.sp),
                            SizedBox(width: 6.w),
                            Text(context.l10n.activeOrdersCount(activeList.length)),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_bag_outlined, size: 16.sp),
                            SizedBox(width: 6.w),
                            Text(context.l10n.pastOrdersCount(pastList.length)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2. TAB BAR VIEW CONTENT
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersTabList(
                  context: context,
                  orders: activeList,
                  isActiveTab: true,
                  isDark: isDark,
                  textColor: textColor,
                  secondaryColor: secondaryColor,
                ),
                _buildOrdersTabList(
                  context: context,
                  orders: pastList,
                  isActiveTab: false,
                  isDark: isDark,
                  textColor: textColor,
                  secondaryColor: secondaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTabList({
    required BuildContext context,
    required List<OrderModel> orders,
    required bool isActiveTab,
    required bool isDark,
    required Color textColor,
    required Color secondaryColor,
  }) {
    if (orders.isEmpty) {
      return AppRefreshIndicator(
        onRefresh: () async {
          await ref.read(ordersViewModelProvider.notifier).refresh(isRefresh: true);
          await ref.read(activeOrderViewModelProvider.notifier).fetchActiveOrder(isRefresh: true);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          children: [
            SizedBox(height: 100.h),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTintStrong,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      size: 40.sp,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    isActiveTab ? 'No Active Orders' : 'No Past Orders',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    isActiveTab
                        ? 'Your active food orders will appear here.'
                        : 'You have no past completed or cancelled orders.',
                    style: TextStyle(fontSize: 12.sp, color: secondaryColor),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 18.h),
                  OutlinedButton.icon(
                    onPressed: () {
                      Haptics.light();
                      ref.read(ordersViewModelProvider.notifier).refresh(isRefresh: true);
                      ref.read(activeOrderViewModelProvider.notifier).fetchActiveOrder(isRefresh: true);
                    },
                    icon: Icon(Icons.refresh_rounded, size: 16.sp, color: AppColors.primary),
                    label: Text(
                      'Refresh Orders',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AppRefreshIndicator(
      onRefresh: () async {
        await ref.read(ordersViewModelProvider.notifier).refresh(isRefresh: true);
        await ref.read(activeOrderViewModelProvider.notifier).fetchActiveOrder(isRefresh: true);
      },
      child: ListView.builder(
        controller: isActiveTab ? _activeScrollController : _pastScrollController,
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 20.h),
        itemCount: orders.length + 1, // Orders + Need Help Card at bottom
        itemBuilder: (context, index) {
          if (index == orders.length) {
            return _buildNeedHelpCard(
              context,
              isDark,
              textColor,
              secondaryColor,
            );
          }

          final order = orders[index];
          return _buildOrderCard(
            context,
            order,
            isDark,
            textColor,
            secondaryColor,
          );
        },
      ),
    );
  }

  /// Single Order Card matching screenshot 3 (White card, ORD-ID, Confirmed pill, Placed on, Location, Items, Green total, Track Order & Invoice)
  Widget _buildOrderCard(
    BuildContext context,
    OrderModel order,
    bool isDark,
    Color textColor,
    Color secondaryColor,
  ) {
    final createdDate = order.createdAt?.toLocal();
    final fullOrderedStr = createdDate != null
        ? DateFormat('MMM dd, yyyy, hh:mm a').format(createdDate)
        : 'Dec 16, 2025, 03:08 PM';

    final totalItems = order.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final cleanId = (order.id.isNotEmpty ? order.id : order.orderNumber).replaceAll('#', '').trim();
    final addressCity = order.deliveryAddress.trim().isNotEmpty
        ? order.deliveryAddress.trim()
        : 'New York, NY';

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: () {
            Haptics.light();
            context.push('/orders/details/$cleanId');
          },
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Icon + Order ID + Status pill (Screenshot 3)
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF008A45).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: const Color(0xFF008A45),
                        size: 18.sp,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'Order ORD-${order.orderNumber.isNotEmpty ? order.orderNumber : (order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id.toUpperCase())}',
                        style: TextStyle(
                          fontSize: 14.5.sp,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    _buildScreenshotStatusPill(order),
                  ],
                ),

                SizedBox(height: 10.h),

                // Placed on date row (Screenshot 3)
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14.sp,
                      color: const Color(0xFF6B7280),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Placed on $fullOrderedStr',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 6.h),

                // Location row (Screenshot 3)
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14.sp,
                      color: const Color(0xFF6B7280),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      addressCity,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12.h),

                // Items list (Screenshot 3)
                Text(
                  'Items ($totalItems):',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                SizedBox(height: 4.h),
                if (order.items.isNotEmpty)
                  ...order.items.map((item) => Padding(
                        padding: EdgeInsets.only(top: 2.h),
                        child: Text(
                          '• ${item.name} × ${item.quantity}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                      ))
                else
                  Text(
                    '• ${order.restaurantName}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),

                SizedBox(height: 12.h),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6),
                ),
                SizedBox(height: 12.h),

                // Bottom row: Total on Left, [ Track Order → ] & [ Invoice ] on Right (Screenshot 3)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '₹${order.total.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF008A45),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            Haptics.light();
                            context.push('/orders/details/$cleanId');
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark ? AppColors.borderDark : const Color(0xFFD1D5DB),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          child: Text(
                            'Track Order →',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        OutlinedButton(
                          onPressed: () {
                            Haptics.light();
                            context.push('/orders/details/$cleanId');
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark ? AppColors.borderDark : const Color(0xFFD1D5DB),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          child: Text(
                            'Invoice',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildScreenshotStatusPill(OrderModel order) {
    if (order.isDelivered || order.orderStatus == 'delivered') {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          'Delivered',
          style: TextStyle(
            color: const Color(0xFF2E7D32),
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    if (order.isCancelled || order.orderStatus.contains('cancelled')) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          'Cancelled',
          style: TextStyle(
            color: const Color(0xFFC62828),
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    // Offline payment waiting for the admin: not confirmed yet.
    if (order.isOfflinePaymentPending) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E6),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          'Payment under verification',
          style: TextStyle(
            color: const Color(0xFFB45309),
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF3FE),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        'Confirmed',
        style: TextStyle(
          color: const Color(0xFF1976D2),
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Need Help? Card at bottom of screen matching screenshot
  Widget _buildNeedHelpCard(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color secondaryColor,
  ) {
    return Container(
      margin: EdgeInsets.only(top: 6.h, bottom: 20.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primaryTintDark : AppColors.primaryTint,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? AppColors.primaryTintDarkStrong : AppColors.primaryTintStrong,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(7.r),
            decoration: BoxDecoration(
              color: AppColors.primaryTintStrong,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: AppColors.primary,
              size: 18.sp,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need Help?',
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'For any issue with your order, contact our support team.',
                  style: TextStyle(fontSize: 10.5.sp, color: secondaryColor),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          InkWell(
            onTap: () {
              Haptics.light();
              context.push(RouteNames.helpSupport);
            },
            borderRadius: BorderRadius.circular(20.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: AppColors.primaryTintStrong, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.headset_mic_rounded,
                    color: AppColors.primary,
                    size: 14.sp,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'Contact Support',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
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
}