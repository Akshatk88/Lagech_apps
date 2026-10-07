import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';
import 'package:food_user_application/features/orders/data/orders_repository.dart';
import 'package:food_user_application/features/orders/presentation/screens/customer_qr_payment_screen.dart';

/// Collect a pay-at-delivery order at the door: the rider takes cash, or the
/// customer scans a Razorpay QR (the money goes to the company's account,
/// never to the rider). Pops `true` once the order is paid or cash is
/// confirmed, and the caller moves on to completing the delivery.
class CollectPaymentSheet extends ConsumerStatefulWidget {
  const CollectPaymentSheet({super.key, required this.order});

  final DeliveryOrder order;

  @override
  ConsumerState<CollectPaymentSheet> createState() => _CollectPaymentSheetState();
}

class _CollectPaymentSheetState extends ConsumerState<CollectPaymentSheet> {
  bool _collecting = false;
  String? _error;

  /// Cash: confirm the amount with the rider, then switch the order to cash
  /// (`POST collect/cash`). The backend marks it paid when the delivery is
  /// completed.
  Future<void> _collectCash() async {
    final amount = widget.order.cashToCollect;
    final confirmed = await confirmCashReceived(context, amount);
    if (confirmed != true || !mounted) return;

    setState(() {
      _collecting = true;
      _error = null;
    });
    final result = await ref.read(ordersRepositoryProvider).collectCash(widget.order.id);
    if (!mounted) return;
    result.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (error) => setState(() {
        _error = error.message;
        _collecting = false;
      }),
    );
  }

  /// QR: full-screen QR for the customer. `true` = paid (or the rider switched
  /// to cash and confirmed it there).
  Future<void> _customerPaysByQr() async {
    setState(() => _error = null);
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CustomerQrPaymentScreen(order: widget.order),
      ),
    );
    if (done == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1E1E1E);
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final order = widget.order;

    return SafeArea(
      child: Container(
        margin: EdgeInsets.all(12.w),
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(28.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Collect Payment',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: textColor),
                ),
                // Only the cash part of a wallet + cash order (server
                // `amountToCollect`); the order total for an older backend.
                Text(
                  '₹${order.cashToCollect.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: theme.primaryColor),
                ),
              ],
            ),
            if (order.isPartiallyPrepaid) ...[
              SizedBox(height: 6.h),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Bill ₹${order.total.toStringAsFixed(0)} · ₹${(order.total - order.cashToCollect).toStringAsFixed(0)} already paid from the customer\'s wallet',
                  style: TextStyle(fontSize: 12.sp, color: subTextColor),
                ),
              ),
            ],
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              onPressed: _collecting ? null : _customerPaysByQr,
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text('Customer pays by QR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
            ),
            SizedBox(height: 12.h),
            OutlinedButton.icon(
              onPressed: _collecting ? null : _collectCash,
              icon: _collecting
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor),
                    )
                  : const Icon(Icons.money_rounded),
              label: Text('Collect cash ₹${order.cashToCollect.toStringAsFixed(0)}'),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 48.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: 8.h),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Have you received ₹X in cash?" — shared by the sheet and the QR screen's
/// "Switch to cash".
Future<bool?> confirmCashReceived(BuildContext context, double amount) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Collect cash'),
      content: Text('Collect ₹${amount.toStringAsFixed(0)} in cash from the customer. Have you received it?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not yet'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Cash received'),
        ),
      ],
    ),
  );
}
