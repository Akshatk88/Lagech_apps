import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/order_help_model.dart';
import '../../../data/models/order_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/order_help_viewmodel.dart';
import 'order_help_sheet.dart';

/// "Need help with this order?" on the order details screen.
///
/// Refund: only for a delivered order, and only offered when the server says
/// the order is eligible (`GET /food/user/orders/:id/refund-request`);
/// otherwise the server's own reason is shown, with the latest request's
/// status and the admin's note. Report an issue: any placed order, with the
/// latest report's status and the admin's reply.
class OrderHelpCard extends ConsumerWidget {
  final OrderModel order;

  const OrderHelpCard({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (order.orderStatus.toLowerCase() == 'pending_payment') return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final refundAsync = order.isDelivered ? ref.watch(orderRefundStateProvider(order.id)) : null;
    final issuesAsync = ref.watch(orderIssueReportsProvider(order.id));
    final refund = refundAsync?.asData?.value;
    final latestIssue = issuesAsync.asData?.value.firstOrNull;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Need help with this order?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Haptics.light();
                  context.push(RouteNames.orderHelpRequests);
                },
                child: Text(
                  'My requests',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
            ],
          ),
          if (refundAsync != null && refundAsync.isLoading) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (refund?.latest != null) ...[
            const SizedBox(height: 10),
            _RefundStatusRow(request: refund!.latest!, textColor: textColor, secondary: secondary),
          ],
          if (refund != null &&
              !refund.eligible &&
              refund.message.isNotEmpty &&
              (refund.latest == null || refund.latest!.status == 'rejected')) ...[
            const SizedBox(height: 8),
            Text(refund.message, style: TextStyle(fontSize: 12, color: secondary)),
          ],
          if (latestIssue != null) ...[
            const SizedBox(height: 10),
            _IssueStatusRow(issue: latestIssue, textColor: textColor, secondary: secondary),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (refund != null && refund.eligible) ...[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () async {
                      Haptics.light();
                      final sent = await OrderHelpSheet.show(
                        context,
                        kind: OrderHelpKind.refund,
                        orderId: order.id,
                        orderNumber: order.orderNumber,
                        maxAmount: refund.maxAmount,
                        refundTo: refund.refundTo,
                      );
                      if (sent && context.mounted) {
                        AppSnackbar.success(context, 'Refund request sent. We will update you here.');
                      }
                    },
                    child: Text(
                      refund.latest?.status == 'rejected' ? 'REQUEST AGAIN' : 'REQUEST REFUND',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: latestIssue != null && latestIssue.isOpen
                      ? null
                      : () async {
                          Haptics.light();
                          final sent = await OrderHelpSheet.show(
                            context,
                            kind: OrderHelpKind.issue,
                            orderId: order.id,
                            orderNumber: order.orderNumber,
                          );
                          if (sent && context.mounted) {
                            AppSnackbar.success(context, 'Thanks, we have your report.');
                          }
                        },
                  child: const Text(
                    'REPORT AN ISSUE',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color helpStatusColor(String status) => switch (status) {
      'refunded' || 'resolved' => AppColors.success,
      'rejected' => AppColors.error,
      _ => AppColors.warning,
    };

class HelpStatusChip extends StatelessWidget {
  final String label;
  final String status;

  const HelpStatusChip({super.key, required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = helpStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _RefundStatusRow extends StatelessWidget {
  final RefundRequest request;
  final Color textColor;
  final Color secondary;

  const _RefundStatusRow({required this.request, required this.textColor, required this.secondary});

  @override
  Widget build(BuildContext context) {
    final refunded = request.refundedAmount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Refund request · ${request.reason}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textColor),
              ),
            ),
            HelpStatusChip(label: request.statusLabel, status: request.status),
          ],
        ),
        if (request.status == 'refunded' && refunded != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '₹${refunded.toStringAsFixed(2)} refunded to your ${request.refundMethodLabel}',
              style: TextStyle(fontSize: 12, color: secondary),
            ),
          ),
        if (request.adminNote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Lagech: ${request.adminNote}', style: TextStyle(fontSize: 12, color: secondary)),
          ),
      ],
    );
  }
}

class _IssueStatusRow extends StatelessWidget {
  final OrderIssueReport issue;
  final Color textColor;
  final Color secondary;

  const _IssueStatusRow({required this.issue, required this.textColor, required this.secondary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Reported issue · ${issue.reason}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textColor),
              ),
            ),
            HelpStatusChip(label: issue.statusLabel, status: issue.status),
          ],
        ),
        if (issue.adminResponse.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Lagech: ${issue.adminResponse}', style: TextStyle(fontSize: 12, color: secondary)),
          ),
      ],
    );
  }
}
