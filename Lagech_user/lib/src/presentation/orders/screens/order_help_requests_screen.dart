import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/order_help_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_refresh_indicator.dart';
import '../../navigation/back_navigation.dart';
import '../viewmodels/order_help_viewmodel.dart';
import '../widgets/order_help_card.dart';

/// The customer's refund requests and reported order issues, with their
/// status and Lagech's reply. Opened from Profile and from an order's help card.
class OrderHelpRequestsScreen extends ConsumerWidget {
  const OrderHelpRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
            onPressed: () {
              Haptics.light();
              context.backOr();
            },
          ),
          title: Text(
            'Refunds & reports',
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: secondary,
            indicatorColor: AppColors.primary,
            tabs: const [Tab(text: 'Refund requests'), Tab(text: 'Reported issues')],
          ),
        ),
        body: TabBarView(
          children: [
            _AsyncList<RefundRequest>(
              value: ref.watch(myRefundRequestsProvider),
              onRefresh: () => ref.refresh(myRefundRequestsProvider.future),
              emptyText: 'You have not asked for any refunds.',
              itemBuilder: (r) => _HelpTile(
                orderId: r.orderId,
                orderNumber: r.orderDisplayId,
                title: r.reason,
                note: r.note,
                date: r.createdAt,
                status: r.status,
                statusLabel: r.statusLabel,
                detail: r.status == 'refunded' && r.refundedAmount != null
                    ? '₹${r.refundedAmount!.toStringAsFixed(2)} refunded to your ${r.refundMethodLabel}'
                    : 'Requested ₹${r.requestedAmount.toStringAsFixed(2)}',
                reply: r.adminNote,
              ),
            ),
            _AsyncList<OrderIssueReport>(
              value: ref.watch(myOrderIssueReportsProvider),
              onRefresh: () => ref.refresh(myOrderIssueReportsProvider.future),
              emptyText: 'You have not reported any issues.',
              itemBuilder: (i) => _HelpTile(
                orderId: i.orderId,
                orderNumber: i.orderDisplayId,
                title: i.reason,
                note: i.note,
                date: i.createdAt,
                status: i.status,
                statusLabel: i.statusLabel,
                detail: '',
                reply: i.adminResponse,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AsyncList<T> extends StatelessWidget {
  final AsyncValue<List<T>> value;
  final Future<void> Function() onRefresh;
  final String emptyText;
  final Widget Function(T item) itemBuilder;

  const _AsyncList({
    required this.value,
    required this.onRefresh,
    required this.emptyText,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    Widget message(String text, {bool retry = false}) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 80),
            Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: secondary)),
            if (retry) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: onRefresh,
                  child: Text('RETRY', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        );

    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => message('Could not load this list. Please check your connection.', retry: true),
        data: (items) => items.isEmpty
            ? message(emptyText)
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) => itemBuilder(items[index]),
              ),
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  final String orderId;
  final String orderNumber;
  final String title;
  final String note;
  final DateTime? date;
  final String status;
  final String statusLabel;
  final String detail;
  final String reply;

  const _HelpTile({
    required this.orderId,
    required this.orderNumber,
    required this.title,
    required this.note,
    required this.date,
    required this.status,
    required this.statusLabel,
    required this.detail,
    required this.reply,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: orderId.isEmpty
          ? null
          : () {
              Haptics.light();
              context.push('/orders/details/$orderId');
            },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #$orderNumber',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
                  ),
                ),
                HelpStatusChip(label: statusLabel, status: status),
              ],
            ),
            if (date != null) ...[
              const SizedBox(height: 2),
              Text(DateFormat('d MMM yyyy, h:mm a').format(date!), style: TextStyle(fontSize: 11.5, color: secondary)),
            ],
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(note, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: secondary)),
            ],
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(detail, style: TextStyle(fontSize: 12, color: secondary)),
            ],
            if (reply.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryAlpha(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Lagech: $reply', style: TextStyle(fontSize: 12, color: textColor)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
