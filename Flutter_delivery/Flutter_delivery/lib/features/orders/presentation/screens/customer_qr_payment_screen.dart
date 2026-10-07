import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/core/services/socket_service.dart';
import 'package:food_user_application/features/orders/data/models/collect_payment.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';
import 'package:food_user_application/features/orders/data/orders_repository.dart';
import 'package:food_user_application/features/orders/presentation/widgets/collect_payment_sheet.dart';
import 'package:share_plus/share_plus.dart';

/// Full-screen Razorpay QR the customer scans at the door.
///
/// The QR is raised by the backend (`POST collect/qr`) for exactly what the
/// customer owes; the money goes to the company's Razorpay account. Payment
/// is picked up from the `payment_received` socket event and, in case the
/// socket is down, by polling `GET payment-status` every 3 seconds.
///
/// Pops `true` when the order is paid (or the rider switched to cash and
/// confirmed it), so the caller continues to complete the delivery.
class CustomerQrPaymentScreen extends ConsumerStatefulWidget {
  const CustomerQrPaymentScreen({super.key, required this.order});

  final DeliveryOrder order;

  @override
  ConsumerState<CustomerQrPaymentScreen> createState() => _CustomerQrPaymentScreenState();
}

class _CustomerQrPaymentScreenState extends ConsumerState<CustomerQrPaymentScreen> {
  static const _pollEvery = Duration(seconds: 3);

  CollectQr? _qr;
  bool _loading = true;
  bool _switching = false;
  bool _paid = false;
  double? _paidAmount;
  String? _notice;
  String? _error;
  Duration _remaining = Duration.zero;

  Timer? _pollTimer;
  Timer? _clockTimer;
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _socketSub = ref.read(socketServiceProvider).onPaymentReceived.listen(_onSocketPayment);
    _createQr();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _clockTimer?.cancel();
    _socketSub?.cancel();
    super.dispose();
  }

  Future<void> _createQr() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(ordersRepositoryProvider).createCollectQr(widget.order.id);
    if (!mounted) return;
    result.when(
      success: (qr) {
        setState(() {
          _qr = qr;
          _loading = false;
        });
        _startTimers();
      },
      failure: (error) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
        // "Order already paid": the customer paid before the screen opened.
        _checkStatus();
      },
    );
  }

  void _startTimers() {
    _tick();
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollEvery, (_) => _checkStatus());
  }

  void _tick() {
    final expiresAt = _qr?.expiresAt;
    if (!mounted || expiresAt == null) return;
    final left = expiresAt.difference(DateTime.now());
    setState(() => _remaining = left.isNegative ? Duration.zero : left);
  }

  bool get _expired => !_paid && _qr != null && (_qr!.isExpired || (_qr!.expiresAt != null && _remaining == Duration.zero));

  Future<void> _checkStatus() async {
    if (_polling || _paid) return;
    _polling = true;
    final result = await ref.read(ordersRepositoryProvider).getPaymentStatus(widget.order.id);
    _polling = false;
    if (!mounted || _paid) return;
    result.when(
      success: (status) {
        if (status.paid) {
          _markPaid(status.amount > 0 ? status.amount : (_qr?.amount ?? widget.order.cashToCollect),
              byQr: status.paidByQr);
          return;
        }
        final serverQr = status.qr;
        if (serverQr != null && _qr != null && serverQr.status == 'expired' && !_qr!.isExpired) {
          setState(() => _qr = serverQr);
        }
      },
      failure: (_) {},
    );
  }

  void _onSocketPayment(Map<String, dynamic> event) {
    if (_paid || !mounted) return;
    final id = event['orderId']?.toString();
    final code = event['orderCode']?.toString();
    final order = widget.order;
    if (id != order.id && (code == null || code != order.orderCode)) return;
    final amount = event['amount'];
    _markPaid(amount is num ? amount.toDouble() : (_qr?.amount ?? order.cashToCollect), byQr: true);
  }

  void _markPaid(double amount, {required bool byQr}) {
    _pollTimer?.cancel();
    _clockTimer?.cancel();
    setState(() {
      _paid = true;
      _paidAmount = amount;
      _error = null;
      _notice = byQr ? 'Do not collect cash — the customer has paid online.' : null;
    });
  }

  Future<void> _switchToCash() async {
    final confirmed = await confirmCashReceived(context, widget.order.cashToCollect);
    if (confirmed != true || !mounted) return;
    setState(() {
      _switching = true;
      _error = null;
    });
    final result = await ref.read(ordersRepositoryProvider).collectCash(widget.order.id);
    if (!mounted) return;
    result.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (error) {
        setState(() {
          _switching = false;
          _error = error.message;
        });
        // Refused because the QR was paid meanwhile: show it as paid.
        _checkStatus();
      },
    );
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment link copied')));
  }

  String _formatRemaining(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1E1E1E);
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final amount = _qr?.amount ?? widget.order.cashToCollect;

    return PopScope(
      canPop: !_paid,
      onPopInvokedWithResult: (didPop, _) {
        // Once paid, leaving the screen continues to the delivery step.
        if (!didPop && _paid) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Order #${widget.order.orderCode}'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _paid ? 'Payment received' : 'Ask the customer to scan and pay',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.sp, color: subTextColor),
                ),
                SizedBox(height: 6.h),
                Text(
                  '₹${(_paidAmount ?? amount).toStringAsFixed(0)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 34.sp, fontWeight: FontWeight.w900, color: textColor),
                ),
                SizedBox(height: 20.h),
                if (_paid)
                  _PaidPanel(amount: _paidAmount ?? amount, notice: _notice)
                else if (_loading)
                  SizedBox(height: 280.w, child: const Center(child: CircularProgressIndicator()))
                else if (_qr != null)
                  _expired ? _ExpiredPanel(textColor: textColor) : _QrPanel(qr: _qr!, onCopy: _copyLink)
                else
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.h),
                    child: Icon(Icons.qr_code_2_rounded, size: 80.sp, color: Colors.grey),
                  ),
                if (!_paid && _qr != null && !_expired && !_loading) ...[
                  SizedBox(height: 14.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14.w,
                        height: 14.w,
                        child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Waiting for payment · expires in ${_formatRemaining(_remaining)}',
                        style: TextStyle(fontSize: 12.sp, color: subTextColor),
                      ),
                    ],
                  ),
                ],
                if (_error != null && !_paid) ...[
                  SizedBox(height: 12.h),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.redAccent, fontSize: 12.sp),
                  ),
                ],
                SizedBox(height: 24.h),
                if (_paid)
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.done_all_rounded),
                    label: const Text('Continue to delivery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    ),
                  )
                else ...[
                  if (_expired || (_qr == null && !_loading))
                    ElevatedButton.icon(
                      onPressed: _switching ? null : _createQr,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(_qr == null ? 'Try again' : 'Create new QR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 48.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      ),
                    ),
                  SizedBox(height: 12.h),
                  OutlinedButton.icon(
                    onPressed: _switching || _loading ? null : _switchToCash,
                    icon: _switching
                        ? SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor),
                          )
                        : const Icon(Icons.money_rounded),
                    label: const Text('Switch to cash'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(double.infinity, 48.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QrPanel extends StatelessWidget {
  const _QrPanel({required this.qr, required this.onCopy});

  final CollectQr qr;
  final Future<void> Function(String url) onCopy;

  @override
  Widget build(BuildContext context) {
    final imageUrl = qr.imageUrl;
    if (imageUrl != null) {
      return Center(
        child: Container(
          padding: EdgeInsets.all(10.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 290.w,
              fit: BoxFit.contain,
              placeholder: (_, _) => SizedBox(
                width: 290.w,
                height: 290.w,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => SizedBox(
                width: 290.w,
                height: 120.h,
                child: Center(
                  child: Text(
                    'Could not load the QR. Check the internet and try "Switch to cash" if needed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Payment-link fallback (no QR Codes on the Razorpay account): no QR
    // package in the app, so the link is shown to copy or share instead.
    final link = qr.shortUrl ?? '';
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.link_rounded, size: 40.sp, color: Theme.of(context).primaryColor),
          SizedBox(height: 8.h),
          Text(
            'Share this payment link with the customer',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8.h),
          SelectableText(link, textAlign: TextAlign.center, style: TextStyle(fontSize: 14.sp)),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: link.isEmpty ? null : () => onCopy(link),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy'),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: link.isEmpty
                      ? null
                      : () => SharePlus.instance.share(ShareParams(text: 'Pay for your order: $link')),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpiredPanel extends StatelessWidget {
  const _ExpiredPanel({required this.textColor});

  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 32.h),
      child: Column(
        children: [
          Icon(Icons.timer_off_rounded, size: 56.sp, color: Colors.orange),
          SizedBox(height: 10.h),
          Text(
            'This QR has expired',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: textColor),
          ),
          SizedBox(height: 4.h),
          Text(
            'Create a new QR or collect cash.',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _PaidPanel extends StatelessWidget {
  const _PaidPanel({required this.amount, this.notice});

  final double amount;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green, size: 72.sp),
          SizedBox(height: 12.h),
          Text(
            'Paid ✓ ₹${amount.toStringAsFixed(0)} received',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: Colors.green[700]),
          ),
          if (notice != null) ...[
            SizedBox(height: 8.h),
            Text(
              notice!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.green[800]),
            ),
          ],
        ],
      ),
    );
  }
}
